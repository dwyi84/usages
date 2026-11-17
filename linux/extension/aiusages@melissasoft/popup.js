import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import Pango from 'gi://Pango';
import St from 'gi://St';

import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';

import {drawQuotaBar, drawTrend} from './drawing.js';
import {disposeContext} from './panel.js';
import {errorLabel, t} from './i18n.js';

const QUOTA_PROVIDERS = ['opencode', 'google_ai'];
const TOKEN_PROVIDERS = ['openrouter'];

function formatTokens(value) {
    const number = String(Math.round(Number(value) || 0));
    return number.replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

function formatMoney(value) {
    return `$${(Number(value) || 0).toFixed(2)}`;
}

function formatTime(epochSeconds) {
    if (!epochSeconds)
        return '';
    const date = new Date(epochSeconds * 1000);
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    return `${hours}:${minutes}`;
}

function statusText(snapshot) {
    if (snapshot.status === 'rate_limited')
        return t('요청 한도 대기 중', 'Rate limited');
    if (snapshot.error && snapshot.error !== 'rate_limited')
        return errorLabel(snapshot.error) || t('오류', 'Error');
    if (snapshot.status === 'critical')
        return t('위험', 'Critical');
    if (snapshot.status === 'warning')
        return t('주의', 'Warning');
    return t('정상', 'Healthy');
}

const CardItem = GObject.registerClass(
class CardItem extends PopupMenu.PopupBaseMenuItem {
    _init(styleClass = 'aiusages-card') {
        super._init({
            reactive: false,
            activate: false,
            can_focus: false,
            style_class: styleClass,
        });
        this.box = new St.BoxLayout({
            vertical: true,
            x_expand: true,
            style_class: 'aiusages-card-box',
        });
        this.add_child(this.box);
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

        this.set_size(320, 52);
        this.connect('repaint', () => this._repaint());
        this.connect('motion-event', (actor, event) => {
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

    _repaint() {
        const cr = this.get_context();
        try {
            drawTrend(this, cr, this._points, this.get_width(), this.get_height(), this._hover);
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
        const width = this.get_width() || 320;
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
        this._tab = 'quota';
    }

    rebuild() {
        this._menu.removeAll();
        this._menu.addMenuItem(this._headerItem());
        this._menu.addMenuItem(this._tabsItem());

        const content = new CardItem('aiusages-content-item');
        const scroll = new St.ScrollView({
            style_class: 'aiusages-scroll',
            hscrollbar_policy: St.PolicyType.NEVER,
            vscrollbar_policy: St.PolicyType.AUTOMATIC,
        });
        const body = new St.BoxLayout({vertical: true, style_class: 'aiusages-body'});
        scroll.set_child(body);
        scroll.set_size(366, 600);

        body.connect('notify::height', () => {
            const [, natural] = body.get_preferred_height(-1);
            const target = Math.max(120, Math.min(600, natural));
            if (Math.abs(scroll.height - target) > 1)
                scroll.height = target;
        });

        content.box.add_child(scroll);
        this._menu.addMenuItem(content);

        this._fillBody(body);
        this._menu.addMenuItem(this._footerItem());
    }

    _fillBody(body) {
        const state = this._extension.state;
        const ids = this._tab === 'quota' ? QUOTA_PROVIDERS : TOKEN_PROVIDERS;
        const order = this._extension.settings?.get_strv('provider-order') ?? ids;
        const ordered = [...ids].sort((a, b) => order.indexOf(a) - order.indexOf(b));
        let shown = 0;

        for (const id of ordered) {
            if (!this._extension.isProviderEnabled(id))
                continue;
            const snapshot = state?.providers?.[id];
            if (!snapshot)
                continue;

            body.add_child(this._providerCard(id, snapshot));
            shown++;
        }

        if (shown === 0) {
            const empty = new St.BoxLayout({vertical: true, style_class: 'aiusages-empty'});
            const label = new St.Label({
                text: state
                    ? t('표시할 프로바이더가 없습니다. 설정에서 활성화하세요.', 'No providers to show. Enable them in Settings.')
                    : t('사용량을 불러오는 중…', 'Loading usage…'),
                style_class: 'aiusages-note',
                x_align: Clutter.ActorAlign.CENTER,
            });
            label.clutter_text.line_wrap = true;
            empty.add_child(label);
            body.add_child(empty);
        }
    }

    _providerCard(id, snapshot) {
        const card = new St.BoxLayout({vertical: true, style_class: 'aiusages-provider'});

        const head = new St.BoxLayout({style_class: 'aiusages-card-head'});
        const titles = new St.BoxLayout({vertical: true, x_expand: true});
        titles.add_child(new St.Label({text: snapshot.name ?? id, style_class: 'aiusages-card-title'}));
        const subtitle = new St.Label({text: statusText(snapshot), style_class: 'aiusages-card-subtitle'});
        subtitle.clutter_text.ellipsize = Pango.EllipsizeMode.END;
        titles.add_child(subtitle);
        head.add_child(titles);

        if (snapshot.category !== 'token_and_cost') {
            head.add_child(new St.Label({
                text: `${Math.round(Number(snapshot.primary_percent) || 0)}%`,
                style_class: 'aiusages-card-percent',
            }));
        }
        card.add_child(head);

        for (const row of snapshot.rows ?? [])
            card.add_child(this._metricRow(row, snapshot));

        if (snapshot.billing?.date_string)
            card.add_child(new St.Label({text: snapshot.billing.date_string, style_class: 'aiusages-note'}));

        if (snapshot.error && snapshot.error !== 'rate_limited') {
            const error = new St.Label({text: errorLabel(snapshot.error), style_class: 'aiusages-error'});
            error.clutter_text.line_wrap = true;
            card.add_child(error);
        }

        const trend = this._trendBlock(snapshot);
        if (trend)
            card.add_child(trend);

        return card;
    }

    _metricRow(row, snapshot) {
        const box = new St.BoxLayout({vertical: true, style_class: 'aiusages-metric'});
        const top = new St.BoxLayout({x_expand: true});
        top.add_child(new St.Label({
            text: row.label ?? '',
            x_expand: true,
            style_class: 'aiusages-metric-label',
        }));
        top.add_child(new St.Label({
            text: row.percent != null ? `${Math.round(Number(row.percent) || 0)}%` : (row.value ?? ''),
            style_class: 'aiusages-metric-value',
        }));
        box.add_child(top);

        if (row.percent != null) {
            const bar = new St.DrawingArea({style_class: 'aiusages-quota-bar', x_expand: true});
            bar.set_size(330, 7);
            bar.connect('repaint', () => {
                const cr = bar.get_context();
                try {
                    drawQuotaBar(bar, cr, row.percent, snapshot.status, bar.get_width() || 330, 7);
                } finally {
                    disposeContext(cr);
                }
            });
            box.add_child(bar);

            if (row.reset)
                box.add_child(new St.Label({text: row.reset, style_class: 'aiusages-metric-reset'}));
        }

        return box;
    }

    _trendBlock(snapshot) {
        const trend = snapshot.trend;
        const points = trend?.daily_points ?? [];
        if (points.length === 0)
            return null;

        const box = new St.BoxLayout({vertical: true, style_class: 'aiusages-trend'});
        const unit = trend.unit === 'steps' ? t('스텝', 'steps') : t('토큰', 'tokens');

        const title = new St.Label({text: t('사용 트렌드', 'Usage Trend'), style_class: 'aiusages-section-title'});
        box.add_child(title);

        const summary = new St.Label({
            text: `${t('오늘', 'Today')} ${formatTokens(trend.today_tokens)} ${unit} · 30d ${formatTokens(trend.last_30_days_tokens)}`,
            style_class: 'aiusages-note',
        });
        box.add_child(summary);

        const defaultInfo = t('막대에 마우스를 올리면 일별 사용량을 확인할 수 있습니다.',
            'Hover a bar to inspect daily usage.');
        const info = new St.Label({text: defaultInfo, style_class: 'aiusages-chart-info'});
        info.clutter_text.line_wrap = true;

        const area = new TrendArea(points, point => {
            if (!point) {
                info.text = defaultInfo;
                return;
            }
            let text = `${point.label} · ${formatTokens(point.tokens)} ${unit}`;
            if (trend.cost_available)
                text += ` · ${formatMoney(point.spend_usd)}`;
            info.text = text;
        });
        box.add_child(area);
        box.add_child(info);

        if (trend.peak_label) {
            box.add_child(new St.Label({
                text: `${t('최대 사용일', 'Peak Day')}: ${trend.peak_label} (${formatTokens(trend.peak_tokens)}) · ${t('일평균', 'Daily Avg')} ${formatTokens(trend.daily_avg_tokens)}`,
                style_class: 'aiusages-note',
            }));
        }

        if (trend.recent_log) {
            const log = new St.Label({text: trend.recent_log, style_class: 'aiusages-note'});
            log.clutter_text.line_wrap = true;
            box.add_child(log);
        }

        return box;
    }

    _headerItem() {
        const item = new CardItem('aiusages-header');
        const row = new St.BoxLayout({x_expand: true});

        const titles = new St.BoxLayout({vertical: true, x_expand: true});
        titles.add_child(new St.Label({text: 'AI Usages', style_class: 'aiusages-title'}));
        const subtitle = this._extension.loading
            ? t('새로고침 중…', 'Refreshing…')
            : t('OpenCode · Google AI · OpenRouter', 'OpenCode · Google AI · OpenRouter');
        titles.add_child(new St.Label({text: subtitle, style_class: 'aiusages-subtitle'}));
        row.add_child(titles);

        const refresh = new St.Button({
            style_class: 'aiusages-icon-button',
            can_focus: true,
            child: new St.Icon({icon_name: 'view-refresh-symbolic', icon_size: 16}),
        });
        refresh.accessible_name = t('새로고침', 'Refresh');
        refresh.reactive = !this._extension.loading;
        refresh.can_focus = !this._extension.loading;
        if (this._extension.loading)
            refresh.add_style_pseudo_class('insensitive');
        refresh.connect('clicked', () => this._extension.refresh(true));
        row.add_child(refresh);

        const settings = new St.Button({
            style_class: 'aiusages-icon-button',
            can_focus: true,
            child: new St.Icon({icon_name: 'emblem-system-symbolic', icon_size: 16}),
        });
        settings.accessible_name = t('설정', 'Settings');
        settings.connect('clicked', () => {
            this._menu.close();
            this._extension.openPreferences();
        });
        row.add_child(settings);

        item.box.add_child(row);
        return item;
    }

    _tabsItem() {
        const item = new CardItem('aiusages-tabs');
        const row = new St.BoxLayout({x_expand: true, style_class: 'aiusages-tab-row'});

        for (const [id, korean, english] of [
            ['quota', '한도 쿼터', 'Quotas'],
            ['token', '토큰 & 비용', 'Tokens & Cost'],
        ]) {
            const button = new St.Button({
                style_class: 'aiusages-tab',
                can_focus: true,
                label: t(korean, english),
                x_expand: true,
            });
            if (this._tab === id)
                button.add_style_class_name('aiusages-tab-active');
            button.connect('clicked', () => {
                this._tab = id;
                // Rebuilding destroys the button that emitted this signal, so
                // defer until the event has been fully processed.
                GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
                    this.rebuild();
                    return GLib.SOURCE_REMOVE;
                });
            });
            row.add_child(button);
        }

        item.box.add_child(row);
        return item;
    }

    _footerItem() {
        const item = new CardItem('aiusages-footer');
        const row = new St.BoxLayout({x_expand: true, style_class: 'aiusages-footer-row'});

        const state = this._extension.state;
        const updated = state?.generated_at ? formatTime(state.generated_at) : '';
        let text = updated ? `${t('마지막 갱신', 'Updated')} ${updated}` : t('데이터 없음', 'No data');
        if (this._extension.lastError)
            text += ` · ${this._extension.lastError}`;

        const label = new St.Label({text, style_class: 'aiusages-note', x_expand: true});
        row.add_child(label);
        row.add_child(new St.Label({text: 'Linux', style_class: 'aiusages-note'}));
        item.box.add_child(row);
        return item;
    }
}
