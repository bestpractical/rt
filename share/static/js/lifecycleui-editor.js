jQuery(function () {

    RT.Editor = class LifecycleEditor {
        constructor(container, name, config, ticketStatus) {
            self.container    = container;
            self.name         = name;
            self.config       = config;
            self.ticketStatus = ticketStatus;
            this.pointHandleRadius = 5;

            this.width = 809;
            this.height = 500;
            this.statusCircleRadius = 35;
            this.statusCircleRadiusFudge = 4; // required to give room for the arrowhead
            this.gridSize = 10;
            this.padding = this.statusCircleRadius * 2;
            this.animationFactor = 1; // bump this to 10 debug JS animations
        }

        initializeEditor(node, name, config, focusStatus) {
            var self = this;

            self.container = jQuery(node);
            self.svg = d3.select(node).select('svg');
            self.svg.on('click', function(){ self.defocus() } );
            self.transformContainer = self.svg.select('g.transform');
            self.transitionContainer = self.svg.select('g.transitions');
            self.statusContainer = self.svg.select('g.statuses');
            self.decorationContainer = self.svg.select('g.decorations');
            self._xScale = self.createScale(self.width, self.padding);
            self._yScale = self.createScale(self.height, self.padding);
            self._xScaleZero = self.createScale(self.width, 0);
            self._yScaleZero = self.createScale(self.height, 0);
            // zoom in a bit, but not too much
            var scale = self.svg.node().getBoundingClientRect().width / self.width;
            scale = scale ** .6;
            self._zoomIdentityScale = scale;
            self._zoomIdentity = self._currentZoom = d3.zoomIdentity.scale(self._zoomIdentityScale);
            RT.Lifecycle.name = name;
            self.lifecycle = RT.Lifecycle;
            self.lifecycle.initializeFromConfig(config);

            self.container.closest('form[name=ModifyLifecycle]').submit(function (e) {
                var config = self.lifecycle.exportAsConfiguration();
                var form = jQuery(this);
                var field = jQuery('<input type="hidden" name="Config">');
                field.val(JSON.stringify(config));
                form.append(field);

                return true;
            });
            self.container.on('contextmenu', function (e) {
                e.preventDefault();

                self.addNewStatus()
                self.renderDisplay();
            });
            d3.select("body").on("keydown", function () {
                if ( self._focusItem ) {
                    if ( d3.event.keyCode == 68 || d3.event.keyCode == 46 ) {
                        RT.Lifecycle.deleteStatus(self._focusItem._key);
                        self.renderDisplay();
                    }
                    self.defocus();
                }
            })
            self.renderDisplay();
        }

        clickedStatus(d) {
            self = this;

            let g          = d3.select(d3.select('#key-'+d._key)._groups[0][0]);
            let circle     = d3.select(g)._groups[0][0].select('circle');

            let current_val = d.name;
            d.name = '';
            // Defocus so that a 'd' key doesn't delete our node
            self.defocus();
            self.renderDisplay();

            var frm = g.append("foreignObject");
            var inp = frm
                .attr("x", Number(circle.attr('cx')) - Number(circle.attr('r')) / 2)
                .attr("y", Number(circle.attr('cy')) - Number(circle.attr('r')) / 4)
                .attr("width", 200)
                .attr("height", 20)
                .append("xhtml:form")
                .append("input")
                .attr("value", function() {
                    this.focus();

                    return current_val;
                })
            .attr("style", "width: 294px; background: transparent; border: none;")
            // make the form go away when you jump out (form looses focus) or hit ENTER:
            .on("blur", function() {
                if ( inp.node().value && inp.node().value != current_val ) {
                    d.name = inp.node().value;
                    RT.Lifecycle.updateStatusName( current_val, d.name );
                }
                else {
                    d.name = current_val;
                }

                // Note to self: frm.remove() will remove the entire <g> group! Remember the D3 selection logic!
                d3.select("foreignObject").remove();
                self.renderDisplay();
            })
            .on("keypress", function() {
                // IE fix
                if (!d3.event)
                    d3.event = window.event;

                var e = d3.event;
                if (e.keyCode == 13)
                {
                    if (typeof(e.cancelBubble) !== 'undefined') // IE
                        e.cancelBubble = true;
                    if (e.stopPropagation)
                        e.stopPropagation();
                    e.preventDefault();

                    if ( inp.node().value && inp.node().value != current_val ) {
                        d.name = inp.node().value;
                        RT.Lifecycle.updateStatusName( current_val, d.name );
                    }
                    else {
                        d.name = current_val;
                    }

                    d3.select("foreignObject").remove();
                    self.renderDisplay();
                }
            });
        }
        clickedTransition(d) {
            this.focusItem(d);
        }
        clickedDecoration(d) {
            this.focusItem(d);
        }
        viewportCenterPoint() {
            var rect = this.svg.node().getBoundingClientRect();
            var x = 0;
            var y = 0;
            return [this.xScaleInvert(x), this.yScaleInvert(y)];
        }
        addNewStatus() {
            var p = this.viewportCenterPoint();
            this.lifecycle.createStatus(p[0], p[1]);
        }

        _refreshLifecycleUI(refreshContent) {
            var self = this;
            var lifecycle = self.lifecycle;
            var inspector = self.inspector;
            var node = self.inspectorNode;
            var params = { lifecycle: lifecycle };
            var header = inspector.find('.header');
            var refreshedNode = header;
            if (refreshContent) {
                var type = node ? node._type : 'canvas';
                params[type] = node;
                inspector.find('.content').html(self.templates[type](params));
                refreshedNode = inspector;
            }
            refreshedNode.find(".toplevel").addClass('sf-menu sf-js-enabled sf-shadow').supersubs().superfish({ speed: 'fast' });
            refreshedNode.find(':checkbox[data-show-hide]').each(function () {
                var field = jQuery(this);
                var selector = field.data('show-hide');
                var flip = field.data('show-hide-flip') ? true : false;
                var toggle = function () {
                    if ((field.prop('checked') ? true : false) != flip) {
                        jQuery(selector).show();
                    }
                    else {
                        jQuery(selector).hide();
                    }
                };
                field.change(function (e) { toggle(); });
                toggle();
            });
            refreshedNode.find('option[data-show-hide]').each(function () {
                var option = jQuery(this);
                var field = option.closest('select');
                var selector = option.data('show-hide');
                var flip = option.data('show-hide-flip') ? true : false;
                var toggle = function () {
                    if ((field.val() == option.val()) != flip) {
                        jQuery(selector).show();
                    }
                    else {
                        jQuery(selector).hide();
                    }
                };
                field.change(function (e) { toggle(); });
                toggle();
            });
            refreshedNode.find(".combobox input.combo-text").each(function () {
                ComboBox_Load(this.id);
            });
        }

        renderTextDecorationBackgrounds(initial) {
            var self = this;
            var rects = self.decorationContainer.selectAll("rect.text-background")
                .data(self.lifecycle.decorations.text, function (d) { return d._key; });
            rects.exit()
                .classed("removing", true)
                .transition().duration(200 * self.animationFactor)
                .remove();
            var newRects = rects.enter().insert("rect", ":first-child")
                .attr("data-key", function (d) { return d._key; })
                .classed("text-background", true)
                .on("click", function (d) {
                    d3.event.stopPropagation();
                    self.clickedDecoration(d);
                })
                .call(function (rects) { self.didEnterTextDecorations(rects); });
            if (!initial) {
                newRects.style("opacity", 0.15)
                    .transition().duration(200 * self.animationFactor)
                    .style("opacity", 1)
                    .on("end", function () { d3.select(this).style("opacity", undefined); });
            }
        }

        didBeginDrag(d, node) { }
        didEndDrag(d, node) {
            d._dragging = false;
        }
        didDragItem(d, node) {
            if (this.inspectorNode && this.inspectorNode._key != d._key) {
                return;
            }

            var x = this.xScaleInvert(d3.event.x);
            var y = this.yScaleInvert(d3.event.y);
            if (this.xScale(x) == this.xScale(d.x) && this.yScale(y) == this.yScale(d.y)) {
                return;
            }
            if (!d._dragging) {
                this.lifecycle.beginDragging();
                d._dragging = true;
            }
            this.lifecycle.moveItem(d, x, y);
            this.renderDisplay();
        }
        _createDrag() {
            var self = this;
            return d3.drag()
                .subject(function (d) { return { x: self.xScale(d.x), y: self.yScale(d.y) }; })
                .on("start", function (d) { self.didBeginDrag(d, this); })
                .on("drag", function (d) { self.didDragItem(d, this); })
                .on("end", function (d) { self.didEndDrag(d, this); })
        }
        didEnterStatusNodes(statuses) {
            statuses.call(this._createDrag());
        }
        didEnterTextDecorations(labels) {
            labels.call(this._createDrag());
        }
        didEnterLineDecorations(lines) {
            lines.call(this._createDrag());
        }




        // View
        createScale(size, padding) {
            return d3.scaleLinear()
                .domain([0, 10000])
                .range([padding, size - padding]);
        }
        gridScale(v) { return Math.round(v / this.gridSize) * this.gridSize; }
        xScale(x) { return this.gridScale(this._xScale(x)); }
        yScale(y) { return this.gridScale(this._yScale(y)); }
        xScaleZero(x) { return this.gridScale(this._xScaleZero(x)); }
        yScaleZero(y) { return this.gridScale(this._yScaleZero(y)); }
        xScaleInvert(x) { return Math.floor(this._xScale.invert(x)); }
        yScaleInvert(y) { return Math.floor(this._yScale.invert(y)); }
        xScaleZeroInvert(x) { return Math.floor(this._xScaleZero.invert(x)); }
        yScaleZeroInvert(y) { return Math.floor(this._yScaleZero.invert(y)); }

        // Should we get rid of these
        didEnterTransitions(paths) { }
        didEnterPolygonDecorations(polygons) { }
        didEnterCircleDecorations(circles) { }
        didEnterLineDecorations(lines) { }

        renderStatusNodes(initial) {
            var self = this;
            var statuses = self.statusContainer.selectAll("g")
                .data(self.lifecycle.statusObjects(), function (d) { return d._key; });
            var exitStatuses = statuses.exit()
                .classed("removing", true)
                .transition().duration(200 * self.animationFactor)
                .remove();
            exitStatuses.select('circle')
                .attr("r", self.statusCircleRadius * .8);
            var newStatuses = statuses.enter().append("g")
                .attr("data-key", function (d) { return d._key; })
                .attr("id", function (d) { return 'key-'+d._key; })
                .call(function (statuses) { self.didEnterStatusNodes(statuses); });
            newStatuses.append("circle")
                .attr("r", initial ? self.statusCircleRadius : self.statusCircleRadius * .8)
                .on("click", function (d) {
                    d3.event.stopPropagation();

                    self.focusItem(d)
                })
            newStatuses.append("text")
                .attr("r", initial ? self.statusCircleRadius : self.statusCircleRadius * .8)
                .on("click", function (d) {
                    d3.event.stopPropagation();

                    self.clickedStatus(d);
                })
            if (!initial) {
                newStatuses.transition().duration(200 * self.animationFactor)
                    .select("circle")
                    .attr("r", self.statusCircleRadius);
            }
            var allStatuses = newStatuses.merge(statuses)
                .classed("focus", function (d) { return self.isFocused(d); })
                .classed("focus-from", function (d) { return self.isFocusedTransition(d, true); })
                .classed("focus-to", function (d) { return self.isFocusedTransition(d, false); });
            allStatuses.select("circle")
                .attr("cx", function (d) { return self.xScale(d.x); })
                .attr("cy", function (d) { return self.yScale(d.y); })
                .attr("fill", function (d) { return d.color; });
            allStatuses.select("text")
                .attr("x", function (d) { return self.xScale(d.x); })
                .attr("y", function (d) { return self.yScale(d.y); })
                .attr("fill", function (d) { return d3.hsl(d.color).l > 0.35 ? '#000' : '#fff'; })
                .text(function (d) { return d.name; }).each(function () { self.truncateLabel(this); });
        }
        truncateLabel(element) {
            var node = d3.select(element), textLength = node.node().getComputedTextLength(), text = node.text();
            while (textLength > this.statusCircleRadius * 1.8 && text.length > 0) {
                text = text.slice(0, -1);
                node.text(text + '…');
                textLength = node.node().getComputedTextLength();
            }
        }
        transitionArc(d) {
            // c* variables are circle centers
            // a* variables are for the arc path which is from circle edge to circle edge
            var from = this.lifecycle.statusObjectForName(d.from), to = this.lifecycle.statusObjectForName(d.to), cx0 = this.xScale(from.x), cx1 = this.xScale(to.x), cy0 = this.yScale(from.y), cy1 = this.yScale(to.y), cdx = cx1 - cx0, cdy = cy1 - cy0;
            // the circles on top of each other would calculate atan2(0,0) which is
            // undefined and a little nonsensical
            if (cdx == 0 && cdy == 0) {
                return null;
            }
            var theta = Math.atan2(cdy, cdx), r = this.statusCircleRadius, ax0 = cx0 + r * Math.cos(theta), ay0 = cy0 + r * Math.sin(theta), ax1 = cx1 - (r + this.statusCircleRadiusFudge) * Math.cos(theta), ay1 = cy1 - (r + this.statusCircleRadiusFudge) * Math.sin(theta), dr = Math.abs((ax1 - ax0) * 4) + Math.abs((ay1 - ay0) * 4);
            return "M" + ax0 + "," + ay0 + " A" + dr + "," + dr + " 0 0,1 " + ax1 + "," + ay1;
        }
        renderTransitions(initial) {
            var self = this;
            var paths = self.transitionContainer.selectAll("path")
                .data(self.lifecycle.transitions, function (d) { return d._key; });
            paths.exit().classed("removing", true)
                .each(function (d) {
                    var length = this.getTotalLength();
                    var path = d3.select(this);
                    path.attr("stroke-dasharray", length + " " + length)
                        .attr("stroke-dashoffset", 0)
                        .style("marker-end", "none")
                        .transition().duration(200 * self.animationFactor).ease(d3.easeLinear)
                        .attr("stroke-dashoffset", length)
                        .remove();
                });
            var newPaths = paths.enter().append("path")
                .attr("data-key", function (d) { return d._key; })
                .on("click", function (d) {
                    d3.event.stopPropagation();
                    self.clickedTransition(d);
                })
                .call(function (paths) { self.didEnterTransitions(paths); });
            newPaths.merge(paths)
                .attr("d", function (d) { return self.transitionArc(d); })
                .classed("dashed", function (d) { return d.style == 'dashed'; })
                .classed("dotted", function (d) { return d.style == 'dotted'; })
                .classed("focus", function (d) { return self.isFocused(d); })
                .classed("focus-from", function (d) { return self.isFocusedTransition(d, true); })
                .classed("focus-to", function (d) { return self.isFocusedTransition(d, false); });
            if (!initial) {
                newPaths.each(function (d) {
                    var length = this.getTotalLength();
                    var path = d3.select(this);
                    path.attr("stroke-dasharray", length + " " + length)
                        .attr("stroke-dashoffset", length)
                        .style("marker-end", "none")
                        .transition().duration(200 * self.animationFactor).ease(d3.easeLinear)
                        .attr("stroke-dashoffset", 0)
                        .on("end", function () {
                            d3.select(this)
                                .attr("stroke-dasharray", undefined)
                                .attr("stroke-offset", undefined)
                                .style("marker-end", undefined);
                        });
                });
            }
        }
        _wrapTextDecoration(node, text) {
            if (node.attr('data-text') == text) {
                return;
            }
            var lines = text.split(/\n/), lineHeight = 1.1;
            if (node.attr('data-text')) {
                node.selectAll("*").remove();
            }
            node.attr('data-text', text);
            for (var i = 0; i < lines.length; ++i) {
                node.append("tspan").attr("dy", (i + 1) * lineHeight + "em").text(lines[i]);
            }
        }
        renderTextDecorations(initial) {
            var self = this;
            var labels = self.decorationContainer.selectAll("text")
                .data(self.lifecycle.decorations.text, function (d) { return d._key; });
            labels.exit()
                .classed("removing", true)
                .transition().duration(200 * self.animationFactor)
                .remove();
            var newLabels = labels.enter().append("text")
                .attr("data-key", function (d) { return d._key; })
                .on("click", function (d) {
                    d3.event.stopPropagation();
                    self.clickedDecoration(d);
                })
                .call(function (labels) { self.didEnterTextDecorations(labels); });
            if (!initial) {
                newLabels.style("opacity", 0.15)
                    .transition().duration(200 * self.animationFactor)
                    .style("opacity", 1)
                    .on("end", function () { d3.select(this).style("opacity", undefined); });
            }
            newLabels.merge(labels)
                .attr("x", function (d) { return self.xScale(d.x); })
                .attr("y", function (d) { return self.yScale(d.y); })
                .classed("bold", function (d) { return d.bold; })
                .classed("italic", function (d) { return d.italic; })
                .classed("focus", function (d) { return self.isFocused(d); })
                .each(function (d) { self._wrapTextDecoration(d3.select(this), d.text); })
                .selectAll("tspan")
                .attr("x", function (d) { return self.xScale(d.x); })
                .attr("y", function (d) { return self.yScale(d.y); });
        }
        renderPolygonDecorations(initial) {
            var self = this;
            var polygons = self.decorationContainer.selectAll("polygon")
                .data(self.lifecycle.decorations.polygon, function (d) { return d._key; });
            polygons.exit()
                .classed("removing", true)
                .transition().duration(200 * self.animationFactor)
                .remove();
            var newPolygons = polygons.enter().append("polygon")
                .attr("data-key", function (d) { return d._key; })
                .on("click", function (d) {
                    d3.event.stopPropagation();
                    self.clickedDecoration(d);
                })
                .call(function (polygons) { self.didEnterPolygonDecorations(polygons); });
            if (!initial) {
                newPolygons.style("opacity", 0.15)
                    .transition().duration(200 * self.animationFactor)
                    .style("opacity", 1)
                    .on("end", function () { d3.select(this).style("opacity", undefined); });
            }
            newPolygons.merge(polygons)
                .attr("stroke", function (d) { return d.renderStroke ? d.stroke : 'none'; })
                .classed("dashed", function (d) { return d.strokeStyle == 'dashed'; })
                .classed("dotted", function (d) { return d.strokeStyle == 'dotted'; })
                .attr("fill", function (d) { return d.renderFill ? d.fill : 'none'; })
                .attr("transform", function (d) { return "translate(" + self.xScale(d.x) + ", " + self.yScale(d.y) + ")"; })
                .attr("points", function (d) {
                    return jQuery.map(d.points, function (p) {
                        return [self.xScaleZero(p.x), self.yScaleZero(p.y)].join(",");
                    }).join(" ");
                })
                .classed("focus", function (d) { return self.isFocused(d); });
        }
        renderCircleDecorations(initial) {
            var self = this;
            var circles = self.decorationContainer.selectAll("circle.decoration")
                .data(self.lifecycle.decorations.circle, function (d) { return d._key; });
            circles.exit()
                .classed("removing", true)
                .transition().duration(200 * self.animationFactor)
                .remove();
            var newCircles = circles.enter().append("circle")
                .classed("decoration", true)
                .attr("data-key", function (d) { return d._key; })
                .on("click", function (d) {
                    d3.event.stopPropagation();
                    self.clickedDecoration(d);
                })
                .call(function (circles) { self.didEnterCircleDecorations(circles); });
            if (!initial) {
                newCircles.style("opacity", 0.15)
                    .transition().duration(200 * self.animationFactor)
                    .style("opacity", 1)
                    .on("end", function () { d3.select(this).style("opacity", undefined); });
            }
            newCircles.merge(circles)
                .attr("stroke", function (d) { return d.renderStroke ? d.stroke : 'none'; })
                .classed("dashed", function (d) { return d.strokeStyle == 'dashed'; })
                .classed("dotted", function (d) { return d.strokeStyle == 'dotted'; })
                .attr("fill", function (d) { return d.renderFill ? d.fill : 'none'; })
                .attr("cx", function (d) { return self.xScale(d.x); })
                .attr("cy", function (d) { return self.yScale(d.y); })
                .attr("r", function (d) { return d.r; })
                .classed("focus", function (d) { return self.isFocused(d); });
        }
        renderLineDecorations(initial) {
            var self = this;
            var lines = self.decorationContainer.selectAll("line")
                .data(self.lifecycle.decorations.line, function (d) { return d._key; });
            lines.exit()
                .classed("removing", true)
                .transition().duration(200 * self.animationFactor)
                .remove();
            var newLines = lines.enter().append("line")
                .attr("data-key", function (d) { return d._key; })
                .on("click", function (d) {
                    d3.event.stopPropagation();
                    self.clickedDecoration(d);
                })
                .call(function (lines) { self.didEnterLineDecorations(lines); });
            if (!initial) {
                newLines.each(function (d) {
                    var length = Math.sqrt((d.points[1].x - d.points[0].x) ** 2 + (d.points[1].y - d.points[0].y) ** 2);
                    var path = d3.select(this);
                    path.attr("stroke-dasharray", length + " " + length)
                        .attr("stroke-dashoffset", length)
                        .style("marker-start", "none")
                        .style("marker-end", "none")
                        .transition().duration(200 * self.animationFactor).ease(d3.easeLinear)
                        .attr("stroke-dashoffset", 0)
                        .on("end", function () {
                            d3.select(this)
                                .attr("stroke-dasharray", undefined)
                                .attr("stroke-offset", undefined)
                                .style("marker-start", undefined)
                                .style("marker-end", undefined);
                        });
                });
            }
            newLines.merge(lines)
                .classed("dashed", function (d) { return d.style == 'dashed'; })
                .classed("dotted", function (d) { return d.style == 'dotted'; })
                .attr("transform", function (d) { return "translate(" + self.xScale(d.x) + ", " + self.yScale(d.y) + ")"; })
                .attr("x1", function (d) { return self.xScaleZero(d.points[0].x); })
                .attr("y1", function (d) { return self.yScaleZero(d.points[0].y); })
                .attr("x2", function (d) { return self.xScaleZero(d.points[1].x); })
                .attr("y2", function (d) { return self.yScaleZero(d.points[1].y); })
                .classed("focus", function (d) { return self.isFocused(d); })
                .attr("marker-start", function (d) { return d.startMarker == 'none' ? undefined : "url(#line_marker_" + d.startMarker + ")"; })
                .attr("marker-end", function (d) { return d.endMarker == 'none' ? undefined : "url(#line_marker_" + d.endMarker + ")"; });
        }
        renderDecorations(initial) {
            this.renderPolygonDecorations(initial);
            this.renderCircleDecorations(initial);
            this.renderLineDecorations(initial);
            this.renderTextDecorations(initial);
        }
        renderDisplay(initial) {
            this.renderTransitions(initial);
            this.renderStatusNodes(initial);
            this.renderDecorations(initial);
        }
        defocus() {
            if ( this._focusItem ) {
                // TODO Make this abstracted
                let g          = d3.select(d3.select('#key-'+this._focusItem._key)._groups[0][0]);
                let circle     = d3.select(g)._groups[0][0].select('circle');

                circle.classed("node-selected", false);
            }
            this.svg.classed("has-focus", false)
                .attr('data-focus-type', undefined);
            this._focusItem = null;
        }
        focusItem(d) {
            this.defocus();
            this._focusItem = d;

            let g          = d3.select(d3.select('#key-'+d._key)._groups[0][0]);
            let circle     = d3.select(g)._groups[0][0].select('circle');

            circle.classed("node-selected", true);
        }
        focusOnStatus(statusName, center, animated) {
            if (!statusName) {
                return;
            }
            var meta = this.lifecycle.statusObjectForName(statusName);
            this.focusItem(meta);
            if (center) {
                this.centerOnItem(meta, animated);
            }
        }
        isFocused(d) {
            if (!this._focusItem) {
                return false;
            }
            return this._focusItem._key == d._key;
        }
        isFocusedTransition(d, isFrom) {
            if (!this._focusItem) {
                return false;
            }
            if (d._type == 'status') {
                if (this._focusItem._type == 'status') {
                    if (isFrom) {
                        return this.lifecycle.hasTransition(d.name, this._focusItem.name);
                    }
                    else {
                        return this.lifecycle.hasTransition(this._focusItem.name, d.name);
                    }
                }
                else if (this._focusItem._type == 'transition') {
                    if (isFrom) {
                        return this._focusItem.from == d.name;
                    }
                    else {
                        return this._focusItem.to == d.name;
                    }
                }
            }
            else if (d._type == 'transition') {
                if (this._focusItem._type == 'status') {
                    if (isFrom) {
                        return d.to == this._focusItem.name;
                    }
                    else {
                        return d.from == this._focusItem.name;
                    }
                }
            }
            return false;
        }
    }

});
