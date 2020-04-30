
class LifecycleModel {
    constructor() {
        this.links_seq = 0;
        this.nodes_seq = 0;
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
            if ( fromNode.toLowerCase() == node.toLowerCase() ) {
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

            self.UpdateChecks(d.source);
            self.UpdateChecks(d.target);
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

        self.UpdateChecks(d);

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

    UpdateChecks(d) {
        var self = this;

        self.CheckRights(d);
        self.CheckDefaults(d);
        self.CheckActions(d);
    }

    CheckDefaults(d) {
        var self = this;

        jQuery.each(self.config.defaults, function (key, value) {
            if (value && value.toLowerCase() === d.name.toLowerCase()) {
                delete self.config.defaults[key];
            }
        });
    }

    CheckRights(d) {
        var self = this;

        jQuery.each(self.config.rights, function(key, value) {
            var pattern = d.name.toLowerCase()+" ->|-> "+d.name.toLowerCase();
            var re = new RegExp(pattern,"g");
            if ( re.test(key.toLowerCase()) ) {
                delete self.config.rights[key];
            }
        });
    }

    CheckActions(d) {
        var self = this;

        var actions = [];
        var tempArr = self.config.actions || [];

        var i = tempArr.length / 2;
        while (i--) {
            var action, info;
            [action, info] = tempArr.splice(0, 2);
            if (!action) continue;

            var re = new RegExp(d.name.toLowerCase()+" *->|-> *"+d.name.toLowerCase(),"g");
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
        self.UpdateChecks(node);
    }

    UpdateNodeModel(node, args) {
        var self = this;

        self.UpdateChecks(node);

        var nodeIndex = self.nodes.findIndex(function(x) { return x.id == node.id });

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
        config.transitions[""] = self.config.transitions ? self.config.transitions[""]: [];

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

        var field = jQuery('input[name=Config]');
        field.val(JSON.stringify(self.config));

        var pos;
        if ( !jQuery('#enableSimulation').is(":checked") ) {
            pos = {};
            self.nodes.forEach( function(d) {
                pos[d.name] = [Math.round(d.x), Math.round(d.y)];
            });
        }
        var layout = jQuery('input[name=Layout]');
        layout.val(pos ? JSON.stringify(pos) : '');
    };
}
