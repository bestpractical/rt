jQuery(function () {
    var _ELEMENT_KEY_SEQ = 0;

    function Lifecycle (name) {
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
        this._undoState = { undoStack: [], redoStack: [] };
        this._keyMap = {};
        this._statusMeta = {};
    };

    Lifecycle.prototype._initialPointsForPolygon = {
        Line: [
            {x: -700, y: 0},
            {x:  700, y: 0},
        ],
        Triangle: [
            {x:  700, y: 2000},
            {x:   0, y:  0},
            {x: -600, y: 2000}
        ],
        Rectangle: [
            {x: -600, y: -600},
            {x:  600, y: -600},
            {x:  600, y:  600},
            {x: -600, y:  600}
        ]
    };

    Lifecycle.prototype.initializeFromConfig = function (config) {
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
                    item._key  = _ELEMENT_KEY_SEQ++;
                    item._type = 'status';
                    item.name  = statusName;
                    item.type  = type;
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
                meta.x = 10000 * (Math.sin(2 * Math.PI * (i/statusCount)) + 1) / 2;
                meta.y = 10000 * (Math.cos(2 * Math.PI * (i/statusCount)) + 1) / 2;
            };

            if (!meta.color) {
                meta.color = self.defaultColor;
            };
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
                        transition._key    = _ELEMENT_KEY_SEQ++;
                        transition._type   = 'transition';
                        transition.from    = fromStatus;
                        transition.to      = toStatus;
                        transition.style   = transition.style || 'solid';
                        transition.actions = [];

                        self.transitions.push(transition);
                        self._keyMap[transition._key] = transition;
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
                jQuery.each(config.actions, function(description, action) {
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
    };

    Lifecycle.prototype.defaultRightForTransition = function (transition) {
        if (this.type == 'asset') {
            return 'ModifyAsset';
        }

        if (transition.to == 'deleted') {
            return 'DeleteTicket';
        }

        return 'ModifyTicket';
    };

    Lifecycle.prototype._sanitizeForExport = function (o) {
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
    };

    Lifecycle.prototype.exportAsConfiguration = function () {
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
                    var serialized = { label : action.label };
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
    };

    Lifecycle.prototype.updateStatusName = function (oldValue, newValue) {
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
    };

    Lifecycle.prototype.statusNameForKey = function (key) {
        return this._keyMap[key].name;
    };

    Lifecycle.prototype.statusObjects = function () {
        return Object.values(this._statusMeta);
    };

    Lifecycle.prototype.keyForStatusName = function (statusName) {
        return this._statusMeta[statusName]._key;
    };

    Lifecycle.prototype.statusObjectForName = function (statusName) {
        return this._statusMeta[statusName];
    };

    Lifecycle.prototype.deleteStatus = function (key) {
        var self = this;

        self._saveUndoEntry(false);

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

        self._undoStateChanged();
    };

    Lifecycle.prototype.addTransition = function (fromStatus, toStatus) {
        this._saveUndoEntry(false);

        var transition = {
            _key    : _ELEMENT_KEY_SEQ++,
            _type   : 'transition',
            from    : fromStatus,
            to      : toStatus,
            style   : 'solid',
            actions : []
        };
        this.transitions.push(transition);
        this._keyMap[transition._key] = transition;

        transition.right = this.defaultRightForTransition(transition);

        this._undoStateChanged();

        return transition;
    };

    Lifecycle.prototype.hasTransition = function (fromStatus, toStatus) {
        if (fromStatus == toStatus || !fromStatus || !toStatus) {
            return false;
        }

        for (var i = 0; i < this.transitions.length; ++i) {
            var transition = this.transitions[i];
            if (transition.from == fromStatus && transition.to == toStatus) {
                return transition;
            }
        };

        return false;
    };

    Lifecycle.prototype.transitionsFrom = function (fromStatus) {
        var transitions = [];
        for (var i = 0; i < this.transitions.length; ++i) {
            var transition = this.transitions[i];
            if (transition.from == fromStatus) {
                transitions.push(transition);
            }
        };
        return transitions;
    };

    Lifecycle.prototype.transitionsTo = function (toStatus) {
        var transitions = [];
        for (var i = 0; i < this.transitions.length; ++i) {
            var transition = this.transitions[i];
            if (transition.to == toStatus) {
                transitions.push(transition);
            }
        };
        return transitions;
    };

    Lifecycle.prototype.deleteTransition = function (key) {
        this._saveUndoEntry(false);

        this.transitions = jQuery.grep(this.transitions, function (transition) {
            if (transition._key == key) {
                return false;
            }
            return true;
        });
        delete this._keyMap[key];

        this._undoStateChanged();
    };

    Lifecycle.prototype.deleteDecoration = function (type, key) {
        this._saveUndoEntry(false);

        this.decorations[type] = jQuery.grep(this.decorations[type], function (decoration) {
            if (decoration._key == key) {
                return false;
            }
            return true;
        });
        delete this._keyMap[key];

        this._undoStateChanged();
    };

    Lifecycle.prototype.itemForKey = function (key) {
        return this._keyMap[key];
    };

    Lifecycle.prototype.deleteItemForKey = function (key) {
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
    };

    Lifecycle.prototype.deleteActionForTransition = function (transition, key) {
        this._saveUndoEntry(false);

        transition.actions = jQuery.grep(transition.actions, function (action) {
            if (action._key == key) {
                return false;
            }
            return true;
        });
        delete this._keyMap[key];

        this._undoStateChanged();
    };

    Lifecycle.prototype.updateItem = function (item, field, newValue, skipUndo) {
        if (!skipUndo) {
            this._saveUndoEntry(false);
        }

        var oldValue = item[field];

        item[field] = newValue;

        if (item._type == 'status' && field == 'name') {
            this.updateStatusName(oldValue, newValue);
        }

        if (!skipUndo) {
            this._undoStateChanged();
        }
    };

    Lifecycle.prototype.createActionForTransition = function (transition) {
        this._saveUndoEntry(false);

        var action = {
            _type : 'action',
            _key  : _ELEMENT_KEY_SEQ++,
        };
        transition.actions.push(action);
        this._keyMap[action._key] = action;

        this._undoStateChanged();

        return action;
    };

    Lifecycle.prototype.beginDragging = function () {
        this._saveUndoEntry(true);
    };

    Lifecycle.prototype.beginChangingColor = function () {
        this._saveUndoEntry(true);
    };

    Lifecycle.prototype.moveItem = function (item, x, y) {
        item.x = x;
        item.y = y;
    };

    Lifecycle.prototype.moveCircleRadiusPoint = function (circle, x, y) {
        circle.r = Math.max(10, Math.sqrt(x**2 + y**2));
    }

    Lifecycle.prototype.movePolygonPoint = function (polygon, index, x, y) {
        var point = polygon.points[index];
        point.x = x;
        point.y = y;
    };

    Lifecycle.prototype.createStatus = function (x, y) {
        this._saveUndoEntry(false);

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
            name:  name,
            type:  'initial',
            x:     x,
            y:     y
        };
        item.color = this.defaultColor;

        this._statusMeta[name] = item;
        this._keyMap[item._key] = item;

        this._undoStateChanged();

        return item;
    };

    Lifecycle.prototype.createTextDecoration = function (x, y) {
        this._saveUndoEntry(false);

        var item = {
            _key: _ELEMENT_KEY_SEQ++,
            _type: 'text',
            text:  'New label',
            x:     x,
            y:     y
        };
        this.decorations.text.push(item);
        this._keyMap[item._key] = item;

        this._undoStateChanged();
        return item;
    };

    Lifecycle.prototype.createPolygonDecoration = function (x, y, type) {
        this._saveUndoEntry(false);

        var item = {
            _key: _ELEMENT_KEY_SEQ++,
            _type: 'polygon',
            label: type,
            stroke: '#000000',
            renderStroke: true,
            strokeStyle: 'solid',
            fill: '#ffffff',
            renderFill: true,
            x: x,
            y: y,
            points: JSON.parse(JSON.stringify(this._initialPointsForPolygon[type]))
        };
        this.decorations.polygon.push(item);
        this._keyMap[item._key] = item;

        this._undoStateChanged();
        return item;
    };

    Lifecycle.prototype.createCircleDecoration = function (x, y, r) {
        this._saveUndoEntry(false);

        var item = {
            _key: _ELEMENT_KEY_SEQ++,
            _type: 'circle',
            label: 'Circle',
            stroke: '#000000',
            renderStroke: true,
            strokeStyle: 'solid',
            fill: '#ffffff',
            renderFill: true,
            x: x,
            y: y,
            r: r
        };
        this.decorations.circle.push(item);
        this._keyMap[item._key] = item;

        this._undoStateChanged();
        return item;
    };

    Lifecycle.prototype.createLineDecoration = function (x, y) {
        this._saveUndoEntry(false);

        var item = {
            _key: _ELEMENT_KEY_SEQ++,
            _type: 'line',
            label: 'Line',
            style: 'solid',
            startMarker: 'none',
            endMarker: 'arrowhead',
            x: x,
            y: y,
            points: JSON.parse(JSON.stringify(this._initialPointsForPolygon.Line))
        };
        this.decorations.line.push(item);
        this._keyMap[item._key] = item;

        this._undoStateChanged();
        return item;
    };

    Lifecycle.prototype.update = function (field, value) {
        this._saveUndoEntry(false);

        if (field == 'on_create' || field == 'approved' || field == 'denied' || field == 'reminder_on_open' || field == 'reminder_on_resolve') {
            this.defaults[field] = value;
        }
        else if (field == 'ticket_display' || field == 'ticket_zoom' || field == 'ticket_center') {
            this[field] = value;
        }
        else {
            console.error("Unhandled field in Lifecycle.update: " + field);
        }

        this._undoStateChanged();
    };

    Lifecycle.prototype._currentUndoFrame = function () {
        var undoState = this._undoState;
        var keyMap = this._keyMap;
        delete this._undoState;
        delete this._keyMap;

        var entry = JSON.stringify(this);

        this._undoState = undoState;
        this._keyMap = keyMap;

        var frame = [entry];
        if (this.undoFrameCallback) {
            this.undoFrameCallback(frame);
        }

        return frame;
    };

    Lifecycle.prototype._undoStateChanged = function () {
        this._canUndo = this._undoState.undoStack.length > 0;
        this._canRedo = this._undoState.redoStack.length > 0;

        if (this.undoStateChangedCallback) {
            this.undoStateChangedCallback();
        }
    };

    Lifecycle.prototype._saveUndoEntry = function (notify) {
        var frame = this._currentUndoFrame();
        this._undoState.undoStack.push(frame);
        this._undoState.redoStack = [];

        if (notify) {
            this._undoStateChanged();
        }
    };

    Lifecycle.prototype._rebuildKeyMap = function () {
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
    };

    Lifecycle.prototype._restoreState = function (state) {
        for (var key in state) {
            this[key] = state[key];
        }

        this._rebuildKeyMap();
    };

    Lifecycle.prototype.undo = function () {
        var undoStack = this._undoState.undoStack;
        if (undoStack.length == 0) {
            return null;
        }

        this._undoState.redoStack.push(this._currentUndoFrame());

        var frame = undoStack.pop();
        var entry = JSON.parse(frame[0]);

        this._restoreState(entry);

        this._undoStateChanged();

        return frame;
    };

    Lifecycle.prototype.redo = function () {
        var redoStack = this._undoState.redoStack;
        if (redoStack.length == 0) {
            return null;
        }

        this._undoState.undoStack.push(this._currentUndoFrame());

        var frame = redoStack.pop();
        var entry = JSON.parse(frame[0]);

        this._restoreState(entry);

        this._undoStateChanged();

        return frame;
    };

    Lifecycle.prototype.cloneItem = function (source, x, y) {
        this._saveUndoEntry(false);

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

        this._undoStateChanged();

        return clone;
    };

    Lifecycle.prototype.selectedRights = function () {
        var rights = jQuery.map(this.transitions, function (transition) { return transition.right });

        if (this.type == 'ticket') {
            rights = rights.concat(['ModifyTicket', 'DeleteTicket']);
        }
        else if (this.type == 'asset') {
            rights = rights.concat(['ModifyAsset']);
        }

        return jQuery.unique(rights.sort());
    };

    RT.Lifecycle = Lifecycle;
});

