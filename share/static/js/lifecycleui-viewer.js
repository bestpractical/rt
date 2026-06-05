RT.LifecycleViewer ||= class {
    constructor(container) {
        const self = this;

        self.container       = container;
        self.graphEl         = container.querySelector('.lifecycle-viewer-graph');
        self.config = { initial: [], active: [], inactive: [], transitions: {}, colors: {} };
        const configAttr = container.getAttribute('data-config');
        if (configAttr) {
            try { self.config = JSON.parse(configAttr) || self.config; } catch (e) { /* keep default */ }
        }
        self.currentStatus   = container.getAttribute('data-current') || '';
        self.node_radius     = 30;

        const layoutAttr = container.getAttribute('data-layout');
        let parsedLayout = null;
        if (layoutAttr) {
            try { parsedLayout = JSON.parse(layoutAttr); } catch (e) { parsedLayout = null; }
        }
        // Only treat the layout as usable if it's a non-empty hash.
        self.layout = (parsedLayout && typeof parsedLayout === 'object' && Object.keys(parsedLayout).length) ? parsedLayout : null;

        // Click-to-transition: a click on a directly-reachable status moves the
        // ticket there. The reachable-now targets are the permitted one-hop
        // transitions out of the current status (the config is already filtered
        // to those by the server).
        self.ticketId = container.getAttribute('data-ticket-id') || '';
        self.confirmStatusChange = container.getAttribute('data-confirm-status-change') !== '0';
        self.directTargets = self.DirectTargets();

        // User-facing descriptions for tooltips, keyed lower-case.
        self.descriptions = { statuses: {}, transitions: {} };
        const descAttr = container.getAttribute('data-descriptions');
        if (descAttr) {
            try { self.descriptions = JSON.parse(descAttr) || self.descriptions; } catch (e) { /* keep default */ }
        }

        self.cy = cytoscape({
            container: self.graphEl,
            elements: self.BuildElements(),
            style: self.Stylesheet(),
            layout: self.LayoutOptions(),
            boxSelectionEnabled: false,
            autoungrabify: true,
            autounselectify: true,   // read-only view: clicking shouldn't select
            userPanningEnabled: true,
            // Plain wheel scrolls the page; AddZoomControls binds Ctrl/Cmd+wheel
            // (and trackpad pinch) for zooming instead.
            userZoomingEnabled: false,
            minZoom: RT.LifecycleGraph.MinZoom,
            maxZoom: RT.LifecycleGraph.MaxZoom,
        });

        // --- Persist the user's zoom/pan per lifecycle so it survives reloads.
        const lifecycleName = container.getAttribute('data-lifecycle') || '';
        const storeKey = lifecycleName ? 'RT-LifecycleViewerZoom-' + lifecycleName : null;

        let savedView = null;
        if (storeKey) {
            try { savedView = JSON.parse(localStorage.getItem(storeKey)); } catch (e) { savedView = null; }
            if (!savedView || typeof savedView.zoom !== 'number' || !savedView.pan) savedView = null;
        }
        // A customized view should be preserved across reflows rather than
        // re-fitted. True once a saved view is loaded or the user zooms/pans.
        let customized = !!savedView;

        let saveTimer;
        const saveView = function () {           // debounced; coalesces wheel/drag bursts
            clearTimeout(saveTimer);
            if (!storeKey) return;
            saveTimer = setTimeout(function () {
                if (!self.cy) return;
                customized = true;
                try {
                    localStorage.setItem(storeKey, JSON.stringify({ zoom: self.cy.zoom(), pan: self.cy.pan() }));
                } catch (e) { /* storage unavailable (private mode / quota) — ignore */ }
            }, 300);
        };
        const cancelSave = function () { clearTimeout(saveTimer); };

        // Add the circle + badge once the layout has placed the real nodes, so
        // we can glue them to the current node's final position.
        self.cy.ready(function () { self.HighlightCurrent(); });

        // Tracks the listeners AddZoomControls binds outside this widget's own
        // DOM subtree (the document-level keydown) so destroy() can remove them
        // when an htmx portlet refresh swaps the viewer out.
        self._abort = new AbortController();

        RT.LifecycleGraph.AddZoomControls(self.cy, self.graphEl, {
            keyboard: true,
            signal: self._abort.signal,
            onReset: function () {             // fit-to-view: drop the saved view
                cancelSave();
                customized = false;
                if (storeKey) { try { localStorage.removeItem(storeKey); } catch (e) {} }
            }
        });

        if (storeKey) {
            // Any user zoom/pan (buttons, keys, wheel, drag) persists. The
            // programmatic changes below cancel the pending save so a restore,
            // reset, or resize never overwrites or resurrects a view.
            self.cy.on('zoom pan', saveView);

            // Restore after the initial layout/fit has run.
            self.cy.ready(function () {
                if (savedView) {
                    self.cy.zoom(savedView.zoom);   // clamped to min/maxZoom
                    self.cy.pan(savedView.pan);
                }
                cancelSave();
            });
        }

        // Keep the graph framed as the container resizes. The widget can live in
        // columns of any width, and with the CSS aspect-ratio its height tracks
        // that width — so we react to any size change (column reflow, sidebar
        // toggle, window resize). resize() preserves zoom/pan, so we only
        // re-fit when the user hasn't customized the view. rAF-coalesced.
        if (window.ResizeObserver) {
            let pending = false;
            self._resizeObserver = new ResizeObserver(function() {
                if (pending) return;
                pending = true;
                requestAnimationFrame(function() {
                    pending = false;
                    if (!self.cy) return;
                    self.cy.resize();
                    if (!customized) self.cy.fit(undefined, 20);
                    cancelSave();
                });
            });
            self._resizeObserver.observe(self.graphEl);
        }

        if (self.ticketId) self.EnableClickToTransition();
        self.SetupTooltips();
    }

    // Tear down everything that outlives this widget's DOM subtree. The viewer
    // lives in an htmx-refreshed portlet (a status change refreshes it), so
    // without this each refresh would accumulate a document keydown listener, an
    // orphan tooltip on document.body, and a dead cytoscape instance. Called
    // from init.js's htmx:beforeCleanupElement / beforeHistorySave hooks.
    // Idempotent.
    destroy() {
        this._abort?.abort();              // removes the document-level keydown listener
        this._resizeObserver?.disconnect();
        this._tooltipHandle?.destroy();    // popper instance still tracking a hovered element
        this._tooltipHandle = null;
        this._tooltip?.remove();           // tooltip is appended to document.body
        // The confirm dialog is a Bootstrap modal; dispose it so its instance
        // doesn't linger in Bootstrap's element-keyed registry once this
        // portlet is swapped out on a status-change refresh.
        if (window.bootstrap) {
            const modalEl = this.ModalEl();
            if (modalEl) bootstrap.Modal.getInstance(modalEl)?.dispose();
        }
        this.cy?.destroy();                // also drops every cy.on binding
        this.cy = null;
    }

    // Show a status/transition's description on hover.
    //
    // Cytoscape draws to a canvas, so nodes/edges have no DOM element to anchor
    // a tooltip to. cytoscape-popper bridges that: el.popper() gives a Popper
    // reference that tracks the element's rendered position, which positions
    // our Bootstrap-styled tooltip. The factory reuses the Popper v2 that RT
    // already bundles for Bootstrap.
    SetupTooltips() {
        const self = this, cy = self.cy;
        const statuses    = self.descriptions.statuses || {};
        const transitions = self.descriptions.transitions || {};
        if (!Object.keys(statuses).length && !Object.keys(transitions).length) return;
        if (!window.cytoscape || !window.cytoscapePopper || !window.Popper) return;

        // Register the extension once per page, wiring in the bundled Popper v2.
        if (!RT.LifecycleGraph._popperRegistered) {
            cytoscape.use(cytoscapePopper(function (ref, content, opts) {
                return Popper.createPopper(ref, content, opts);
            }));
            RT.LifecycleGraph._popperRegistered = true;
        }

        // One reusable tooltip element using Bootstrap's tooltip markup/classes.
        const tip = document.createElement('div');
        tip.className = 'tooltip bs-tooltip-auto';
        tip.setAttribute('role', 'tooltip');
        tip.style.position = 'absolute';
        tip.style.pointerEvents = 'none';
        tip.innerHTML = '<div class="tooltip-arrow"></div><div class="tooltip-inner"></div>';
        document.body.appendChild(tip);
        const inner = tip.querySelector('.tooltip-inner');
        const arrow = tip.querySelector('.tooltip-arrow');
        self._tooltip = tip;

        // Stored on the instance (not a closure local) so destroy() can dispose
        // a tooltip still showing when an htmx refresh swaps the viewer out.
        self._tooltipHandle = null;
        const hide = function () {
            tip.classList.remove('show');
            if (self._tooltipHandle) { self._tooltipHandle.destroy(); self._tooltipHandle = null; }
        };
        const show = function (el, text) {
            if (!text) { hide(); return; }
            // Render each line as text (no HTML) so admin-entered descriptions
            // can't inject markup; multi-line is only the two-direction edge case.
            inner.textContent = '';
            text.split('\n').forEach(function (line, i) {
                if (i) inner.appendChild(document.createElement('br'));
                inner.appendChild(document.createTextNode(line));
            });
            if (self._tooltipHandle) self._tooltipHandle.destroy();
            self._tooltipHandle = el.popper({
                content: tip,
                popper: {
                    placement: 'top',
                    modifiers: [
                        { name: 'arrow',          options: { element: arrow } },
                        { name: 'offset',         options: { offset: [0, 6] } },
                        { name: 'flip',           options: { fallbackPlacements: ['bottom', 'right', 'left'] } },
                        { name: 'preventOverflow', options: { padding: 8 } },
                    ],
                },
            });
            tip.classList.add('show');
        };

        cy.on('mouseover', 'node', function (evt) {
            const node = evt.target;
            if (node.hasClass('current-badge')) return;
            show(node, statuses[String(node.data('name')).toLowerCase()]);
        });
        cy.on('mouseout', 'node', hide);

        cy.on('mouseover', 'edge', function (evt) {
            show(evt.target, self.EdgeTooltipText(evt.target));
        });
        cy.on('mouseout', 'edge', hide);

        // Keep the tooltip glued to its element as the view moves.
        cy.on('pan zoom resize', function () { if (self._tooltipHandle) self._tooltipHandle.update(); });
    }

    // Build an edge's tooltip from its transition description(s). A
    // bidirectional edge labels each direction; a one-way edge shows its single
    // description plainly.
    EdgeTooltipText(edge) {
        const t = this.descriptions.transitions || {};
        const from = edge.source().data('name'), to = edge.target().data('name');
        if (from === undefined || to === undefined) return '';
        const fwd = t[(from + ' -> ' + to).toLowerCase()];
        const rev = t[(to + ' -> ' + from).toLowerCase()];
        const bidir = edge.hasClass('has-start') && edge.hasClass('has-end');
        const lines = [];
        if (bidir) {
            if (fwd) lines.push(from + ' → ' + to + ': ' + fwd);
            if (rev) lines.push(to + ' → ' + from + ': ' + rev);
        } else if (fwd) {
            lines.push(fwd);
        } else if (rev) {
            lines.push(rev);
        }
        return lines.join('\n');
    }

    BuildElements() {
        const self = this;
        const elements = [];
        const rawColors = self.config.colors || {};
        const colors = {};
        Object.keys(rawColors).forEach(function(k) { colors[k.toLowerCase()] = rawColors[k]; });

        const current = (self.currentStatus || '').toLowerCase();
        // Only fade unreachable statuses when the viewer is interactive and the
        // user actually has somewhere to click to; otherwise nothing is clickable
        // and dimming would be a false signal.
        const dimUnreachable = !!self.ticketId
            && self.directTargets && Object.keys(self.directTargets).length > 0;

        self._allPositioned = true;
        const nodeByLower = {};   // lower-cased status name -> canonical name, for edges
        ['initial', 'active', 'inactive'].forEach(function(type) {
            (self.config[type] || []).forEach(function(name) {
                const bg = RT.LifecycleGraph.NodeColor(colors[name.toLowerCase()], type);
                const isCurrent = name.toLowerCase() === current;
                const classes = [];
                if (isCurrent) {
                    classes.push('current');
                } else if (self.directTargets && self.directTargets[name.toLowerCase()]) {
                    classes.push('clickable');
                } else if (dimUnreachable) {
                    classes.push('unreachable');   // can't transition here from the current status
                }
                const el = {
                    group: 'nodes',
                    data: {
                        id: 'n:' + name,
                        name: name,
                        type: type,
                        color: bg,
                        textColor: contrastTextColor(bg),
                    },
                    classes: classes.join(' '),
                };
                if (self.layout && self.layout[name]) {
                    el.position = { x: self.layout[name][0], y: self.layout[name][1] };
                } else {
                    self._allPositioned = false;
                }
                nodeByLower[name.toLowerCase()] = name;
                elements.push(el);
            });
        });

        // Edges from transitions; skip the '' key (on-create entry points, not
        // real transitions). Merge the two directions of a bidirectional
        // transition into one double-headed edge, matching the admin editor.
        const created = {};   // "source|target" -> element
        let edgeId = 0;
        Object.keys(self.config.transitions || {}).forEach(function(from) {
            if (!from) return;
            (self.config.transitions[from] || []).forEach(function(to) {
                // Transition keys are stored lower-cased while node ids use the
                // status's canonical case, so resolve both ends to the canonical
                // node name. Skip a transition to/from a status with no node
                // (e.g. one removed from the type lists but left in a hand-edited
                // config): cytoscape throws on an edge with a missing endpoint,
                // which would abort rendering the whole graph.
                const f = nodeByLower[String(from).toLowerCase()];
                const t = nodeByLower[String(to).toLowerCase()];
                if (!f || !t) return;
                const key = f + '|' + t;
                const revKey = t + '|' + f;
                if (created[key]) return;                 // same direction already added
                if (created[revKey]) {                    // reverse exists -> bidirectional
                    created[revKey].classes = 'has-start has-end';
                    return;
                }
                const el = {
                    group: 'edges',
                    data: {
                        id: 'e' + (++edgeId),
                        source: 'n:' + f,
                        target: 'n:' + t,
                    },
                    classes: 'has-end',
                };
                created[key] = el;
                elements.push(el);
            });
        });

        return elements;
    }

    // Glue the green "active/live" badge to the current status node. Added
    // after layout (rather than in BuildElements) so it tracks the node's
    // final position regardless of which layout placed it, and so it never
    // participates in layout itself.
    HighlightCurrent() {
        const cur = this.cy.nodes('.current');
        if (!cur.length) return;
        const pos = cur.position();
        const r = this.node_radius;
        this.cy.add({
            // ~45° up and to the right, sitting on the node's perimeter.
            group: 'nodes',
            data: { id: '__current_badge' },
            position: { x: pos.x + r * 0.72, y: pos.y - r * 0.72 },
            classes: 'current-badge',
            selectable: false,
            grabbable: false,
        });
    }

    // The statuses reachable in a single permitted transition from the current
    // status — i.e. the ones a click may move the ticket to. Returned as a set
    // keyed by lower-cased status name.
    DirectTargets() {
        const current = (this.currentStatus || '').toLowerCase();
        const targets = {};
        const transitions = this.config.transitions || {};
        Object.keys(transitions).forEach(function (from) {
            if (from.toLowerCase() !== current) return;
            (transitions[from] || []).forEach(function (to) { targets[to.toLowerCase()] = true; });
        });
        return targets;
    }

    ModalEl() {
        return this.container.parentNode
            ? this.container.parentNode.querySelector('.lifecycle-confirm-modal')
            : null;
    }

    // Wire up clicking a reachable status to change the ticket's status.
    EnableClickToTransition() {
        const self = this, cy = self.cy, graphEl = self.graphEl;

        // A pointer cursor signals the clickable statuses.
        cy.on('mouseover', 'node.clickable', function () { graphEl.style.cursor = 'pointer'; });
        cy.on('mouseout', 'node.clickable', function () { graphEl.style.cursor = ''; });

        cy.on('tap', 'node.clickable', function (evt) {
            const name = evt.target.data('name');
            if (name) self.PromptStatusChange(name);
        });

        // Bind the dialog's confirm button once; it acts on the pending target.
        const modalEl = self.ModalEl();
        if (modalEl) {
            const okButton = modalEl.querySelector('.lifecycle-confirm-ok');
            if (okButton) okButton.addEventListener('click', function () {
                const skip = modalEl.querySelector('.lifecycle-confirm-skip');
                if (skip && skip.checked) self.DisableConfirmation();
                const target = self._pendingStatus;
                self._pendingStatus = null;
                // The modal has no fade, so hide() finishes synchronously and
                // is fully torn down before the change's portlet refresh swaps
                // this markup out.
                if (window.bootstrap) bootstrap.Modal.getOrCreateInstance(modalEl).hide();
                if (target) self.ChangeStatus(target);
            });
        }
    }

    // Show the confirmation dialog for a status change, or skip straight to it
    // when the user has turned the confirmation off.
    PromptStatusChange(toStatus) {
        const modalEl = this.ModalEl();
        if (!this.confirmStatusChange || !modalEl || !window.bootstrap) {
            this.ChangeStatus(toStatus);
            return;
        }
        this._pendingStatus = toStatus;
        const label = modalEl.querySelector('.lifecycle-target-status');
        if (label) label.textContent = toStatus;
        const skip = modalEl.querySelector('.lifecycle-confirm-skip');
        if (skip) skip.checked = false;
        bootstrap.Modal.getOrCreateInstance(modalEl).show();
    }

    // Remember (server-side) that this user doesn't want the confirmation
    // dialog, and stop showing it for the rest of this page's life.
    DisableConfirmation() {
        this.confirmStatusChange = false;
        if (window.htmx) {
            htmx.ajax('POST', RT.Config.WebPath + '/Helpers/SetLifecycleConfirmPref',
                { values: { Confirm: 0 }, source: this.container, swap: 'none' });
        }
    }

    // Post the status change the same way the inline Basics edit does. The
    // response's HX-Trigger fires ticketStatusChanged, which refreshes this
    // portlet (and the others) with the new current status.
    ChangeStatus(toStatus) {
        if (!window.htmx || !this.ticketId) return;
        htmx.ajax('POST', RT.Config.WebPath + '/Helpers/TicketUpdate',
            { values: { id: this.ticketId, Status: toStatus }, source: this.container, swap: 'none' });
    }

    // Resolve a CSS custom property (a Bootstrap theme variable) to its current
    // value, read from the graph element so theme overrides cascade in. Used to
    // keep canvas colors — which cytoscape parses itself and can't read CSS vars
    // for — in sync with the active light/dark theme.
    ThemeColor(varName) {
        return getComputedStyle(this.graphEl).getPropertyValue(varName).trim();
    }

    Stylesheet() {
        // A bright "active/live" green for the badge, ringed in the theme's body
        // foreground color for contrast against the node behind it (so the ring
        // tracks light/dark mode).
        const badgeFill   = '#2ecc40';
        const badgeBorder = this.ThemeColor('--bs-body-color');
        return RT.LifecycleGraph.Stylesheet({
            nodeRadius: this.node_radius,
            fontSize: 10,
            edgeColor: '#888',
            arrowScale: 0.8,
        }).concat([
            // Suppress cytoscape's default gray tap/active overlay on nodes —
            // this is a read-only view, so a click shouldn't leave a highlight.
            {
                selector: 'node',
                style: { 'overlay-opacity': 0 },
            },
            // Fade statuses the object can't transition to from the current one
            // (tagged only when the viewer is interactive) so the clickable
            // targets stand out as the actionable ones.
            {
                selector: 'node.unreachable',
                style: { 'opacity': 0.4 },
            },
            // Ring the current status node so it reads as "you are here" at a
            // glance, not by the corner dot alone. Reuses the badge's active
            // green; the thicker border is a shape cue, not color only.
            {
                selector: 'node.current',
                style: {
                    'border-width': 5,
                    'border-color': badgeFill,
                },
            },
            // The current status is marked with a small green "active/live"
            // badge on its upper-right, added as a decoration node by
            // HighlightCurrent(), like a notification dot.
            {
                // Badge: small green dot ringed for contrast. Sits above the
                // status nodes (which default to z-index 0).
                selector: 'node.current-badge',
                style: {
                    'shape': 'ellipse',
                    'width': 13,
                    'height': 13,
                    'background-color': badgeFill,
                    'border-width': 1.5,
                    'border-color': badgeBorder,
                    'events': 'no',
                    'z-index': 20,
                    // Decoration dot: no text. Set label/color explicitly so the
                    // base node rule's data(name)/data(textColor) mappings aren't
                    // applied to this node, which has neither (cytoscape warns
                    // "no mapping for property ... with data field ..." otherwise).
                    'label': '',
                    'color': badgeBorder,
                },
            },
        ]);
    }

    LayoutOptions() {
        // Prefer the admin-saved positions when every visible status has one —
        // gives users a predictable, admin-designed layout that scales to fit
        // the portlet via Cytoscape's preset+fit. This is the normal case.
        if (this.layout && this._allPositioned) {
            return { name: 'preset', fit: true, padding: 20 };
        }
        // Fallback only — no saved layout, or a status was added after the
        // admin last saved. Use a built-in layout so the viewer never depends
        // on a layout extension. The admin re-saving the lifecycle restores a
        // proper preset layout.
        return { name: 'cose', animate: false, fit: true, padding: 20 };
    }
}
