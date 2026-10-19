// Theme editor: keep color pickers and text fields in sync and preview the
// palette by rewriting <style id="sitecss">.
//
// Loaded by a <script> tag at the end of Admin/Tools/Theme.html, so it runs
// once per page render, after the form exists. Nothing is bound outside the
// swapped content; the preview does change <style id="sitecss"> and <html>,
// which live outside it, so destroy() puts them back (see init.js).
(function() {
    const form = document.getElementById('ThemePalette');
    if (!form || form.themeEditor) return;

    const sitecss = document.getElementById('sitecss');
    const html = document.documentElement;
    // The server's rendering of the saved palette and custom CSS. Boosted
    // navigation never re-renders #sitecss, so this is both the starting
    // point and what destroy() restores.
    const savedCss = form.dataset.savedCss || '';
    const extra = JSON.parse(form.dataset.extraPalette || '{}');
    const toggleButton = document.getElementById('preview-mode');
    let previousTheme = null;

    const modeSpecific = new Set(JSON.parse(form.dataset.modeSpecific || '[]'));
    const userCss = document.getElementById('user_css');
    let lastFocused = null;
    let resetTimer = null;

    // UserCSS may close <style id="sitecss"> to add a <script> (see
    // Elements/Header). Only the text before that belongs in the element; it
    // must never get HTML, which textContent would show as CSS, not run.
    // Theme.html splits the saved UserCSS the same way.
    const cssPart = function(text) {
        const end = text.search(/<\/style/i);
        return end < 0 ? text : text.slice(0, end);
    };

    const toHex = function(value) {
        if (/^#[0-9a-f]{6}$/i.test(value)) return value;
        if (/^#[0-9a-f]{3}$/i.test(value)) {
            return '#' + value.slice(1).split('').map(c => c + c).join('');
        }
        const m = value.match(/^rgb\((\d+),\s*(\d+),\s*(\d+)\)$/);
        if (m) return '#' + m.slice(1, 4).map(n => parseInt(n).toString(16).padStart(2, '0')).join('');
        return null;
    };

    // Same rule as RT::Interface::Web->ThemeContrastColor: #fff or #000,
    // whichever has the higher WCAG contrast ratio; null unless hex.
    const contrastColor = function(value) {
        const m = /^#([0-9a-f]{3}|[0-9a-f]{6})$/i.exec(value);
        if (!m) return null;
        const hex = m[1].length === 3 ? m[1].split('').map(c => c + c).join('') : m[1];
        const [r, g, b] = [0, 2, 4].map(function(i) {
            const c = parseInt(hex.slice(i, i + 2), 16) / 255;
            return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
        });
        const luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b;
        return 1.05 / (luminance + 0.05) >= (luminance + 0.05) / 0.05 ? '#fff' : '#000';
    };

    // Same block format as RT::Interface::Web->ThemePaletteCSS
    const block = function(selector, values) {
        const names = Object.keys(values).sort();
        if (!names.length) return '';
        return selector + ' {\n' + names.map(n => '    ' + n + ': ' + values[n] + ';\n').join('') + '}\n';
    };

    // The page's mode; init.js resolves 'auto' to light or dark, so do the
    // same if we beat it.
    const currentMode = function() {
        const current = html.getAttribute('data-bs-theme');
        if (current === 'dark' || current === 'light') return current;
        return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    };

    // Computed colors come back as rgb(), rgba() or, for color-mix(),
    // color(srgb r g b / a). Fully transparent means the property didn't
    // resolve to a color (the probe inherits transparent).
    const computedToHex = function(value) {
        let channels, alpha;
        let m = value.match(/^rgba?\(\s*([\d.]+)[\s,]+([\d.]+)[\s,]+([\d.]+)(?:\s*[,\/]\s*([\d.]+)(%?))?\s*\)$/);
        if (m) {
            channels = m.slice(1, 4).map(Number);
        }
        else if ((m = value.match(/^color\(srgb\s+([-\d.e]+)\s+([-\d.e]+)\s+([-\d.e]+)(?:\s*\/\s*([\d.]+)(%?))?\s*\)$/))) {
            channels = m.slice(1, 4).map(n => Number(n) * 255);
        }
        else {
            return null;
        }
        alpha = m[4] === undefined ? 1 : Number(m[4]);
        if (alpha === 0) return null;
        return '#' + channels.map(c => Math.min(255, Math.max(0, Math.round(c))).toString(16).padStart(2, '0')).join('');
    };

    // Hidden frames, one per mode, load the page's stylesheets plus the
    // preview CSS. A probe in each reads the color a property has in effect
    // in that mode. A probe on the page itself can't do this: tokens defined
    // on :root as var() chains are computed once at <html> in the page's
    // current mode, and Bootstrap's light block hides the palette's values.
    let framesLoaded = 0;
    let destroyed = false;
    let previewCss = '';
    const escapeAttr = s => s.replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;');
    const links = Array.from(document.head.querySelectorAll('link[rel="stylesheet"]'))
        .map(link => '<link rel="stylesheet" href="' + escapeAttr(link.href) + '"'
            + (link.media ? ' media="' + escapeAttr(link.media) + '"' : '') + '>').join('');
    const frames = {};
    for (const mode of ['light', 'dark']) {
        const frame = document.createElement('iframe');
        frame.className = 'visually-hidden';
        frame.setAttribute('aria-hidden', 'true');
        frame.tabIndex = -1;
        frame.srcdoc = '<!DOCTYPE html><html data-bs-theme="' + mode + '"><head>' + links
            + '<style id="sitecss"></style></head><body><div style="color: transparent"><span id="probe"></span></div></body></html>';
        frame.addEventListener('load', function() {
            if (++framesLoaded === 2) refreshPickers();
        });
        frames[mode] = frame;
        form.append(frame);
    }

    const effectiveColor = function(name, mode) {
        const doc = frames[mode].contentDocument;
        const probe = doc.getElementById('probe');
        probe.style.color = 'var(' + name + ')';
        return computedToHex(doc.defaultView.getComputedStyle(probe).color);
    };

    // A picker can't be empty, so for a field without a hex value it shows
    // the color in effect. Until both frames load, pickers stay as they are.
    const refreshPickers = function() {
        if (destroyed || framesLoaded < 2) return;
        for (const frame of Object.values(frames)) {
            const style = frame.contentDocument.getElementById('sitecss');
            if (style.textContent !== previewCss) style.textContent = previewCss;
        }
        form.querySelectorAll('input.palette-picker').forEach(function(picker) {
            if (toHex(pairedInput(picker, 'palette-value').value.trim())) return;
            const hex = effectiveColor(picker.dataset.property, picker.dataset.mode);
            if (hex) picker.value = hex;
        });
    };

    const render = function() {
        previewCss = preview();
        if (sitecss) sitecss.textContent = previewCss;
        refreshPickers();
    };

    const preview = function() {
        const shared = {}, lightOnly = {}, dark = {};
        // Stored properties without a field in the editor stay in the preview.
        Object.assign(dark, extra.dark);
        for (const [name, value] of Object.entries(extra.light || {})) {
            (modeSpecific.has(name) ? lightOnly : shared)[name] = value;
        }
        form.querySelectorAll('input.palette-value').forEach(function(input) {
            const value = input.value.trim();
            if (!value) return;
            const name = input.dataset.property;
            if (input.dataset.mode === 'dark') dark[name] = value;
            else if (modeSpecific.has(name)) lightOnly[name] = value;
            else shared[name] = value;
        });
        // As in ThemePaletteCSS, each mode's contrast derives from that
        // mode's own primary, and the light one goes where any light value
        // of that name would.
        const light = Object.assign({}, shared, lightOnly);
        const contrastName = '--rt-primary-contrast';
        for (const [values, target] of [[light, modeSpecific.has(contrastName) ? lightOnly : shared], [dark, dark]]) {
            if (!values['--bs-primary'] || contrastName in values) continue;
            const contrast = contrastColor(values['--bs-primary']);
            if (contrast) target[contrastName] = contrast;
        }
        const css = [
            block(':root', shared),
            block(':root:not([data-bs-theme=dark])', lightOnly),
            block('[data-bs-theme=dark]', dark),
        ].filter(Boolean).join('\n');
        return css + (userCss ? '\n' + cssPart(userCss.value) : '');
    };

    const pairedInput = function(el, selector) {
        return form.querySelector('input.' + selector + '[data-mode="' + el.dataset.mode
            + '"][data-property="' + el.dataset.property + '"]');
    };

    form.querySelectorAll('input.palette-picker').forEach(function(picker) {
        const hex = toHex(pairedInput(picker, 'palette-value').value.trim());
        if (hex) picker.value = hex;
        picker.addEventListener('input', function() {
            pairedInput(picker, 'palette-value').value = picker.value;
            render();
        });
    });

    form.querySelectorAll('input.palette-value').forEach(function(input) {
        input.addEventListener('focus', function() { lastFocused = input; });
        input.addEventListener('input', function() {
            const picker = pairedInput(input, 'palette-picker');
            const hex = toHex(input.value.trim());
            if (picker && hex) picker.value = hex;
            render();
        });
    });

    document.querySelectorAll('.color-swatch').forEach(function(swatch) {
        swatch.addEventListener('click', function() {
            if (!lastFocused) return;
            lastFocused.value = swatch.dataset.color;
            lastFocused.dispatchEvent(new Event('input'));
        });
    });

    toggleButton?.addEventListener('click', function() {
        const current = currentMode();
        if (previousTheme === null) previousTheme = current;
        const next = current === 'dark' ? 'light' : 'dark';
        html.setAttribute('data-bs-theme', next);
        toggleButton.textContent = next === 'dark' ? toggleButton.dataset.labelLight : toggleButton.dataset.labelDark;
    });

    // Lets the page come back on the tab the palette was saved from.
    // shown.bs.tab also fires for arrow-key switching, which click misses.
    const tabField = form.querySelector('input[name="theme_tab"]');
    document.getElementById('theme-tabs')?.addEventListener('shown.bs.tab', function(evt) {
        const tab = evt.target.dataset.themeTab;
        if (tab !== 'custom-css') tabField.value = tab;
    });

    userCss?.addEventListener('input', render);
    document.getElementById('try')?.addEventListener('click', render);
    // The form's reset restores the textarea after this event fires.
    document.getElementById('reset')?.addEventListener('click', function() {
        resetTimer = setTimeout(function() {
            render();
        }, 0);
    });

    form.themeEditor = {
        destroy() {
            clearTimeout(resetTimer);
            destroyed = true;
            Object.values(frames).forEach(frame => frame.remove());
            if (sitecss) sitecss.textContent = savedCss;
            if (previousTheme !== null) html.setAttribute('data-bs-theme', previousTheme);
        },
    };

    if (sitecss) sitecss.textContent = savedCss;
    render();
})();
