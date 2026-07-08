RT.NewLifecycleEditor ||= class {
    constructor(container, config, maps, layout) {
        const self = this;

        self.container        = container;
        self.graphContainer   = container.querySelector('.lifecycle-graph');
        self.config           = config;
        self.maps             = maps || {};
        self.layout           = layout;
        self.links_seq        = 0;
        self.nodes_seq        = 0;
        self.create_nodes     = [];
        self.nodes            = [];
        self.links            = [];
        self.node_radius      = 40;
        self.selected_node    = null;
        self.selected_edge    = null;
        self.editing_node     = null;
        self.editing_edge     = null;
        self.edgeDragSource   = null;

        // Tracks the listeners SetUp/SetupEdgeDrag/AddZoomControls bind on
        // document, which outlive this widget's own DOM subtree. destroy()
        // aborts the signal to remove them when an hx-boost navigation swaps
        // the editor out, so they don't accumulate across visits.
        self._abort           = new AbortController();

        // "Pending changes" reminder state. The baseline is the serialized
        // state at load; until it's captured no reminder is shown, so opening
        // the editor never looks like an edit. With a saved layout (preset) the
        // state is settled by the end of this constructor; without one, the
        // async cose layout finishes later, so the baseline is captured in the
        // layoutstop handler instead.
        self._changeBaseline      = null;
        self._currentSerialized   = null;
        self._pendingReminderReady = false;

        self.NormalizeMetadata();
        self.WireEditPanel();
        self.WireTransitionPanel();
        self.NodesFromConfig(config);
        self.LinksFromConfig(config);
        self.CytoscapeInit();
        self.SetUp();
        self.ExportAsConfiguration();

        // When the initial view is settled synchronously (saved/preset layout,
        // or an empty new lifecycle), lock in the baseline and restore any saved
        // view now. A non-empty cose layout defers both to layoutstop.
        if (self._layoutSettledSync) {
            self._changeBaseline = self._currentSerialized;
            self._pendingReminderReady = true;
            self.RestoreSavedView();
        }
    }

    // Tear down everything that outlives this widget's DOM subtree. The editor
    // lives on an hx-boost-navigated admin page, so without this each visit
    // would leave behind document-level listeners (the edge-drag mouseup and
    // the zoom keydown) and a live cytoscape instance.
    // Called from init.js's htmx:beforeCleanupElement / beforeHistorySave
    // hooks. Idempotent.
    destroy() {
        this._abort?.abort();              // removes the document-level listeners
        if (this._cancelSaveView) this._cancelSaveView();
        clearTimeout(this._hideEditTimer);
        // Dispose the Bootstrap modal instances so they don't linger in
        // Bootstrap's element-keyed registry after this admin page is swapped
        // out by an hx-boost navigation.
        if (window.bootstrap) {
            ['lifecycle-ui-edit-node', 'lifecycle-ui-edit-transition'].forEach(function (id) {
                const el = document.getElementById(id);
                if (el) bootstrap.Modal.getInstance(el)?.dispose();
            });
        }
        this.cy?.destroy();                // also drops every cy.on binding
        this.cy = null;
    }

    // ---------- Data layer (renderer-agnostic) ----------

    NodesFromConfig(config) {
        const self = this;
        self.nodes = [];
        const rawColors = config.colors || {};
        const colors = {};
        Object.keys(rawColors).forEach(function(key) { colors[key.toLowerCase()] = rawColors[key]; });

        ['initial', 'active', 'inactive'].forEach(function (type) {
            if (!config[type]) return;
            config[type].forEach(function(element) {
                const node = {
                    id: ++self.nodes_seq,
                    name: element,
                    type: type,
                    color: colors[element.toLowerCase()] || ''
                };
                if (self.layout && self.layout[element]) {
                    node.x = parseInt(self.layout[element][0]);
                    node.y = parseInt(self.layout[element][1]);
                }
                self.nodes.push(node);
            });
        });
    }

    LinksFromConfig(config) {
        const self = this;
        self.links = [];
        self.create_nodes = [];

        for (let [fromName, toList] of Object.entries(config.transitions || {})) {
            if (fromName === '') {
                self.create_nodes = toList.slice();
                continue;
            }
            const source = self.nodes.find(n => n.name.toLowerCase() === fromName.toLowerCase());
            if (!source) continue;

            toList.forEach(function(targetName) {
                const target = self.nodes.find(n => n.name.toLowerCase() === targetName.toLowerCase());
                if (!target) return;

                // Merge bidirectional transitions into a single link regardless of
                // the order the two directions appear in the config. A link is
                // source->target with end (arrow at target); the reverse direction
                // is recorded as start (arrow at source) on the same link.
                const forward = self.links.find(l => l.source.id === source.id && l.target.id === target.id);
                if (forward) { forward.end = true; return; }
                const reverse = self.links.find(l => l.source.id === target.id && l.target.id === source.id);
                if (reverse) { reverse.start = true; return; }
                self.links.push({id: ++self.links_seq, source: source, target: target, start: false, end: true});
            });
        }
    }

    AddNode(point) {
        const self = this;
        let i = 0, name;
        while (true) {
            name = 'status #' + ++i;
            if (!self.nodes.find(n => n.name.toLowerCase() === name.toLowerCase())) break;
        }
        self.nodes.push({
            id: ++self.nodes_seq,
            name: name,
            type: 'active',
            color: '',
            x: point.x,
            y: point.y
        });
    }

    AddLink(source, target) {
        const self = this;
        if (!source || !target) return;

        const reverse = self.links.find(l => l.source.id === target.id && l.target.id === source.id);
        if (reverse) {
            reverse.start = true;
            return;
        }
        const existing = self.links.find(l => l.source.id === source.id && l.target.id === target.id);
        if (existing) {
            // A source->target link already exists, but may currently show only
            // its reverse arrow (after a direction cycle). Re-asserting the drag
            // restores the forward arrow, mirroring LinksFromConfig.
            existing.end = true;
        }
        else {
            self.links.push({id: ++self.links_seq, source: source, target: target, start: false, end: true});
        }
    }

    // Cycle a transition's direction: forward (source->target) -> reverse
    // (target->source) -> both -> forward. Deletion is a separate action.
    CycleLinkDirection(d) {
        const self = this;
        const link = self.links.find(x => x.id === d.id);
        if (!link) return;

        if (link.end && !link.start) {        // forward -> reverse
            link.end = false;
            link.start = true;
        }
        else if (link.start && !link.end) {   // reverse -> both
            link.end = true;
        }
        else {                                // both (or any other state) -> forward
            link.start = false;
            link.end = true;
        }
    }

    DeleteLink(d) {
        const self = this;
        const index = self.links.findIndex(x => x.id === d.id);
        if (index < 0) return;
        self.links.splice(index, 1);
        const crit = { from: d.source.name, to: d.target.name };
        self.DeleteRights(crit);
        self.DeleteActions(crit);
        self.DeleteTransitionMetadata(crit);
    }

    DeleteNode(d) {
        const self = this;
        const index = self.nodes.findIndex(x => x.id === d.id);
        if (index < 0) return;
        self.DeleteLinksForNode(self.nodes[index]);
        self.DeleteRights({ node: d.name });
        self.DeleteDefaults(d);
        self.DeleteActions({ node: d.name });
        self.DeleteStatusMetadata(d.name);
        self.DeleteTransitionMetadata({ node: d.name });
        self.nodes.splice(index, 1);
        self.create_nodes = self.create_nodes.filter(name => name !== d.name);
    }

    DeleteLinksForNode(node) {
        const self = this;
        if (!node) return;
        self.links = self.links.filter(link => link.source.id !== node.id && link.target.id !== node.id);
    }

    DeleteDefaults(d) {
        const self = this;
        for (let key in (self.config.defaults || {})) {
            if (self.config.defaults[key] && self.config.defaults[key].toLowerCase() === d.name.toLowerCase()) {
                delete self.config.defaults[key];
            }
        }
    }

    // Split a "from -> to" transition key into its two trimmed, lowercased
    // status names. Returns null for anything that isn't a single transition.
    // Splitting on the literal "->" avoids building a RegExp from status names,
    // which could contain regex-special characters or match across statuses
    // (e.g. "open" matching inside "reopen").
    SplitTransition(key) {
        const parts = String(key).split('->');
        if (parts.length !== 2) return null;
        return [parts[0].trim(), parts[1].trim()];
    }

    // Does a "from -> to" key match the criterion? crit is either
    // { node: name } (either endpoint is that status) or { from, to }
    // (the specific transition, in either direction). Status names are
    // compared case-insensitively.
    TransitionMatches(key, crit) {
        const pair = this.SplitTransition(key);
        if (!pair) return false;
        const from = pair[0].toLowerCase(), to = pair[1].toLowerCase();
        if (crit.node) {
            const n = crit.node.toLowerCase();
            return from === n || to === n;
        }
        const a = crit.from.toLowerCase(), b = crit.to.toLowerCase();
        return (from === a && to === b) || (from === b && to === a);
    }

    // Rewrite a "from -> to" key when one endpoint is renamed. Returns the new
    // key, or null if the key isn't a transition or names nothing renamed.
    RenameTransition(key, oldName, newName) {
        const pair = this.SplitTransition(key);
        if (!pair) return null;
        const old = oldName.toLowerCase();
        let changed = false;
        if (pair[0].toLowerCase() === old) { pair[0] = newName; changed = true; }
        if (pair[1].toLowerCase() === old) { pair[1] = newName; changed = true; }
        return changed ? pair[0] + ' -> ' + pair[1] : null;
    }

    DeleteRights(crit) {
        const self = this;
        for (let key in (self.config.rights || {})) {
            if (self.TransitionMatches(key, crit)) {
                delete self.config.rights[key];
            }
        }
    }

    DeleteActions(crit) {
        const self = this;
        const actions = [];
        const tempArr = self.config.actions || [];
        for (let i = 0; i < tempArr.length; i += 2) {
            const action = tempArr[i];
            const info = tempArr[i+1];
            if (!action) continue;
            if (!self.TransitionMatches(action, crit)) {
                actions.push(action);
                actions.push(info);
            }
        }
        self.config.actions = actions;
    }

    // ---------- Status / transition metadata ----------
    //
    // Metadata lives in config.status_metadata (keyed by lower-cased status
    // name) and config.transition_metadata (keyed by lower-cased "from -> to",
    // wildcards allowed). The server lower-cases these on save; we do the same
    // in memory so reads, writes, and the rename/delete cascades all agree on a
    // single canonical key. Each entry holds optional description / notes text.

    NormalizeMetadata() {
        const self = this;
        const sm = self.config.status_metadata;
        if (sm) {
            const ns = {};
            Object.keys(sm).forEach(function(k) { ns[String(k).toLowerCase()] = sm[k]; });
            self.config.status_metadata = ns;
        }
        const tm = self.config.transition_metadata;
        if (tm) {
            const nt = {};
            Object.keys(tm).forEach(function(k) {
                const pair = self.SplitTransition(k);
                nt[pair ? pair[0].toLowerCase() + ' -> ' + pair[1].toLowerCase() : k] = tm[k];
            });
            self.config.transition_metadata = nt;
        }
    }

    // Trim a {description, notes} pair down to the fields that actually carry
    // text, so we never persist blank entries.
    CleanMetadata(meta) {
        const clean = {};
        ['description', 'notes'].forEach(function(field) {
            const val = (meta[field] || '').trim();
            if (val !== '') clean[field] = val;
        });
        return clean;
    }

    StatusMetadataFor(name) {
        return (this.config.status_metadata || {})[String(name).toLowerCase()] || {};
    }

    SetStatusMetadata(name, meta) {
        const self = this;
        self.config.status_metadata ||= {};
        const key = String(name).toLowerCase();
        const clean = self.CleanMetadata(meta);
        if (Object.keys(clean).length) self.config.status_metadata[key] = clean;
        else delete self.config.status_metadata[key];
    }

    DeleteStatusMetadata(name) {
        if (this.config.status_metadata) delete this.config.status_metadata[String(name).toLowerCase()];
    }

    TransitionMetadataFor(from, to) {
        const key = String(from).toLowerCase() + ' -> ' + String(to).toLowerCase();
        return (this.config.transition_metadata || {})[key] || {};
    }

    SetTransitionMetadata(from, to, meta) {
        const self = this;
        self.config.transition_metadata ||= {};
        const key = String(from).toLowerCase() + ' -> ' + String(to).toLowerCase();
        const clean = self.CleanMetadata(meta);
        if (Object.keys(clean).length) self.config.transition_metadata[key] = clean;
        else delete self.config.transition_metadata[key];
    }

    // Remove transition metadata matching a criterion (see TransitionMatches).
    // With { from, to } only the exact pair (in either direction) is removed,
    // so wildcard entries like "* -> rejected" survive deleting a single edge.
    DeleteTransitionMetadata(crit) {
        const self = this;
        for (let key in (self.config.transition_metadata || {})) {
            if (self.TransitionMatches(key, crit)) {
                delete self.config.transition_metadata[key];
            }
        }
    }

    UpdateNodeModel(node, args) {
        const self = this;
        const nodeIndex = self.nodes.findIndex(x => x.id === node.id);
        if (nodeIndex < 0) return;

        const oldValue = self.nodes[nodeIndex];
        self.nodes[nodeIndex] = {...self.nodes[nodeIndex], ...args};
        const nodeUpdated = self.nodes[nodeIndex];

        self.links.forEach(link => {
            if (link.source.id === node.id) link.source = nodeUpdated;
            if (link.target.id === node.id) link.target = nodeUpdated;
        });

        if (oldValue.name === nodeUpdated.name) return;

        self.create_nodes = self.create_nodes.map(target =>
            target === oldValue.name ? nodeUpdated.name : target
        );

        for (let type in (self.config.defaults || {})) {
            if (self.config.defaults[type] === oldValue.name) {
                self.config.defaults[type] = nodeUpdated.name;
            }
        }

        for (let key in (self.config.rights || {})) {
            let updated = self.RenameTransition(key, oldValue.name, nodeUpdated.name);
            if (updated !== null && updated !== key) {
                self.config.rights[updated] = self.config.rights[key];
                delete self.config.rights[key];
            }
        }

        let actions = [];
        if (self.config.actions) {
            for (let i = 0; i < self.config.actions.length; i += 2) {
                let action = self.config.actions[i];
                let info = self.config.actions[i+1];
                let updated = self.RenameTransition(action, oldValue.name, nodeUpdated.name);
                actions.push(updated !== null ? updated : action);
                actions.push(info);
            }
        }
        self.config.actions = actions;

        // status metadata: move the entry to the renamed status's key
        if (self.config.status_metadata) {
            let oldKey = oldValue.name.toLowerCase(), newKey = nodeUpdated.name.toLowerCase();
            if (oldKey !== newKey && self.config.status_metadata[oldKey] !== undefined) {
                self.config.status_metadata[newKey] = self.config.status_metadata[oldKey];
                delete self.config.status_metadata[oldKey];
            }
        }

        // transition metadata: rewrite any key mentioning the renamed status
        if (self.config.transition_metadata) {
            let tm = self.config.transition_metadata, updated = {};
            for (let key in tm) {
                let renamed = self.RenameTransition(key, oldValue.name, nodeUpdated.name);
                updated[(renamed !== null ? renamed : key).toLowerCase()] = tm[key];
            }
            self.config.transition_metadata = updated;
        }

        let nameInput = document.querySelector('form[name=ModifyLifecycle] input[name=Name]');
        let config_name = nameInput ? nameInput.value : '';
        for (let item in self.maps) {
            // Map keys are "FromLifecycle -> ToLifecycle". Split on the literal
            // "->" rather than building a RegExp from the (user-supplied)
            // lifecycle name, which could carry regex-special characters or match
            // across names. (Mirrors SplitTransition's reasoning.)
            const pair = self.SplitTransition(item);
            if (!pair) continue;
            if (pair[0] === config_name) {
                let m = self.maps[item];
                for (let from in m) {
                    // Map keys are stored lower-cased; match case-insensitively.
                    if (from.toLowerCase() === oldValue.name.toLowerCase()) {
                        m[nodeUpdated.name] = m[from];
                        delete m[from];
                    }
                }
            }
            else if (pair[1] === config_name) {
                let m = self.maps[item];
                for (let from in m) {
                    // Map values are stored lower-cased; match case-insensitively.
                    if (m[from].toLowerCase() === oldValue.name.toLowerCase()) {
                        m[from] = nodeUpdated.name;
                    }
                }
            }
        }
    }

    // ---------- Cytoscape setup ----------

    BuildElements() {
        const self = this;
        const elements = [];

        self.nodes.forEach(n => {
            const bg = RT.LifecycleGraph.NodeColor(n.color, n.type);
            const el = {
                group: 'nodes',
                data: {
                    id: 'n' + n.id,
                    name: n.name,
                    type: n.type,
                    color: bg,
                    textColor: contrastTextColor(bg),
                    _node: n,
                },
            };
            if (n.x !== undefined && n.y !== undefined) {
                el.position = { x: n.x, y: n.y };
            }
            elements.push(el);
        });

        self.links.forEach(l => {
            const classes = [];
            if (l.start) classes.push('has-start');
            if (l.end)   classes.push('has-end');
            elements.push({
                group: 'edges',
                data: {
                    id: 'e' + l.id,
                    source: 'n' + l.source.id,
                    target: 'n' + l.target.id,
                    _link: l,
                },
                classes: classes.join(' '),
            });
        });

        return elements;
    }

    Stylesheet() {
        return RT.LifecycleGraph.Stylesheet({
            nodeRadius: this.node_radius,
            fontSize: 14,
            edgeColor: '#000',
            arrowScale: 1.2,
        }).concat([
            {
                selector: 'node.selected',
                style: {
                    'border-width': 3,
                    'border-color': '#ffb74d',
                },
            },
            {
                selector: 'edge.selected-edge',
                style: {
                    'width': 3,
                    'line-color': '#ffb74d',
                    'target-arrow-color': '#ffb74d',
                    'source-arrow-color': '#ffb74d',
                    'underlay-color': '#ffb74d',
                    'underlay-opacity': 0.25,
                    'underlay-padding': 6,
                },
            },
        ]);
    }

    CytoscapeInit() {
        const self = this;
        const allPositioned = self.nodes.length > 0
            && self.nodes.every(function(n) { return n.x !== undefined && n.y !== undefined; });

        // Is the initial view settled by the end of the constructor? It is when
        // a saved layout uses the synchronous 'preset' layout, and also when the
        // graph is empty (a brand-new lifecycle) -- there is nothing to lay out,
        // and the async 'cose' layout never fires layoutstop on an empty graph.
        // In both cases the constructor captures the reminder baseline; only a
        // non-empty 'cose' layout defers it to the layoutstop handler.
        self._layoutSettledSync = allPositioned || self.nodes.length === 0;

        // Load any saved zoom/pan for this lifecycle (browser-local, per
        // lifecycle) so an admin's framing sticks across reloads. Kept separate
        // from the viewer's key: the editor's working view is its own.
        self.LoadSavedView();

        self.cy = cytoscape({
            container: self.graphContainer,
            elements: self.BuildElements(),
            style: self.Stylesheet(),
            // Skip the layout's auto-fit when we have a saved view to restore;
            // otherwise the fit would fight the restore.
            layout: allPositioned
                ? { name: 'preset', fit: !self._savedView, padding: 40 }
                : Object.assign(self.AutoLayoutOptions(), { fit: !self._savedView }),
            boxSelectionEnabled: false,
            // Plain wheel scrolls the page; AddZoomControls binds Ctrl/Cmd+wheel
            // (and trackpad pinch) for zooming instead.
            userZoomingEnabled: false,
            minZoom: RT.LifecycleGraph.MinZoom,
            maxZoom: RT.LifecycleGraph.MaxZoom,
        });

        RT.LifecycleGraph.AddZoomControls(self.cy, self.graphContainer, {
            keyboard: true,
            signal: self._abort.signal,   // remove the document keydown on destroy()
            onReset: function () {        // fit-to-view: drop the saved view
                self._cancelSaveView();
                if (self._zoomStoreKey) {
                    try { localStorage.removeItem(self._zoomStoreKey); } catch (e) {}
                }
            },
        });

        // Any user zoom/pan (buttons, keys, wheel, drag) persists, debounced.
        // Programmatic changes (the initial fit, restoring a saved view) cancel
        // the pending save so they never overwrite or resurrect a view.
        if (self._zoomStoreKey) self.cy.on('zoom pan', function () { self._saveView(); });

        // Re-export positions after the async cose layout (Auto-arrange button)
        // so a save captures what's actually rendered.
        self.cy.on('layoutstop', function() {
            self.ExportAsConfiguration();
            // The first layoutstop is the settled initial layout: treat that
            // serialized state as the baseline the "pending changes" reminder
            // compares against, and restore any saved view now the fit has run.
            // Later layoutstops (Auto-arrange) are real edits and leave it.
            if (!self._pendingReminderReady) {
                self._changeBaseline = self._currentSerialized;
                self._pendingReminderReady = true;
                self.RestoreSavedView();
            }
        });
    }

    // ---------- Zoom/pan persistence (browser-local, per lifecycle) ----------

    LoadSavedView() {
        const self = this;
        const name = self.container.getAttribute('data-lifecycle') || '';
        self._zoomStoreKey = name ? 'RT-LifecycleEditorZoom-' + name : null;
        self._zoomRestored = false;
        self._savedView = null;
        if (self._zoomStoreKey) {
            try { self._savedView = JSON.parse(localStorage.getItem(self._zoomStoreKey)); }
            catch (e) { self._savedView = null; }
            if (!self._savedView || typeof self._savedView.zoom !== 'number' || !self._savedView.pan) {
                self._savedView = null;
            }
        }

        let saveTimer;
        self._saveView = function () {        // debounced; coalesces wheel/drag bursts
            clearTimeout(saveTimer);
            if (!self._zoomStoreKey) return;
            saveTimer = setTimeout(function () {
                if (!self.cy) return;
                try {
                    localStorage.setItem(self._zoomStoreKey,
                        JSON.stringify({ zoom: self.cy.zoom(), pan: self.cy.pan() }));
                } catch (e) { /* storage unavailable (private mode / quota) - ignore */ }
            }, 300);
        };
        self._cancelSaveView = function () { clearTimeout(saveTimer); };
    }

    // Apply the saved zoom/pan once, after the initial layout/fit has run.
    RestoreSavedView() {
        const self = this;
        if (self._zoomRestored) return;
        self._zoomRestored = true;
        if (self._savedView) {
            self.cy.zoom(self._savedView.zoom);   // clamped to min/maxZoom
            self.cy.pan(self._savedView.pan);
        }
        if (self._cancelSaveView) self._cancelSaveView();   // don't persist the fit
    }

    Refresh() {
        const self = this;
        // Capture any in-place positions before we tear elements down.
        if (self.cy) {
            self.cy.nodes().forEach(function(n) {
                const node = n.data('_node');
                if (!node) return;
                const p = n.position();
                node.x = p.x;
                node.y = p.y;
            });
        }
        self.cy.elements().remove();
        self.cy.add(self.BuildElements());

        // The rebuilt elements make any held selection stale; clear it and the
        // edit button so neither points at a removed element.
        self.Deselect();

        // No auto-layout on refresh - newly added nodes already carry their
        // click positions, and existing nodes keep theirs. Use the layout
        // buttons explicitly to re-arrange.
    }

    // Sync an edge's arrowhead classes to its link model, in place.
    ApplyLinkClasses(cyEdge) {
        const l = cyEdge.data('_link');
        cyEdge.toggleClass('has-start', !!(l && l.start));
        cyEdge.toggleClass('has-end', !!(l && l.end));
    }

    AutoLayoutOptions() {
        // Cytoscape's built-in cose (force-directed). Spaces statuses apart in
        // a simple, readable way. Admins who care about exact placement drag
        // nodes manually; this is just a quick "untangle" starting point.
        return {
            name: 'cose',
            animate: false,
            fit: true,
            padding: 40,
            nodeRepulsion: 4000,
            idealEdgeLength: 100,
        };
    }

    // ---------- Event wiring ----------

    SetUp() {
        const self = this;

        self.cy.on('tap', function(evt) {
            if (evt.target !== self.cy) return;
            if (self.editing_node || self.selected_node || self.selected_edge) {
                self.Deselect();
                return;
            }
            self.AddNode(evt.position);
            self.ExportAsConfiguration();
            self.Refresh();
        });

        self.cy.on('tap', 'node', function(evt) {
            evt.stopPropagation();
            if (self.edgeDragSource) return;
            self.SelectNode(evt.target);
            self.UpdateNode(evt.target.data('_node'));
        });

        self.cy.on('tap', 'edge', function(evt) {
            evt.stopPropagation();
            const edge = evt.target;
            if (self.selected_edge && self.selected_edge.id() === edge.id()) {
                // Already selected: cycle its direction in place (no Refresh, so
                // selection and the delete button stay put).
                self.CycleLinkDirection(edge.data('_link'));
                self.ApplyLinkClasses(edge);
                self.ExportAsConfiguration();
            }
            else {
                self.SelectEdge(edge);
            }
        });

        self.cy.on('dragfree', 'node', function(evt) {
            const node = evt.target.data('_node');
            const p = evt.target.position();
            node.x = p.x;
            node.y = p.y;
            self.ExportAsConfiguration();
        });

        self.SetupEdgeDrag();
        self.SetupEdgeEdit();

        const autoArrange = document.getElementById('AutoArrange');
        if (autoArrange) autoArrange.addEventListener('click', function(e) {
            e.preventDefault();
            self.cy.layout(self.AutoLayoutOptions()).run();
        });

        const form = document.querySelector('form[name=ModifyLifecycle]');
        if (form) {
            form.addEventListener('htmx:configRequest', function(evt) {
                self.ExportAsConfiguration();
                evt.detail.parameters['Config'] = evt.detail.elt.querySelector('input[name=Config]').value;
                evt.detail.parameters['Layout'] = evt.detail.elt.querySelector('input[name=Layout]').value;
            }, { signal: self._abort.signal });
        }
    }

    // ---------- Edge drag (Shift+drag from source node to target) ----------

    SetupEdgeDrag() {
        const self = this;

        const ns = 'http://www.w3.org/2000/svg';
        const overlay = document.createElement('div');
        overlay.style.cssText = 'position:absolute; inset:0; pointer-events:none;';
        const svg = document.createElementNS(ns, 'svg');
        svg.setAttribute('width', '100%');
        svg.setAttribute('height', '100%');
        const line = document.createElementNS(ns, 'line');
        line.setAttribute('stroke', '#000');
        line.setAttribute('stroke-width', '1');
        line.setAttribute('stroke-opacity', '0.6');
        line.setAttribute('stroke-dasharray', '4,2');
        line.style.display = 'none';
        svg.appendChild(line);
        overlay.appendChild(svg);

        self.graphContainer.style.position = 'relative';
        self.graphContainer.appendChild(overlay);
        self.dragLine = line;

        self.cy.on('mousedown', 'node', function(evt) {
            if (!evt.originalEvent || !evt.originalEvent.shiftKey) return;
            evt.originalEvent.preventDefault();
            self.edgeDragSource = evt.target;
            evt.target.ungrabify();
            const rPos = evt.target.renderedPosition();
            line.setAttribute('x1', rPos.x);
            line.setAttribute('y1', rPos.y);
            line.setAttribute('x2', rPos.x);
            line.setAttribute('y2', rPos.y);
            line.style.display = '';
        });

        self.graphContainer.addEventListener('mousemove', function(evt) {
            if (!self.edgeDragSource) return;
            const rect = self.graphContainer.getBoundingClientRect();
            line.setAttribute('x2', evt.clientX - rect.left);
            line.setAttribute('y2', evt.clientY - rect.top);
        });

        // Listen on document so mouseup outside the graph also clears state
        document.addEventListener('mouseup', function(evt) {
            if (!self.edgeDragSource) return;
            const target = self.NodeAtClientPos(evt.clientX, evt.clientY);
            self.edgeDragSource.grabify();
            if (target && target.id() !== self.edgeDragSource.id()) {
                self.AddLink(self.edgeDragSource.data('_node'), target.data('_node'));
                self.ExportAsConfiguration();
                self.Refresh();
            }
            self.edgeDragSource = null;
            line.style.display = 'none';
        }, { signal: self._abort.signal });
    }

    // Transition edit button (pencil on hover / while selected)

    SetupEdgeEdit() {
        const self = this;

        const btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'lifecycle-edge-edit';
        btn.setAttribute('aria-label', RT.I18N.Catalog.edit_transition);
        btn.setAttribute('title', RT.I18N.Catalog.edit_transition);
        btn.innerHTML = '<svg class="bi" width="12" height="12" fill="currentColor" ' +
            'viewBox="0 0 16 16" aria-hidden="true"><use href="' +
            RT.Config.WebPath + '/NoAuth/css/icons.svg#pencil"></use></svg>';
        btn.style.cssText =
            'position:absolute; display:none; z-index:10; width:22px; height:22px; padding:0; ' +
            'line-height:1; text-align:center; border-radius:50%; border:1px solid var(--bs-border-color); ' +
            'background:var(--bs-body-bg); color:var(--bs-body-color); cursor:pointer; transform:translate(-50%,-50%);';
        self.graphContainer.style.position = 'relative';
        self.graphContainer.appendChild(btn);
        self.editButton = btn;
        self.editButtonEdge = null;

        const restoreOrHide = function() {
            if (self.selected_edge) self.ShowEditButton(self.selected_edge);
            else self.HideEditButton();
        };

        btn.addEventListener('mouseenter', function() { clearTimeout(self._hideEditTimer); });
        btn.addEventListener('mouseleave', restoreOrHide);
        btn.addEventListener('click', function(e) {
            e.preventDefault();
            e.stopPropagation();
            const edge = self.editButtonEdge || self.selected_edge;
            if (!edge) return;
            self.EditTransition(edge);
        });

        self.cy.on('mouseover', 'edge', function(evt) {
            clearTimeout(self._hideEditTimer);
            self.ShowEditButton(evt.target);
        });
        self.cy.on('mouseout', 'edge', function() {
            clearTimeout(self._hideEditTimer);
            self._hideEditTimer = setTimeout(restoreOrHide, 200);
        });

        // Keep the button glued to its edge as the graph pans, zooms, or nodes move.
        const reposition = function() {
            if (self.editButton.style.display !== 'none' && self.editButtonEdge) {
                self.PositionEditButton(self.editButtonEdge);
            }
        };
        self.cy.on('pan zoom', reposition);
        self.cy.on('position', 'node', reposition);
    }

    PositionEditButton(cyEdge) {
        const self = this;
        const mp = cyEdge.midpoint();   // model coordinates
        const zoom = self.cy.zoom(), pan = self.cy.pan();
        self.editButton.style.left = (mp.x * zoom + pan.x) + 'px';
        self.editButton.style.top  = (mp.y * zoom + pan.y) + 'px';
    }

    ShowEditButton(cyEdge) {
        const self = this;
        if (!self.editButton) return;
        self.editButtonEdge = cyEdge;
        self.PositionEditButton(cyEdge);
        self.editButton.style.display = '';
    }

    HideEditButton() {
        const self = this;
        if (self.editButton) self.editButton.style.display = 'none';
        self.editButtonEdge = null;
    }

    NodeAtClientPos(clientX, clientY) {
        const rect = this.graphContainer.getBoundingClientRect();
        if (clientX < rect.left || clientX > rect.right || clientY < rect.top || clientY > rect.bottom) {
            return null;
        }
        const rendered = { x: clientX - rect.left, y: clientY - rect.top };
        const pan = this.cy.pan();
        const zoom = this.cy.zoom();
        const modelPos = { x: (rendered.x - pan.x) / zoom, y: (rendered.y - pan.y) / zoom };
        let hit = null;
        const radius = this.node_radius;
        this.cy.nodes().forEach(function(n) {
            const p = n.position();
            const dx = modelPos.x - p.x, dy = modelPos.y - p.y;
            if (Math.sqrt(dx*dx + dy*dy) <= radius) hit = n;
        });
        return hit;
    }

    // ---------- Selection & edit panel ----------

    SelectNode(cyNode) {
        const self = this;
        self.DeselectEdge();
        if (self.selected_node) self.selected_node.removeClass('selected');
        self.selected_node = cyNode;
        cyNode.addClass('selected');
    }

    SelectEdge(cyEdge) {
        const self = this;
        self.Deselect();   // clear any node/panel and previously selected edge
        self.selected_edge = cyEdge;
        cyEdge.addClass('selected-edge');
        self.ShowEditButton(cyEdge);
    }

    DeselectEdge() {
        const self = this;
        if (self.selected_edge) {
            self.selected_edge.removeClass('selected-edge');
            self.selected_edge = null;
        }
        self.HideEditButton();
    }

    // The edit panels are Bootstrap modals; show/hide goes through its API.
    ShowModal(id) {
        const el = document.getElementById(id);
        if (el && window.bootstrap) bootstrap.Modal.getOrCreateInstance(el).show();
    }
    HideModal(id) {
        const el = document.getElementById(id);
        if (!el || !window.bootstrap) return;
        const modal = bootstrap.Modal.getInstance(el);
        if (modal) modal.hide();
    }

    Deselect() {
        const self = this;
        self.HideModal('lifecycle-ui-edit-node');
        self.HideModal('lifecycle-ui-edit-transition');
        self.editing_node = null;
        self.editing_edge = null;
        self.DeselectEdge();
        if (self.selected_node) {
            self.selected_node.removeClass('selected');
            self.selected_node = null;
        }
    }

    UpdateNode(element) {
        const self = this;

        const list = document.getElementById('lifecycle-ui-edit-node').querySelectorAll('input, select');

        if (element) {
            for (let item of list) {
                if (item.tomselect) {
                    item.tomselect.setValue(element[item.name]);
                }
                else if (item.name === 'color') {
                    const colorUse = document.getElementById('color-use');
                    const colorInputs = document.getElementById('color-inputs');
                    const colorHex = document.getElementById('color-hex');
                    const value = element.color || '#ffffff';
                    colorUse.checked = !!element.color;
                    colorInputs.style.display = element.color ? '' : 'none';
                    item.value = value;
                    colorHex.value = value;
                    colorHex.classList.remove('is-invalid');
                }
                else if (item.name === 'color-hex' || item.name === 'color-use') {
                    // handled via 'color'
                }
                else if (item.name === 'id') {
                    item.value = element.id;
                }
                else {
                    item.value = element[item.name];
                }
            }
            const smeta = self.StatusMetadataFor(element.name);
            document.getElementById('status-description').value = smeta.description || '';
            document.getElementById('status-notes').value = smeta.notes || '';
            self.editing_node = element;
            self.ShowModal('lifecycle-ui-edit-node');
        }
        else {
            if (!self.editing_node) return;
            const name = document.getElementById('name').value;
            // Status names are treated case-insensitively everywhere else (colors,
            // metadata, transition keys), so reject a rename that collides with
            // another status under that same case-folding.
            if (name === '' || self.nodes.find(x => x.id !== self.editing_node.id
                                                    && x.name.toLowerCase() === name.toLowerCase())) {
                document.getElementById('lifecycle-ui-edit-node')
                    .querySelector('div.invalid-name').classList.remove('hidden');
                return;
            }
            const values = {};
            for (let item of list) {
                if (item.name === 'color-hex' || item.name === 'color-use') continue;
                if (item.name === 'id') {
                    values.index = self.nodes.findIndex(x => x.id == item.value);
                }
                values[item.name] = item.value;
            }
            if (!document.getElementById('color-use').checked) {
                values.color = '';
            }
            self.UpdateNodeModel(self.nodes[values.index], values);
            // Write metadata under the (possibly renamed) status. UpdateNodeModel
            // has already moved any prior entry to the new name; this overwrites
            // it with the edited text.
            self.SetStatusMetadata(name, {
                description: document.getElementById('status-description').value,
                notes: document.getElementById('status-notes').value,
            });
            self.ExportAsConfiguration();
            self.editing_node = null;
            self.HideModal('lifecycle-ui-edit-node');
            self.Refresh();
        }
    }

    WireEditPanel() {
        const self = this;

        const saveNode = document.getElementById('SaveNode');
        if (saveNode) saveNode.addEventListener('click', function(e) {
            e.preventDefault();
            self.UpdateNode();
        });

        // Cancel/X/backdrop/Esc all dismiss via Bootstrap; clean up on hide.
        const nodeModal = document.getElementById('lifecycle-ui-edit-node');
        if (nodeModal) {
            nodeModal.addEventListener('hidden.bs.modal', function() {
                self.editing_node = null;
                nodeModal.querySelectorAll('div.alert').forEach(function(el) { el.classList.add('hidden'); });
                document.getElementById('color-hex').classList.remove('is-invalid');
                if (self.selected_node) {
                    self.selected_node.removeClass('selected');
                    self.selected_node = null;
                }
            });
        }

        const deleteNode = document.getElementById('DeleteNode');
        if (deleteNode) deleteNode.addEventListener('click', function(e) {
            e.preventDefault();
            if (!self.editing_node) return;
            self.DeleteNode(self.editing_node);
            self.editing_node = null;
            self.ExportAsConfiguration();
            self.HideModal('lifecycle-ui-edit-node');
            self.Refresh();
        });

        const color = document.getElementById('color');
        if (color) color.addEventListener('input', function() {
            const colorHex = document.getElementById('color-hex');
            colorHex.value = this.value;
            colorHex.classList.remove('is-invalid');
        });
        const colorHex = document.getElementById('color-hex');
        if (colorHex) colorHex.addEventListener('input', function() {
            const val = this.value;
            if (/^#[0-9a-fA-F]{6}$/.test(val)) {
                document.getElementById('color').value = val;
                this.classList.remove('is-invalid');
            }
            else {
                this.classList.add('is-invalid');
            }
        });
        const colorUse = document.getElementById('color-use');
        if (colorUse) colorUse.addEventListener('change', function() {
            document.getElementById('color-inputs').style.display = this.checked ? '' : 'none';
        });
    }

    // Open the transition panel for an edge. Shows one metadata block per
    // direction the edge carries (two for a bidirectional edge), each labeled
    // "from -> to" and populated from that direction's stored metadata.
    EditTransition(cyEdge) {
        const self = this;
        const link = cyEdge.data('_link');
        if (!link) return;

        self.SelectEdge(cyEdge);     // marks selected and clears other panels
        self.editing_edge = cyEdge;

        const dirs = [];
        if (link.end)   dirs.push({ from: link.source.name, to: link.target.name });
        if (link.start) dirs.push({ from: link.target.name, to: link.source.name });

        const panel = document.getElementById('lifecycle-ui-edit-transition');
        panel.querySelectorAll('.lifecycle-transition-dir').forEach(function(block, i) {
            const d = dirs[i];
            if (!d) { block.style.display = 'none'; return; }
            block.style.display = '';
            block.setAttribute('data-from', d.from);
            block.setAttribute('data-to', d.to);
            block.querySelector('.lifecycle-transition-label').textContent = d.from + ' \u2192 ' + d.to;
            const meta = self.TransitionMetadataFor(d.from, d.to);
            block.querySelector('[data-field=description]').value = meta.description || '';
            block.querySelector('[data-field=notes]').value = meta.notes || '';
        });

        self.ShowModal('lifecycle-ui-edit-transition');
    }

    WireTransitionPanel() {
        const self = this;
        const panel = function() { return document.getElementById('lifecycle-ui-edit-transition'); };

        const saveTransition = document.getElementById('SaveTransition');
        if (saveTransition) saveTransition.addEventListener('click', function(e) {
            e.preventDefault();
            panel().querySelectorAll('.lifecycle-transition-dir').forEach(function(block) {
                if (block.style.display === 'none') return;
                self.SetTransitionMetadata(block.getAttribute('data-from'), block.getAttribute('data-to'), {
                    description: block.querySelector('[data-field=description]').value,
                    notes:       block.querySelector('[data-field=notes]').value,
                });
            });
            self.ExportAsConfiguration();
            self.editing_edge = null;
            self.HideModal('lifecycle-ui-edit-transition');
        });

        const deleteTransition = document.getElementById('DeleteTransition');
        if (deleteTransition) deleteTransition.addEventListener('click', function(e) {
            e.preventDefault();
            if (!self.editing_edge) return;
            self.DeleteLink(self.editing_edge.data('_link'));
            self.ExportAsConfiguration();
            self.editing_edge = null;
            self.HideModal('lifecycle-ui-edit-transition');
            self.Refresh();
        });

        // X/backdrop/Esc dismiss via Bootstrap; clean up on hide.
        const transModal = panel();
        if (transModal) {
            transModal.addEventListener('hidden.bs.modal', function() {
                self.editing_edge = null;
                self.DeselectEdge();
            });
        }
    }

    // ---------- Serialization ----------

    ExportAsConfiguration() {
        const self = this;

        const config = {
            type: self.config.type,
            initial:  [],
            active:   [],
            inactive: [],
            colors:   {},
            transitions: {},
        };

        ['initial', 'active', 'inactive'].forEach(function(type) {
            config[type] = self.nodes.filter(n => n.type === type).map(n => n.name);
        });

        self.nodes.forEach(function(n) {
            if (n.color) config.colors[n.name.toLowerCase()] = n.color;
        });

        self.create_nodes = self.create_nodes.filter(target => self.nodes.find(n => n.name === target));
        config.transitions[""] = self.create_nodes;

        const seen = {};
        self.nodes.forEach(function(source) {
            const targets = [];
            self.links.forEach(function(link) {
                if (link.source.id === source.id && link.end) targets.push(link.target.name);
                else if (link.target.id === source.id && link.start) targets.push(link.source.name);
            });
            config.transitions[source.name] = targets;
            seen[source.name] = 1;
        });

        for (let transition in config.transitions) {
            if (transition && (!seen[transition] || !config.transitions[transition].length)) {
                delete config.transitions[transition];
            }
        }

        self.config = {...self.config, ...config};
        self.config.defaults ||= {};
        self.config.defaults.on_create ||= self.config.initial[0] || self.config.active[0] || null;

        const form = document.querySelector('form[name=ModifyLifecycle]');
        const setField = function(name, value) {
            if (!form) return;
            const input = form.querySelector('input[name=' + name + ']');
            if (input) input.value = value;
        };

        const configJSON = JSON.stringify(self.config);
        setField('Config', configJSON);

        // Always export current positions so the viewer (and any reload) can show
        // exactly what the admin saw at save time. The Auto Layout toggle only
        // controls how the editor *arranges* nodes - it doesn't suppress saving.
        const pos = {};
        self.nodes.forEach(function(n) {
            if (self.cy) {
                const cyNode = self.cy.getElementById('n' + n.id);
                if (cyNode && cyNode.length) {
                    const p = cyNode.position();
                    n.x = p.x;
                    n.y = p.y;
                }
            }
            if (n.x !== undefined && n.y !== undefined) {
                pos[n.name] = [Math.round(n.x), Math.round(n.y)];
            }
        });
        const layoutJSON = JSON.stringify(pos);
        setField('Layout', layoutJSON);
        const mapsJSON = JSON.stringify(self.maps);
        setField('Maps', mapsJSON);

        // Whole saved state, in the same shape that gets submitted, so the
        // reminder reflects exactly what a Save would persist.
        self._currentSerialized = [configJSON, layoutJSON, mapsJSON].join('\0');
        self.SyncPendingChanges();
    }

    // Show or hide the "changes pending" reminder by comparing the current
    // serialized state to the baseline captured at load. Mirrors the page
    // layout / dashboard editors' save reminder.
    SyncPendingChanges() {
        const self = this;
        if (!self._pendingReminderReady) return;

        const reminder = self.container.querySelector('.pending-changes');
        if (!reminder) return;

        if (self._currentSerialized === self._changeBaseline) {
            reminder.classList.add('hidden');
        }
        else {
            reminder.classList.remove('hidden');
        }
    }
}
