import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import Pango from 'gi://Pango';
import St from 'gi://St';

import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';

import {
    createBrandIcon,
    createBrandIconChip,
    createHeaderIcon,
    drawQuotaBar,
    drawSparkline,
    drawTrend,
    headerGIcon,
} from './drawing.js';
import {disposeContext} from './panel.js';
import {errorLabel, t} from './i18n.js';

const APP_VERSION = '0.2.14';
const POPUP_WIDTH = 520;
const BUY_ME_A_COFFEE_URL = 'https://buymeacoffee.com/dwyi84d';

const INTERVAL_OPTIONS = [
    [60, '1분', '1m'],
    [180, '3분', '3m'],
    [300, '5분', '5m'],
    [900, '15분', '15m'],
];

const PROVIDER_META = {
    opencode: {
        title: 'OpenCode Go',
        gridName: 'OpenCode',
    },
    google_ai: {
        title: 'Google AI Pro',
        gridName: 'Google AI',
    },
    openrouter: {
        title: 'OpenRouter',
        gridName: 'OpenRouter',
    },
    codex: {
        title: 'Codex',
        gridName: 'Codex',
        localHint: ['~/.codex 또는 OPENAI_API_KEY', '~/.codex or OPENAI_API_KEY'],
    },
    claude: {
        title: 'Claude',
        gridName: 'Claude',
        localHint: ['~/.claude 또는 ANTHROPIC_API_KEY', '~/.claude or ANTHROPIC_API_KEY'],
    },
    cursor: {
        title: 'Cursor',
        gridName: 'Cursor',
        localHint: ['~/.cursor 또는 ~/.config/Cursor', '~/.cursor or ~/.config/Cursor'],
    },
    copilot: {
        title: 'Copilot',
        gridName: 'Copilot',
        localHint: ['~/.config/github-copilot', '~/.config/github-copilot'],
    },
    perplexity: {
        title: 'Perplexity',
        gridName: 'Perplexity',
        localHint: ['PERPLEXITY_API_KEY 환경변수', 'PERPLEXITY_API_KEY env var'],
    },
    deepseek: {
        title: 'DeepSeek',
        gridName: 'DeepSeek',
        localHint: ['DEEPSEEK_API_KEY 환경변수', 'DEEPSEEK_API_KEY env var'],
    },
};

function formatTimeHMS(epochSeconds) {
    if (!epochSeconds)
        return '--:--:--';
    const date = new Date(epochSeconds * 1000);
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    const seconds = String(date.getSeconds()).padStart(2, '0');
    return `${hours}:${minutes}:${seconds}`;
}

function formatMoney(value) {
    return `$${(Number(value) || 0).toFixed(2)}`;
}

function formatSpend(usd, costAvailable) {
    if (!costAvailable)
        return '—';
    return formatMoney(usd);
}

function formatShortNumber(count) {
    const n = Number(count) || 0;
    if (n >= 1_000_000_000)
        return `${(n / 1_000_000_000).toFixed(1)}B`;
    if (n >= 1_000_000)
        return `${(n / 1_000_000).toFixed(1)}M`;
    if (n >= 1_000)
        return `${(n / 1_000).toFixed(1)}K`;
    return String(Math.round(n));
}

function formatCompactTokens(count, unitLabel) {
    return `${formatShortNumber(count)} ${unitLabel}`;
}

function formatPercentLabel(percent) {
    const value = Number(percent) || 0;
    const num = Math.abs(value - Math.round(value)) < 0.005
        ? String(Math.round(value))
        : value.toFixed(2);
    return `${num}% ${t('남음', 'remaining')}`;
}

function softDivider(extraClass = '') {
    return new St.Widget({
        style_class: extraClass ? `aiusages-soft-divider ${extraClass}` : 'aiusages-soft-divider',
        x_expand: true,
    });
}

function rightAlignedCellWithLabel(text, styleClass, width) {
    const bin = new St.Bin({
        y_align: Clutter.ActorAlign.CENTER,
    });
    if (width)
        bin.set_width(width);
    const label = new St.Label({
        text,
        style_class: styleClass,
        x_expand: true,
        x_align: Clutter.ActorAlign.END,
        y_align: Clutter.ActorAlign.CENTER,
    });
    bin.set_child(label);
    return {bin, label};
}

function rightAlignedCell(text, styleClass, width) {
    return rightAlignedCellWithLabel(text, styleClass, width).bin;
}

function emptyTrend(recentLog = '') {
    return {
        today_spend_usd: 0,
        today_tokens: 0,
        yesterday_spend_usd: 0,
        yesterday_tokens: 0,
        last_30_days_spend_usd: 0,
        last_30_days_tokens: 0,
        daily_bars: new Array(30).fill(0.05),
        daily_points: [],
        daily_avg_spend_usd: 0,
        daily_avg_tokens: 0,
        peak_label: '',
        peak_tokens: 0,
        recent_log: recentLog,
        unit: 'tokens',
        cost_available: true,
    };
}

const SparklineArea = GObject.registerClass(
class SparklineArea extends St.DrawingArea {
    _init(bars) {
        super._init({
            style_class: 'aiusages-sparkline',
            x_expand: false,
            y_align: Clutter.ActorAlign.CENTER,
        });
        this._bars = bars ?? [];
        this.set_size(80, 14);
        this.connect('repaint', () => this._repaint());
    }

    setBars(bars) {
        this._bars = bars ?? [];
        this.queue_repaint();
    }

    _repaint() {
        const cr = this.get_context();
        try {
            const width = this.get_width() || 80;
            const height = this.get_height() || 14;
            drawSparkline(this, cr, this._bars, width, height);
        } finally {
            disposeContext(cr);
        }
    }
});

const TrendArea = GObject.registerClass(
class TrendArea extends St.DrawingArea {
    _init(points, onHover) {
        super._init({
            style_class: 'aiusages-chart',
            reactive: true,
            x_expand: true,
        });
        this._points = points;
        this._hover = null;
        this._onHover = onHover;

        this.set_height(96);
        this.connect('repaint', () => this._repaint());
        this.connect('motion-event', (_actor, event) => {
            this._updateHover(event);
            return Clutter.EVENT_PROPAGATE;
        });
        this.connect('leave-event', () => {
            this._hover = null;
            this.queue_repaint();
            this._onHover?.(null);
            return Clutter.EVENT_PROPAGATE;
        });
    }

    setPoints(points) {
        this._points = points ?? [];
        if (this._hover !== null) {
            if (this._hover >= this._points.length) {
                this._hover = null;
                this._onHover?.(null);
            } else if (this._points[this._hover]) {
                this._onHover?.(this._points[this._hover]);
            }
        }
        this.queue_repaint();
    }

    _repaint() {
        const cr = this.get_context();
        try {
            const width = Math.max(1, this.get_width());
            const height = Math.max(1, this.get_height());
            drawTrend(this, cr, this._points, width, height, this._hover);
        } finally {
            disposeContext(cr);
        }
    }

    _updateHover(event) {
        const points = this._points;
        if (!points || points.length === 0)
            return;

        const [x] = event.get_coords();
        const [originX] = this.get_transformed_position();
        const width = Math.max(1, this.get_width());
        const gap = 2;
        const barWidth = Math.max(2, (width - gap * (points.length - 1)) / points.length);
        const index = Math.floor((x - originX) / (barWidth + gap));
        const clamped = Math.max(0, Math.min(points.length - 1, index));

        if (clamped !== this._hover) {
            this._hover = clamped;
            this.queue_repaint();
        }
        this._onHover?.(points[clamped]);
    }
});

export class PopupView {
    constructor(indicator, extension) {
        this._menu = indicator.menu;
        this._extension = extension;

        this._menu.box.add_style_class_name('aiusages-menu');
        this._menu.box.set_width(POPUP_WIDTH);
        this._menu.actor?.set_offscreen_redirect?.(Clutter.OffscreenRedirect.AUTOMATIC_FOR_OPACITY);

        this._showProviderSettings = false;
        this._expandedTrendProvider = null;
        this._editingGoogleBilling = false;
        this._selectedBillingDay = 1;

        this._scroll = null;
        this._body = null;
        this._savedScrollY = 0;
        this._scrollToBottom = false;
        this._rebuildIdleId = 0;
        this._scrollRestoreId = 0;
        this._bodyUpdaters = [];
        this._lastBodyStructureKey = null;

        this._headerIcon = null;
        this._subtitleLabel = null;
        this._refreshBtn = null;
        this._intervalBtns = new Map();
        this._updateBtn = null;
        this._checkIcon = null;
        this._craftedLabel = null;

        this._buildSkeleton();
        this.updateStatus();
    }

    applyTheme() {
        const isDark = this._extension.isDarkTheme ? this._extension.isDarkTheme() : true;
        if (isDark) {
            this._menu.box.remove_style_class_name('aiusages-menu-light');
            this._menu.box.add_style_class_name('aiusages-menu-dark');
        } else {
            this._menu.box.remove_style_class_name('aiusages-menu-dark');
            this._menu.box.add_style_class_name('aiusages-menu-light');
        }
        return isDark;
    }

