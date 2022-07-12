jQuery(function () {
    RT.LifecycleViewer = class LifecycleViewer {
        constructor(container, config, layout) {
            this.links_seq = 0;
            this.nodes_seq = 0;
            // Here we store the '' => transitions
            this.create_nodes = [];

            var self              = this;
            self.width            = 900;
            self.height           = 350;
            self.node_radius      = 35;
            self.layout           = layout;
            self.enableSimulation = 1;
            self.current_status   = container.getAttribute('data-status');
            self.object_id        = container.getAttribute('data-id');
            self.container        = container;

            self.active_statuses  = config.transitions[self.current_status];
            if ( self.layout ) {
                self.enableSimulation = 0;
            }

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

            self.NodesFromConfig(config);
            self.nodes.forEach(function(source) {
                self.LinksForNodeFromConfig(source.name).forEach(function(targetName) {
                    // Get our target node
                    var target = self.nodes.filter(function(source) { return source.name === targetName; })[0];
                    if (!target) { return };

                    if ( source.id < target.id ) {
                        self.links.push({
                            id: ++self.links_seq,
                            source: source,
                            target: target,
                            start: false,
                            end: true,
                            descriptions: {
                                [source.name + ' -> ' + target.name]: self.config.descriptions[source.name + ' -> ' + target.name],
                                [target.name + ' -> ' + source.name]: self.config.descriptions[target.name + ' -> ' + source.name],
                            }
                        });
                        return;
                    }
                    var link = self.links.filter(function(l) { return (l.source === target && l.target === source); })[0];
                    if (link) {
                        link.start = true;
                    } else {
                        self.links.push({
                            id: ++self.links_seq,
                            source: source,
                            target: target,
                            start: false,
                            end: true,
                            descriptions: {
                                [source.name + ' -> ' + target.name]: self.config.descriptions[source.name + ' -> ' + target.name],
                                [target.name + ' -> ' + source.name]: self.config.descriptions[target.name + ' -> ' + source.name],
                            }
                        });
                    }
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
        }

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
                .attr('class', 'marker');

            self.svg.append('svg:defs').append('svg:marker')
                .attr('id', 'end-arrow-active')
                .attr('viewBox', '0 -5 10 10')
                .attr('refX', 6)
                .attr('markerWidth', 5)
                .attr('markerHeight', 5)
                .attr('orient', 'auto')
                .append('svg:path')
                .attr('d', 'M0,-5L10,0L0,5')
                .attr('class', 'marker marker-active');

            self.svg.append('svg:defs').append('svg:marker')
                .attr('id', 'start-arrow')
                .attr('viewBox', '0 -5 10 10')
                .attr('refX', 6)
                .attr('markerWidth', 5)
                .attr('markerHeight', 5)
                .attr('orient', 'auto')
                .append('svg:path')
                .attr('d', 'M10,-5L0,0L10,5')
                .attr('class', 'marker');

            self.svg.append('svg:defs').append('svg:marker')
                .attr('id', 'start-arrow-active')
                .attr('viewBox', '0 -5 10 10')
                .attr('refX', 6)
                .attr('markerWidth', 5)
                .attr('markerHeight', 5)
                .attr('orient', 'auto')
                .append('svg:path')
                .attr('d', 'M10,-5L0,0L10,5')
                .attr('class', 'marker marker-active');

            self.svg
                .on('click', function () {
                    d3.event.preventDefault();
                    d3.event.stopPropagation();

                    hide(jQuery('div.lifecycle-ui-status-menu'));
                })
                .on('contextmenu', function() { d3.event.preventDefault(); });
        }

        // Generate nodes from config
        NodesFromConfig(config) {
            var self = this;
            self.nodes = [];
            config.descriptions ||= {};

            jQuery.each(['initial', 'active', 'inactive'], function (i, type) {
                if ( config[type] ) {
                    config[type].forEach(function(element) {
                        self.nodes = self.nodes.concat({
                            id: ++self.nodes_seq,
                            name: element,
                            type: type,
                            description: config.descriptions[element],
                            transition_description: config.descriptions[self.current_status + ' -> ' + element]
                        });
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

        RenderNode() {
            var self = this;

            self.node = self.svg.selectAll(".node")
                .data(self.nodes.filter(function(d) { return d.id >= 0 }));

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
                .attr("class", function(d) {
                    let classes = ['status', 'status-type-' + d.type];

                    if ( d.name === self.current_status ) {
                        classes.push('status-current');
                    }

                    if (self.active_statuses.includes(d.name)) {
                        classes.push('status-active');
                    }
                    return classes.join(' ');
                })
                .on("click", function(d) {
                    d3.event.stopPropagation();
                    d3.event.preventDefault();
                    if (self.active_statuses.includes(d.name)) {
                        if ( self.config.type === 'asset' ) {
                            location.href = RT.Config.WebPath + '/Asset/Modify.html?Update=1;DisplayAfter=1;Status=' + d.name + ';id=' + self.object_id;
                        }
                        else {
                           location.href = RT.Config.WebPath + '/Ticket/Update.html?DefaultStatus=' + d.name + ';id=' + self.object_id;
                        }
                    }
                })
                .on('contextmenu', function(d) {
                    hide(jQuery('div.lifecycle-ui-status-menu[data-status!=' + d.name + ']'));
                    if (!self.active_statuses.includes(d.name)) return;

                    let menu = jQuery('div.lifecycle-ui-status-menu[data-status=' + d.name + ']');
                    menu.css('left', d3.event.pageX).css('top', d3.event.pageY);

                    if ( !menu.find('.toplevel').hasClass('sf-menu') ) {
                        menu.find('.toplevel').addClass('sf-menu sf-vertical sf-js-enabled sf-shadow').superfish({ speed: 'fast' });
                    }
                    show(menu);
                })
                .on('mouseover', function(d) {
                    if ( d.transition_description ) {
                        jQuery('#lifecycle-ui-tooltip').css('left', d3.event.pageX).css('top', d3.event.pageY);
                        jQuery('#lifecycle-ui-tooltip').attr('data-original-title', d.transition_description);
                        jQuery('#lifecycle-ui-tooltip').tooltip('show');
                    }
                })
                .on('mouseout', function() {
                    jQuery('#lifecycle-ui-tooltip').tooltip('hide');
                });

            self.node.select("text")
                .text(function(d) { return d.name; })
                .each(function () { self.TruncateLabel(this, self); })
                .attr("x", function(d) {
                    var node = d3.select(this), textLength = node.node().getComputedTextLength();
                    if ( textLength > self.node_radius*2 ) textLength = self.node_radius*2;
                    return -textLength/2+5; // +5 visually makes text in the center.
                })
                .attr("y", 0)
                .style("font-size", "10px");

            self.node.select('text').on('mouseover', function(d) {
                if ( d.description ) {
                    jQuery('#lifecycle-ui-tooltip').css('left', d3.event.pageX).css('top', d3.event.pageY);
                    jQuery('#lifecycle-ui-tooltip').attr('data-original-title', d.description);
                    jQuery('#lifecycle-ui-tooltip').tooltip('show');
                }
            })
            .on('mouseout', function() {
                jQuery('#lifecycle-ui-tooltip').tooltip('hide');
            });
        }

        RenderLink() {
            var self = this;

            self.link = self.svg.selectAll(".link")
                .data(self.links);

            // Add new links and draw them
            var linkEnter = self.link.enter().append("g")
                .append("path")
                .attr("class", 'link')
                .style("marker-start", function(d) { return d.start ? 'url(#start-arrow)' : '' })
                .style("marker-end", function(d) { return d.end ? 'url(#end-arrow)' : '' })
                .attr("transform", "translate(0,0)");
            self.link = linkEnter.merge(self.link);

            self.link.filter(function(d) {
                return d.source.name == self.current_status && self.active_statuses.includes(d.target.name)
            }).style("marker-end", function(d) {
                return d.end ? 'url(#end-arrow-active)' : ''
            }).attr('class', 'link link-active');

            self.link.filter(function(d) {
                return d.target.name == self.current_status && self.active_statuses.includes(d.source.name)
            }).style("marker-start", function(d) {
                return d.end ? 'url(#start-arrow-active)' : ''
            }).attr('class', 'link link-active');

            self.link.on('mouseover', function(d) {
                let descriptions = [];
                let item = d.source.name + ' -> ' + d.target.name;
                let reverse_item = d.target.name + ' -> ' + d.source.name;
                // if it's bidirectional
                if ( d.start ) {
                    for ( let i of [item, reverse_item] ) {
                        if ( d.descriptions[i] ) {
                            descriptions.push(i + ': ' + d.descriptions[i]);
                        }
                    }
                }
                else {
                    if ( d.descriptions[item] ) {
                        descriptions.push(d.descriptions[item]);
                    }
                }

                if ( descriptions.length ) {
                    jQuery('#lifecycle-ui-tooltip').css('left', d3.event.pageX).css('top', d3.event.pageY);
                    jQuery('#lifecycle-ui-tooltip').attr('data-original-title', descriptions.join('<br>'));
                    jQuery('#lifecycle-ui-tooltip').tooltip('show');
                }
            })
            .on('mouseout', function() {
                jQuery('#lifecycle-ui-tooltip').tooltip('hide');
            })
            .on("click", function(d) {
                d3.event.stopPropagation();
                d3.event.preventDefault();
                let status;
                if ( d.source.name === self.current_status ) {
                    status = d.target.name;
                }
                else if ( d.target.name === self.current_status ) {
                    status = d.source.name;
                }

                if (status && self.active_statuses.includes(status)) {
                    if ( self.config.type === 'asset' ) {
                        location.href = RT.Config.WebPath + '/Asset/Modify.html?Update=1;DisplayAfter=1;Status=' + status + ';id=' + self.object_id;
                    }
                    else {
                       location.href = RT.Config.WebPath + '/Ticket/Update.html?DefaultStatus=' + status + ';id=' + self.object_id;
                    }
                }
            });
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
    }
});
