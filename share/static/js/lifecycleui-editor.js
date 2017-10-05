jQuery(function () {
    var Super = RT.LifecycleViewer;

    function Editor (container) {
        Super.call(this);
        this.pointHandleRadius = 5;
    };
    Editor.prototype = Object.create(Super.prototype);

    Editor.prototype._initializeTemplates = function (container) {
        var self = this;

        Handlebars.registerHelper('select', function(value, options) {
            var node = jQuery('<select />').html( options.fn(this) );
            node.find('[value="' + value + '"]').attr({'selected':'selected'});
            return node.html();
        });

        Handlebars.registerHelper('canAddTransition', function(fromStatus, toStatus, lifecycle) {
            if (fromStatus == toStatus) {
                return false;
            }
            return !lifecycle.hasTransition(fromStatus, toStatus);
        });

        Handlebars.registerHelper('canSelectTransition', function(fromStatus, toStatus, lifecycle) {
            return lifecycle.hasTransition(fromStatus, toStatus);
        });

        Handlebars.registerHelper('selectedRights', function(lifecycle) {
            return lifecycle.selectedRights();
        });

        Handlebars.registerHelper('truncate', function(text) {
            if (text.length > 15) {
                text = text.substr(0, 15) + '…';
            }
            return text;
        });

        var templates = {};
        self.container.find('script.lifecycle-inspector-template').each(function () {
            var type = jQuery(this).data('type');
            var template = jQuery(this).html();
            var fn = Handlebars.compile(template);
            templates[type] = fn;
            Handlebars.registerPartial('lifecycleui_' + type, fn);
        });
        return templates;
    };

    Editor.prototype._refreshInspector = function (refreshContent) {
        var self = this;
        var lifecycle = self.lifecycle;
        var inspector = self.inspector;
        var node = self.inspectorNode;

        var params = { lifecycle: lifecycle };

        var header = inspector.find('.header');
        header.html(self.templates.header(params));

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
                } else {
                    jQuery(selector).hide();
                }
            }
            field.change(function (e) { toggle() });
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
                } else {
                    jQuery(selector).hide();
                }
            }
            field.change(function (e) { toggle() });
            toggle();
        });

        refreshedNode.find(".combobox input.combo-text").each(function () {
            ComboBox_Load(this.id);
        });
    };

    Editor.prototype.setInspectorContent = function (node) {
        this.inspectorNode = node;
        this._refreshInspector(true);
    };

    Editor.prototype.bindInspectorEvents = function () {
        var self = this;
        var lifecycle = self.lifecycle;
        var inspector = self.inspector;

        inspector.on('change', ':input', function () {
            var node = jQuery(this);
            var value;

            if (node.is('.combo-list')) {
                value = node.val();
                node = node.closest('.combobox').find('.combo-text');
            }
            else if (node.is(':checkbox')) {
                value = node[0].checked;
            }
            else {
                value = node.val();
            }

            var field = node.attr('name');

            var action = node.closest('li.action');
            if (action.length) {
                var action = lifecycle.itemForKey(action.data('key'));
                lifecycle.updateItem(action, field, value);
            }
            else if (inspector.find('.canvas').length) {
                lifecycle.update(field, value);
            }
            else {
                lifecycle.updateItem(self.inspectorNode, field, value);
            }
            self.renderDisplay();
        });

        inspector.on('click', 'button.change-color', function (e) {
            e.preventDefault();
            var inputContainer = jQuery(this).closest('.color-control');
            var field = inputContainer.data('field');
            var pickerContainer = jQuery('tr.color-widget[data-field="'+field+'"]');
            var picker = pickerContainer.find('.color-picker');
            jQuery(this).remove();

            var skipUpdateCallback = 0;
            var farb = jQuery.farbtastic(picker, function (newColor) {
                if (skipUpdateCallback) {
                    return;
                }
                inputContainer.find('.current-color').val(newColor);
                lifecycle.updateItem(self.inspectorNode, field, newColor, true);
                self.renderDisplay();
            });
            farb.setColor(self.inspectorNode[field]);

            // see farbtastic's implementation
            jQuery('*', picker).mousedown(function () {
                self.lifecycle.beginChangingColor();
            });

            var input = jQuery('<input class="current-color" size=8 maxlength=7>');
            inputContainer.find('.current-color').replaceWith(input);
            input.on('input', function () {
                var newColor = input.val();
                if (newColor.match(/^#[a-fA-F0-9]{6}$/)) {
                    skipUpdateCallback = 1;
                    farb.setColor(newColor);
                    skipUpdateCallback = 0;

                    lifecycle.updateItem(self.inspectorNode, field, newColor);
                    self.renderDisplay();
                }
            });
            input.val(self.inspectorNode[field]);
        });

        inspector.on('click', 'button.delete', function (e) {
            e.preventDefault();

            var action = jQuery(this).closest('li.action');
            if (action.length) {
                lifecycle.deleteActionForTransition(self.inspectorNode, action.data('key'));
                action.slideUp(200, function () { jQuery(this).remove() });
            }
            else {
                lifecycle.deleteItemForKey(self.inspectorNode._key);
                self.defocus();
            }
        });

        inspector.on('click', 'button.clone', function (e) {
            e.preventDefault();
            var p = self.viewportCenterPoint();
            var clone = self.lifecycle.cloneItem(self.inspectorNode, p[0], p[1]);
            self.focusItem(clone);
        });

        inspector.on('click', 'button.add-action', function (e) {
            e.preventDefault();
            var action = lifecycle.createActionForTransition(self.inspectorNode);

            var params = {action:action, lifecycle:lifecycle};
            var html = self.templates.action(params);
            jQuery(html).appendTo(inspector.find('ul.actions'))
                        .hide()
                        .slideDown(200);
        });

        inspector.on('click', 'a.add-transition', function (e) {
            e.preventDefault();
            var button = jQuery(this);
            var fromStatus = button.data('from');
            var toStatus   = button.data('to');

            lifecycle.addTransition(fromStatus, toStatus);

            button.closest('li').addClass('hidden');

            inspector.find('a.select-transition[data-from="'+fromStatus+'"][data-to="'+toStatus+'"]').closest('li').removeClass('hidden');

            self.renderDisplay();
        });

        inspector.on('click', 'a.select-status', function (e) {
            e.preventDefault();
            var statusName = jQuery(this).data('name');
            var d = self.lifecycle.statusObjectForName(statusName);
            self.focusItem(d);
        });

        inspector.on('mouseenter', 'a.select-status', function (e) {
            var statusName = jQuery(this).data('name');
            var d = self.lifecycle.statusObjectForName(statusName);
            self.hoverItem(d);
        });

        inspector.on('mouseenter', 'a.add-transition', function (e) {
            var statusName = jQuery(this).data('to');
            var d = self.lifecycle.statusObjectForName(statusName);
            self.hoverItem(d);
        });

        inspector.on('click', 'a.select-transition', function (e) {
            e.preventDefault();
            var button = jQuery(this);
            var fromStatus = button.data('from');
            var toStatus   = button.data('to');

            var d = self.lifecycle.hasTransition(fromStatus, toStatus);
            self.focusItem(d);
        });

        inspector.on('mouseenter', 'a.select-transition', function (e) {
            var button = jQuery(this);
            var fromStatus = button.data('from');
            var toStatus   = button.data('to');

            var d = self.lifecycle.hasTransition(fromStatus, toStatus);
            self.hoverItem(d);
        });

        inspector.on('click', 'a.select-decoration', function (e) {
            e.preventDefault();
            var key = jQuery(this).data('key');
            var d = self.lifecycle.itemForKey(key);
            self.focusItem(d);
        });

        inspector.on('mouseenter', 'a.select-decoration', function (e) {
            var key = jQuery(this).data('key');
            var d = self.lifecycle.itemForKey(key);
            self.hoverItem(d);
        });

        inspector.on('mouseleave', 'a.select-status, a.add-transition, a.select-transition, a.select-decoration', function () {
            self.hoverItem(null);
        });

        inspector.on('click', '.add-status', function (e) {
            e.preventDefault();
            self.addNewStatus();
        });

        inspector.on('click', '.add-text', function (e) {
            e.preventDefault();
            self.addNewTextDecoration();
        });

        inspector.on('click', '.add-polygon', function (e) {
            e.preventDefault();
            self.addNewPolygonDecoration(jQuery(this).data('type'));
        });

        inspector.on('click', '.add-circle', function (e) {
            e.preventDefault();
            self.addNewCircleDecoration();
        });

        inspector.on('click', '.add-line', function (e) {
            e.preventDefault();
            self.addNewLineDecoration();
        });

        inspector.on('click', 'button.undo', function (e) {
            e.preventDefault();
            var frame = self.lifecycle.undo();
            var uiState = frame[1];

            if (uiState.focusKey) {
                var node = self.lifecycle.itemForKey(uiState.focusKey);
                self.focusItem(node);
            }
            else {
                self.defocus();
            }
        });

        inspector.on('click', 'button.redo', function (e) {
            e.preventDefault();
            var frame = self.lifecycle.redo();
            var uiState = frame[1];

            if (uiState.focusKey) {
                var node = self.lifecycle.itemForKey(uiState.focusKey);
                self.focusItem(node);
            }
            else {
                self.defocus();
            }
        });

        inspector.on('focus', 'textarea[name=text]', function (e) {
            if (jQuery(this).val() == jQuery(this).data('default')) {
                jQuery(this).val("");
            }
        });
    };

    Editor.prototype.addPointHandles = function (d) {
        var self = this;
        var points = [];

        if (d._type == 'circle') {
            points.push({
                _key: d._key + '-r',
                x: this.xScaleZeroInvert(d.r + this.pointHandleRadius/2),
                y: 0
            });
        }
        else {
            for (var i = 0; i < d.points.length; ++i) {
                points.push({
                    _key: d._key + '-' + i,
                    i: i,
                    x: d.points[i].x,
                    y: d.points[i].y
                });
            }
        }
        self.pointHandles = points;
    };

    Editor.prototype.removePointHandles = function () {
        if (!this.pointHandles) {
            return;
        }

        delete this.pointHandles;
        this.renderDecorations();
    };

    Editor.prototype.didDragPointHandle = function (d, node) {
        var x = this.xScaleZeroInvert(d3.event.x);
        var y = this.yScaleZeroInvert(d3.event.y);

        if (this.xScaleZero(x) == this.xScaleZero(d.x) && this.yScaleZero(y) == this.yScaleZero(d.y)) {
            return;
        }

        if (!d._dragging) {
            this.lifecycle.beginDragging();
            d._dragging = true;
        }

        d.x = x;
        d.y = y;

        if (this.inspectorNode._type == 'circle') {
            this.lifecycle.moveCircleRadiusPoint(this.inspectorNode, this.xScaleZero(x), this.yScaleZero(y));
        }
        else {
            this.lifecycle.movePolygonPoint(this.inspectorNode, d.i, x, y);
        }

        this.renderDisplay();
    };

    // add rects under text decorations for highlighting
    Editor.prototype.renderTextDecorations = function (initial) {
        Super.prototype.renderTextDecorations.call(this, initial);
        var self = this;

        self.renderTextDecorationBackgrounds(initial);
    };

    Editor.prototype.renderTextDecorationBackgrounds = function (initial) {
        var self = this;
        var rects = self.decorationContainer.selectAll("rect.text-background")
                         .data(self.lifecycle.decorations.text, function (d) { return d._key });

        rects.exit()
            .classed("removing", true)
            .transition().duration(200*self.animationFactor)
              .remove();

        var newRects = rects.enter().insert("rect", ":first-child")
                     .attr("data-key", function (d) { return d._key })
                     .classed("text-background", true)
                     .on("click", function (d) {
                         d3.event.stopPropagation();
                         self.clickedDecoration(d);
                     })
                     .call(function (rects) { self.didEnterTextDecorations(rects) });

        if (!initial) {
            newRects.style("opacity", 0.15)
                    .transition().duration(200*self.animationFactor)
                        .style("opacity", 1)
                        .on("end", function () { d3.select(this).style("opacity", undefined) });
        }

        newRects.merge(rects)
                      .classed("focus", function (d) { return self.isFocused(d) })
                      .each(function (d) {
                          var rect = d3.select(this);
                          var label = self.decorationContainer.select("text[data-key='"+d._key+"']");
                          var bbox = label.node().getBoundingClientRect();
                          var width = bbox.width / self._currentZoom.k;
                          var height = bbox.height / self._currentZoom.k;
                          var padding = 5 / self._currentZoom.k;

                          rect.attr("x", self.xScale(d.x)-padding)
                              .attr("y", self.yScale(d.y)-padding)
                              .attr("width", width+padding*2)
                              .attr("height", height+padding*2);
                      });
    };

    Editor.prototype.renderPolygonDecorations = function (initial) {
        Super.prototype.renderPolygonDecorations.call(this, initial);

        var self = this;
        var handles = self.transformContainer.selectAll("circle.point-handle")
                           .data(self.pointHandles || [], function (d) { return d._key });

        handles.exit()
              .remove();

        var newHandles = handles.enter().append("circle")
                           .classed("point-handle", true)
                           .attr("r", self.pointHandleRadius)
                           .call(d3.drag()
                               .subject(function (d) { return { x: self.xScaleZero(d.x), y : self.yScaleZero(d.y) } })
                               .on("start", function (d) { self.didBeginDrag(d, this) })
                               .on("drag", function (d) { self.didDragPointHandle(d) })
                               .on("end", function (d) { self.didEndDrag(d, this) })
                           );

        if (!initial) {
            newHandles.style("opacity", 0.15)
                      .transition().duration(200*self.animationFactor)
                          .style("opacity", 1)
                          .on("end", function () { d3.select(this).style("opacity", undefined) });
        }

        newHandles.merge(handles)
                     .attr("transform", function (d) {
                         var x = self.xScale(self.inspectorNode.x);
                         var y = self.yScale(self.inspectorNode.y);
                         if (self.inspectorNode._type == 'line') {
                             y += 20;
                         }
                         return "translate(" + x + ", " + y + ")";
                     })
                     .attr("cx", function (d) { return self.xScaleZero(d.x) })
                     .attr("cy", function (d) { return self.yScaleZero(d.y) })
    };

    Editor.prototype.clickedStatus = function (d) {
        this.focusItem(d);
    };

    Editor.prototype.clickedTransition = function (d) {
        this.focusItem(d);
    };

    Editor.prototype.clickedDecoration = function (d) {
        this.focusItem(d);
    };

    Editor.prototype.didBeginDrag = function (d, node) { };

    Editor.prototype.didEndDrag = function (d, node) {
        d._dragging = false;
    };

    Editor.prototype.didDragItem = function (d, node) {
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
    };

    Editor.prototype._createDrag = function () {
        var self = this;
        return d3.drag()
                 .subject(function (d) { return { x: self.xScale(d.x), y : self.yScale(d.y) } })
                 .on("start", function (d) { self.didBeginDrag(d, this) })
                 .on("drag", function (d) { self.didDragItem(d, this) })
                 .on("end", function (d) { self.didEndDrag(d, this) })
    };

    Editor.prototype.didEnterStatusNodes = function (statuses) {
        statuses.call(this._createDrag());
    };

    Editor.prototype.didEnterTextDecorations = function (labels) {
        labels.call(this._createDrag());
    };

    Editor.prototype.didEnterPolygonDecorations = function (polygons) {
        polygons.call(this._createDrag());
    };

    Editor.prototype.didEnterCircleDecorations = function (circles) {
        circles.call(this._createDrag());
    };

    Editor.prototype.didEnterLineDecorations = function (lines) {
        lines.call(this._createDrag());
    };

    Editor.prototype.viewportCenterPoint = function () {
        var rect = this.svg.node().getBoundingClientRect();
        var x = (rect.width / 2 - this._currentZoom.x)/this._currentZoom.k;
        var y = (rect.height / 2 - this._currentZoom.y)/this._currentZoom.k;
        return [this.xScaleInvert(x), this.yScaleInvert(y)];
    };

    Editor.prototype.addNewStatus = function () {
        var p = this.viewportCenterPoint();
        var status = this.lifecycle.createStatus(p[0], p[1]);
        this.focusItem(status);
    };

    Editor.prototype.addNewTextDecoration = function () {
        var p = this.viewportCenterPoint();
        var text = this.lifecycle.createTextDecoration(p[0], p[1]);
        this.focusItem(text);
    };

    Editor.prototype.addNewPolygonDecoration = function (type) {
        var p = this.viewportCenterPoint();
        var polygon = this.lifecycle.createPolygonDecoration(p[0], p[1], type);
        this.focusItem(polygon);
    };

    Editor.prototype.addNewCircleDecoration = function () {
        var p = this.viewportCenterPoint();
        var circle = this.lifecycle.createCircleDecoration(p[0], p[1], this.statusCircleRadius);
        this.focusItem(circle);
    };

    Editor.prototype.addNewLineDecoration = function () {
        var p = this.viewportCenterPoint();
        var line = this.lifecycle.createLineDecoration(p[0], p[1]);
        this.focusItem(line);
    };

    Editor.prototype.initializeEditor = function (node, name, config, focusStatus) {
        var self = this;
        self.initializeViewer(node, name, config, focusStatus);

        self.templates = self._initializeTemplates(self.container);
        self.inspector = self.container.find('.inspector');

        self.setInspectorContent(null);
        self.bindInspectorEvents();

        self.container.closest('form[name=ModifyLifecycle]').submit(function (e) {
            var config = self.lifecycle.exportAsConfiguration();
            var form = jQuery(this);
            var field = jQuery('<input type="hidden" name="Config">');
            field.val(JSON.stringify(config));
            form.append(field);
            return true;
        });

        self.svg.on('click', function () { self.defocus() });

        self.lifecycle.undoFrameCallback = function (frame) {
            var uiState = {};
            if (self._focusItem) {
                uiState.focusKey = self._focusItem._key;
            }
            frame.push(uiState);
        };

        self.lifecycle.undoStateChangedCallback = function () {
            self._refreshInspector(false);
        };
        self.lifecycle.undoStateChangedCallback();

        setTimeout(function () {
            jQuery('.results').slideUp();
        }, 10*1000);
    };

    Editor.prototype.defocus = function () {
        Super.prototype.defocus.call(this);
        this.setInspectorContent(null);
        this.removePointHandles();
        this.hoverItem(null);
        this.renderDisplay();
    };

    Editor.prototype.focusItem = function (item) {
        Super.prototype.focusItem.call(this, item);
        this.setInspectorContent(item);

        if (item._type == 'polygon' || item._type == 'line' || item._type == 'circle') {
            this.addPointHandles(item);
        }

        this.renderDisplay();
    };

    Editor.prototype.hoverItem = function (item) {
        this.svg.selectAll(".hover").classed('hover', false);

        if (item) {
            this.svg.selectAll("*[data-key='"+item._key+"']").classed('hover', true);
        }
    };

    RT.LifecycleEditor = Editor;
});
