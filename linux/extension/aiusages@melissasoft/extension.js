import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Meta from 'gi://Meta';
import Pango from 'gi://Pango';
import St from 'gi://St';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as ModalDialog from 'resource:///org/gnome/shell/ui/modalDialog.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

import {UsageIndicator} from './panel.js';
import {PopupView} from './popup.js';
import {isKorean, t} from './i18n.js';

const CACHE_FILENAME = 'state.json';
const SPAWN_TIMEOUT_SECONDS = 90;
const LINUX_METADATA_URL = 'https://raw.githubusercontent.com/dwyi84/usages/main/linux/extension/aiusages@melissasoft/metadata.json';
const LATEST_RELEASE_API = 'https://api.github.com/repos/dwyi84/usages/releases/latest';
const REMOTE_INSTALL_URL = 'https://raw.githubusercontent.com/dwyi84/usages/main/linux/remote-install.sh';

function isNewerVersion(remote, current) {
    const parse = v => String(v || '').replace(/^[vV]/, '').split('.').map(n => parseInt(n, 10) || 0);
    const r = parse(remote);
    const c = parse(current);
    const len = Math.max(r.length, c.length, 3);
    for (let i = 0; i < len; i++) {
        const rv = r[i] ?? 0;
        const cv = c[i] ?? 0;
        if (rv > cv)
            return true;
        if (rv < cv)
            return false;
    }
    return false;
}

export const ALL_PROVIDER_IDS = [
    'opencode',
    'google_ai',
    'openrouter',
    'codex',
    'claude',
    'cursor',
    'copilot',
    'perplexity',
    'deepseek',
];

export default class AIUsagesExtension extends Extension {
    enable() {
        this._settings = this.getSettings();
        this._state = null;
        this._loading = false;
        this._lastError = null;
        this._timerId = 0;
        this._spawnTimeoutId = 0;
        this._proc = null;
        this._signals = [];
        this._interfaceSignals = [];
        this._lastPercents = new Map();

        this._installedVersion = this.metadata?.['version-name'] ?? '0.2.14';
        this._updateState = 'idle';
        this._latestVersion = null;
        this._latestTag = null;
        this._latestUrl = null;
        this._updateProc = null;
        this._updateResetId = 0;
        this._updateDialog = null;

        try {
            this._interfaceSettings = new Gio.Settings({schema_id: 'org.gnome.desktop.interface'});
            for (const key of ['color-scheme', 'gtk-theme']) {
                this._interfaceSignals.push(
                    this._interfaceSettings.connect(`changed::${key}`, () => {
                        this._popup?.applyTheme?.();
                        if (this._menuIsOpen())
                            this._popup?.scheduleRebuild();
                    })
                );
            }
        } catch (error) {
            this._interfaceSettings = null;
        }

        this._indicator = new UsageIndicator(this);
        Main.panel.addToStatusArea('aiusages', this._indicator, 0, 'right');

        this._popup = new PopupView(this._indicator, this);
        this._popup.rebuild();

        this._menuSignal = this._indicator.menu.connect('open-state-changed', (_menu, open) => {
            if (!open)
                return;
            this._popup.rebuild();
            const age = this._stateAge();
            if (age > this._intervalSeconds())
                this.refresh();
        });

        for (const key of [
            'refresh-interval',
            'enabled-providers',
            'providers-configured',
            'provider-order',
            'google-billing-day',
            'panel-metrics',
            'show-panel-percent',
            'collector-path',
            'notify-threshold',
        ]) {
            this._signals.push(this._settings.connect(`changed::${key}`, () => this._onSettingsChanged(key)));
        }

        this._loadCache();
        this.refresh();
        this._startTimer();
        this.checkForUpdates(false);
    }