    destroy() {
        if (this._rebuildIdleId) {
            GLib.source_remove(this._rebuildIdleId);
            this._rebuildIdleId = 0;
        }
        if (this._scrollRestoreId) {
            GLib.source_remove(this._scrollRestoreId);
            this._scrollRestoreId = 0;
        }
        this._bodyUpdaters = [];
        this._lastBodyStructureKey = null;
        this._body = null;
        this._scroll = null;
        this._headerIcon = null;
        this._subtitleLabel = null;
        this._refreshBtn = null;
        this._intervalBtns?.clear();
        this._intervalBtns = null;
        this._updateBtn = null;
        this._checkIcon = null;
        this._craftedLabel = null;
    }

    scheduleRebuild() {
        if (this._rebuildIdleId)
            return;
        this._rebuildIdleId = GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
            this._rebuildIdleId = 0;
            this.rebuild();
            return GLib.SOURCE_REMOVE;
        });
    }

    _createSectionItem(styleClass) {
        const section = new PopupMenu.PopupMenuSection();
        section.actor.add_style_class_name(styleClass);
        return section;
    }

    _buildSkeleton() {
        const isDark = this.applyTheme();
        this._menu.removeAll();
        this._menu.box.set_width(POPUP_WIDTH);

        this._menu.addMenuItem(this._buildHeaderSection(isDark));

        const scrollSection = new PopupMenu.PopupMenuSection();
        const scroll = new St.ScrollView({
            style_class: 'aiusages-scroll',
            style: '-st-vfade-offset: 0px; -st-hfade-offset: 0px;',
            hscrollbar_policy: St.PolicyType.NEVER,
            vscrollbar_policy: St.PolicyType.EXTERNAL,
            overlay_scrollbars: false,
            enable_mouse_scrolling: true,
            x_expand: true,
            clip_to_allocation: true,
        });
        scroll.set_policy(St.PolicyType.NEVER, St.PolicyType.EXTERNAL);
        scroll.remove_effect_by_name?.('fade');
        const listSection = new PopupMenu.PopupMenuSection();
        listSection.actor.add_style_class_name('aiusages-body');
        scroll.add_child(listSection.actor);
        scrollSection.actor.add_child(scroll);
        this._menu.addMenuItem(scrollSection);

        this._scroll = scroll;
        this._body = listSection.actor;

        this._menu.addMenuItem(this._buildFooterSection());
    }

    updateStatus() {
        const isDark = this.applyTheme();
        if (this._headerIcon)
            this._headerIcon.gicon = headerGIcon(isDark);

        const state = this._extension.state;
        const version = this._extension.currentVersion ?? APP_VERSION;
        const loading = Boolean(this._extension.loading);

        if (this._subtitleLabel) {
            this._subtitleLabel.text = loading
                ? `v${version} · ${t('새로고침 중…', 'Refreshing…')}`
                : `v${version} · ${formatTimeHMS(state?.generated_at)}`;
        }

        if (this._refreshBtn) {
            this._refreshBtn.reactive = !loading;
            this._refreshBtn.can_focus = !loading;
            if (loading)
                this._refreshBtn.add_style_pseudo_class('insensitive');
            else
                this._refreshBtn.remove_style_pseudo_class('insensitive');
        }

        const currentInterval = this._extension.settings?.get_uint('refresh-interval') ?? 300;
        if (this._intervalBtns) {
            for (const [seconds, btn] of this._intervalBtns.entries()) {
                btn.style_class = currentInterval === seconds
                    ? 'aiusages-seg-btn aiusages-seg-btn-active'
                    : 'aiusages-seg-btn';
            }
        }

        this._syncUpdateButton();

        const showPercent = Boolean(this._extension.settings?.get_boolean('show-panel-percent'));
        if (this._checkIcon) {
            this._checkIcon.icon_name = showPercent ? 'checkbox-checked-symbolic' : 'checkbox-symbolic';
            this._checkIcon.style_class = showPercent
                ? 'aiusages-checkbox-icon-active'
                : 'aiusages-checkbox-icon';
        }

        if (this._craftedLabel) {
            const err = this._extension.lastError;
            this._craftedLabel.text = err
                ? `Crafted by MelissaSoft · ${err}`
                : state?.generated_at
                    ? 'Crafted by MelissaSoft'
                    : `Crafted by MelissaSoft · ${t('데이터 없음', 'No data')}`;
            this._craftedLabel.style_class = err ? 'aiusages-error-inline' : 'aiusages-crafted';
        }
    }

    _computeBodyStructureKey(isDark) {
        const order = this._extension.providerOrder();
        const activeOrder = order.filter(id => this._extension.isProviderEnabled(id));
        const state = this._extension.state;
        const billingDay = this._extension.settings?.get_uint('google-billing-day') ?? 0;

        const cardKeys = activeOrder.map(id => {
            const snap = state?.providers?.[id];
            const expanded = this._expandedTrendProvider === id;
            const pts = snap?.trend?.daily_points ?? [];
            const drawerKey = expanded
                ? `:exp:${pts.length}:${snap?.trend?.cost_available !== false ? 1 : 0}`
                : '';

            if (id === 'opencode') {
                const avail = Boolean(snap?.available);
                const err = avail && snap?.error && snap.error !== 'rate_limited' ? snap.error : '';
                return `${id}:${avail ? 1 : 0}:${err}${drawerKey}`;
            }
            if (id === 'google_ai') {
                const avail = Boolean(snap?.available);
                const rows = snap?.rows ?? [];
                const hasArgon = avail && Boolean(
                    rows.some(r => r.key === 'google_argon_weekly') ||
                    snap?.metrics?.google_argon_weekly !== undefined
                );
                const hasBilling = avail && billingDay > 0 && Boolean(snap?.billing?.date_string);
                const err = avail && snap?.error && snap.error !== 'rate_limited' ? snap.error : '';
                const edit = this._editingGoogleBilling ? (billingDay > 0 ? 'E1' : 'E0') : 'E-';
                return `${id}:${avail ? 1 : 0}:${hasArgon ? 1 : 0}:${hasBilling ? 1 : 0}:${err}:${edit}${drawerKey}`;
            }
            if (id === 'openrouter') {
                const conn = Boolean(snap?.connected);
                const err = !conn && snap?.error && snap.error !== 'missing_key' ? snap.error : '';
                return `${id}:${conn ? 1 : 0}:${err}${drawerKey}`;
            }
            const detected = this._extension.isProviderDetected(id);
            return `${id}:${detected ? 1 : 0}${drawerKey}`;
        });

        let mgmtKey = 'mgmt:0';
        if (this._showProviderSettings) {
            const tileStates = Object.keys(PROVIDER_META)
                .sort()
                .map(id => `${id}=${this._extension.isProviderEnabled(id) ? 1 : 0}:${this._extension.isProviderDetected(id) ? 1 : 0}`)
                .join(',');
            mgmtKey = `mgmt:1:${tileStates}`;
        }

        return `${isDark ? 'dark' : 'light'}|${cardKeys.join('|')}|${mgmtKey}`;
    }

    rebuild() {
        const isDark = this.applyTheme();
        this.updateStatus();
        if (!this._body)
            return;

        const nextKey = this._computeBodyStructureKey(isDark);
        if (nextKey === this._lastBodyStructureKey && this._bodyUpdaters.length > 0 && !this._scrollToBottom) {
            for (const updater of this._bodyUpdaters)
                updater();
            return;
        }

        if (this._scrollRestoreId) {
            GLib.source_remove(this._scrollRestoreId);
            this._scrollRestoreId = 0;
        }
        const prevAdj = this._scroll?.vadjustment ?? this._scroll?.vscroll?.adjustment;
        if (prevAdj)
            this._savedScrollY = prevAdj.value;

        this._body.destroy_all_children();
        this._bodyUpdaters = [];
        this._fillBody(this._body, isDark);
        this._lastBodyStructureKey = nextKey;

        const scrollToBottom = this._scrollToBottom;
        this._scrollToBottom = false;
        if (scrollToBottom || this._savedScrollY > 0) {
            const targetScroll = this._savedScrollY;
            this._scrollRestoreId = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
                this._scrollRestoreId = 0;
                const adj = this._scroll?.vadjustment ?? this._scroll?.vscroll?.adjustment;
                if (adj) {
                    const max = Math.max(0, adj.upper - adj.page_size);
                    adj.value = scrollToBottom ? max : Math.min(targetScroll, max);
                }
                return GLib.SOURCE_REMOVE;
            });
        }
    }

    // ------------------------------------------------------------------ //
    // Header & Footer
    // ------------------------------------------------------------------ //

    _buildHeaderSection(isDark) {
        const section = this._createSectionItem('aiusages-header');
        const row = new St.BoxLayout({x_expand: true, y_align: Clutter.ActorAlign.CENTER});

        const brandBox = new St.BoxLayout({
            style_class: 'aiusages-header-brand',
            y_align: Clutter.ActorAlign.CENTER,
        });
        this._headerIcon = createHeaderIcon(15, isDark);
        brandBox.add_child(this._headerIcon);

        const titles = new St.BoxLayout({vertical: true, style_class: 'aiusages-header-titles'});
        titles.add_child(new St.Label({text: 'AI Usages', style_class: 'aiusages-title'}));

        this._subtitleLabel = new St.Label({text: '', style_class: 'aiusages-subtitle'});
        titles.add_child(this._subtitleLabel);
        brandBox.add_child(titles);
        row.add_child(brandBox);

        row.add_child(new St.Widget({x_expand: true}));

        this._refreshBtn = new St.Button({
            style_class: 'aiusages-icon-button',
            can_focus: true,
            reactive: true,
            y_align: Clutter.ActorAlign.CENTER,
            child: new St.Icon({icon_name: 'view-refresh-symbolic', icon_size: 14}),
        });
        this._refreshBtn.accessible_name = t('새로고침', 'Refresh');
        this._refreshBtn.connect('clicked', () => this._extension.refresh(true));
        row.add_child(this._refreshBtn);

        const segmented = new St.BoxLayout({
            style_class: 'aiusages-segmented',
            y_align: Clutter.ActorAlign.CENTER,
        });
        for (const [seconds, korean, english] of INTERVAL_OPTIONS) {
            const btn = new St.Button({
                style_class: 'aiusages-seg-btn',
                can_focus: true,
                label: t(korean, english),
            });
            btn.connect('clicked', () => {
                this._extension.settings?.set_uint('refresh-interval', seconds);
                this.updateStatus();
            });
            this._intervalBtns.set(seconds, btn);
            segmented.add_child(btn);
        }
        row.add_child(segmented);

        this._updateBtn = new St.Button({
            style_class: 'aiusages-header-btn aiusages-header-update-idle',
            can_focus: true,
            reactive: true,
            y_align: Clutter.ActorAlign.CENTER,
            label: t('업데이트 확인', 'Check for Updates'),
        });
        this._updateBtn.connect('clicked', () => this._onUpdateButtonClicked());
        row.add_child(this._updateBtn);

        const settingsBtn = new St.Button({
            style_class: 'aiusages-icon-button aiusages-settings-icon-btn',
            can_focus: true,
            y_align: Clutter.ActorAlign.CENTER,
            child: new St.Icon({icon_name: 'emblem-system-symbolic', icon_size: 14}),
        });
        settingsBtn.accessible_name = t('설정', 'Settings');
        settingsBtn.connect('clicked', () => {
            this._menu.close();
            this._extension.openPreferences();
        });
        row.add_child(settingsBtn);

        section.actor.add_child(row);
        section.actor.add_child(softDivider('aiusages-header-divider'));
        return section;
    }

    _onUpdateButtonClicked() {
        if (this._extension.updateState === 'available')
            this._extension.promptInstallUpdate();
        else
            this._extension.checkForUpdates(true);
    }

    _syncUpdateButton() {
        if (!this._updateBtn)
            return;

        const updateState = this._extension.updateState ?? 'idle';
        let label;
        let styleClass = 'aiusages-header-btn aiusages-header-update-idle';
        let reactive = true;

        switch (updateState) {
        case 'available':
            label = `v${this._extension.latestVersion} ${t('업데이트', 'Update')}`;
            styleClass = 'aiusages-header-update-btn';
            break;
        case 'checking':
            label = t('확인 중…', 'Checking…');
            reactive = false;
            break;
        case 'installing':
            label = t('설치 중…', 'Updating…');
            reactive = false;
            break;
        case 'up_to_date':
            label = t('✓ 최신 버전', '✓ Up to date');
            reactive = false;
            break;
        case 'installed':
            label = t('✓ 업데이트됨', '✓ Updated');
            reactive = false;
            break;
        case 'failed':
            label = t('확인 실패', 'Check failed');
            break;
        default:
            label = t('업데이트 확인', 'Check for Updates');
            break;
        }

        this._updateBtn.style_class = styleClass;
        this._updateBtn.label = label;
        this._updateBtn.can_focus = reactive;
        this._updateBtn.reactive = reactive;
        if (reactive)
            this._updateBtn.remove_style_pseudo_class('insensitive');
        else
            this._updateBtn.add_style_pseudo_class('insensitive');
    }

    _buildFooterSection() {
        const section = this._createSectionItem('aiusages-footer');
        section.actor.add_child(softDivider('aiusages-footer-divider'));

        const row = new St.BoxLayout({
            x_expand: true,
            style_class: 'aiusages-footer-row',
            y_align: Clutter.ActorAlign.CENTER,
        });

        const checkContent = new St.BoxLayout({
            style_class: 'aiusages-checkbox-inner',
            y_align: Clutter.ActorAlign.CENTER,
        });
        this._checkIcon = new St.Icon({
            icon_name: 'checkbox-symbolic',
            icon_size: 13,
            style_class: 'aiusages-checkbox-icon',
        });
        checkContent.add_child(this._checkIcon);
        checkContent.add_child(new St.Label({
            text: t('탑바에 퍼센트 표시', 'Show % in Top Bar'),
            style_class: 'aiusages-footer-check-label',
        }));
        const checkBtn = new St.Button({
            style_class: 'aiusages-checkbox-btn',
            can_focus: true,
            child: checkContent,
        });
        checkBtn.connect('clicked', () => {
            const current = Boolean(this._extension.settings?.get_boolean('show-panel-percent'));
            this._extension.settings?.set_boolean('show-panel-percent', !current);
            this.updateStatus();
        });
        row.add_child(checkBtn);

        row.add_child(new St.Widget({x_expand: true}));

        const coffee = new St.Button({
            style_class: 'aiusages-coffee-btn',
            can_focus: true,
            label: `☕ ${t('커피 후원하기', 'Buy me a coffee')}`,
        });
        coffee.connect('clicked', () => {
            this._menu.close();
            try {
                Gio.AppInfo.launch_default_for_uri(BUY_ME_A_COFFEE_URL, null);
            } catch (error) {
                logError(error, 'AI Usages: failed to open support link');
            }
        });
        row.add_child(coffee);

        section.actor.add_child(row);

        const subRow = new St.BoxLayout({
            x_expand: true,
            style_class: 'aiusages-footer-meta',
            y_align: Clutter.ActorAlign.CENTER,
        });
        this._craftedLabel = new St.Label({
            text: 'Crafted by MelissaSoft',
            style_class: 'aiusages-crafted',
            x_expand: true,
            x_align: Clutter.ActorAlign.CENTER,
        });
        this._craftedLabel.clutter_text.ellipsize = Pango.EllipsizeMode.END;
        subRow.add_child(this._craftedLabel);
        section.actor.add_child(subRow);

        return section;
    }

    // ------------------------------------------------------------------ //
    // Body & Cards
    // ------------------------------------------------------------------ //

    _fillBody(body, isDark) {
        const order = this._extension.providerOrder();
        const activeOrder = order.filter(id => this._extension.isProviderEnabled(id));

        if (activeOrder.length === 0) {
            const empty = new St.BoxLayout({vertical: true, style_class: 'aiusages-empty'});
            empty.add_child(new St.Label({
                text: t('활성화된 프로바이더가 없습니다.', 'No active providers.'),
                style_class: 'aiusages-empty-title',
                x_align: Clutter.ActorAlign.CENTER,
            }));
            const hint = new St.Label({
                text: t(
                    "아래 '프로바이더 활성화 및 관리'에서 사용할 서비스를 체크해 주세요.",
                    'Check the services you want to track below.'
                ),
                style_class: 'aiusages-empty-subtitle',
                x_align: Clutter.ActorAlign.CENTER,
            });
            hint.clutter_text.line_wrap = true;
            empty.add_child(hint);
            body.add_child(empty);
        } else {
            activeOrder.forEach((id, idx) => {
                if (idx > 0)
                    body.add_child(softDivider('aiusages-section-divider'));
                body.add_child(this._providerCard(id, activeOrder, isDark));
            });
        }

        body.add_child(softDivider('aiusages-section-divider'));
        body.add_child(this._providerManagementSection(isDark));
    }

    _cardHeader(id, title, rightText, rightStyleClass, activeOrder, isDark, getRightState = null) {
        const head = new St.BoxLayout({
            style_class: 'aiusages-card-head',
            x_expand: true,
            y_align: Clutter.ActorAlign.CENTER,
        });

        const idx = activeOrder.indexOf(id);
        const canUp = idx > 0;
        const canDown = idx >= 0 && idx < activeOrder.length - 1;

        const arrows = new St.BoxLayout({style_class: 'aiusages-reorder-box', y_align: Clutter.ActorAlign.CENTER});
        const upBtn = new St.Button({
            style_class: canUp ? 'aiusages-reorder-btn' : 'aiusages-reorder-btn aiusages-reorder-disabled',
            reactive: canUp,
            can_focus: canUp,
            child: new St.Icon({icon_name: 'pan-up-symbolic', icon_size: 11}),
        });
        upBtn.accessible_name = t('위로 이동', 'Move Up');
        upBtn.connect('clicked', () => this._extension.moveProvider(id, -1));
        arrows.add_child(upBtn);

        const downBtn = new St.Button({
            style_class: canDown ? 'aiusages-reorder-btn' : 'aiusages-reorder-btn aiusages-reorder-disabled',
            reactive: canDown,
            can_focus: canDown,
            child: new St.Icon({icon_name: 'pan-down-symbolic', icon_size: 11}),
        });
        downBtn.accessible_name = t('아래로 이동', 'Move Down');
        downBtn.connect('clicked', () => this._extension.moveProvider(id, 1));
        arrows.add_child(downBtn);
        head.add_child(arrows);

        head.add_child(createBrandIcon(id, 16, isDark));
        head.add_child(new St.Label({
            text: title,
            style_class: 'aiusages-card-title',
            y_align: Clutter.ActorAlign.CENTER,
        }));

        head.add_child(new St.Widget({x_expand: true}));

        const badge = new St.Label({
            text: rightText || '',
            style_class: rightStyleClass || 'aiusages-card-meta',
            y_align: Clutter.ActorAlign.CENTER,
            visible: Boolean(rightText),
        });
        head.add_child(badge);

        if (getRightState) {
            this._bodyUpdaters.push(() => {
                const next = getRightState();
                badge.text = next?.text || '';
                badge.style_class = next?.styleClass || 'aiusages-card-meta';
                badge.visible = Boolean(next?.text);
            });
        }

        return head;
    }

    _providerCard(id, activeOrder, isDark) {
        const snapshot = this._extension.state?.providers?.[id];
        if (id === 'opencode')
            return this._openCodeCard(snapshot, activeOrder, isDark);
        if (id === 'google_ai')
            return this._googleAICard(snapshot, activeOrder, isDark);
        if (id === 'openrouter')
            return this._openRouterCard(snapshot, activeOrder, isDark);
        return this._genericCard(id, activeOrder, isDark);
    }

    // ------------------------------------------------------------------ //
    // OpenCode Go Card (Stacked Single-Column)
    // ------------------------------------------------------------------ //

    _openCodeCard(snapshot, activeOrder, isDark) {
        const card = new St.BoxLayout({vertical: true, style_class: 'aiusages-provider-card', x_expand: true});
        const getRightState = () => {
            const cur = this._extension.state?.providers?.opencode;
            return {
                text: cur?.billing?.date_string ? `• ${cur.billing.date_string}` : '',
                styleClass: 'aiusages-card-meta',
            };
        };
        const initRight = getRightState();
        card.add_child(this._cardHeader(
            'opencode',
            'OpenCode Go',
            initRight.text,
            initRight.styleClass,
            activeOrder,
            isDark,
            getRightState
        ));

        if (snapshot?.available) {
            const split = new St.BoxLayout({style_class: 'aiusages-two-col', x_expand: true});
            const leftCol = new St.BoxLayout({vertical: true, style_class: 'aiusages-col-left', x_expand: true});
            leftCol.set_width(232);

            const rowLabels = {
                opencode_5h: t('5시간 윈도우', '5-hour window'),
                opencode_weekly: t('주간', 'Weekly'),
                opencode_monthly: t('월간', 'Monthly'),
            };
            const getMetricData = key => {
                const cur = this._extension.state?.providers?.opencode;
                const entry = (cur?.rows ?? []).find(r => r.key === key);
                return {
                    percent: entry?.percent ?? cur?.metrics?.[key] ?? 0,
                    reset: entry?.reset ?? '-',
                    status: cur?.status,
                };
            };
            for (const key of ['opencode_5h', 'opencode_weekly', 'opencode_monthly']) {
                const initial = getMetricData(key);
                leftCol.add_child(this._quotaProgressBar(
                    'opencode',
                    key,
                    rowLabels[key],
                    initial.percent,
                    initial.reset,
                    initial.status,
                    () => getMetricData(key)
                ));
            }

            if (snapshot.error && snapshot.error !== 'rate_limited')
                leftCol.add_child(this._inlineErrorLabel(snapshot.error));

            split.add_child(leftCol);

            const getTrend = () => this._extension.state?.providers?.opencode?.trend ?? emptyTrend();
            const trendPair = this._trendSection('opencode', 'OpenCode Go', getTrend(), getTrend, isDark);
            trendPair.summary.set_width(234);
            split.add_child(trendPair.summary);
            card.add_child(split);

            if (trendPair.drawer)
                card.add_child(trendPair.drawer);
        } else {
            card.add_child(this._unavailableTile(
                t('OpenCode Go 인증 미감지', 'OpenCode Go Credentials Not Detected'),
                t(
                    '로컬 OpenCode 인증 파일(~/.local/share/opencode/opencode.db)이 없거나 로그인되지 않았습니다.',
                    'Local OpenCode credentials (~/.local/share/opencode/opencode.db) not found or not signed in.'
                )
            ));
        }

        return card;
    }

    // ------------------------------------------------------------------ //
    // Google AI Pro Card (Stacked Single-Column)
    // ------------------------------------------------------------------ //

    _googleAICard(snapshot, activeOrder, isDark) {
        const card = new St.BoxLayout({vertical: true, style_class: 'aiusages-provider-card', x_expand: true});
        const billingDay = this._extension.settings?.get_uint('google-billing-day') ?? 0;
        const getRightState = () => {
            const cur = this._extension.state?.providers?.google_ai;
            const day = this._extension.settings?.get_uint('google-billing-day') ?? 0;
            return {
                text: (day > 0 && cur?.billing?.date_string) ? `• ${cur.billing.date_string}` : '',
                styleClass: 'aiusages-card-meta',
            };
        };
        const initRight = getRightState();
        card.add_child(this._cardHeader(
            'google_ai',
            'Google AI Pro',
            initRight.text,
            initRight.styleClass,
            activeOrder,
            isDark,
            getRightState
        ));

        if (this._editingGoogleBilling)
            card.add_child(this._googleBillingEditor(billingDay));

        if (snapshot?.available) {
            const split = new St.BoxLayout({style_class: 'aiusages-two-col', x_expand: true});
            const leftCol = new St.BoxLayout({vertical: true, style_class: 'aiusages-col-left', x_expand: true});
            leftCol.set_width(232);

            const getMetricData = key => {
                const cur = this._extension.state?.providers?.google_ai;
                const entry = (cur?.rows ?? []).find(r => r.key === key);
                return {
                    percent: entry?.percent ?? cur?.metrics?.[key] ?? 0,
                    reset: entry?.reset ?? '-',
                    status: cur?.status,
                };
            };

            leftCol.add_child(new St.Label({
                text: t('5시간 윈도우', '5-hour window'),
                style_class: 'aiusages-sub-header',
            }));
            for (const [key, label] of [
                ['google_gemini_5h', t('Gemini 모델', 'Gemini Models')],
                ['google_claude_5h', 'Claude & GPT'],
            ]) {
                const initial = getMetricData(key);
                leftCol.add_child(this._quotaProgressBar(
                    'google_ai',
                    key,
                    label,
                    initial.percent,
                    initial.reset,
                    initial.status,
                    () => getMetricData(key)
                ));
            }

            leftCol.add_child(new St.Label({
                text: t('주간', 'Weekly'),
                style_class: 'aiusages-sub-header',
            }));
            for (const [key, label] of [
                ['google_gemini_weekly', t('Gemini 모델', 'Gemini Models')],
                ['google_claude_weekly', 'Claude & GPT'],
            ]) {
                const initial = getMetricData(key);
                leftCol.add_child(this._quotaProgressBar(
                    'google_ai',
                    key,
                    label,
                    initial.percent,
                    initial.reset,
                    initial.status,
                    () => getMetricData(key)
                ));
            }

            const rows = snapshot.rows ?? [];
            const argonEntry = rows.find(r => r.key === 'google_argon_weekly');
            if (argonEntry || snapshot.metrics?.google_argon_weekly !== undefined) {
                const initial = getMetricData('google_argon_weekly');
                leftCol.add_child(this._quotaProgressBar(
                    'google_ai',
                    'google_argon_weekly',
                    'Gemini 4 Argon',
                    initial.percent,
                    initial.reset,
                    initial.status,
                    () => getMetricData('google_argon_weekly')
                ));
            }

            // Monthly & Reset Day Row
            const monthlyLine = new St.BoxLayout({x_expand: true, y_align: Clutter.ActorAlign.CENTER, style_class: 'aiusages-monthly-line'});

            const monthlyInner = new St.BoxLayout({y_align: Clutter.ActorAlign.CENTER, style_class: 'aiusages-monthly-inner'});
            const monthlyDot = new St.Label({text: '○', style_class: 'aiusages-select-dot'});
            monthlyInner.add_child(monthlyDot);
            monthlyInner.add_child(new St.Icon({
                icon_name: 'x-office-calendar-symbolic',
                icon_size: 11,
                style_class: 'aiusages-muted-icon',
            }));
            const monthlyLabel = new St.Label({
                text: t('월간', 'Monthly'),
                style_class: 'aiusages-metric-label',
            });
            monthlyInner.add_child(monthlyLabel);
            const monthlyDateLabel = new St.Label({
                text: snapshot.billing?.date_string || '-',
                style_class: 'aiusages-monthly-value',
            });
            monthlyInner.add_child(monthlyDateLabel);

            const monthlyBtn = new St.Button({
                style_class: 'aiusages-quota-btn',
                can_focus: true,
                x_expand: true,
                child: monthlyInner,
            });
            monthlyBtn.connect('clicked', () => {
                this._extension.setPanelMetric('google_ai', 'google_monthly');
            });
            monthlyLine.add_child(monthlyBtn);

            const applyMonthly = () => {
                const selected = this._extension.panelMetricFor('google_ai') === 'google_monthly';
                monthlyDot.text = selected ? '●' : '○';
                monthlyDot.style_class = selected ? 'aiusages-select-dot-active' : 'aiusages-select-dot';
                monthlyLabel.style_class = selected ? 'aiusages-metric-label-selected' : 'aiusages-metric-label';
                monthlyBtn.style_class = selected ? 'aiusages-quota-btn aiusages-quota-btn-selected' : 'aiusages-quota-btn';
                monthlyDateLabel.text = this._extension.state?.providers?.google_ai?.billing?.date_string || '-';
            };
            applyMonthly();
            this._bodyUpdaters.push(applyMonthly);

            if (billingDay > 0 && snapshot.billing?.date_string) {
                const editBtn = new St.Button({
                    style_class: 'aiusages-pill-btn',
                    can_focus: true,
                    label: t('리셋일 변경', 'Change'),
                });
                editBtn.connect('clicked', () => {
                    this._selectedBillingDay = this._extension.settings?.get_uint('google-billing-day') || billingDay;
                    this._editingGoogleBilling = !this._editingGoogleBilling;
                    this.scheduleRebuild();
                });
                monthlyLine.add_child(editBtn);
            } else {
                const setBtn = new St.Button({
                    style_class: 'aiusages-pill-accent-btn',
                    can_focus: true,
                    label: t('+ 리셋일', '+ Reset'),
                });
                setBtn.connect('clicked', () => {
                    this._selectedBillingDay = new Date().getDate();
                    this._editingGoogleBilling = !this._editingGoogleBilling;
                    this.scheduleRebuild();
                });
                monthlyLine.add_child(setBtn);
            }
            leftCol.add_child(monthlyLine);

            if (snapshot.error && snapshot.error !== 'rate_limited')
                leftCol.add_child(this._inlineErrorLabel(snapshot.error));

            split.add_child(leftCol);

            const getTrend = () => this._extension.state?.providers?.google_ai?.trend ?? emptyTrend();
            const trendPair = this._trendSection('google_ai', 'Google AI Pro', getTrend(), getTrend, isDark);
            trendPair.summary.set_width(234);
            split.add_child(trendPair.summary);
            card.add_child(split);

            if (trendPair.drawer)
                card.add_child(trendPair.drawer);
        } else {
            card.add_child(this._unavailableTile(
                t('Google AI Pro (Antigravity) 미감지', 'Google AI Pro (Antigravity) Not Detected'),
                t(
                    'Antigravity CLI(agy) 또는 Google AI 계정 키링 토큰이 설치/로그인되어 있지 않습니다.',
                    'Antigravity CLI (agy) or Google AI keyring token is not installed or signed in.'
                )
            ));
        }

        return card;
    }

    _googleBillingEditor(currentDay) {
        const box = new St.BoxLayout({
            style_class: 'aiusages-billing-editor',
            x_expand: true,
            y_align: Clutter.ActorAlign.CENTER,
        });
        box.add_child(new St.Label({
            text: t('매월 리셋일:', 'Reset Day:'),
            style_class: 'aiusages-billing-editor-label',
        }));

        const dayValueLabel = new St.Label({
            text: `${this._selectedBillingDay}${t('일', 'th')}`,
            style_class: 'aiusages-billing-day-value',
        });

        const prevBtn = new St.Button({
            style_class: 'aiusages-step-btn',
            can_focus: true,
            child: new St.Icon({icon_name: 'go-previous-symbolic', icon_size: 11}),
        });
        prevBtn.connect('clicked', () => {
            this._selectedBillingDay = this._selectedBillingDay <= 1 ? 31 : this._selectedBillingDay - 1;
            dayValueLabel.text = `${this._selectedBillingDay}${t('일', 'th')}`;
        });
        box.add_child(prevBtn);

        box.add_child(dayValueLabel);

        const nextBtn = new St.Button({
            style_class: 'aiusages-step-btn',
            can_focus: true,
            child: new St.Icon({icon_name: 'go-next-symbolic', icon_size: 11}),
        });
        nextBtn.connect('clicked', () => {
            this._selectedBillingDay = this._selectedBillingDay >= 31 ? 1 : this._selectedBillingDay + 1;
            dayValueLabel.text = `${this._selectedBillingDay}${t('일', 'th')}`;
        });
        box.add_child(nextBtn);

        box.add_child(new St.Widget({x_expand: true}));

        const saveBtn = new St.Button({
            style_class: 'aiusages-editor-save-btn',
            can_focus: true,
            label: t('저장', 'Save'),
        });
        saveBtn.connect('clicked', () => {
            this._editingGoogleBilling = false;
            this._extension.settings?.set_uint('google-billing-day', this._selectedBillingDay);
            this.scheduleRebuild();
        });
        box.add_child(saveBtn);

        if (currentDay > 0) {
            const resetBtn = new St.Button({
                style_class: 'aiusages-editor-btn',
                can_focus: true,
                label: t('초기화', 'Reset'),
            });
            resetBtn.connect('clicked', () => {
                this._editingGoogleBilling = false;
                this._extension.settings?.set_uint('google-billing-day', 0);
                this.scheduleRebuild();
            });
            box.add_child(resetBtn);
        }

        const closeBtn = new St.Button({
            style_class: 'aiusages-editor-close-btn',
            can_focus: true,
            child: new St.Icon({icon_name: 'window-close-symbolic', icon_size: 11}),
        });
        closeBtn.connect('clicked', () => {
            this._editingGoogleBilling = false;
            this.scheduleRebuild();
        });
        box.add_child(closeBtn);

        return box;
    }

    // ------------------------------------------------------------------ //
    // OpenRouter Card (Stacked Single-Column)
    // ------------------------------------------------------------------ //

    _openRouterCard(snapshot, activeOrder, isDark) {
        const card = new St.BoxLayout({vertical: true, style_class: 'aiusages-provider-card', x_expand: true});
        const getBalanceStr = () => {
            const cur = this._extension.state?.providers?.openrouter;
            const balanceRow = (cur?.rows ?? []).find(r => r.key === 'balance');
            return balanceRow?.value || '—';
        };
        const getRightState = () => {
            const cur = this._extension.state?.providers?.openrouter;
            const conn = Boolean(cur?.connected);
            if (conn)
                return {text: `${t('잔액', 'Balance')}: ${getBalanceStr()}`, styleClass: 'aiusages-accent-text'};
            if (cur?.error === 'invalid_key')
                return {text: `• ${t('키 오류', 'Invalid Key')}`, styleClass: 'aiusages-error-text'};
            return {text: `• ${t('키 미설정', 'Key Not Set')}`, styleClass: 'aiusages-card-meta'};
        };
        const initRight = getRightState();
        card.add_child(this._cardHeader(
            'openrouter',
            'OpenRouter',
            initRight.text,
            initRight.styleClass,
            activeOrder,
            isDark,
            getRightState
        ));

        const split = new St.BoxLayout({style_class: 'aiusages-two-col', x_expand: true});
        const leftCol = new St.BoxLayout({vertical: true, style_class: 'aiusages-col-left', x_expand: true});
        leftCol.set_width(232);

        const connected = Boolean(snapshot?.connected);
        const balanceStr = getBalanceStr();
        const statusRow = new St.BoxLayout({x_expand: true, y_align: Clutter.ActorAlign.CENTER, style_class: 'aiusages-openrouter-row'});
        const balanceLabel = new St.Label({
            text: connected ? balanceStr : '—',
            style_class: 'aiusages-balance-big',
        });
        statusRow.add_child(balanceLabel);
        statusRow.add_child(new St.Label({
            text: connected ? t('✓ 연동됨', '✓ Active') : t('키 등록 필요', 'Setup Required'),
            style_class: connected ? 'aiusages-green-badge' : 'aiusages-accent-badge',
            x_expand: true,
        }));

        this._bodyUpdaters.push(() => {
            const cur = this._extension.state?.providers?.openrouter;
            balanceLabel.text = cur?.connected ? getBalanceStr() : '—';
        });

        leftCol.add_child(statusRow);

        const keyBtn = new St.Button({
            style_class: connected ? 'aiusages-pill-btn' : 'aiusages-pill-accent-btn',
            can_focus: true,
            x_align: Clutter.ActorAlign.START,
            label: connected ? t('새 키 등록', 'Replace Key') : t('API 키 설정', 'Configure Key'),
        });
        keyBtn.connect('clicked', () => {
            this._menu.close();
            this._extension.openPreferences();
        });
        leftCol.add_child(keyBtn);

        if (!connected && snapshot?.error && snapshot.error !== 'missing_key')
            leftCol.add_child(this._inlineErrorLabel(snapshot.error));

        split.add_child(leftCol);

        const getTrend = () => {
            const cur = this._extension.state?.providers?.openrouter;
            return cur?.trend ?? emptyTrend(cur?.connected ? t('API 키 정상 연동됨', 'API Key Connected') : '');
        };
        const trendPair = this._trendSection('openrouter', 'OpenRouter', getTrend(), getTrend, isDark);
        trendPair.summary.set_width(234);
        split.add_child(trendPair.summary);
        card.add_child(split);

        if (trendPair.drawer)
            card.add_child(trendPair.drawer);

        return card;
    }

    // ------------------------------------------------------------------ //
    // Generic / Cursor Provider Card (Stacked Single-Column)
    // ------------------------------------------------------------------ //

    _genericCard(id, activeOrder, isDark) {
        const meta = PROVIDER_META[id] ?? {title: id, gridName: id};
        const detected = this._extension.isProviderDetected(id);
        const card = new St.BoxLayout({vertical: true, style_class: 'aiusages-provider-card', x_expand: true});

        let rightText;
        let rightClass;
        if (id === 'cursor') {
            rightText = detected ? `• ${t('감지됨', 'Detected')}` : `• ${t('미설치', 'Not Installed')}`;
            rightClass = detected ? 'aiusages-green-badge' : 'aiusages-card-meta';
        } else {
            rightText = detected ? `• ${t('연동됨', 'Active')}` : `• ${t('키 미설정', 'Key Not Set')}`;
            rightClass = detected ? 'aiusages-green-badge' : 'aiusages-card-meta';
        }
        card.add_child(this._cardHeader(id, meta.title, rightText, rightClass, activeOrder, isDark));

        const hintText = meta.localHint
            ? t(meta.localHint[0], meta.localHint[1])
            : t('로컬 설정 감지', 'Local configuration check');
        const statusRow = new St.BoxLayout({x_expand: true, y_align: Clutter.ActorAlign.CENTER, style_class: 'aiusages-generic-row'});
        statusRow.add_child(new St.Label({
            text: detected
                ? (id === 'cursor' ? t('Cursor 활성화', 'Cursor Active') : t('환경변수/로컬 감지', 'Detected Locally'))
                : (id === 'cursor' ? t('Cursor 미설치', 'Not Found') : t('미설정', 'Not Linked')),
            style_class: detected ? 'aiusages-generic-status-ok' : 'aiusages-generic-status-off',
        }));
        const pathLabel = new St.Label({
            text: `· ${hintText}`,
            style_class: 'aiusages-note',
            x_expand: true,
        });
        pathLabel.clutter_text.ellipsize = Pango.EllipsizeMode.END;
        statusRow.add_child(pathLabel);
        statusRow.add_child(new St.Label({
            text: detected
                ? (id === 'cursor' ? t('✓ 설치됨', '✓ Installed') : t('✓ 정상', '✓ OK'))
                : t('미감지', 'Missing'),
            style_class: detected ? 'aiusages-green-badge' : 'aiusages-card-meta',
        }));
        card.add_child(statusRow);

        const recentLog = detected
            ? (id === 'cursor'
                ? t('Cursor 로컬 설치 감지됨', 'Cursor Installed')
                : t('세션 연결됨 · 활동 대기', 'Session Connected · Ready'))
            : (id === 'cursor'
                ? t('Cursor 미설치', 'Cursor Not Installed')
                : t('API 연동 필요', 'Setup Required'));
        const trend = emptyTrend(recentLog);
        card.add_child(this._trendSection(id, meta.title, trend, null, isDark));

        return card;
    }

    // ------------------------------------------------------------------ //
    // Shared Progress Bar & Stacked Trend Section
    // ------------------------------------------------------------------ //

    _quotaProgressBar(providerId, metricKey, title, percent, resetInfo, barStatus, getEntryData = null) {
        let curPercent = percent;
        let curStatus = barStatus;
        const inner = new St.BoxLayout({vertical: true, style_class: 'aiusages-quota-inner', x_expand: true});

        const top = new St.BoxLayout({x_expand: true, y_align: Clutter.ActorAlign.CENTER});
        const left = new St.BoxLayout({x_expand: true, y_align: Clutter.ActorAlign.CENTER, style_class: 'aiusages-quota-title-row'});
        const dotLabel = new St.Label({
            text: '○',
            style_class: 'aiusages-select-dot',
        });
        left.add_child(dotLabel);
        const titleLabel = new St.Label({
            text: title,
            style_class: 'aiusages-metric-label',
        });
        titleLabel.clutter_text.ellipsize = Pango.EllipsizeMode.END;
        left.add_child(titleLabel);
        top.add_child(left);

        const valueLabel = new St.Label({
            text: formatPercentLabel(percent),
            style_class: 'aiusages-metric-value',
        });
        top.add_child(valueLabel);
        inner.add_child(top);

        const bar = new St.DrawingArea({
            style_class: 'aiusages-quota-bar',
            x_expand: true,
        });
        bar.set_height(5);
        bar.connect('repaint', () => {
            const cr = bar.get_context();
            try {
                const w = bar.get_width();
                const h = bar.get_height();
                if (w > 0 && h > 0)
                    drawQuotaBar(bar, cr, curPercent, curStatus, w, h);
            } finally {
                disposeContext(cr);
            }
        });
        inner.add_child(bar);

        const resetLabel = new St.Label({
            text: resetInfo && resetInfo !== '-' ? resetInfo : '',
            style_class: 'aiusages-metric-reset',
            visible: Boolean(resetInfo && resetInfo !== '-'),
        });
        resetLabel.clutter_text.ellipsize = Pango.EllipsizeMode.END;
        inner.add_child(resetLabel);

        const btn = new St.Button({
            style_class: 'aiusages-quota-btn',
            can_focus: true,
            x_expand: true,
            child: inner,
        });
        btn.connect('clicked', () => {
            this._extension.setPanelMetric(providerId, metricKey);
        });

        const apply = () => {
            const selected = this._extension.panelMetricFor(providerId) === metricKey;
            dotLabel.text = selected ? '●' : '○';
            dotLabel.style_class = selected ? 'aiusages-select-dot-active' : 'aiusages-select-dot';
            titleLabel.style_class = selected ? 'aiusages-metric-label-selected' : 'aiusages-metric-label';
            btn.style_class = selected ? 'aiusages-quota-btn aiusages-quota-btn-selected' : 'aiusages-quota-btn';

            if (getEntryData) {
                const data = getEntryData();
                const nextReset = data.reset ?? '-';
                if (nextReset && nextReset !== '-') {
                    resetLabel.text = nextReset;
                    resetLabel.visible = true;
                } else {
                    resetLabel.visible = false;
                }
                const nextPercent = data.percent ?? 0;
                const nextStatus = data.status;
                valueLabel.text = formatPercentLabel(nextPercent);
                if (curPercent !== nextPercent || curStatus !== nextStatus) {
                    curPercent = nextPercent;
                    curStatus = nextStatus;
                    bar.queue_repaint();
                }
            }
        };
        apply();
        this._bodyUpdaters.push(apply);

        return btn;
    }

    _trendSection(id, title, initialTrend, getTrend, isDark) {
        const trend = initialTrend;
        const box = new St.BoxLayout({vertical: true, style_class: 'aiusages-trend-section', x_expand: true});
        const expanded = this._expandedTrendProvider === id;

        const headContent = new St.BoxLayout({x_expand: true, y_align: Clutter.ActorAlign.CENTER});
        const titleGroup = new St.BoxLayout({y_align: Clutter.ActorAlign.CENTER, style_class: 'aiusages-trend-title-group'});
        titleGroup.add_child(new St.Label({
            text: t('사용 트렌드', 'Usage Trend'),
            style_class: 'aiusages-trend-title',
        }));
        titleGroup.add_child(new St.Label({
            text: expanded ? '↙' : '↗',
            style_class: 'aiusages-trend-expand-icon',
        }));
        headContent.add_child(titleGroup);
        headContent.add_child(new St.Widget({x_expand: true}));
        const sparkline = new SparklineArea(trend.daily_bars);
        headContent.add_child(sparkline);

        const headBtn = new St.Button({
            style_class: 'aiusages-trend-header-btn',
            can_focus: true,
            x_expand: true,
            child: headContent,
        });
        headBtn.connect('clicked', () => {
            this._expandedTrendProvider = expanded ? null : id;
            this.scheduleRebuild();
        });
        box.add_child(headBtn);

        const todayRow = this._trendMetricRow(t('오늘', 'Today'));
        const yesterdayRow = this._trendMetricRow(t('어제', 'Yesterday'));
        const monthRow = this._trendMetricRow(t('최근 30일', 'Last 30 Days'));
        box.add_child(todayRow.actor);
        box.add_child(yesterdayRow.actor);
        box.add_child(monthRow.actor);

        const metaRow = new St.BoxLayout({vertical: true, x_expand: true, style_class: 'aiusages-trend-meta-row'});
        const avgLabel = new St.Label({
            text: '',
            style_class: 'aiusages-trend-label-compact',
            x_expand: true,
        });
        avgLabel.clutter_text.ellipsize = Pango.EllipsizeMode.END;
        metaRow.add_child(avgLabel);

        const peakLabel = new St.Label({
            text: '',
            style_class: 'aiusages-trend-label-compact',
            x_expand: true,
            visible: false,
        });
        peakLabel.clutter_text.ellipsize = Pango.EllipsizeMode.END;
        metaRow.add_child(peakLabel);
        box.add_child(metaRow);

        const logRow = new St.BoxLayout({
            style_class: 'aiusages-log-pill',
            x_expand: true,
            y_align: Clutter.ActorAlign.CENTER,
            visible: false,
        });
        logRow.add_child(new St.Icon({
            icon_name: 'document-open-recent-symbolic',
            icon_size: 10,
            style_class: 'aiusages-muted-icon',
        }));
        const logLabel = new St.Label({
            text: '',
            style_class: 'aiusages-log-text',
            x_expand: true,
        });
        logLabel.clutter_text.ellipsize = Pango.EllipsizeMode.END;
        logRow.add_child(logLabel);
        box.add_child(logRow);

        const applyTrend = cur => {
            const unitLabel = cur.unit === 'steps' ? t('스텝', 'steps') : t('토큰', 'tokens');
            const costAvailable = cur.cost_available !== false;
            sparkline.setBars(cur.daily_bars);
            todayRow.update(
                formatSpend(cur.today_spend_usd, costAvailable),
                formatCompactTokens(cur.today_tokens, unitLabel)
            );
            yesterdayRow.update(
                formatSpend(cur.yesterday_spend_usd, costAvailable),
                formatCompactTokens(cur.yesterday_tokens, unitLabel)
            );
            monthRow.update(
                formatSpend(cur.last_30_days_spend_usd, costAvailable),
                formatCompactTokens(cur.last_30_days_tokens, unitLabel)
            );

            let avgText = `${t('일평균 사용', 'Daily Avg')}: `;
            if (costAvailable)
                avgText += `${formatMoney(cur.daily_avg_spend_usd)} · `;
            avgText += formatCompactTokens(cur.daily_avg_tokens, unitLabel);
            avgLabel.text = avgText;

            if (cur.peak_label && (Number(cur.peak_tokens) || 0) > 0) {
                peakLabel.text = `${t('최대', 'Peak')} ${cur.peak_label} (${formatCompactTokens(cur.peak_tokens, unitLabel)})`;
                peakLabel.visible = true;
            } else {
                peakLabel.visible = false;
            }

            if (cur.recent_log) {
                logLabel.text = cur.recent_log;
                logRow.visible = true;
            } else {
                logRow.visible = false;
            }
        };

        applyTrend(trend);
        if (getTrend)
            this._bodyUpdaters.push(() => applyTrend(getTrend()));

        const drawer = expanded ? this._detailedTrendDrawer(title, trend, getTrend, isDark) : null;

        return {summary: box, drawer};
    }

    _trendMetricRow(label) {
        const row = new St.BoxLayout({
            x_expand: true,
            y_align: Clutter.ActorAlign.CENTER,
            style_class: 'aiusages-trend-row',
        });
        const lbl = new St.Label({
            text: label,
            style_class: 'aiusages-trend-label',
            x_expand: true,
        });
        lbl.clutter_text.ellipsize = Pango.EllipsizeMode.END;
        row.add_child(lbl);

        const spendCell = rightAlignedCellWithLabel('', 'aiusages-trend-val', 44);
        const tokenCell = rightAlignedCellWithLabel('', 'aiusages-trend-val', 78);
        row.add_child(spendCell.bin);
        row.add_child(tokenCell.bin);
        return {
            actor: row,
            update: (spendText, tokenText) => {
                spendCell.label.text = spendText;
                tokenCell.label.text = tokenText;
            },
        };
    }

    // ------------------------------------------------------------------ //
    // Expandable 30-Day Detailed Trend Drawer
    // ------------------------------------------------------------------ //

    _detailedTrendDrawer(title, initialTrend, getTrend, isDark = true) {
        const trend = initialTrend;
        const drawer = new St.BoxLayout({vertical: true, style_class: 'aiusages-trend-drawer', x_expand: true});
        const points = trend.daily_points ?? [];
        const unitLabel = trend.unit === 'steps' ? t('스텝', 'steps') : t('토큰', 'tokens');
        const unitTitle = trend.unit === 'steps' ? t('총 스텝', 'Total Steps') : t('총 토큰', 'Total Tokens');
        const costAvailable = trend.cost_available !== false;

        const head = new St.BoxLayout({x_expand: true, y_align: Clutter.ActorAlign.CENTER, style_class: 'aiusages-drawer-head'});
        head.add_child(createHeaderIcon(13, isDark));
        const drawerTitle = new St.Label({
            text: `${title} ${t('상세 사용 트렌드', 'Detailed Usage Trend')}`,
            style_class: 'aiusages-drawer-title',
        });
        drawerTitle.clutter_text.ellipsize = Pango.EllipsizeMode.END;
        head.add_child(drawerTitle);
        const drawerSub = new St.Label({
            text: t('(최근 30일)', '(Last 30 Days)'),
            style_class: 'aiusages-drawer-subtitle',
            x_expand: true,
        });
        drawerSub.clutter_text.ellipsize = Pango.EllipsizeMode.END;
        head.add_child(drawerSub);
        const closeBtn = new St.Button({
            style_class: 'aiusages-editor-close-btn',
            can_focus: true,
            child: new St.Icon({icon_name: 'window-close-symbolic', icon_size: 12}),
        });
        closeBtn.connect('clicked', () => {
            this._expandedTrendProvider = null;
            this.scheduleRebuild();
        });
        head.add_child(closeBtn);
        drawer.add_child(head);

        const cards = new St.BoxLayout({vertical: true, x_expand: true, style_class: 'aiusages-metric-cards'});
        const totalTokCard = this._summaryMetricCardWithLabel(unitTitle, '', 'aiusages-summary-val');
        const totalCostCard = this._summaryMetricCardWithLabel(t('총 환산비용', 'Total Cost'), '', 'aiusages-summary-val-green');
        const avgCard = this._summaryMetricCardWithLabel(t('일평균 사용', 'Daily Avg'), '', 'aiusages-summary-val-accent');
        const peakCard = this._summaryMetricCardWithLabel(t('최대 사용일', 'Peak Day'), '', 'aiusages-summary-val');
        const cardsRow1 = new St.BoxLayout({x_expand: true, style_class: 'aiusages-metric-cards-row'});
        cardsRow1.layout_manager.homogeneous = true;
        cardsRow1.add_child(totalTokCard.card);
        cardsRow1.add_child(totalCostCard.card);
        const cardsRow2 = new St.BoxLayout({x_expand: true, style_class: 'aiusages-metric-cards-row'});
        cardsRow2.layout_manager.homogeneous = true;
        cardsRow2.add_child(avgCard.card);
        cardsRow2.add_child(peakCard.card);
        cards.add_child(cardsRow1);
        cards.add_child(cardsRow2);
        drawer.add_child(cards);

        const banner = new St.BoxLayout({
            x_expand: true,
            y_align: Clutter.ActorAlign.CENTER,
            style_class: 'aiusages-inspect-banner',
        });
        const tipText = t(
            '막대에 마우스를 올리면 일별 토큰과 비용을 확인할 수 있습니다.',
            'Hover over a bar to view daily tokens and spend.'
        );
        const tipLabel = new St.Label({text: tipText, style_class: 'aiusages-inspect-tip', x_expand: true});
        tipLabel.clutter_text.ellipsize = Pango.EllipsizeMode.END;

        const inspectRow = new St.BoxLayout({x_expand: true, y_align: Clutter.ActorAlign.CENTER, visible: false});
        const dot = new St.Widget({style_class: 'aiusages-inspect-dot'});
        const dateLbl = new St.Label({text: '', style_class: 'aiusages-inspect-date-lbl'});
        dateLbl.clutter_text.ellipsize = Pango.EllipsizeMode.END;
        const dateBox = new St.BoxLayout({style_class: 'aiusages-inspect-date', y_align: Clutter.ActorAlign.CENTER});
        dateBox.add_child(dot);
        dateBox.add_child(dateLbl);
        inspectRow.add_child(dateBox);

        inspectRow.add_child(new St.Label({text: '•', style_class: 'aiusages-inspect-sep'}));

        const tokValueLbl = new St.Label({
            text: '',
            style_class: 'aiusages-inspect-tok-val',
            x_expand: true,
            x_align: Clutter.ActorAlign.END,
            y_align: Clutter.ActorAlign.CENTER,
        });
        const tokBin = new St.Bin({y_align: Clutter.ActorAlign.CENTER});
        tokBin.set_width(44);
        tokBin.set_child(tokValueLbl);
        const tokBox = new St.BoxLayout({style_class: 'aiusages-inspect-tok', y_align: Clutter.ActorAlign.CENTER});
        tokBox.add_child(tokBin);
        tokBox.add_child(new St.Label({text: unitLabel, style_class: 'aiusages-inspect-unit'}));
        inspectRow.add_child(tokBox);

        const costSep = new St.Label({text: '•', style_class: 'aiusages-inspect-sep', visible: costAvailable});
        const costLbl = new St.Label({
            text: '',
            style_class: 'aiusages-inspect-cost-val',
            x_expand: true,
            x_align: Clutter.ActorAlign.END,
            y_align: Clutter.ActorAlign.CENTER,
        });
        const costBin = new St.Bin({y_align: Clutter.ActorAlign.CENTER, visible: costAvailable});
        costBin.set_width(46);
        costBin.set_child(costLbl);
        inspectRow.add_child(costSep);
        inspectRow.add_child(costBin);

        banner.add_child(tipLabel);
        banner.add_child(inspectRow);
        drawer.add_child(banner);

        const plotBox = new St.BoxLayout({vertical: true, style_class: 'aiusages-plot-box', x_expand: true});
        const chartRow = new St.BoxLayout({x_expand: true, style_class: 'aiusages-chart-row'});
        const yAxis = new St.BoxLayout({vertical: true, style_class: 'aiusages-y-axis'});
        yAxis.set_size(38, 96);
        const yTopCell = rightAlignedCellWithLabel('1', 'aiusages-axis-label', 38);
        const yMidCell = rightAlignedCellWithLabel('0', 'aiusages-axis-label', 38);
        yAxis.add_child(yTopCell.bin);
        yAxis.add_child(new St.Widget({y_expand: true}));
        yAxis.add_child(yMidCell.bin);
        yAxis.add_child(new St.Widget({y_expand: true}));
        yAxis.add_child(rightAlignedCell('0', 'aiusages-axis-label', 38));
        chartRow.add_child(yAxis);

        const toPlotPoints = pts => (pts.length > 0
            ? pts
            : Array.from({length: 30}, () => ({date: '', label: '', tokens: 0, spend_usd: 0, normalized: 0})));

        const area = new TrendArea(toPlotPoints(points), point => {
            if (!point || !point.date) {
                inspectRow.visible = false;
                tipLabel.visible = true;
                return;
            }
            tipLabel.visible = false;
            inspectRow.visible = true;
            dateLbl.text = `${point.date} (${point.label})`;
            tokValueLbl.text = formatShortNumber(point.tokens);
            if (costAvailable)
                costLbl.text = formatMoney(point.spend_usd);
        });
        chartRow.add_child(area);
        plotBox.add_child(chartRow);

        const xTickPairs = [];
        if (points.length > 0) {
            const xAxis = new St.BoxLayout({x_expand: true, style_class: 'aiusages-x-axis'});
            const yOffset = new St.Widget();
            yOffset.set_width(44);
            xAxis.add_child(yOffset);

            const tickIndices = [0, 7, 14, 21, points.length - 1]
                .filter((v, i, arr) => v >= 0 && v < points.length && arr.indexOf(v) === i);
            tickIndices.forEach((ptIdx, idx) => {
                if (idx > 0)
                    xAxis.add_child(new St.Widget({x_expand: true}));
                const lbl = new St.Label({
                    text: points[ptIdx].label,
                    style_class: idx === tickIndices.length - 1 ? 'aiusages-axis-label-today' : 'aiusages-axis-label',
                });
                xTickPairs.push({ptIdx, lbl});
                xAxis.add_child(lbl);
            });
            plotBox.add_child(xAxis);
        }

        drawer.add_child(plotBox);

        const applyDrawer = cur => {
            const curPts = cur.daily_points ?? [];
            const cAvail = cur.cost_available !== false;
            const maxTok = Math.max(1, ...curPts.map(p => Number(p.tokens) || 0));

            totalTokCard.label.text = formatShortNumber(cur.last_30_days_tokens);
            totalCostCard.label.text = cAvail ? formatMoney(cur.last_30_days_spend_usd) : '—';
            avgCard.label.text = formatShortNumber(Math.round((Number(cur.last_30_days_tokens) || 0) / Math.max(curPts.length, 30)));
            peakCard.label.text = cur.peak_label && (Number(cur.peak_tokens) || 0) > 0
                ? `${cur.peak_label}: ${formatShortNumber(cur.peak_tokens)}`
                : '-';

            yTopCell.label.text = formatShortNumber(maxTok);
            yMidCell.label.text = formatShortNumber(Math.floor(maxTok / 2));
            area.setPoints(toPlotPoints(curPts));

            for (const {ptIdx, lbl} of xTickPairs) {
                if (curPts[ptIdx])
                    lbl.text = curPts[ptIdx].label;
            }
        };

        applyDrawer(trend);
        if (getTrend)
            this._bodyUpdaters.push(() => applyDrawer(getTrend()));

        return drawer;
    }

    _summaryMetricCardWithLabel(title, value, valueClass) {
        const card = new St.BoxLayout({vertical: true, style_class: 'aiusages-summary-card', x_expand: true});
        const titleLbl = new St.Label({text: title, style_class: 'aiusages-summary-title'});
        titleLbl.clutter_text.ellipsize = Pango.EllipsizeMode.END;
        card.add_child(titleLbl);
        const val = new St.Label({text: value, style_class: valueClass});
        val.clutter_text.ellipsize = Pango.EllipsizeMode.END;
        card.add_child(val);
        return {card, label: val};
    }

    _unavailableTile(title, description) {
        const tile = new St.BoxLayout({style_class: 'aiusages-unavail-tile', x_expand: true, y_align: Clutter.ActorAlign.CENTER});
        tile.add_child(new St.Icon({
            icon_name: 'dialog-warning-symbolic',
            icon_size: 16,
            style_class: 'aiusages-accent-icon',
        }));
        const texts = new St.BoxLayout({vertical: true, x_expand: true, style_class: 'aiusages-unavail-texts'});
        texts.add_child(new St.Label({text: title, style_class: 'aiusages-unavail-title'}));
        const desc = new St.Label({text: description, style_class: 'aiusages-note'});
        desc.clutter_text.line_wrap = true;
        texts.add_child(desc);
        tile.add_child(texts);
        return tile;
    }

    _inlineErrorLabel(code) {
        const text = errorLabel(code);
        if (!text)
            return new St.Widget();
        const label = new St.Label({text, style_class: 'aiusages-error'});
        label.clutter_text.line_wrap = true;
        return label;
    }

    // ------------------------------------------------------------------ //
    // Provider Activation & Management (2-Column Grid inside ScrollView)
    // ------------------------------------------------------------------ //

    _providerManagementSection(isDark = true) {
        const section = new St.BoxLayout({vertical: true, style_class: 'aiusages-mgmt-section', x_expand: true});

        const header = new St.BoxLayout({x_expand: true, y_align: Clutter.ActorAlign.CENTER});
        header.add_child(new St.Label({
            text: t('프로바이더 활성화 및 관리', 'Provider Activation & Management'),
            style_class: 'aiusages-section-heading',
            x_expand: true,
        }));

        const toggleInner = new St.BoxLayout({y_align: Clutter.ActorAlign.CENTER, style_class: 'aiusages-collapse-inner'});
        toggleInner.add_child(new St.Icon({
            icon_name: this._showProviderSettings ? 'pan-up-symbolic' : 'pan-down-symbolic',
            icon_size: 11,
            style_class: 'aiusages-accent-icon',
        }));
        toggleInner.add_child(new St.Label({
            text: this._showProviderSettings ? t('접기', 'Collapse') : t('펼치기', 'Manage'),
            style_class: 'aiusages-collapse-label',
        }));
        const toggleBtn = new St.Button({
            style_class: 'aiusages-collapse-btn',
            can_focus: true,
            child: toggleInner,
        });
        toggleBtn.connect('clicked', () => {
            this._showProviderSettings = !this._showProviderSettings;
            this._scrollToBottom = this._showProviderSettings;
            this.scheduleRebuild();
        });
        header.add_child(toggleBtn);
        section.add_child(header);

        if (this._showProviderSettings) {
            const gridBox = new St.BoxLayout({vertical: true, style_class: 'aiusages-provider-grid-box', x_expand: true});
            const sortedIds = Object.keys(PROVIDER_META).sort((a, b) =>
                PROVIDER_META[a].gridName.localeCompare(PROVIDER_META[b].gridName, 'en', {sensitivity: 'base'})
            );

            for (let rowStart = 0; rowStart < sortedIds.length; rowStart += 2) {
                const row = new St.BoxLayout({style_class: 'aiusages-provider-grid-row', x_expand: true});
                row.layout_manager.homogeneous = true;
                for (let col = 0; col < 2; col++) {
                    const id = sortedIds[rowStart + col];
                    if (id)
                        row.add_child(this._providerGridTile(id, isDark));
                    else
                        row.add_child(new St.Widget({x_expand: true}));
                }
                gridBox.add_child(row);
            }
            section.add_child(gridBox);
        }

        return section;
    }

    _providerGridTile(id, isDark = true) {
        const meta = PROVIDER_META[id];
        const enabled = this._extension.isProviderEnabled(id);
        const detected = this._extension.isProviderDetected(id);

        const content = new St.BoxLayout({
            x_expand: true,
            y_align: Clutter.ActorAlign.CENTER,
            style_class: 'aiusages-grid-tile-inner',
        });
        content.add_child(createBrandIconChip(id, 15, detected, isDark));

        const nameLabel = new St.Label({
            text: meta.gridName,
            style_class: enabled ? 'aiusages-grid-name-active' : 'aiusages-grid-name',
            x_expand: true,
        });
        nameLabel.clutter_text.ellipsize = Pango.EllipsizeMode.END;
        content.add_child(nameLabel);

        const miniSwitch = new St.Bin({
            style_class: enabled ? 'aiusages-switch aiusages-switch-on' : 'aiusages-switch',
            y_align: Clutter.ActorAlign.CENTER,
            child: new St.Widget({
                style_class: 'aiusages-switch-knob',
                x_expand: true,
                x_align: enabled ? Clutter.ActorAlign.END : Clutter.ActorAlign.START,
                y_align: Clutter.ActorAlign.CENTER,
            }),
        });
        content.add_child(miniSwitch);

        const btn = new St.Button({
            style_class: enabled ? 'aiusages-grid-tile aiusages-grid-tile-active' : 'aiusages-grid-tile',
            can_focus: true,
            x_expand: true,
            child: content,
        });
        btn.accessible_name = `${meta.title}: ${enabled ? t('활성화됨', 'Enabled') : t('비활성화됨', 'Disabled')}`;
        btn.connect('clicked', () => {
            this._extension.toggleProvider(id);
        });
        return btn;
    }
}
