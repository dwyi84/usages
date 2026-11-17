import Adw from 'gi://Adw';
import Gdk from 'gi://Gdk';
import GLib from 'gi://GLib';
import Gtk from 'gi://Gtk';
import Secret from 'gi://Secret';

import {ExtensionPreferences} from 'resource:///org/gnome/Shell/Extensions/js/extensions/prefs.js';

import {t} from './i18n.js';

const SERVICE = 'com.melissasoft.aiusages';
const OPENROUTER_ACCOUNT = 'openrouter_api_key';

const PROVIDERS = [
    ['opencode', 'OpenCode Go'],
    ['google_ai', 'Google AI Pro'],
    ['openrouter', 'OpenRouter'],
];

const OPENCODE_METRICS = [
    ['opencode_5h', t('5시간 윈도우', '5-hour window')],
    ['opencode_weekly', t('주간', 'Weekly')],
    ['opencode_monthly', t('월간', 'Monthly')],
];

const GOOGLE_METRICS = [
    ['google_gemini_5h', t('Gemini 5시간', 'Gemini 5h')],
    ['google_gemini_weekly', t('Gemini 주간', 'Gemini Weekly')],
    ['google_claude_5h', t('Claude & GPT 5시간', 'Claude & GPT 5h')],
    ['google_claude_weekly', t('Claude & GPT 주간', 'Claude & GPT Weekly')],
    ['google_argon_weekly', t('Gemini 4 Argon 주간', 'Gemini 4 Argon Weekly')],
];

const INTERVALS = [60, 180, 300, 900];
const secretSchema = Secret.Schema.new(
    'org.freedesktop.Secret.Generic',
    Secret.SchemaFlags.NONE,
    {
        'service': Secret.SchemaAttributeType.STRING,
        'username': Secret.SchemaAttributeType.STRING,
    }
);

export default class AIUsagesPreferences extends ExtensionPreferences {
    fillPreferencesWindow(window) {
        this._settings = this.getSettings();
        this._window = window;
        window.set_default_size(560, 700);

        window.add(this._buildGeneralPage());
        window.add(this._buildProvidersPage());
        window.add(this._buildPanelPage());
        window.add(this._buildGooglePage());
        window.add(this._buildOpenRouterPage());
        window.add(this._buildAboutPage());
    }

    // ------------------------------------------------------------------ //
    // Pages
    // ------------------------------------------------------------------ //

    _buildGeneralPage() {
        const page = new Adw.PreferencesPage({
            title: t('일반', 'General'),
            icon_name: 'preferences-system-symbolic',
        });
        const group = new Adw.PreferencesGroup({
            title: t('동작', 'Behaviour'),
        });
        page.add(group);

        const intervalRow = new Adw.ComboRow({
            title: t('확인 주기', 'Check interval'),
            subtitle: t('사용량을 다시 가져오는 간격입니다.', 'How often usage is refreshed.'),
            model: Gtk.StringList.new([
                t('1분', '1 minute'),
                t('3분', '3 minutes'),
                t('5분', '5 minutes'),
                t('15분', '15 minutes'),
            ]),
        });
        const currentInterval = this._settings.get_uint('refresh-interval');
        intervalRow.selected = Math.max(0, INTERVALS.indexOf(currentInterval));
        intervalRow.connect('notify::selected', () => {
            this._settings.set_uint('refresh-interval', INTERVALS[intervalRow.selected] ?? 300);
        });
        group.add(intervalRow);

        const percentRow = new Adw.SwitchRow({
            title: t('탑바에 퍼센트 표시', 'Show percentage in the top bar'),
        });
        percentRow.active = this._settings.get_boolean('show-panel-percent');
        percentRow.connect('notify::active', () => {
            this._settings.set_boolean('show-panel-percent', percentRow.active);
        });
        group.add(percentRow);

        const notifyRow = new Adw.SwitchRow({
            title: t('쿼터 부족 알림', 'Low quota notifications'),
            subtitle: t('남은 쿼터가 15% 이하로 떨어지면 알려줍니다.', 'Notify when remaining quota drops below 15%.'),
        });
        notifyRow.active = this._settings.get_boolean('notify-threshold');
        notifyRow.connect('notify::active', () => {
            this._settings.set_boolean('notify-threshold', notifyRow.active);
        });
        group.add(notifyRow);

        const pathRow = new Adw.EntryRow({
            title: t('수집기 경로', 'Collector path'),
            text: this._settings.get_string('collector-path'),
        });
        pathRow.connect('changed', () => {
            const value = pathRow.text.trim() || 'aiusages-collect';
            this._settings.set_string('collector-path', value);
        });
        group.add(pathRow);

        return page;
    }

