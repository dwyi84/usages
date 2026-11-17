import Clutter from 'gi://Clutter';
import GObject from 'gi://GObject';
import St from 'gi://St';

import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';

import {drawSegmentedGauge, gaugeSize} from './drawing.js';
import {t} from './i18n.js';

export const UsageIndicator = GObject.registerClass(
class UsageIndicator extends PanelMenu.Button {
    _init(extension) {
        super._init(0.5, 'AI Usages');

        this._extension = extension;
        this._items = [];
        this._resetSoon = false;

        this.add_style_class_name('aiusages-panel-button');

        this._box = new St.BoxLayout({
            style_class: 'aiusages-panel-box',
            y_align: Clutter.ActorAlign.CENTER,
        });
        this.add_child(this._box);

        this._gauge = new St.DrawingArea({
            style_class: 'aiusages-panel-gauge',
            y_align: Clutter.ActorAlign.CENTER,
        });
        this._gauge.connect('repaint', () => this._onRepaint());
        this._box.add_child(this._gauge);

        this._percentLabel = new St.Label({
            style_class: 'aiusages-panel-percent',
            y_align: Clutter.ActorAlign.CENTER,
            visible: false,
        });
        this._box.add_child(this._percentLabel);

        this._applySize();
    }

    _onRepaint() {
        const cr = this._gauge.get_context();
        try {
            drawSegmentedGauge(this._gauge, cr, this._items, this._resetSoon);
        } finally {
            disposeContext(cr);
        }
    }

    _applySize() {
        const [width, height] = gaugeSize(this._items.length);
        this._gauge.set_size(width, height);
    }

    update() {
        const extension = this._extension;
        const settings = extension.settings;
        const order = settings.get_strv('provider-order');
        const state = extension.state;

        const items = [];
        const tooltips = ['AI Usages'];
        let nearestBilling = 999;

        for (const id of order) {
            if (!extension.isProviderEnabled(id))
                continue;

            const snapshot = state?.providers?.[id];
            if (!snapshot || !snapshot.available)
                continue;

            let percent;
            let status;
            let label = '';
            let reset = '';
            let extra = '';

            if (id === 'openrouter') {
                percent = Number(snapshot.primary_percent) || 0;
                status = snapshot.status;
                label = t('잔액', 'Balance');
                const row = (snapshot.rows || []).find(entry => entry.key === 'balance');
                if (row?.value)
                    extra = ` ${row.value}`;
            } else {
                const key = extension.panelMetricFor(id);
                percent = Number(snapshot.metrics?.[key] ?? snapshot.primary_percent) || 0;
                const rows = snapshot.rows || [];
                const row = rows.find(entry => entry.key === key) ?? rows[0];
                if (row) {
                    label = row.label ?? '';
                    reset = row.reset ?? '';
                }
                status = snapshot.status === 'rate_limited'
                    ? 'rate_limited'
                    : percent <= 15 ? 'critical' : percent <= 35 ? 'warning' : 'normal';

                const days = snapshot.billing?.days;
                if (Number.isFinite(days)) {
                    if (id === 'opencode')
                        nearestBilling = Math.min(nearestBilling, days);
                    else if (id === 'google_ai' && settings.get_uint('google-billing-day') > 0)
                        nearestBilling = Math.min(nearestBilling, days);
                }
            }

            items.push({percent, status});
            const suffix = reset ? ` (${reset})` : extra;
            tooltips.push(`· ${snapshot.name}${label ? ` (${label})` : ''}: ${Math.round(percent)}% ${t('남음', 'remaining')}${suffix}`);
        }

        if (items.length === 0)
            tooltips.push(`· ${t('활성화된 AI 서비스 없음 (클릭하여 설정)', 'No active AI services (click to configure)')}`);

        this._items = items;
        this._resetSoon = nearestBilling >= 0 && nearestBilling <= 3;
        this._applySize();

        const showPercent = settings.get_boolean('show-panel-percent') && items.length > 0;
        this._percentLabel.visible = showPercent;
        if (showPercent)
            this._percentLabel.text = `${Math.round(items[0].percent)}%`;

        this._gauge.queue_repaint();
        this.set_accessible_name(tooltips.join('\n'));
    }
});

export function disposeContext(cr) {
    try {
        if (typeof cr.$dispose === 'function')
            cr.$dispose();
    } catch (e) {
        // Cairo contexts are garbage collected on newer GJS releases.
    }
}
