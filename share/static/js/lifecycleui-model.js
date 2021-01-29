
class LifecycleModel {
    constructor() {
        this.links_seq = 0;
        this.nodes_seq = 0;
        // Here we store the '' => transitions
        this.create_nodes = [];
    }

    // Generate nodes from config
    NodesFromConfig(config) {
        var self = this;
        self.nodes = [];

        jQuery.each(['initial', 'active', 'inactive'], function (i, type) {
            if ( config[type] ) {
                config[type].forEach(function(element) {
                    self.nodes = self.nodes.concat({id: ++self.nodes_seq, name: element, type: type});
                });
            }
        });
    }

    // Find all links associated with node object
    LinksForNodeFromConfig (node, config) {
        var config = config || this.config;

        for (let [fromNode, toList] of Object.entries(config.transitions)) {
            if ( fromNode == '' ) {
                this.create_nodes = toList;
            }
            else if ( fromNode.toLowerCase() == node.toLowerCase() ) {
                return toList;
            }
        }
        return [];
    }

    // Create a new node for our JS model
    AddNode(point) {
        var self = this;

        var i = 0,
            name;
        while (1) {
            name = 'status #' + ++i;
            var index = self.nodes.findIndex(function(x) { return x.name.toLowerCase() == name.toLowerCase() });
            if ( index < 0 ) {
                break;
            }
        }
        self.nodes.push({id: ++self.nodes_seq, name: name, type: 'active', x: point[0], y: point[1]});
    }

    AddLink(source, target) {
        var self = this;
        if (!source || !target) return;

        var link = self.links.filter(function(l) { return (l.source.id === target.id && l.target.id === source.id); })[0];

        if ( link ) {
            link.start = true;
        }
        else {
            link = self.links.filter(function(l) { return (l.source.id === source.id && l.target.id === target.id); })[0];
            if (!link ) {
                self.links.push({id: ++self.links_seq, source: source, target: target, start: false, end: true});
            }
        }
    }

    ToggleLink(d) {
        var self = this;
        var index = self.links.findIndex(function(x) { return x.id == d.id });

        var link = self.links[index];
        // delete link if we have both transitions already
        if ( link.start && link.end ) {
            self.links.splice(index, 1);
            var from = d.source.name.toLowerCase();
            var to = d.target.name.toLowerCase();
            var pattern = from + ' *-> *' + to + '|' + to + ' *-> *' + from;
            self.DeleteRights(null, pattern);
            self.DeleteActions(null, pattern);
        }
        else if( link.start ) {
            link.end = true;
        }
        else {
            link.start = true;
        }
    }

    NodeById(id) {
        var self = this;

        var nodeMap = d3.map(self.nodes, function(d) { return d.id; });
        return nodeMap.get( id );
    }

    NodeByStatus(status) {
        var self = this;

        var nodeMap = d3.map(self.nodes, function(d) { return d.name; });
        return nodeMap.get( status );
    }

    DeleteNode(d) {
        var self = this;

        var index = self.nodes.findIndex(function(x) { return x.id == d.id });
        self.DeleteLinksForNode(self.nodes[index]);

        self.DeleteRights(d);
        self.DeleteDefaults(d);
        self.DeleteActions(d);

        self.nodes.splice(index, 1);
    }

    LinksForNode (node) {
        var self = this;

        return self.links.filter(function(link) {
            if ( link.source.id === node.id ) {
                return true;
            }
            else if ( link.target.id === node.id && link.start ) {
                return true;
            }
            else {
                return false;
            }
        });
    }

    DeleteDefaults(d) {
        var self = this;

        jQuery.each(self.config.defaults, function (key, value) {
            if (value && value.toLowerCase() === d.name.toLowerCase()) {
                delete self.config.defaults[key];
            }
        });
    }

    DeleteRights(d, pattern) {
        var self = this;
        if ( !pattern ) {
            pattern = d.name.toLowerCase() + " *->|-> *" + d.name.toLowerCase();
        }

        var re = new RegExp(pattern);
        jQuery.each(self.config.rights, function(key, value) {
            if ( re.test(key.toLowerCase()) ) {
                delete self.config.rights[key];
            }
        });
    }

    DeleteActions(d, pattern) {
        var self = this;
        if ( !pattern ) {
            pattern = d.name.toLowerCase() + " *->|-> *" + d.name.toLowerCase();
        }

        var re = new RegExp(pattern);
        var actions = [];
        var tempArr = self.config.actions || [];

        var i = tempArr.length / 2;
        while (i--) {
            var action, info;
            [action, info] = tempArr.splice(0, 2);
            if (!action) continue;

            if ( ! re.test(action) ) {
                actions.push(action);
                actions.push(info);
            }
        }
        self.config.actions = actions;
    }