    _buildProvidersPage() {
        const page = new Adw.PreferencesPage({
            title: t('프로바이더', 'Providers'),
            icon_name: 'network-server-symbolic',
        });
        const group = new Adw.PreferencesGroup({
            title: t('사용할 프로바이더', 'Enabled providers'),
            description: t('OpenCode와 Google AI Pro는 로컬 로그인에서 자동 감지됩니다.',
                'OpenCode and Google AI Pro are detected from local logins.'),
        });
        page.add(group);

        this._ensureProviderList();

        for (const [id, name] of PROVIDERS) {
            const row = new Adw.SwitchRow({title: name});
            row.active = this._isEnabled(id);
            row.connect('notify::active', () => {
                this._setEnabled(id, row.active);
            });
            group.add(row);
        }

        return page;
    }

    _buildPanelPage() {
        const page = new Adw.PreferencesPage({
            title: t('탑바', 'Top Bar'),
            icon_name: 'focus-top-bar-symbolic',
        });
        const group = new Adw.PreferencesGroup({
            title: t('게이지에 표시할 항목', 'Gauge metric'),
            description: t('탑바 아이콘에 표시할 쿼터를 선택합니다.', 'Choose which quota each top-bar bar represents.'),
        });
        page.add(group);

        group.add(this._metricRow('opencode', t('OpenCode Go', 'OpenCode Go'), OPENCODE_METRICS, 'opencode_5h'));
        group.add(this._metricRow('google_ai', t('Google AI Pro', 'Google AI Pro'), GOOGLE_METRICS, 'google_gemini_5h'));

        return page;
    }

    _metricRow(providerId, title, options, fallback) {
        const row = new Adw.ComboRow({
            title,
            model: Gtk.StringList.new(options.map(([, label]) => label)),
        });
        const current = this._panelMetric(providerId) || fallback;
        const index = Math.max(0, options.findIndex(([key]) => key === current));
        row.selected = index;
        row.connect('notify::selected', () => {
            const [key] = options[row.selected] ?? options[0];
            this._setPanelMetric(providerId, key);
        });
        return row;
    }

    _buildGooglePage() {
        const page = new Adw.PreferencesPage({
            title: t('Google', 'Google'),
            icon_name: 'x-office-calendar-symbolic',
        });
        const group = new Adw.PreferencesGroup({
            title: t('결제 주기', 'Billing cycle'),
            description: t('Google은 리셋일을 제공하지 않으므로 직접 설정합니다. 0이면 표시하지 않습니다.',
                'Google does not expose a renewal date, so set it manually. Use 0 to hide it.'),
        });
        page.add(group);

        const row = new Adw.SpinRow({
            title: t('매월 리셋일', 'Monthly reset day'),
            adjustment: new Gtk.Adjustment({
                lower: 0,
                upper: 31,
                step_increment: 1,
                page_increment: 1,
                value: this._settings.get_uint('google-billing-day'),
            }),
        });
        row.connect('notify::value', () => {
            this._settings.set_uint('google-billing-day', Math.round(row.value));
        });
        group.add(row);
        return page;
    }

    _buildOpenRouterPage() {
        const page = new Adw.PreferencesPage({
            title: 'OpenRouter',
            icon_name: 'dialog-password-symbolic',
        });
        const group = new Adw.PreferencesGroup({
            title: t('API 키', 'API key'),
            description: t('키는 GNOME 키링에 안전하게 저장됩니다.', 'The key is stored in the GNOME keyring.'),
        });
        page.add(group);

        const entry = new Adw.PasswordEntryRow({
            title: t('OpenRouter API Key', 'OpenRouter API Key'),
            show_apply_button: true,
        });
        entry.text = this._readSecret() ?? '';
        entry.connect('apply', () => {
            this._writeSecret(entry.text.trim());
        });
        group.add(entry);

        const status = new Adw.ActionRow({
            title: t('상태', 'Status'),
            subtitle: this._readSecret() ? t('키가 저장되어 있습니다.', 'A key is configured.') : t('키가 없습니다.', 'No key configured.'),
        });

        const deleteButton = new Gtk.Button({
            label: t('삭제', 'Delete'),
            valign: Gtk.Align.CENTER,
            css_classes: ['destructive-action'],
        });
        deleteButton.connect('clicked', () => {
            this._deleteSecret();
            entry.text = '';
            status.subtitle = t('키가 없습니다.', 'No key configured.');
        });
        status.add_suffix(deleteButton);
        group.add(status);

        return page;
    }

    _buildAboutPage() {
        const page = new Adw.PreferencesPage({
            title: t('정보', 'About'),
            icon_name: 'help-about-symbolic',
        });
        const group = new Adw.PreferencesGroup({title: 'AI Usages'});
        page.add(group);

        const versionRow = new Adw.ActionRow({
            title: 'AI Usages for Linux',
            subtitle: t('GNOME Shell 확장 · Ubuntu 24.04+', 'GNOME Shell extension · Ubuntu 24.04+'),
        });
        group.add(versionRow);

        const repoRow = new Adw.ActionRow({
            title: t('GitHub 저장소', 'GitHub repository'),
            subtitle: 'github.com/dwyi84/usages',
            activatable: true,
        });
        repoRow.connect('activated', () => {
            Gtk.show_uri(this._window, 'https://github.com/dwyi84/usages', Gdk.CURRENT_TIME);
        });
        group.add(repoRow);

        return page;
    }

