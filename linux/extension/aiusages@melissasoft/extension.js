import Gio from 'gi://Gio';
import GLib from 'gi://GLib';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

import {UsageIndicator} from './panel.js';
import {PopupView} from './popup.js';
import {isKorean, t} from './i18n.js';

const CACHE_FILENAME = 'state.json';
const SPAWN_TIMEOUT_SECONDS = 90;

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
        this._lastPercents = new Map();

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
        if (this._proc) {
            try {
                this._proc.force_exit();
            } catch (e) {
                // already exited
            }
            this._proc = null;
        }
        for (const id of this._signals)
            this._settings.disconnect(id);
        this._signals = [];
        if (this._menuSignal) {
            this._indicator.menu.disconnect(this._menuSignal);
            this._menuSignal = 0;
        }
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

    isProviderEnabled(id) {
        if (!this._settings)
            return false;
        if (!this._settings.get_boolean('providers-configured'))
            return Boolean(this._state?.providers?.[id]?.available);
        return this._settings.get_strv('enabled-providers').includes(id);
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
            this._popup?.rebuild();

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
            this._popup?.rebuild();
        if (this._settings?.get_boolean('notify-threshold'))
            this._notifyThresholds(previous, payload);
    }

    _setError(message) {
        this._lastError = message;
        this._indicator?.update();
        if (this._menuIsOpen())
            this._popup?.rebuild();
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
        if (key === 'refresh-interval')
            this._restartTimer();

        if (key === 'panel-metrics' || key === 'show-panel-percent' || key === 'provider-order') {
            this._indicator?.update();
            if (this._menuIsOpen())
                this._popup?.rebuild();
            return;
        }

        if (key === 'collector-path' || key === 'enabled-providers' || key === 'providers-configured' ||
            key === 'google-billing-day') {
            this._indicator?.update();
            this.refresh(true);
            return;
        }

        if (key === 'notify-threshold')
            return;

        this._indicator?.update();
    }
}