    DeleteLinksForNode(node) {
        var self = this;

        if ( !node ) {
            return;
        }

        self.links = jQuery.grep(self.links, function (transition) {
            if (transition.source.id == node.id || transition.target.id == node.id) {
                return false;
            }
            return true;
        });
    }

    UpdateNodeModel(node, args) {
        var self = this;

        var nodeIndex = self.nodes.findIndex(function(x) { return x.id == node.id });

        var oldValue =  self.nodes[nodeIndex];

        self.nodes[nodeIndex] = {...self.nodes[nodeIndex], ...args};
        var nodeUpdated = self.nodes[nodeIndex];

        // Update any links with node being changed as source
        var links = self.links.filter(function(l) { return (
            ( l.source.id === node.id ) )
        });
        links.forEach(function(link) {
            var index = self.links.findIndex(function(x) { return x.id == link.id });
            self.links[index] = {...link, source: nodeUpdated}
        });

        // Update any links with node being changed as target
        var links = self.links.filter(function(l) { return (
            ( l.target.id === node.id ) )
        });
        links.forEach(function(link) {
            var index = self.links.findIndex(function(x) { return x.id == link.id });
            self.links[index] = {...link, target: nodeUpdated}
        });

        if ( oldValue.name === nodeUpdated.name ) return;

        // Only need to check for target
        var tempArr = [];
        self.create_nodes.forEach(function(target) {
            if ( target != oldValue.name ) {
                tempArr.push(target);
            }
            else {
                tempArr.push(nodeUpdated.name);
            }
        });
        self.create_nodes = tempArr;

        for (let type in self.config.defaults) {
            if ( self.config.defaults[type] === oldValue.name ) {
                self.config.defaults[type] = nodeUpdated.name;
            }
        }

        let re_from = new RegExp(oldValue.name + ' *->');
        let re_to = new RegExp('-> *' + oldValue.name);

        for (let action in self.config.rights) {
            let updated = action.replace(re_from, nodeUpdated.name + ' ->').replace(re_to, '-> ' + nodeUpdated.name);
            if ( action != updated ) {
                self.config.rights[updated] = self.config.rights[action];
                delete self.config.rights[action];
            }
        }

        let actions = [];
        if ( self.config.actions ) {
            for ( let i = 0; i < self.config.actions.length; i += 2 ) {
                let action = self.config.actions[i];
                let info = self.config.actions[i+1];
                let updated = action.replace(re_from, nodeUpdated.name + ' ->').replace(re_to, '-> ' + nodeUpdated.name);
                actions.push(updated);
                actions.push(info);
            }
        }
        self.config.actions = actions;

        let config_name = jQuery('form[name=ModifyLifecycle] input[name=Name]').val();
        for (let item in self.maps) {
            if ( item.match(config_name + ' *->')) {
                let maps = self.maps[item];
                for ( let from in maps ) {
                    if ( from === oldValue.name ) {
                        maps[nodeUpdated.name] = maps[from];
                        delete maps[from];
                    }
                }
            }
            else if ( item.match('-> *' + config_name) ) {
                let maps = self.maps[item];
                for ( let from in maps ) {
                    if ( maps[from] === oldValue.name ) {
                        maps[from] = nodeUpdated.name;
                    }
                }
            }
        }
    }

    ExportAsConfiguration () {
        var self = this;

        var config = {
            type: self.type,
            initial:  [],
            active:   [],
            inactive: [],
            transitions: {},
        };

        // Grab our status nodes
        ['initial', 'active', 'inactive'].forEach(function(type) {
            config[type] = self.nodes.filter(function(n) { return n.type == type }).map(function(n) { return n.name });
        });

        // Grab our links
        config.transitions[""] = self.create_nodes;

        var seen = {};
        self.nodes.forEach(function(source) {
            var links = self.LinksForNode(source);
            var targets = links.map(link => {
                if ( link.source.id === source.id ) {
                    return link.target.name;
                }
                else {
                    return link.source.name;
                }
            });
            config.transitions[source.name] = targets;
            seen[source.name] = 1;
        });

        for (let transition in config.transitions) {
            if ( transition && ( !seen[transition] || !config.transitions[transition].length ) ) {
                delete config.transitions[transition];
            }
        }

        self.config = {...self.config, ...config};

        var field = jQuery('form[name=ModifyLifecycle] input[name=Config]');
        field.val(JSON.stringify(self.config));

        var pos;
        if ( !jQuery('#enableSimulation').is(":checked") ) {
            pos = {};
            self.nodes.forEach( function(d) {
                pos[d.name] = [Math.round(d.x), Math.round(d.y)];
            });
        }
        var layout = jQuery('form[name=ModifyLifecycle] input[name=Layout]');
        layout.val(pos ? JSON.stringify(pos) : '');

        var maps = jQuery('form[name=ModifyLifecycle] input[name=Maps]');
        maps.val(JSON.stringify(self.maps));
    };
}
