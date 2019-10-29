jQuery(function () {
    var _ELEMENT_KEY_SEQ = 0;

    RT.Lifecycle = class Lifecycle {
        constructor(name) {
            this.name = name;
            this.type = 'ticket';
            this.is_ticket = true;
            this.statuses = [];
            this.defaults = {};
            this.transitions = [];
            this.decorations = {};
            this.ticket_zoom = 'dynamic';
            this.ticket_center = 'status';
            this.defaultColor = '#547CCC';
            this._keyMap = {};
            this._statusMeta = {};

            // Viewer
            this.width = 809;
            this.height = 500;
            this.statusCircleRadius = 35;
            this.statusCircleRadiusFudge = 4; // required to give room for the arrowhead
            this.gridSize = 10;
            this.padding = this.statusCircleRadius * 2;
            this.animationFactor = 1; // bump this to 10 debug JS animations
        }
        initializeFromConfig(config) {
            var self = this;
            if (config.type) {
                self.type = config.type;
                self.is_ticket = self.type == 'ticket';
            }
            if (config.ticket_display) {
                self.ticket_display = config.ticket_display;
            }
            if (config.ticket_zoom) {
                self.ticket_zoom = config.ticket_zoom;
            }
            if (config.ticket_center) {
                self.ticket_center = config.ticket_center;
            }
            jQuery.each(['initial', 'active', 'inactive'], function (i, type) {
                if (config[type]) {
                    self.statuses = self.statuses.concat(config[type]);
                    jQuery.each(config[type], function (j, statusName) {
                        var item;
                        if (config.statusExtra) {
                            item = config.statusExtra[statusName] || {};
                        }
                        else {
                            item = {};
                        }
                        item._key = _ELEMENT_KEY_SEQ++;
                        item._type = 'status';
                        item.name = statusName;
                        item.type = type;
                        self._statusMeta[statusName] = item;
                        self._keyMap[item._key] = item;
                    });
                }
            });
            var statusCount = self.statuses.length;
            jQuery.each(self.statuses, function (i, statusName) {
                var meta = self._statusMeta[statusName];
                // arrange statuses evenly-spaced around a circle
                if (!meta.x) {
                    meta.x = 10000 * (Math.sin(2 * Math.PI * (i / statusCount)) + 1) / 2;
                    meta.y = 10000 * (Math.cos(2 * Math.PI * (i / statusCount)) + 1) / 2;
                }
                ;
                if (!meta.color) {
                    meta.color = self.defaultColor;
                }
                ;
            });
            if (config.defaults) {
                self.defaults = config.defaults;
            }
            if (config.transitions) {
                jQuery.each(config.transitions, function (fromStatus, toList) {
                    if (fromStatus == "") {
                        jQuery.each(toList, function (i, toStatus) {
                            self._statusMeta[toStatus].creation = true;
                        });
                    }
                    else {
                        jQuery.each(toList, function (i, toStatus) {
                            var description = fromStatus + ' -> ' + toStatus;
                            var transition;
                            if (config.transitionExtra) {
                                transition = config.transitionExtra[description] || {};
                            }
                            else {
                                transition = {};
                            }
                            var exists = jQuery.grep( self.transitions, function(t){
                                if ( ( t.from == toStatus && t.to == fromStatus ) ||
                                    ( t.from == fromStatus && t.to == toStatus ) ) {
                                    return (t);
                                }
                                return;
                            })[0];

                            if ( exists ) {
                                exists.leftSide  = 1;
                            }
                            else {
                                transition._key      = _ELEMENT_KEY_SEQ++;
                                transition._type     = 'transition';
                                transition.from      = fromStatus;
                                transition.to        = toStatus;
                                transition.style     = transition.style || 'solid';
                                transition.actions   = [];
                                transition.rightSide = 1;
                                self.transitions.push(transition);
                                self._keyMap[transition._key] = transition;
                            }
                        });
                    }
                });
            }
            if (config.rights) {
                jQuery.each(config.rights, function (description, right) {
                    jQuery.each(self.transitions, function (i, transition) {
                        var from = transition.from;
                        var to = transition.to;
                        if (description == (from + ' -> ' + to)
                            || description == ('* -> ' + to)
                            || description == (from + ' -> *')
                            || description == ('* -> *')) {
                            transition.right = right;
                        }
                    });
                });
            }
            jQuery.each(self.transitions, function (i, transition) {
                if (!transition.right) {
                    transition.right = self.defaultRightForTransition(transition);
                }
            });
            if (config.actions) {
                var actions = config.actions;
                // convert hash-based actions to array of pairs
                if (jQuery.type(config.actions) == "object") {
                    actions = [];
                    jQuery.each(config.actions, function (description, action) {
                        actions.push(description, action);
                    });
                }
                for (var i = 0; i < actions.length; ++i) {
                    var description;
                    var spec;
                    if (jQuery.type(actions[i]) == "string") {
                        description = actions[i];
                        spec = actions[++i];
                    }
                    else {
                        spec = actions[i];
                        var from = (delete spec.from) || '*';
                        var to = (delete spec.to) || '*';
                        description = from + ' -> ' + to;
                    }
                    jQuery.each(self.transitions, function (i, transition) {
                        var from = transition.from;
                        var to = transition.to;
                        if (description == (from + ' -> ' + to)
                            || description == ('* -> ' + to)
                            || description == (from + ' -> *')
                            || description == ('* -> *')) {
                            var action = jQuery.extend({}, spec);
                            action._key = _ELEMENT_KEY_SEQ++;
                            action._type = 'action';
                            transition.actions.push(action);
                            self._keyMap[action._key] = action;
                        }
                    });
                }
            }
            self.decorations = {};
            jQuery.each(['text', 'polygon', 'circle', 'line'], function (i, type) {
                var decorations = [];
                if (config.decorations && config.decorations[type]) {
                    jQuery.each(config.decorations[type], function (i, decoration) {
                        decoration._key = _ELEMENT_KEY_SEQ++;
                        decoration._type = type;
                        decorations.push(decoration);
                        self._keyMap[decoration._key] = decoration;
                    });
                }
                self.decorations[type] = decorations;
            });
        }
        defaultRightForTransition(transition) {
            if (this.type == 'asset') {
                return 'ModifyAsset';
            }
            if (transition.to == 'deleted') {
                return 'DeleteTicket';
            }
            return 'ModifyTicket';
        }
        _sanitizeForExport(o) {
            var clone = jQuery.extend(true, {}, o);
            var type = o._type;
            jQuery.each(clone, function (key, value) {
                if (key.substr(0, 1) == '_') {
                    delete clone[key];
                }
            });
            // remove additional redundant information to provide a single source
            // of truth
            if (type == 'status') {
                delete clone.name;
                delete clone.type;
                delete clone.creation;
            }
            else if (type == 'transition') {
                delete clone.from;
                delete clone.to;
                delete clone.actions;
                delete clone.right;
            }
            return clone;
        }
        exportAsConfiguration() {
            var self = this;
            var config = {
                type: self.type,
                initial: [],
                active: [],
                inactive: [],
                defaults: self.defaults,
                actions: [],
                rights: {},
                transitions: self.transitions,
                ticket_display: self.ticket_display,
                ticket_zoom: self.ticket_zoom,
                ticket_center: self.ticket_center,
                decorations: {},
                statusExtra: {},
                transitionExtra: {}
            };
            var transitions = { "": [] };
            jQuery.each(self.statuses, function (i, statusName) {
                var meta = self._statusMeta[statusName];
                var statusType = meta.type;
                config[statusType].push(statusName);
                config.statusExtra[statusName] = self._sanitizeForExport(meta);
                if (meta.creation) {
                    transitions[""].push(statusName);
                }
            });
            jQuery.each(self.transitions, function (i, transition) {
                var from = transition.from;
                var to = transition.to;
                var description = transition.from + ' -> ' + transition.to;
                config.transitionExtra[description] = self._sanitizeForExport(transition);
                if (!transitions[from]) {
                    transitions[from] = [];
                }
                transitions[from].push(to);
                if (transition.right) {
                    config.rights[description] = transition.right;
                }
                jQuery.each(transition.actions, function (i, action) {
                    if (action.label) {
                        var serialized = { label: action.label };
                        if (action.update) {
                            serialized.update = action.update;
                        }
                        config.actions.push(description, serialized);
                    }
                });
            });
            config.transitions = transitions;
            config.decorations = {};
            jQuery.each(self.decorations, function (type, decorations) {
                var out = [];
                jQuery.each(decorations, function (i, decoration) {
                    out.push(self._sanitizeForExport(decoration));
                });
                config.decorations[type] = out;
            });
            return config;
        }
        updateStatusName(oldValue, newValue) {
            var self = this;

            // statusMeta key
            var oldMeta = self._statusMeta[oldValue];
            delete self._statusMeta[oldValue];
            self._statusMeta[newValue] = oldMeta;
            // statuses array value
            var index = self.statuses.indexOf(oldValue);
            self.statuses[index] = newValue;
            // defaults
            jQuery.each(self.defaults, function (key, statusName) {
                if (statusName == oldValue) {
                    self.defaults[key] = newValue;
                }
            });
            // transitions
            jQuery.each(self.transitions, function (i, transition) {
                if (transition.from == oldValue) {
                    transition.from = newValue;
                }
                if (transition.to == oldValue) {
                    transition.to = newValue;
                }
            });
        }
        statusNameForKey(key) {
            return this._keyMap[key].name;
        }
        statusObjects() {
            return Object.values(this._statusMeta);
        }
        keyForStatusName(statusName) {
            return this._statusMeta[statusName]._key;
        }
        statusObjectForName(statusName) {
            return this._statusMeta[statusName];
        }
        deleteStatus(key) {
            var self = this;
            var statusName = self.statusNameForKey(key);
            if (!statusName) {
                console.error("no status for key '" + key + "'; did you accidentally pass status name?");
            }
            // internal book-keeping
            delete self._statusMeta[statusName];
            delete self._keyMap[key];
            // statuses array value
            var index = self.statuses.indexOf(statusName);
            self.statuses.splice(index, 1);
            // defaults
            jQuery.each(self.defaults, function (key, value) {
                if (value == statusName) {
                    delete self.defaults[key];
                }
            });
            // transitions
            self.transitions = jQuery.grep(self.transitions, function (transition) {
                if (transition.from == statusName || transition.to == statusName) {
                    return false;
                }
                return true;
            });
        }
        addTransition(fromStatus, toStatus) {

            var transition = {
                _key: _ELEMENT_KEY_SEQ++,
                _type: 'transition',
                from: fromStatus,
                to: toStatus,
                style: 'solid',
                actions: []
            };
            this.transitions.push(transition);
            this._keyMap[transition._key] = transition;
            transition.right = this.defaultRightForTransition(transition);

            return transition;
        }
        hasTransition(fromStatus, toStatus) {
            if (fromStatus == toStatus || !fromStatus || !toStatus) {
                return false;
            }
            for (var i = 0; i < this.transitions.length; ++i) {
                var transition = this.transitions[i];
                if (transition.from == fromStatus && transition.to == toStatus) {
                    return transition;
                }
            }
            ;
            return false;
        }
        transitionsFrom(fromStatus) {
            var transitions = [];
            for (var i = 0; i < this.transitions.length; ++i) {
                var transition = this.transitions[i];
                if (transition.from == fromStatus) {
                    transitions.push(transition);
                }
            }
            ;
            return transitions;
        }
        transitionsTo(toStatus) {
            var transitions = [];
            for (var i = 0; i < this.transitions.length; ++i) {
                var transition = this.transitions[i];
                if (transition.to == toStatus) {
                    transitions.push(transition);
                }
            }
            ;
            return transitions;
        }
        deleteTransition(key) {

            this.transitions = jQuery.grep(this.transitions, function (transition) {
                if (transition._key == key) {
                    return false;
                }
                return true;
            });
            delete this._keyMap[key];

        }
        deleteDecoration(type, key) {

            this.decorations[type] = jQuery.grep(this.decorations[type], function (decoration) {
                if (decoration._key == key) {
                    return false;
                }
                return true;
            });
            delete this._keyMap[key];

        }
        itemForKey(key) {
            return this._keyMap[key];
        }
        deleteItemForKey(key) {
            var item = this.itemForKey(key);
            var type = item._type;
            if (type == 'status') {
                this.deleteStatus(key);
            }
            else if (type == 'transition') {
                this.deleteTransition(key);
            }
            else if (type == 'text' || type == 'polygon' || type == 'circle' || type == 'line') {
                this.deleteDecoration(type, key);
            }
            else {
                console.error("unhandled type '" + type + "'");
            }
        }
        deleteActionForTransition(transition, key) {
            transition.actions = jQuery.grep(transition.actions, function (action) {
                if (action._key == key) {
                    return false;
                }
                return true;
            });
            delete this._keyMap[key];
        }
        updateItem(item, field, newValue) {
            var oldValue = item[field];
            item[field] = newValue;
            if (item._type == 'status' && field == 'name') {
                this.updateStatusName(oldValue, newValue);
            }
        }
        createActionForTransition(transition) {

            var action = {
                _type: 'action',
                _key: _ELEMENT_KEY_SEQ++,
            };
            transition.actions.push(action);
            this._keyMap[action._key] = action;

            return action;
        }
        beginDragging() {
        }
        beginChangingColor() {
        }
        moveItem(item, x, y) {
            item.x = x;
            item.y = y;
        }
        moveCircleRadiusPoint(circle, x, y) {
            circle.r = Math.max(10, Math.sqrt(x ** 2 + y ** 2));
        }
        movePolygonPoint(polygon, index, x, y) {
            var point = polygon.points[index];
            point.x = x;
            point.y = y;
        }
        createStatus(x, y) {

            var name;
            var i = 0;
            while (1) {
                name = 'status #' + ++i;
                if (!this._statusMeta[name]) {
                    break;
                }
            }
            this.statuses.push(name);
            var item = {
                _key: _ELEMENT_KEY_SEQ++,
                _type: 'status',
                name: name,
                type: 'initial',
                x: x,
                y: y
            };
            item.color = this.defaultColor;
            this._statusMeta[name] = item;
            this._keyMap[item._key] = item;

            return item;
        }
        update(field, value) {

            if (field == 'on_create' || field == 'approved' || field == 'denied' || field == 'reminder_on_open' || field == 'reminder_on_resolve') {
                this.defaults[field] = value;
            }
            else if (field == 'ticket_display' || field == 'ticket_zoom' || field == 'ticket_center') {
                this[field] = value;
            }
            else {
                console.error("Unhandled field in Lifecycle.update: " + field);
            }

        }
        _rebuildKeyMap() {
            var keyMap = {};
            jQuery.each(this._statusMeta, function (name, meta) {
                keyMap[meta._key] = meta;
            });
            jQuery.each(this.transitions, function (i, transition) {
                keyMap[transition._key] = transition;
                jQuery.each(transition.actions, function (j, action) {
                    keyMap[action._key] = action;
                });
            });
            jQuery.each(this.decorations, function (type, decorations) {
                jQuery.each(decorations, function (i, decoration) {
                    keyMap[decoration._key] = decoration;
                });
            });
            this._keyMap = keyMap;
        }
        _restoreState(state) {
            for (var key in state) {
                this[key] = state[key];
            }
            this._rebuildKeyMap();
        }
        cloneItem(source, x, y) {

            var clone = JSON.parse(JSON.stringify(source));
            clone._key = _ELEMENT_KEY_SEQ++;
            clone.x = x;
            clone.y = y;
            if (clone._type == 'polygon' || clone._type == 'circle' || clone._type == 'line' || clone._type == 'text') {
                this.decorations[clone._type].push(clone);
            }
            else {
                console.error("Unhandled type for clone: " + clone._type);
            }
            this._keyMap[clone._key] = clone;

            return clone;
        }
        selectedRights() {
            var rights = jQuery.map(this.transitions, function (transition) { return transition.right; });
            if (this.type == 'ticket') {
                rights = rights.concat(['ModifyTicket', 'DeleteTicket']);
            }
            else if (this.type == 'asset') {
                rights = rights.concat(['ModifyAsset']);
            }
            return jQuery.unique(rights.sort());
        }

        transitionClicked(key) {
            var transition = this._keyMap[key];

            if ( transition ) {
                if ( transition.leftSide && transition.rightSide ) {
                    delete this._keyMap[key];
                    transition.rightSide = 0;
                    transition.leftSide  = 0;

                    const index = this.transitions.map((el) => el._key).indexOf(transition._key);
                    this.transitions.splice(index, 1)
                }
                else if ( transition.rightSide ) {
                    this._keyMap[key].leftSide = 1;
                }
                else if ( transition.leftSide ) {
                    this._keyMap[key].rightSide = 1;
                }
                else {
                    this._keyMap[key].leftSide = 1;
                }
            }
            return transition;
        }
    };
});