    disable() {
        if (this._timerId) {
            GLib.source_remove(this._timerId);
            this._timerId = 0;
        }
        if (this._spawnTimeoutId) {
            GLib.source_remove(this._spawnTimeoutId);
            this._spawnTimeoutId = 0;
        }
        if (this._updateResetId) {
            GLib.source_remove(this._updateResetId);
            this._updateResetId = 0;
        }
        if (this._proc) {
            try {
                this._proc.force_exit();
            } catch (e) {
                // already exited
            }
            this._proc = null;
        }
        if (this._updateProc) {
            try {
                this._updateProc.force_exit();
            } catch (e) {
                // already exited
            }
            this._updateProc = null;
        }
        if (this._updateDialog) {
            try {
                this._updateDialog.close();
            } catch (e) {
                // already closed
            }
            this._updateDialog = null;
        }
        for (const id of this._signals)
            this._settings.disconnect(id);
        this._signals = [];
        for (const id of this._interfaceSignals)
            this._interfaceSettings?.disconnect(id);
        this._interfaceSignals = [];
        this._interfaceSettings = null;
        if (this._menuSignal) {
            this._indicator.menu.disconnect(this._menuSignal);
            this._menuSignal = 0;
        }
        this._popup?.destroy?.();
        this._popup = null;
        this._indicator?.destroy();
        this._indicator = null;
        this._state = null;
        this._settings = null;
    }

    // ------------------------------------------------------------------ //
    // Data
    // ------------------------------------------------------------------ //

    get state() {
        return this._state;
    }

    get settings() {
        return this._settings;
    }

    get loading() {
        return this._loading;
    }

    get lastError() {
        return this._lastError;
    }

    get currentVersion() {
        return this._installedVersion ?? this.metadata?.['version-name'] ?? '0.2.14';
    }

    get updateState() {
        return this._updateState;
    }

    get latestVersion() {
        return this._latestVersion;
    }

    // ------------------------------------------------------------------ //
    // Updates
    // ------------------------------------------------------------------ //

