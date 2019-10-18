jQuery(function () {

    RT.Editor = class LifecycleEditor extends RT.LifecycleViewer {
        constructor(container, name, config, ticketStatus) {
            super( container, name, config, ticketStatus );

            this.pointHandleRadius = 5;
        }

        initializeEditor(node, name, config, focusStatus) {
            var self = this;
            self.initializeViewer(node, name, config, focusStatus);
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
        }

        clickedStatus(d, p_el) {
            self = this;

            var circle = d3.select(p_el).select('circle')._groups[0][0];

            let current_val = d.name;
            d.name = '';
            self.renderDisplay();

            var frm = d3.select(p_el).append("foreignObject");

            var circle_d3 = d3.select(circle);
            var inp = frm
                .attr("x", circle_d3.attr('cx') - circle_d3.attr('r') + 10)
                .attr("y", circle_d3.attr('cy') - circle_d3.attr('r') / 2 + 4)
                .attr("width", circle_d3.attr('r') * 2)
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
            var x = (rect.width / 2 - this._currentZoom.x) / this._currentZoom.k;
            var y = (rect.height / 2 - this._currentZoom.y) / this._currentZoom.k;
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

        // add rects under text decorations for highlighting
        // renderTextDecorations(initial) {
        //     Super.prototype.renderTextDecorations.call(this, initial);
        //     var self = this;
        //     self.renderTextDecorationBackgrounds(initial);
        // }
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
            newRects.merge(rects)
                .classed("focus", function (d) { return self.isFocused(d); })
                .each(function (d) {
                    var rect = d3.select(this);
                    var label = self.decorationContainer.select("text[data-key='" + d._key + "']");
                    var bbox = label.node().getBoundingClientRect();
                    var width = bbox.width / self._currentZoom.k;
                    var height = bbox.height / self._currentZoom.k;
                    var padding = 5 / self._currentZoom.k;
                    rect.attr("x", self.xScale(d.x) - padding)
                        .attr("y", self.yScale(d.y) - padding)
                        .attr("width", width + padding * 2)
                        .attr("height", height + padding * 2);
                });
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
                .on("end", function (d) { self.didEndDrag(d, this); });
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
    };
});
