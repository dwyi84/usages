import GLib from 'gi://GLib';

const KOREAN_LANGS = /^ko/i;

export function isKorean() {
    try {
        for (const name of GLib.get_language_names()) {
            if (KOREAN_LANGS.test(name))
                return true;
        }
    } catch (e) {
        // ignore
    }
    return false;
}

export function t(korean, english) {
    return isKorean() ? korean : english;
}

export const STATUS_COLORS = {
    normal: [0.18, 0.82, 0.35, 1.0],
    warning: [1.0, 0.62, 0.05, 1.0],
    critical: [1.0, 0.27, 0.23, 1.0],
    rate_limited: [0.68, 0.45, 0.95, 1.0],
    error: [0.62, 0.62, 0.62, 1.0],
    unknown: [0.55, 0.55, 0.55, 1.0],
};

export function colorFor(percent, status) {
    if (status === 'rate_limited')
        return STATUS_COLORS.rate_limited;
    if (status === 'error' || status === 'unknown')
        return STATUS_COLORS[status] ?? STATUS_COLORS.unknown;
    if (percent <= 15)
        return STATUS_COLORS.critical;
    if (percent <= 35)
        return STATUS_COLORS.warning;
    return STATUS_COLORS.normal;
}

export function statusColor(status) {
    return STATUS_COLORS[status] ?? STATUS_COLORS.normal;
}

export function errorLabel(code) {
    switch (code) {
    case 'no_credentials':
        return t('OpenCode 자격 증명을 찾을 수 없습니다 (~/.local/share/opencode/opencode.db).',
            'No OpenCode credentials found (~/.local/share/opencode/opencode.db).');
    case 'missing_key':
        return t('설정에서 OpenRouter API 키를 등록하세요.', 'Add an OpenRouter API key in Settings.');
    case 'invalid_key':
        return t('OpenRouter API 키가 유효하지 않습니다.', 'The OpenRouter API key is not valid.');
    case 'unauthorized':
        return t('인증이 만료되었습니다. 다시 로그인하세요.', 'Authentication expired. Please sign in again.');
    case 'rate_limited':
        return t('요청 한도 대기 중입니다. 이전 값을 표시합니다.', 'Rate limited. Showing the previous value.');
    case 'network':
        return t('네트워크 오류로 이전 값을 표시합니다.', 'Network error. Showing the previous value.');
    case 'internal_error':
        return t('수집기 내부 오류가 발생했습니다.', 'The collector hit an internal error.');
    default:
        return '';
    }
}
