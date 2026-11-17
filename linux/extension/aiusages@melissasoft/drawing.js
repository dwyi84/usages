/**
 * Cairo drawing helpers.
 *
 * The panel gauge mirrors BatteryGaugeRenderer.swift: up to three vertical bars,
 * four segments each, with the same active/inactive proportions and colour ramp.
 */

export const GAUGE = {
    height: 22,
    segments: 4,
    segmentWidth: 4,
    segmentHeight: 2.8,
    segmentGap: 1,
    barSpacing: 2.5,
};

export function gaugeSize(count) {
    const bars = Math.max(1, Math.min(3, count));
    const width = bars * GAUGE.segmentWidth + (bars - 1) * GAUGE.barSpacing + 3;
    return [Math.max(14, Math.ceil(width)), GAUGE.height];
}

function themedForeground(area) {
    try {
        const node = area.get_theme_node();
        const color = node.get_foreground_color();
        if (color && typeof color.red === 'number')
            return [color.red / 255, color.green / 255, color.blue / 255];
    } catch (e) {
        // Theme lookup can fail on older shells; fall back to white.
    }
    return [1, 1, 1];
}

function setColor(cr, color, alphaOverride) {
    const [red, green, blue, alpha] = color;
    cr.setSourceRGBA(red, green, blue, alphaOverride ?? alpha ?? 1);
}

export function drawSegmentedGauge(area, cr, items, resetSoon) {
    const fg = themedForeground(area);
    const display = items.length > 0 ? items.slice(0, 3) : [{ percent: 0, status: 'unknown' }];
    const barCount = display.length;

    const totalHeight = GAUGE.segments * GAUGE.segmentHeight + (GAUGE.segments - 1) * GAUGE.segmentGap;
    const startX = 1.5;
    const startY = (GAUGE.height - totalHeight) / 2;

    display.forEach((item, index) => {
        const barX = startX + index * (GAUGE.segmentWidth + GAUGE.barSpacing);
        const percent = Number(item.percent) || 0;
        const active = percent <= 0
            ? 0
            : Math.max(1, Math.min(GAUGE.segments, Math.ceil((percent / 100) * GAUGE.segments)));

        let color;
        if (item.status === 'rate_limited')
            color = [0.68, 0.45, 0.95, 1];
        else if (percent <= 15)
            color = [1.0, 0.27, 0.23, 1];
        else if (percent <= 35)
            color = [1.0, 0.62, 0.05, 1];
        else
            color = [0.18, 0.82, 0.35, 1];

        for (let segment = 0; segment < GAUGE.segments; segment++) {
            const y = startY + segment * (GAUGE.segmentHeight + GAUGE.segmentGap);
            if (segment < active)
                setColor(cr, color);
            else
                cr.setSourceRGBA(fg[0], fg[1], fg[2], 0.18);
            cr.rectangle(barX, y, GAUGE.segmentWidth, GAUGE.segmentHeight);
            cr.fill();
        }
    });

    if (resetSoon) {
        const dot = 1.8;
        const totalWidth = barCount * GAUGE.segmentWidth + (barCount - 1) * GAUGE.barSpacing;
        const x = startX + (totalWidth - dot) / 2;
        const y = Math.max(0.5, startY - 3);
        cr.setSourceRGBA(1.0, 0.62, 0.05, 1);
        cr.arc(x + dot / 2, y + dot / 2, dot / 2, 0, 2 * Math.PI);
        cr.fill();
    }
}

export function drawQuotaBar(area, cr, percent, status, width, height) {
    const fg = themedForeground(area);
    const clamped = Math.max(0, Math.min(100, Number(percent) || 0));
    const radius = Math.min(height / 2, 3);

    cr.setSourceRGBA(fg[0], fg[1], fg[2], 0.16);
    roundedRect(cr, 0, 0, width, height, radius);
    cr.fill();

    if (clamped > 0) {
        const [red, green, blue] = status === 'rate_limited'
            ? [0.68, 0.45, 0.95]
            : clamped <= 15 ? [1.0, 0.27, 0.23]
            : clamped <= 35 ? [1.0, 0.62, 0.05]
            : [0.18, 0.82, 0.35];
        cr.setSourceRGBA(red, green, blue, 1);
        roundedRect(cr, 0, 0, Math.max(radius * 2, (width * clamped) / 100), height, radius);
        cr.fill();
    }
}

export function drawTrend(area, cr, points, width, height, hoverIndex) {
    const fg = themedForeground(area);
    const count = Math.max(points.length, 1);
    const gap = 2;
    const barWidth = Math.max(2, (width - gap * (count - 1)) / count);
    const baseline = height - 1;

    cr.setSourceRGBA(fg[0], fg[1], fg[2], 0.10);
    cr.rectangle(0, baseline, width, 1);
    cr.fill();

    points.forEach((point, index) => {
        const value = Math.max(0, Math.min(1, Number(point.normalized) || 0));
        const barHeight = Math.max(value > 0 ? 2 : 0, value * (height - 4));
        const x = index * (barWidth + gap);
        const y = baseline - barHeight;

        const hovered = index === hoverIndex;
        if (hovered)
            cr.setSourceRGBA(1.0, 1.0, 1.0, 0.95);
        else if (point.tokens > 0)
            cr.setSourceRGBA(fg[0], fg[1], fg[2], 0.55);
        else
            cr.setSourceRGBA(fg[0], fg[1], fg[2], 0.14);

        roundedRect(cr, x, y, barWidth, Math.max(barHeight, hovered ? 3 : 1), 1.5);
        cr.fill();
    });
}

function roundedRect(cr, x, y, width, height, radius) {
    const r = Math.max(0, Math.min(radius, width / 2, height / 2));
    cr.newSubPath();
    cr.arc(x + r, y + r, r, Math.PI, 1.5 * Math.PI);
    cr.arc(x + width - r, y + r, r, 1.5 * Math.PI, 2 * Math.PI);
    cr.arc(x + width - r, y + height - r, r, 0, 0.5 * Math.PI);
    cr.arc(x + r, y + height - r, r, 0.5 * Math.PI, Math.PI);
    cr.closePath();
}
