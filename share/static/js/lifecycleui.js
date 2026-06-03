// Shared lifecycle-graph helpers used by both the admin editor
// (lifecycleui-editor.js) and the read-only ticket viewer
// (lifecycleui-viewer.js). Loaded alongside cytoscape on the pages that need
// it, not globally — most users never render a lifecycle graph.

RT.LifecycleGraph ||= {
    // Default node background per status type, used when a status has no
    // explicit color of its own.
    TypeColors: { initial: '#599ACC', active: '#547CCC', inactive: '#4bb2cc' },

    // Zoom limits applied to every lifecycle graph.
    MinZoom: 0.3,
    MaxZoom: 3,

    // Resolve a node's background color: an explicit per-status color wins,
    // then the type default, then a neutral fallback.
    NodeColor: function (explicit, type) {
        return explicit || RT.LifecycleGraph.TypeColors[type] || '#e9ecef';
    },

    // Base cytoscape stylesheet shared by the editor and viewer. Each caller
    // concatenates its own selection-highlight rules (the editor's selected
    // node/edge, the viewer's current status). opts:
    //   nodeRadius - node radius in model units (node is 2*r across)
    //   fontSize   - label font size
    //   edgeColor  - line and arrow color
    //   arrowScale - arrowhead scale
    Stylesheet: function (opts) {
        return [
            {
                selector: 'node',
                style: {
                    'shape': 'ellipse',
                    'width': opts.nodeRadius * 2,
                    'height': opts.nodeRadius * 2,
                    'background-color': 'data(color)',
                    'border-width': 1,
                    'border-color': '#000',
                    'label': 'data(name)',
                    'text-valign': 'center',
                    'text-halign': 'center',
                    'color': 'data(textColor)',
                    'font-size': opts.fontSize,
                    'text-wrap': 'wrap',
                    'text-max-width': opts.nodeRadius * 1.9,
                },
            },
            {
                selector: 'edge',
                style: {
                    'width': 1,
                    'line-color': opts.edgeColor,
                    'target-arrow-color': opts.edgeColor,
                    'source-arrow-color': opts.edgeColor,
                    'curve-style': 'bezier',
                    'arrow-scale': opts.arrowScale,
                },
            },
            {
                selector: 'edge.has-end',
                style: { 'target-arrow-shape': 'triangle' },
            },
            {
                selector: 'edge.has-start',
                style: { 'source-arrow-shape': 'triangle' },
            },
        ];
    },

    // Add on-screen zoom controls (zoom in, zoom out, fit-to-view) to a
    // cytoscape graph.
    //   cy        - the cytoscape instance
    //   container - the graph's container element; controls are positioned
    //               within it (made position:relative if it isn't already)
    //   opts      - keyboard: bind +/-/0 while the graph is engaged (pointer
    //                 over it, or it holds keyboard focus).
    //               onReset: optional callback fired when the user hits
    //                 fit-to-view (the fit button or the '0' key). The viewer
    //                 uses it to clear its saved zoom.
    //               signal: optional AbortSignal for the document-level keydown
    //                 listener below. That listener outlives the graph's own
    //                 subtree, so aborting the signal on teardown is what stops
    //                 it accumulating across htmx refreshes. The control/button
    //                 listeners are on elements inside the graph and are GC'd
    //                 with the subtree, so they don't need it.
    AddZoomControls: function (cy, container, opts) {
        opts = opts || {};

        // Reference RT's shared icon sprite (built from the %SVG config) by
        // name, the same way the date picker does in util.js. fill=currentColor
        // lets the CSS drive the glyph color; the icons are overridable via
        // the config.
        const icon = function (name) {
            return '<svg class="bi" width="14" height="14" fill="currentColor" ' +
                   'viewBox="0 0 16 16" aria-hidden="true"><use href="' +
                   RT.Config.WebPath + '/NoAuth/css/icons.svg#' + name + '"></use></svg>';
        };

        const zoomBy = function (factor) {
            cy.zoom({
                level: cy.zoom() * factor,   // cytoscape clamps to min/maxZoom
                renderedPosition: { x: cy.width() / 2, y: cy.height() / 2 }
            });
        };
        const fit = function () {
            cy.fit(undefined, 20);
            if (opts.onReset) opts.onReset();   // e.g. clear a saved zoom
        };

        const controls = document.createElement('div');
        controls.className = 'lifecycle-zoom-controls';

        // The controls sit inside the cytoscape container, so a press on them
        // would otherwise bubble to cytoscape and register as a background tap
        // (e.g. the editor's "click empty space to add a status"). cytoscape
        // derives taps from mousedown/up, so stopping the click is too late —
        // block the pointer events themselves before they reach it.
        ['mousedown', 'mouseup', 'click', 'pointerdown', 'pointerup', 'touchstart', 'touchend']
            .forEach(function (type) {
                controls.addEventListener(type, function (e) { e.stopPropagation(); });
            });

        const makeBtn = function (iconHtml, label, handler) {
            const btn = document.createElement('button');
            btn.type = 'button';
            btn.className = 'lifecycle-zoom-btn';
            btn.setAttribute('aria-label', label);
            btn.setAttribute('title', label);
            btn.innerHTML = iconHtml;
            btn.addEventListener('click', function (e) {
                e.preventDefault();
                handler();
            });
            controls.appendChild(btn);
        };

        makeBtn(icon('plus'),              RT.I18N.Catalog.zoom_in,     function () { zoomBy(1.2); });
        makeBtn(icon('dash-lg'),           RT.I18N.Catalog.zoom_out,    function () { zoomBy(1 / 1.2); });
        makeBtn(icon('arrows-fullscreen'), RT.I18N.Catalog.fit_to_view, fit);

        if (getComputedStyle(container).position === 'static') {
            container.style.position = 'relative';
        }
        container.appendChild(controls);

        // Mouse wheel: a plain scroll passes through to the page (the graph
        // sits in normally-scrollable pages), and only Ctrl/Cmd+wheel zooms,
        // toward the pointer. cytoscape's own wheel zoom is disabled at init
        // (userZoomingEnabled: false), so a plain scroll is never captured.
        // A Mac trackpad pinch arrives as a ctrl+wheel event, so this covers
        // pinch-to-zoom too. Bound on the container (inside the graph subtree),
        // so it's removed with the subtree on an htmx swap; the signal just
        // keeps it consistent with the document-level keydown below.
        container.addEventListener('wheel', function (e) {
            if (!e.ctrlKey && !e.metaKey) return;   // plain scroll -> page scrolls
            e.preventDefault();
            const rect = container.getBoundingClientRect();
            let dy = e.deltaY;
            if (e.deltaMode === 1) dy *= 16;             // lines -> ~px
            else if (e.deltaMode === 2) dy *= rect.height;   // pages -> px
            dy = Math.max(-60, Math.min(60, dy));        // tame oversized deltas
            cy.zoom({
                level: cy.zoom() * Math.exp(-dy * 0.0025),   // cytoscape clamps to min/maxZoom
                renderedPosition: { x: e.clientX - rect.left, y: e.clientY - rect.top }
            });
        }, { passive: false, signal: opts.signal });

        if (opts.keyboard) {
            // Tab-focusable so keyboard-only users can engage the graph; the
            // :focus-visible ring (CSS) shows for them but not for mouse users.
            if (!container.hasAttribute('tabindex')) container.setAttribute('tabindex', '0');

            // The keys work when the graph is "engaged" — the pointer is over
            // it, or it holds keyboard focus. + / - / 0 elsewhere
            // on the page are untouched.
            let hovering = false;
            container.addEventListener('mouseenter', function () { hovering = true; });
            container.addEventListener('mouseleave', function () { hovering = false; });

            document.addEventListener('keydown', function (e) {
                const t = e.target;
                if (t && (t.tagName === 'INPUT' || t.tagName === 'SELECT' ||
                          t.tagName === 'TEXTAREA' || t.isContentEditable)) return;
                if (!hovering && !container.contains(document.activeElement)) return;
                let handled = true;
                if (e.key === '+' || e.key === '=') zoomBy(1.2);
                else if (e.key === '-' || e.key === '_') zoomBy(1 / 1.2);
                else if (e.key === '0') fit();
                else handled = false;
                if (handled) {
                    e.preventDefault();
                    // These keys are ours while engaged; don't let them bubble
                    // to RT's global Mousetrap shortcuts on document.
                    e.stopPropagation();
                }
            }, { signal: opts.signal });
        }
    },
};
