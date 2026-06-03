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
        self.edgeDragSource   = null;

        // Tracks the listeners SetUp/SetupEdgeDrag bind on
        // document, which outlive this widget's own DOM subtree. destroy()
        // aborts the signal to remove them when an hx-boost navigation swaps
        // the editor out, so they don't accumulate across visits.
        self._abort           = new AbortController();

        self.WireEditPanel();
        self.NodesFromConfig(config);
        self.LinksFromConfig(config);
        self.CytoscapeInit();
        self.SetUp();
        self.ExportAsConfiguration();
    }

    // Tear down everything that outlives this widget's DOM subtree. The editor
    // lives on an hx-boost-navigated admin page, so without this each visit
    // would leave behind a document-level listener (the edge-drag mouseup) and
    // a live cytoscape instance.
    // Called from init.js's htmx:beforeCleanupElement / beforeHistorySave
    // hooks. Idempotent.
    destroy() {
        this._abort?.abort();              // removes the document-level listeners
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
    }

    DeleteNode(d) {
        const self = this;
        const index = self.nodes.findIndex(x => x.id === d.id);
        if (index < 0) return;
        self.DeleteLinksForNode(self.nodes[index]);
        self.DeleteRights({ node: d.name });
        self.DeleteDefaults(d);
        self.DeleteActions({ node: d.name });
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
        self.cy = cytoscape({
            container: self.graphContainer,
            elements: self.BuildElements(),
            style: self.Stylesheet(),
            layout: allPositioned
                ? { name: 'preset', fit: true, padding: 40 }
                : self.AutoLayoutOptions(),
            boxSelectionEnabled: false,
            minZoom: RT.LifecycleGraph.MinZoom,
            maxZoom: RT.LifecycleGraph.MaxZoom,
        });

        // Re-export positions after the async cose layout (Auto-arrange button)
        // so a save captures what's actually rendered.
        self.cy.on('layoutstop', function() { self.ExportAsConfiguration(); });
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
            self.UpdateNode(evt.target.data('_node'), evt.originalEvent);
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
        self.SetupEdgeDelete();

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

    // ---------- Edge delete button (✕ on hover / while selected) ----------

    SetupEdgeDelete() {
        const self = this;

        const btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'lifecycle-edge-delete';
        btn.setAttribute('aria-label', 'Delete transition');
        btn.innerHTML = '&times;';
        btn.style.cssText =
            'position:absolute; display:none; z-index:10; width:18px; height:18px; padding:0; ' +
            'line-height:16px; text-align:center; border-radius:50%; border:1px solid #b02a37; ' +
            'background:#dc3545; color:#fff; font-size:13px; cursor:pointer; transform:translate(-50%,-50%);';
        self.graphContainer.style.position = 'relative';
        self.graphContainer.appendChild(btn);
        self.deleteButton = btn;
        self.deleteButtonEdge = null;

        const restoreOrHide = function() {
            if (self.selected_edge) self.ShowDeleteButton(self.selected_edge);
            else self.HideDeleteButton();
        };

        btn.addEventListener('mouseenter', function() { clearTimeout(self._hideDeleteTimer); });
        btn.addEventListener('mouseleave', restoreOrHide);
        btn.addEventListener('click', function(e) {
            e.preventDefault();
            e.stopPropagation();
            const edge = self.deleteButtonEdge || self.selected_edge;
            if (!edge) return;
            self.DeleteLink(edge.data('_link'));
            self.ExportAsConfiguration();
            self.Deselect();
            self.Refresh();
        });

        self.cy.on('mouseover', 'edge', function(evt) {
            clearTimeout(self._hideDeleteTimer);
            self.ShowDeleteButton(evt.target);
        });
        self.cy.on('mouseout', 'edge', function() {
            clearTimeout(self._hideDeleteTimer);
            self._hideDeleteTimer = setTimeout(restoreOrHide, 200);
        });

        // Keep the button glued to its edge as the graph pans, zooms, or nodes move.
        const reposition = function() {
            if (self.deleteButton.style.display !== 'none' && self.deleteButtonEdge) {
                self.PositionDeleteButton(self.deleteButtonEdge);
            }
        };
        self.cy.on('pan zoom', reposition);
        self.cy.on('position', 'node', reposition);
    }

    PositionDeleteButton(cyEdge) {
        const self = this;
        const mp = cyEdge.midpoint();   // model coordinates
        const zoom = self.cy.zoom(), pan = self.cy.pan();
        self.deleteButton.style.left = (mp.x * zoom + pan.x) + 'px';
        self.deleteButton.style.top  = (mp.y * zoom + pan.y) + 'px';
    }

    ShowDeleteButton(cyEdge) {
        const self = this;
        if (!self.deleteButton) return;
        self.deleteButtonEdge = cyEdge;
        self.PositionDeleteButton(cyEdge);
        self.deleteButton.style.display = '';
    }

    HideDeleteButton() {
        const self = this;
        if (self.deleteButton) self.deleteButton.style.display = 'none';
        self.deleteButtonEdge = null;
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
        self.ShowDeleteButton(cyEdge);
    }

    DeselectEdge() {
        const self = this;
        if (self.selected_edge) {
            self.selected_edge.removeClass('selected-edge');
            self.selected_edge = null;
        }
        self.HideDeleteButton();
    }

    Deselect() {
        const self = this;
        if (jQuery("#lifecycle-ui-edit-node").is(':visible')) {
            jQuery("#lifecycle-ui-edit-node").hide();
            jQuery("#lifecycle-ui-edit-node div.alert").addClass('hidden');
        }
        self.editing_node = null;
        self.DeselectEdge();
        if (self.selected_node) {
            self.selected_node.removeClass('selected');
            self.selected_node = null;
        }
    }

    // Position the edit panel at (pageX, pageY) but clamped so it stays fully
    // within the viewport. No-op when no click coordinates are available.
    PositionEditPanel(posX, posY) {
        if (posX === null || posX === undefined) return;
        const panel = document.getElementById('lifecycle-ui-edit-node');
        const margin = 8;
        const maxLeft = window.scrollX + document.documentElement.clientWidth - panel.offsetWidth - margin;
        const maxTop  = window.scrollY + document.documentElement.clientHeight - panel.offsetHeight - margin;
        const left = Math.max(window.scrollX + margin, Math.min(posX, maxLeft));
        const top  = Math.max(window.scrollY + margin, Math.min(posY, maxTop));
        jQuery(panel).css({ position: 'absolute', top: top, left: left });
    }

    UpdateNode(element, mouseEvent) {
        const self = this;
        const nodeInput = jQuery("#lifecycle-ui-edit-node");

        const posX = (mouseEvent && mouseEvent.pageX) ? mouseEvent.pageX : null;
        const posY = (mouseEvent && mouseEvent.pageY) ? mouseEvent.pageY : null;
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
            self.editing_node = element;
            nodeInput.show();
            // Place the panel after it's visible so we can measure it and keep
            // it from spilling off the right/bottom edge for nodes near the border.
            self.PositionEditPanel(posX, posY);
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
            self.ExportAsConfiguration();
            self.editing_node = null;
            nodeInput.hide();
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

        jQuery("#CancelNode").on('click', function(e) {
            e.preventDefault();
            jQuery("#lifecycle-ui-edit-node").hide();
            jQuery("#lifecycle-ui-edit-node div.alert").addClass('hidden');
            jQuery("#color-hex").removeClass('is-invalid');
            self.editing_node = null;
            self.Deselect();
        });

        const deleteNode = document.getElementById('DeleteNode');
        if (deleteNode) deleteNode.addEventListener('click', function(e) {
            e.preventDefault();
            if (!self.editing_node) return;
            self.DeleteNode(self.editing_node);
            jQuery("#lifecycle-ui-edit-node").hide();
            self.editing_node = null;
            self.Deselect();
            self.ExportAsConfiguration();
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

        setField('Config', JSON.stringify(self.config));

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
        setField('Layout', JSON.stringify(pos));
        setField('Maps', JSON.stringify(self.maps));
    }
}