    _scheduleUpdateIdleReset() {
        if (this._updateResetId)
            GLib.source_remove(this._updateResetId);
        this._updateResetId = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 4, () => {
            this._updateResetId = 0;
            if (this._updateState === 'up_to_date' || this._updateState === 'failed') {
                this._updateState = 'idle';
                if (this._menuIsOpen())
                    this._popup?.updateStatus();
            }
            return GLib.SOURCE_REMOVE;
        });
    }

    checkForUpdates(interactive = false) {
        if (!this._settings)
            return;
        if (this._updateState === 'checking' || this._updateState === 'installing')
            return;

        if (this._updateResetId) {
            GLib.source_remove(this._updateResetId);
            this._updateResetId = 0;
        }

        this._updateState = 'checking';
        if (this._menuIsOpen())
            this._popup?.updateStatus();

        const pyScript = [
            'import json, urllib.request',
            'def fetch_json(url, accept):',
            "    req = urllib.request.Request(url, headers={'User-Agent': 'AIUsages-Linux', 'Accept': accept})",
            '    with urllib.request.urlopen(req, timeout=8) as r:',
            '        return json.load(r)',
            'out = None',
            'try:',
            `    d = fetch_json(${JSON.stringify(LINUX_METADATA_URL)}, 'application/json')`,
            "    ver = str(d.get('version-name') or '').strip()",
            '    if ver:',
            "        out = {'version': ver, 'tag_name': 'main', 'html_url': 'https://github.com/dwyi84/usages'}",
            'except Exception:',
            '    pass',
            'if out is None:',
            `    d = fetch_json(${JSON.stringify(LATEST_RELEASE_API)}, 'application/vnd.github+json')`,
            "    tag = str(d.get('tag_name') or '').strip()",
            "    out = {'version': tag, 'tag_name': tag, 'html_url': d.get('html_url', '')}",
            'print(json.dumps(out))',
        ].join('\n');

        let proc;
        try {
            proc = Gio.Subprocess.new(
                ['python3', '-c', pyScript],
                Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE
            );
            this._updateProc = proc;
        } catch (error) {
            this._updateProc = null;
            this._updateState = 'failed';
            if (this._menuIsOpen())
                this._popup?.updateStatus();
            this._scheduleUpdateIdleReset();
            if (interactive)
                Main.notify('AI Usages', t('업데이트 확인에 실패했습니다.', 'Failed to check for updates.'));
            return;
        }

        proc.communicate_utf8_async(null, null, (p, result) => {
            let stdout = '';
            let ok = false;
            try {
                [, stdout] = p.communicate_utf8_finish(result);
                ok = p.get_successful();
            } catch (error) {
                ok = false;
            }
            if (this._updateProc === p)
                this._updateProc = null;
            if (!this._settings)
                return;

            let payload = null;
            if (ok && stdout) {
                try {
                    payload = JSON.parse(stdout);
                } catch (e) {
                    payload = null;
                }
            }

            const rawVer = String(payload?.version || payload?.tag_name || '').trim();
            const rawTag = String(payload?.tag_name || 'main').trim();
            if (!rawVer) {
                this._updateState = 'failed';
                if (this._menuIsOpen())
                    this._popup?.updateStatus();
                this._scheduleUpdateIdleReset();
                if (interactive)
                    Main.notify('AI Usages', t('업데이트 확인에 실패했습니다.', 'Failed to check for updates.'));
                return;
            }

            const ver = rawVer.replace(/^[vV]/, '');
            if (isNewerVersion(ver, this.currentVersion)) {
                this._latestVersion = ver;
                this._latestTag = rawTag || 'main';
                this._latestUrl = payload?.html_url || null;
                this._updateState = 'available';
                if (this._menuIsOpen())
                    this._popup?.updateStatus();
                if (interactive)
                    this.promptInstallUpdate();
            } else {
                this._updateState = 'up_to_date';
                if (this._menuIsOpen())
                    this._popup?.updateStatus();
                this._scheduleUpdateIdleReset();
                if (interactive) {
                    Main.notify(
                        'AI Usages',
                        t(`최신 버전을 사용 중입니다 (v${this.currentVersion}).`, `You're up to date (v${this.currentVersion}).`)
                    );
                }
            }
        });
    }

    promptInstallUpdate() {
        if (!this._latestVersion || this._updateDialog)
            return;

        this._indicator?.menu?.close();

        const dialog = new ModalDialog.ModalDialog({destroyOnClose: true});
        const box = new St.BoxLayout({vertical: true, style_class: 'aiusages-update-dialog'});
        box.add_child(new St.Label({
            text: t(`v${this._latestVersion} 버전으로 업데이트하시겠습니까?`, `Update to v${this._latestVersion}?`),
            style_class: 'aiusages-update-dialog-title',
        }));

        const body = new St.Label({
            text: t(
                `AI Usages v${this._latestVersion}을 사용할 수 있습니다 (현재 버전: v${this.currentVersion}). 자동으로 다운로드하여 설치합니다.`,
                `AI Usages v${this._latestVersion} is available (current: v${this.currentVersion}). It will be downloaded and installed automatically.`
            ),
            style_class: 'aiusages-update-dialog-body',
        });
        body.clutter_text.line_wrap = true;
        body.clutter_text.line_wrap_mode = Pango.WrapMode.WORD_CHAR;
        box.add_child(body);

        dialog.contentLayout.add_child(box);
        dialog.addButton({
            label: t('나중에', 'Later'),
            action: () => dialog.close(),
            key: Clutter.KEY_Escape,
        });
        dialog.addButton({
            label: t('지금 업데이트', 'Update Now'),
            action: () => {
                dialog.close();
                this.installUpdate();
            },
            default: true,
        });

        dialog.connect('closed', () => {
            if (this._updateDialog === dialog)
                this._updateDialog = null;
        });

        this._updateDialog = dialog;
        dialog.open();
    }

    installUpdate() {
        if (!this._settings || !this._latestTag || this._updateState === 'installing')
            return;

        this._updateState = 'installing';
        if (this._menuIsOpen())
            this._popup?.updateStatus();

        const tag = this._latestTag;
        const targetVer = this._latestVersion;

        let proc;
        try {
            const launcher = new Gio.SubprocessLauncher({
                flags: Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE,
            });
            launcher.setenv('AIUSAGES_REF', tag, true);

            const localScript = GLib.build_filenamev([this.path, 'remote-install.sh']);
            const cmd = GLib.file_test(localScript, GLib.FileTest.EXISTS)
                ? ['sh', localScript]
                : ['sh', '-c', `curl -fsSL ${REMOTE_INSTALL_URL} | sh`];

            proc = launcher.spawnv(cmd);
            this._updateProc = proc;
        } catch (error) {
            this._updateProc = null;
            this._updateState = 'failed';
            if (this._menuIsOpen())
                this._popup?.updateStatus();
            this._scheduleUpdateIdleReset();
            logError(error, 'AI Usages: failed to launch updater');
            Main.notify('AI Usages', t('업데이트 실행에 실패했습니다.', 'Failed to start update installer.'));
            return;
        }

        proc.communicate_utf8_async(null, null, (p, result) => {
            let stderr = '';
            let ok = false;
            try {
                [, , stderr] = p.communicate_utf8_finish(result);
                ok = p.get_successful();
            } catch (error) {
                ok = false;
            }
            if (this._updateProc === p)
                this._updateProc = null;
            if (!this._settings)
                return;

            if (!ok) {
                if (stderr && stderr.trim())
                    log(`AI Usages update error: ${stderr.trim()}`);
                this._updateState = 'failed';
                if (this._menuIsOpen())
                    this._popup?.updateStatus();
                this._scheduleUpdateIdleReset();
                Main.notify('AI Usages', t('업데이트 설치에 실패했습니다.', 'Failed to install update.'));
                return;
            }

            this._installedVersion = targetVer;
            try {
                if (this.metadata)
                    this.metadata['version-name'] = targetVer;
            } catch (e) {
                // metadata object may be read-only
            }
            this._updateState = 'installed';
            if (this._menuIsOpen())
                this._popup?.updateStatus();
            this.refresh(true);

            if (!Meta.is_wayland_compositor()) {
                this._promptRestartAfterUpdate(targetVer);
            } else {
                Main.notify(
                    'AI Usages',
                    t(
                        `v${targetVer} 업데이트 설치 완료. 재로그인 시 새 UI가 적용됩니다.`,
                        `Updated to v${targetVer}. Log out and back in to apply the new UI.`
                    )
                );
            }
        });
    }

    _promptRestartAfterUpdate(version) {
        if (this._updateDialog)
            return;

        const dialog = new ModalDialog.ModalDialog({destroyOnClose: true});
        const box = new St.BoxLayout({vertical: true, style_class: 'aiusages-update-dialog'});
        box.add_child(new St.Label({
            text: t(`v${version} 설치 완료`, `v${version} Installed`),
            style_class: 'aiusages-update-dialog-title',
        }));

        const body = new St.Label({
            text: t(
                '새 버전이 설치되었습니다. 지금 GNOME Shell을 재시작하여 UI를 바로 적용할까요?',
                'The new version has been installed. Restart GNOME Shell now to apply the updated UI?'
            ),
            style_class: 'aiusages-update-dialog-body',
        });
        body.clutter_text.line_wrap = true;
        body.clutter_text.line_wrap_mode = Pango.WrapMode.WORD_CHAR;
        box.add_child(body);

        dialog.contentLayout.add_child(box);
        dialog.addButton({
            label: t('나중에', 'Later'),
            action: () => dialog.close(),
            key: Clutter.KEY_Escape,
        });
        dialog.addButton({
            label: t('지금 재시작', 'Restart Now'),
            action: () => {
                dialog.close();
                Meta.restart(t('AI Usages 업데이트 적용 중…', 'Applying AI Usages update…'), global.context);
            },
            default: true,
        });

        dialog.connect('closed', () => {
            if (this._updateDialog === dialog)
                this._updateDialog = null;
        });

        this._updateDialog = dialog;
        dialog.open();
    }

    isDarkTheme() {
        if (!this._interfaceSettings)
            return true;
        try {
            const scheme = this._interfaceSettings.get_string('color-scheme');
            if (scheme === 'prefer-dark')
                return true;
            if (scheme === 'prefer-light')
                return false;
            const gtkTheme = (this._interfaceSettings.get_string('gtk-theme') || '').toLowerCase();
            return gtkTheme.endsWith('-dark') || gtkTheme === 'dark';
        } catch (error) {
            return true;
        }
    }

    isProviderEnabled(id) {
        if (!this._settings)
            return false;
        if (!this._settings.get_boolean('providers-configured'))
            return Boolean(this._state?.providers?.[id]?.available);
        return this._settings.get_strv('enabled-providers').includes(id);
    }

    providerOrder() {
        const saved = this._settings?.get_strv('provider-order') ?? [];
        const merged = [];
        for (const id of saved) {
            if (ALL_PROVIDER_IDS.includes(id) && !merged.includes(id))
                merged.push(id);
        }
        for (const id of ALL_PROVIDER_IDS) {
            if (!merged.includes(id))
                merged.push(id);
        }
        return merged;
    }

    setPanelMetric(providerId, key) {
        if (!this._settings || !providerId || !key)
            return;
        const pairs = new Map();
        for (const pair of this._settings.get_strv('panel-metrics')) {
            const [id, value] = pair.split('=');
            if (id && value)
                pairs.set(id, value);
        }
        pairs.set(providerId, key);
        this._settings.set_strv('panel-metrics', [...pairs].map(([id, value]) => `${id}=${value}`));
    }

    moveProvider(id, delta) {
        if (!this._settings || !delta)
            return;
        const order = this.providerOrder();
        const active = order.filter(pid => this.isProviderEnabled(pid));
        const activeIndex = active.indexOf(id);
        const targetIndex = activeIndex + delta;
        if (activeIndex < 0 || targetIndex < 0 || targetIndex >= active.length)
            return;

        const neighborId = active[targetIndex];
        const i = order.indexOf(id);
        const j = order.indexOf(neighborId);
        if (i < 0 || j < 0)
            return;

        [order[i], order[j]] = [order[j], order[i]];
        this._settings.set_strv('provider-order', order);
    }

    toggleProvider(id) {
        if (!this._settings)
            return;
        const configured = this._settings.get_boolean('providers-configured');
        const current = configured
            ? this._settings.get_strv('enabled-providers')
            : this.providerOrder().filter(pid => this.isProviderEnabled(pid));
        const enabled = new Set(current);
        if (enabled.has(id))
            enabled.delete(id);
        else
            enabled.add(id);

        const ordered = this.providerOrder().filter(pid => enabled.has(pid));
        this._settings.set_strv('enabled-providers', ordered);
        if (!configured)
            this._settings.set_boolean('providers-configured', true);
    }

    isProviderDetected(id) {
        const home = GLib.get_home_dir();
        const exists = (...parts) =>
            GLib.file_test(GLib.build_filenamev([home, ...parts]), GLib.FileTest.EXISTS);

        switch (id) {
        case 'opencode':
            return Boolean(
                this._state?.providers?.opencode?.available ||
                exists('.local', 'share', 'opencode', 'opencode.db') ||
                exists('.local', 'share', 'opencode', 'auth.json')
            );
        case 'google_ai':
            return Boolean(
                this._state?.providers?.google_ai?.available ||
                exists('.gemini', 'antigravity-cli') ||
                GLib.find_program_in_path('agy')
            );
        case 'openrouter':
            return Boolean(
                this._state?.providers?.openrouter?.connected ||
                this._state?.providers?.openrouter?.available ||
                GLib.getenv('OPENROUTER_API_KEY')
            );
        case 'codex':
            return Boolean(
                GLib.getenv('OPENAI_API_KEY') ||
                exists('.codex') ||
                exists('.openai')
            );
        case 'claude':
            return Boolean(
                GLib.getenv('ANTHROPIC_API_KEY') ||
                exists('.anthropic') ||
                exists('.claude')
            );
        case 'cursor':
            return Boolean(
                exists('.cursor') ||
                exists('.config', 'Cursor') ||
                GLib.find_program_in_path('cursor')
            );
        case 'copilot':
            return Boolean(exists('.config', 'github-copilot'));
        case 'perplexity':
            return Boolean(GLib.getenv('PERPLEXITY_API_KEY'));
        case 'deepseek':
            return Boolean(GLib.getenv('DEEPSEEK_API_KEY'));
        default:
            return false;
        }
    }

    panelMetricFor(id) {
        if (!this._settings)
            return '';
        for (const pair of this._settings.get_strv('panel-metrics')) {
            const [providerId, key] = pair.split('=');
            if (providerId === id && key)
                return key;
        }
        if (id === 'opencode')
            return 'opencode_5h';
        if (id === 'google_ai')
            return 'google_gemini_5h';
        return '';
    }

    _intervalSeconds() {
        const configured = this._settings?.get_uint('refresh-interval') ?? 300;
        return Math.max(60, configured);
    }

    _stateAge() {
        const generated = Number(this._state?.generated_at) || 0;
        if (!generated)
            return Number.MAX_SAFE_INTEGER;
        return Math.floor(Date.now() / 1000 - generated);
    }

    _startTimer() {
        if (this._timerId)
            GLib.source_remove(this._timerId);
        this._timerId = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, this._intervalSeconds(), () => {
            this.refresh();
            return GLib.SOURCE_CONTINUE;
        });
    }

    _restartTimer() {
        this._startTimer();
    }

    _collectorPath() {
        const configured = (this._settings?.get_string('collector-path') || 'aiusages-collect').trim();
        if (!configured)
            return null;
        if (configured.startsWith('~/'))
            return GLib.build_filenamev([GLib.get_home_dir(), configured.slice(2)]);
        if (configured.includes('/'))
            return configured;
        return GLib.find_program_in_path(configured)
            ?? GLib.build_filenamev([GLib.get_home_dir(), '.local', 'bin', 'aiusages-collect']);
    }

    refresh(force = false) {
        if (!this._settings || this._loading)
            return;
        if (!force && this._stateAge() < 5)
            return;

        const executable = this._collectorPath();
        if (!executable) {
            this._setError(t('수집기 경로를 찾을 수 없습니다', 'Collector path not found'));
            return;
        }

        const argv = [executable, '--json'];
        argv.push(isKorean() ? '--korean' : '--english');

        const billingDay = this._settings.get_uint('google-billing-day');
        if (billingDay > 0)
            argv.push('--billing-day', String(billingDay));

        if (this._settings.get_boolean('providers-configured')) {
            const enabled = this._settings.get_strv('enabled-providers');
            argv.push('--enabled', enabled.join(','));
        }

        this._loading = true;
        this._lastError = null;
        this._indicator?.update();
        if (this._menuIsOpen())
            this._popup?.updateStatus();

        try {
            this._proc = Gio.Subprocess.new(
                argv,
                Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE
            );
        } catch (error) {
            this._loading = false;
            this._proc = null;
            this._setError(t('수집기를 실행할 수 없습니다', 'Could not run the collector'));
            logError(error, 'AI Usages: failed to spawn collector');
            return;
        }

        this._spawnTimeoutId = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, SPAWN_TIMEOUT_SECONDS, () => {
            this._spawnTimeoutId = 0;
            if (this._proc) {
                log('AI Usages: collector timed out');
                try {
                    this._proc.force_exit();
                } catch (e) {
                    // ignore
                }
            }
            return GLib.SOURCE_REMOVE;
        });

        this._proc.communicate_utf8_async(null, null, (proc, result) => {
            let stdout = '';
            let stderr = '';
            try {
                [, stdout, stderr] = proc.communicate_utf8_finish(result);
            } catch (error) {
                this._finishLoading();
                this._setError(t('수집기 실행 실패', 'Collector failed'));
                logError(error, 'AI Usages: collector failed');
                return;
            }

            this._finishLoading();

            if (stderr && stderr.trim())
                log(`AI Usages collector: ${stderr.trim()}`);

            let payload = null;
            try {
                payload = JSON.parse(stdout);
            } catch (error) {
                this._setError(t('수집기 출력을 해석할 수 없습니다', 'Could not parse collector output'));
                return;
            }

            if (!payload || typeof payload !== 'object' || !payload.providers) {
                this._setError(t('수집기 출력이 비어 있습니다', 'Collector returned no data'));
                return;
            }

            this._applyState(payload);
        });
    }

    _finishLoading() {
        this._loading = false;
        this._proc = null;
        if (this._spawnTimeoutId) {
            GLib.source_remove(this._spawnTimeoutId);
            this._spawnTimeoutId = 0;
        }
    }

    _applyState(payload) {
        const previous = this._state;
        this._state = payload;
        this._lastError = null;
        this._indicator?.update();
        if (this._menuIsOpen())
            this._popup?.scheduleRebuild();
        if (this._settings?.get_boolean('notify-threshold'))
            this._notifyThresholds(previous, payload);
    }

    _setError(message) {
        this._lastError = message;
        this._indicator?.update();
        if (this._menuIsOpen())
            this._popup?.updateStatus();
    }

    _notifyThresholds(previous, current) {
        if (!previous?.providers || !current?.providers)
            return;

        for (const [id, snapshot] of Object.entries(current.providers)) {
            if (!this.isProviderEnabled(id) || !snapshot.available)
                continue;
            const percent = Number(snapshot.primary_percent);
            if (!Number.isFinite(percent) || percent > 15)
                continue;

            const before = Number(previous.providers?.[id]?.primary_percent);
            if (!Number.isFinite(before) || before <= 15)
                continue;

            const label = snapshot.name ?? id;
            Main.notify(
                'AI Usages',
                t(`${label}: ${Math.round(percent)}% 남았습니다`, `${label}: ${Math.round(percent)}% remaining`)
            );
        }
    }

    _menuIsOpen() {
        return Boolean(this._indicator?.menu?.isOpen);
    }

    _cachePath() {
        return GLib.build_filenamev([GLib.get_user_cache_dir(), 'aiusages', CACHE_FILENAME]);
    }

    _loadCache() {
        const path = this._cachePath();
        try {
            const [ok, contents] = GLib.file_get_contents(path);
            if (!ok || !contents)
                return;
            const payload = JSON.parse(new TextDecoder().decode(contents));
            if (!payload?.providers)
                return;
            this._state = payload;
            this._indicator?.update();
            this._popup?.rebuild();
        } catch (error) {
            // A missing or stale cache is expected on first run.
            log(`AI Usages: no usable cache (${error.message})`);
        }
    }

    _onSettingsChanged(key) {
        if (key === 'refresh-interval') {
            this._restartTimer();
            if (this._menuIsOpen())
                this._popup?.updateStatus();
            return;
        }

        if (key === 'show-panel-percent') {
            this._indicator?.update();
            if (this._menuIsOpen())
                this._popup?.updateStatus();
            return;
        }

        if (key === 'panel-metrics' || key === 'provider-order') {
            this._indicator?.update();
            if (this._menuIsOpen())
                this._popup?.scheduleRebuild();
            return;
        }

        if (key === 'collector-path' || key === 'enabled-providers' || key === 'providers-configured' ||
            key === 'google-billing-day') {
            this._indicator?.update();
            if (this._menuIsOpen())
                this._popup?.scheduleRebuild();
            this.refresh(true);
            return;
        }

        if (key === 'notify-threshold')
            return;

        this._indicator?.update();
    }
}
