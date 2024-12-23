RT.NewLifecycleEditor ||= class {
    constructor(container, config, maps, layout) {
        var self = this;

        self.links_seq = 0;
        self.nodes_seq = 0;
        // Here we store the '' => transitions
        self.create_nodes = [];

        self.width            = 900;
        self.height           = 350;
        self.node_radius      = 35;
        self.maps             = maps;
        self.layout           = layout;
        self.enableSimulation = 1;

        if ( !self.layout ) {
            jQuery('#enableSimulation').prop( "checked", true );
        }
        else {
            self.enableSimulation = 0;
            jQuery('#enableSimulation').prop( "checked", false );
        }

        jQuery("#SaveNode").click(function(e) {
            e.preventDefault();
            self.UpdateNode();
        });

        jQuery("#CancelNode").click(function(e) {
            e.preventDefault();
            jQuery("#lifeycycle-ui-edit-node").toggle();
            jQuery("#lifeycycle-ui-edit-node div.alert").addClass('hidden');
        });

        self.svg = d3.select(container).select('svg')
            .attr("preserveAspectRatio", "xMinYMin meet")
            .attr("viewBox", "0 0 "+self.width+" "+self.height)
            .classed("svg-content-responsive", true)
            .attr("border", 1);

        self.svg.append("rect")
            .classed("rect", true)
            .attr("x", 0)
            .attr("y", 0)
            .attr("height", self.height)
            .attr("width", self.width)
            .style("stroke", 'black')
            .style("fill", "none")
            .style("stroke-width", 1);

        self.config   = config;
        self.links    = [];
        self.nodes    = [];
        self.animationFactor = 1;
        // mouse event vars
        self.selected_node   = null;
        self.editing_node    = null;
        self.selected_link   = null;
        self.mousedown_link  = null;
        self.mousedown_node  = null;
        self.mouseup_node    = null;

        self.NodesFromConfig(config);
        self.nodes.forEach(function(source) {
            self.LinksForNodeFromConfig(source.name).forEach(function(targetName) {
                // Get our target node
                var target = self.nodes.filter(function(source) { return source.name === targetName; })[0];
                if (!target) { return };

                if ( source.id < target.id ) {
                    self.links.push({id: ++self.links_seq, source: source, target: target, start: false, end: true});
                    return;
                }
                var link = self.links.filter(function(l) { return (l.source === target && l.target === source); })[0];
                if(link) link.start = true;
                else self.links.push({id: ++self.links_seq, source: source, target: target, start: false, end: true});
            });
            if ( !self.enableSimulation ) {
                if (self.layout[source.name][0]) source.x = parseInt(self.layout[source.name][0]);
                if (self.layout[source.name][1]) source.y = parseInt(self.layout[source.name][1]);
            }
        });

        self.simulation = d3.forceSimulation();
        const link_size = self.nodes.length > 10 ? 300 : self.nodes.length * 35;
        if ( !self.enableSimulation ) {
            self.simulation
                .force("link", null)
                .force("charge", null)
                .force("center", null)
                .force('collision', null);
        }
        else {
            self.simulation
                .force("link", d3.forceLink().distance(link_size < 100 ? 200 : link_size).strength(0.2))
                .force("charge", d3.forceManyBody().strength(-200))
                .force("center", d3.forceCenter(self.width / 2, self.height / 2))
                .force('collision', d3.forceCollide().radius(function(d) {
                return d.radius
                }));
        }

        self.SetUp();
        self.RenderNode();
        self.RenderLink();

        self.simulation
            .nodes(self.nodes)
            .on("tick", function (t) {
                self.node.attr("transform", function (d) {

                    var x = d.x, y = d.y;
                    if ( d.x + self.node_radius / 2 > self.width ) x = self.width - self.node_radius;
                    if ( d.x - self.node_radius / 2 <= 0 ) x = self.node_radius;
                    if ( d.y + self.node_radius / 2 > self.height ) y = self.height - self.node_radius;
                    if ( d.y - self.node_radius / 2 <= 0 ) y = self.node_radius;

                    if ( !self.enableSimulation ) {
                        d.fx = x;
                        d.fy = y;
                    }
                    else {
                        d.fx = null;
                        d.fy = null;
                    }

                    return "translate(" + x + "," + y + ")";
                });

                self.link.attr('d', (function(d) {
                    var sx = d.source.x,
                        sy = d.source.y,
                        tx = d.target.x,
                        ty = d.target.y;

                    if ( sx + self.node_radius / 2 > self.width ) sx = self.width - self.node_radius;
                    if ( sx - self.node_radius / 2 <= 0 ) sx = self.node_radius;
                    if ( sy + self.node_radius / 2 > self.height ) sy = self.height - self.node_radius;
                    if ( sy - self.node_radius / 2 <= 0 ) sy = self.node_radius;
                    if ( tx + self.node_radius / 2 > self.width ) tx = self.width - self.node_radius;
                    if ( tx - self.node_radius / 2 <= 0 ) tx = self.node_radius;
                    if ( ty + self.node_radius / 2 > self.height ) ty = self.height - self.node_radius;
                    if ( ty - self.node_radius / 2 <= 0 ) ty = self.node_radius;

                    var deltaX = tx - sx,
                    deltaY     = ty - sy,
                    dist = Math.sqrt(deltaX * deltaX + deltaY * deltaY),
                    normX = deltaX / dist,
                    normY = deltaY / dist,
                    sourcePadding = 45,
                    targetPadding = 45,
                    sourceX = sx + (sourcePadding * normX),
                    sourceY = sy + (sourcePadding * normY),
                    targetX = tx - (targetPadding * normX),
                    targetY = ty - (targetPadding * normY);
                    return 'M' + sourceX + ',' + sourceY + 'L' + targetX + ',' + targetY;
                })
            );
        });

        self.ExportAsConfiguration();

        self.Refresh();
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

        // Clean removed states from create_nodes
        self.create_nodes = self.create_nodes.filter(target => self.nodes.find(n => n.name == target));

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

        // Set defaults on_create if it's absent
        self.config.defaults ||= {};
        self.config.defaults.on_create ||= self.config.initial[0] || self.config.active[0] || null;

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

    SetUp() {
        var self = this;

        // define arrow markers for graph links
        self.svg.append('svg:defs').append('svg:marker')
            .attr('id', 'end-arrow')
            .attr('viewBox', '0 -5 10 10')
            .attr('refX', 6)
            .attr('markerWidth', 5)
            .attr('markerHeight', 5)
            .attr('orient', 'auto')
            .append('svg:path')
            .attr('d', 'M0,-5L10,0L0,5')
            .attr('fill', '#000');

        self.svg.append('svg:defs').append('svg:marker')
            .attr('id', 'start-arrow')
            .attr('viewBox', '0 -5 10 10')
            .attr('refX', 6)
            .attr('markerWidth', 5)
            .attr('markerHeight', 5)
            .attr('orient', 'auto')
            .append('svg:path')
            .attr('d', 'M10,-5L0,0L10,5')
            .attr('fill', '#000');

        // line displayed when dragging new nodes
        self.drag_line = self.svg.append('svg:path')
            .attr('class', 'dragline hidden')
            .attr('d', 'M0,0L0,0')
            .attr('fill', '#000')
            .attr('markerWidth', 8)
            .attr('markerHeight', 8)
            .attr("stroke-width", 1)
            .attr("style", "stroke: black; stroke-opacity: 0.6;");

        self.svg
            .on('click', function () {
                d3.event.preventDefault();
                d3.event.stopPropagation();

                if ( self.selected_node || self.editing_node ) {
                    self.Deselect();
                }
                else {
                    self.simulation.stop();
                    self.Deselect();

                    self.AddNode(d3.mouse(this));

                    self.ExportAsConfiguration();

                    self.Refresh();
                }
            })
            .on('contextmenu', function() { d3.event.preventDefault(); })
            .on('mousemove', function() { self.Mousemove(this); })
            .on('mouseup', function() { self.Mouseup(this); })
            .on('mousedown', function() { self.Mousedown(this); });

        d3.select("body").on("keydown", function (d) {
            if ( !self.editing_node && self.selected_node && ( d3.event.keyCode == 68 || d3.event.keyCode == 46 ) ) {
                d3.event.preventDefault();
                d3.event.stopPropagation();

                self.simulation.stop();
                self.svg.selectAll('.node-selected').each(function(d) {
                    self.DeleteNode(d);

                    self.ExportAsConfiguration();

                    self.Deselect();
                    self.Refresh();
                });
            }
        });

        jQuery('#enableSimulation').click(function(e) {
            self.ToggleSimulation();
            return true;
        });

        document.querySelector('form[name=ModifyLifecycle]').addEventListener('htmx:configRequest', function(evt) {
            self.ExportAsConfiguration();
            // Manually update values to confirm submitted values are always the latest
            evt.detail.parameters['Config'] = evt.detail.elt.querySelector('input[name=Config]').value;
            evt.detail.parameters['Layout'] = evt.detail.elt.querySelector('input[name=Layout]').value;
        });
    }

    RenderNode() {
        var self = this;
        self.node = self.svg.selectAll(".node")
            .data(self.nodes.filter(function(d) { return d.id >= 0 }));

        self.node.exit()
            .remove();

        // Add new nodes and draw them
        var nodeEnter = self.node.enter().append("g")
            .attr("class", "node");

        nodeEnter.append("circle");
        nodeEnter.append("text");
        nodeEnter.append("title");

        self.node = nodeEnter.merge(self.node)
            .attr("id", function(d) { return d.id });

        self.node.call(d3.drag()
            .on("start", function(d) {
                if (!d3.event.active) self.simulation.alphaTarget(0.3).restart();
                d.fx = d.x, d.fy = d.y;
            })
            .on("drag", function(d) {
                d.fx = d3.event.x, d.fy = d3.event.y;
            })
            .on("end", function(d) {
                if (!d3.event.active) self.simulation.alphaTarget(0);
                if ( !self.enableSimulation ) {
                    d.fx = null, d.fy = null;
                }
            }));

        // Add our circle to our new node
        self.node.select("circle")
            .attr("r", self.node_radius)
            .attr("stroke", "black")
            .attr("fill", function(d) {
                switch(d.type) {
                    case 'active':
                        return '#547CCC';
                    case 'inactive':
                        return '#4bb2cc';
                    case 'initial':
                        return '#599ACC';
                }
            })
            .on("click", function() {
                d3.event.stopPropagation();
                d3.event.preventDefault();

                self.SelectNode(this);
            })
            .on('mousedown', function(d) {
                if(!d3.event.ctrlKey || self.mousedown_node || self.mousedown_link) return;
                d3.event.preventDefault();
                d3.event.stopPropagation();

                // select node
                self.mousedown_node = d;
                if ( !self.mousedown_node ) { self.mousedown_node = null; return; }

                // reposition drag line
                self.drag_line
                    .style('marker-end', 'url(#end-arrow)')
                    .classed('hidden', false)
                    .attr('d', 'M' + self.mousedown_node.x + ',' + self.mousedown_node.y + 'L' + self.mousedown_node.x + ',' + self.mousedown_node.y);

                self.Refresh();
            })
            .on('mouseup', function(d) {
                self.Mouseup(d);
            });

        self.node.select("text")
            .text(function(d) { return d.name; })
            .each(function () { self.TruncateLabel(this, self); })
            .attr("x", function(d) {
                var node = d3.select(this), textLength = node.node().getComputedTextLength();
                if ( textLength > self.node_radius*2 ) textLength = self.node_radius*2;
                return -textLength/2;
            })
            .attr("y", 0)
            .style("font-size", "10px")
            .on("click", function(d) {
                d3.event.stopPropagation();
                d3.event.preventDefault();
                self.UpdateNode(d);
            });

        self.node.select("title")
            .text(function(d) { return d.type; });
    }

    UpdateNode(element) {
        var self = this;
        const nodeInput = jQuery("#lifeycycle-ui-edit-node");

        if ( event.pageX ) {
            var posX = event.pageX;
            var posY =  event.pageY;

            if ( posX + nodeInput.width() > self.width ) posX = self.width - nodeInput.width();
            if ( posY + nodeInput.height() > self.height ) posY = self.height - nodeInput.height();

            nodeInput.css( {position:"absolute", top:posY - self.node_radius, left: posX - self.node_radius});
        }
        var list = document.getElementById('lifeycycle-ui-edit-node').querySelectorAll('input, select');

        if ( element ) {
            for (let item of list) {
                if ( item.tomselect ) {
                    item.tomselect.setValue(element[item.name]);
                }
                else {
                    jQuery(item).val(element[item.name]);
                }
            }
            self.editing_node = element;
        }
        else {
            var name = document.getElementsByName('name')[0].value;

            if ( self.editing_node.name != name && self.nodes.reduce(function(n, x) { return n + (x.name === name) }, 0) >= 1 || name === '' ) {
                var form  = jQuery('#lifeycycle-ui-edit-node');
                form.find('div.invalid-name').removeClass('hidden');
                return;
            }

            var values = {};
            for (let item of list) {
                if ( item.name === 'id' ) {
                    values.index = self.nodes.findIndex(function(x) { return x.id == item.value });
                }
                values[item.name] = item.value;
            }
            self.UpdateNodeModel(self.nodes[values.index], values);
            self.ExportAsConfiguration();
            self.Refresh();
        }
        nodeInput.toggle();
    }

    RenderLink() {
        var self = this;

        self.link = self.svg.selectAll(".link")
            .data(self.links);

        self.link.exit()
            .each(function () {
                var length = this.getTotalLength();
                var path = d3.select(this);
                path.attr("stroke-dasharray", length + " " + length)
                    .attr("stroke-dashoffset", 0)
                    .style("marker-end", "none")
                    .style("marker-start", "none")
                    .transition().duration(200 * self.animationFactor).ease(d3.easeLinear)
                    .attr("stroke-dashoffset", length)
                    .remove();
            });

        // Add new links and draw them
        var linkEnter = self.link.enter().append("g")
            .append("path")
            .attr("class", 'link')
            .style("marker-start", function(d) { return d.start ? 'url(#start-arrow)' : '' })
            .style("marker-end", function(d) { return d.end ? 'url(#end-arrow)' : '' })
            .attr("transform", "translate(0,0)")
            .on("click", function(d) {
                d3.event.stopPropagation();
                self.simulation.stop();
                self.ToggleLink(d);

                self.ExportAsConfiguration();

                self.Refresh();
            });
        self.link = linkEnter.merge(self.link);
        self.link
            .style("marker-start", function(d) { return d.start ? 'url(#start-arrow)' : '' })
            .style("marker-end", function(d) { return d.end ? 'url(#end-arrow)' : '' });
    }

    Refresh() {
        var self = this;

        const link_size = self.nodes.length > 10 ? 300 : self.nodes.length * 35;
        self.simulation
            .force("link", d3.forceLink().distance(link_size < 100 ? 200 : link_size).strength(0.2))

        self.simulation
            .nodes(self.nodes)
            .force("link")
            .links(self.links)
                    .id(function(d) { return d.id });

        self.RenderLink();
        self.RenderNode();

        jQuery('#lifeycycle-ui-edit-node div.alert').addClass('hidden');

        // This is our "cooling" factor
        self.simulation.alpha(0.05).restart();
    }

    SelectNode(node) {
        var self = this;

        self.Deselect();
        self.selected_node = node;

        d3.select(node)
            .classed('node-selected', true);
    }

    Deselect() {
        var self = this;

        if ( jQuery("#lifeycycle-ui-edit-node").is(':visible') ) {
            jQuery("#lifeycycle-ui-edit-node").toggle();
            jQuery("#lifeycycle-ui-edit-node div.alert").addClass('hidden');
        }

        self.editing_node = null;

        if (!self.selected_node) return;
        self.selected_node = null;

        self.svg.selectAll("foreignObject").remove();

        self.svg.selectAll('.node-selected')
            .classed('node-selected', false);
    }

    TruncateLabel(element, self) {
        var node = d3.select(element), textLength = node.node().getComputedTextLength(), text = node.text();
        var diameter = self.node_radius * 2 - textLength/4;

        while (textLength > diameter && text.length > 0) {
            text = text.slice(0, -1);
            node.text(text + '…');
            textLength = node.node().getComputedTextLength();
        }
    }

    Mousemove(d) {
        var self = this;
        if (!self.mousedown_node) return;

        self.drag_line.attr('d', 'M' + self.mousedown_node.x + ',' + self.mousedown_node.y + 'L' + d3.mouse(d)[0] + ',' + d3.mouse(d)[1]);

        self.Refresh();
    }

    Mouseup(d) {
        var self = this;

        if( self.mousedown_node ) {
                // needed by FF
                self.drag_line
                    .classed('hidden', true)
                    .style('marker-end', '');

            if ( d.id && d.id != self.mousedown_node.id ) {
                self.mouseup_node = d;
                self.simulation.stop();
                // add link to model
                self.AddLink(self.mousedown_node, self.mouseup_node);

                self.ExportAsConfiguration();
                self.Refresh();
            }
            self.svg.classed('ctrl', false);
        }
        // because :active only works in WebKit?
        self.svg.classed('active', false);
        self.ResetMouseVars();
    }

    Mousedown(d) {
        d3.event.preventDefault();
        d3.event.stopPropagation();
    }

    ResetMouseVars(){
        var self = this;

        self.mousedown_link  = null;
        self.mousedown_node  = null;
        self.mouseup_node    = null;
    }

    ToggleSimulation(){
        var self = this;
        self.enableSimulation = jQuery('#enableSimulation').is(":checked");

        const link_size = self.nodes.length > 10 ? 300 : self.nodes.length * 35;
        if ( !self.enableSimulation ) {
            self.simulation
                .force("link", null)
                .force("charge", null)
                .force("center", null)
                .force('collision', null);

            self.ExportAsConfiguration();
        }
        else {
            self.nodes.forEach(function(d) {
                d.fx = null, d.fy = null;
            });

            self.simulation
                .force("link", d3.forceLink().distance(link_size < 100 ? 200 : link_size).strength(0.2))
                .force("charge", d3.forceManyBody().strength(-200))
                .force("center", d3.forceCenter(self.width / 2, self.height / 2))
                .force('collision', d3.forceCollide().radius(function(d) {
                return d.radius
                }))
            self.simulation.force("link")
                .links(self.links)
                .id(function(d) { return d.id });
        }
        self.ExportAsConfiguration();
    }
}