    // ------------------------------------------------------------------ //
    // Provider list
    // ------------------------------------------------------------------ //

    _isEnabled(id) {
        return this._settings.get_strv('enabled-providers').includes(id);
    }

    _setEnabled(id, enabled) {
        const current = new Set(this._settings.get_strv('enabled-providers'));
        if (enabled)
            current.add(id);
        else
            current.delete(id);
        const order = PROVIDERS.map(([providerId]) => providerId).filter(providerId => current.has(providerId));
        this._settings.set_strv('enabled-providers', order);
        this._settings.set_boolean('providers-configured', true);

        if (enabled && id === 'openrouter' && !this._readSecret())
            return; // the key entry lives on its own page
    }

    _ensureProviderList() {
        if (this._settings.get_boolean('providers-configured'))
            return;

        const detected = this._detectedProviders();
        this._settings.set_strv('enabled-providers', detected);
        this._settings.set_boolean('providers-configured', true);
    }

    _detectedProviders() {
        const ids = new Set(this._detectedFromCache());
        const home = GLib.get_home_dir();

        if (GLib.file_test(GLib.build_filenamev([home, '.local', 'share', 'opencode', 'opencode.db']),
            GLib.FileTest.EXISTS))
            ids.add('opencode');

        if (GLib.file_test(GLib.build_filenamev([home, '.gemini', 'antigravity-cli']), GLib.FileTest.EXISTS) ||
            GLib.find_program_in_path('agy'))
            ids.add('google_ai');

        if (this._readSecret())
            ids.add('openrouter');

        return PROVIDERS.map(([id]) => id).filter(id => ids.has(id));
    }

    _detectedFromCache() {
        const path = GLib.build_filenamev([GLib.get_user_cache_dir(), 'aiusages', 'state.json']);
        try {
            const [ok, contents] = GLib.file_get_contents(path);
            if (!ok || !contents)
                return [];
            const payload = JSON.parse(new TextDecoder().decode(contents));
            return PROVIDERS
                .map(([id]) => id)
                .filter(id => payload?.providers?.[id]?.available);
        } catch (error) {
            return [];
        }
    }

    // ------------------------------------------------------------------ //
    // Panel metrics ("provider=key" pairs)
    // ------------------------------------------------------------------ //

    _panelMetric(providerId) {
        for (const pair of this._settings.get_strv('panel-metrics')) {
            const [id, key] = pair.split('=');
            if (id === providerId)
                return key;
        }
        return '';
    }

    _setPanelMetric(providerId, key) {
        const pairs = new Map();
        for (const pair of this._settings.get_strv('panel-metrics')) {
            const [id, value] = pair.split('=');
            if (id && value)
                pairs.set(id, value);
        }
        pairs.set(providerId, key);
        this._settings.set_strv('panel-metrics', [...pairs].map(([id, value]) => `${id}=${value}`));
    }

    // ------------------------------------------------------------------ //
    // Secrets
    // ------------------------------------------------------------------ //

    _readSecret() {
        try {
            return Secret.password_lookup_sync(
                secretSchema,
                {service: SERVICE, username: OPENROUTER_ACCOUNT},
                null
            ) || '';
        } catch (error) {
            log(`AI Usages prefs: keyring lookup failed: ${error.message}`);
            return '';
        }
    }

    _writeSecret(value) {
        try {
            if (!value) {
                Secret.password_clear_sync(
                    secretSchema,
                    {service: SERVICE, username: OPENROUTER_ACCOUNT},
                    null
                );
                return;
            }
            Secret.password_store_sync(
                secretSchema,
                {service: SERVICE, username: OPENROUTER_ACCOUNT},
                Secret.COLLECTION_DEFAULT,
                'AI Usages OpenRouter API key',
                value,
                null
            );
            if (!this._settings.get_strv('enabled-providers').includes('openrouter')) {
                const enabled = [...this._settings.get_strv('enabled-providers'), 'openrouter'];
                this._settings.set_strv('enabled-providers', enabled);
            }
            this._settings.set_boolean('providers-configured', true);
        } catch (error) {
            log(`AI Usages prefs: could not store the key: ${error.message}`);
        }
    }

    _deleteSecret() {
        try {
            Secret.password_clear_sync(
                secretSchema,
                {service: SERVICE, username: OPENROUTER_ACCOUNT},
                null
            );
        } catch (error) {
            log(`AI Usages prefs: could not delete the key: ${error.message}`);
        }
    }
}
