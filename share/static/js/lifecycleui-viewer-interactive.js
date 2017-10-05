jQuery(function () {
    var Super = RT.LifecycleViewer;

    function Interactive (container) {
        Super.call(this);
    };
    Interactive.prototype = Object.create(Super.prototype);

    Interactive.prototype.deselectStatus = function () {
        delete this.selectedStatus;
        delete this.selectedMenu;

        this.statusContainer.selectAll('.selected').classed('selected', false);
        this.menuContainer.find('.status-menu.selected').removeClass('selected');
    };

    Interactive.prototype._setMenuPosition = function () {
        if (!this.selectedStatus) {
            return;
        }

        var d = this.selectedStatus;
        var statusNode = this.statusContainer.select('g[data-key="'+ d._key + '"]');
        var bbox = statusNode.node().getBoundingClientRect();
        var x = bbox.right + window.scrollX;
        var y = bbox.top + window.scrollY;

        this.selectedMenu.css({top: y, left: x});
    };

    Interactive.prototype.clickedStatus = function (d) {
        var statusName = d.name;
        this.selectedMenu = this.menuContainer.find('.status-menu[data-status="'+statusName+'"]');
        this.selectedStatus = d;
        var statusNode = this.statusContainer.select('g[data-key="'+ d._key + '"]');

        this.statusContainer.selectAll('.selected').classed('selected', false);
        statusNode.classed('selected', true);

        this.menuContainer.find('.status-menu.selected').removeClass('selected');
        this.selectedMenu.addClass('selected');

        this.selectedMenu.find(".toplevel").addClass('sf-menu sf-vertical sf-js-enabled sf-shadow').supersubs().superfish({ speed: 'fast' });

        this._setMenuPosition();
    };

    Interactive.prototype.didZoom = function () {
        Super.prototype.didZoom.call(this);
        if (this.selectedMenu) {
            this._setMenuPosition();
            var svgBox = this.svg.node().getBoundingClientRect();
            var menuBox = this.selectedMenu[0].getBoundingClientRect();

            var overlap = !(svgBox.right  < menuBox.left ||
                            svgBox.left   > menuBox.right ||
                            svgBox.bottom < menuBox.top ||
                            svgBox.top    > menuBox.bottom);
            if (!overlap) {
                this.deselectStatus();
            }
        }
    };

    Interactive.prototype.initializeViewer = function (node, name, config, focusStatus) {
         var self = this;
         Super.prototype.initializeViewer.call(self, node, name, config, focusStatus);
         self.menuContainer = jQuery(node).find('.status-menus');
         self.svg.on('click', function () { self.deselectStatus() });

         // copy classes from <a> to <li> for improved styling
         self.menuContainer.find('.status-menu li a').each(function () {
             var link = jQuery(this);
             var item = link.closest('li');
             item.addClass(link.attr("class"));
             item.removeClass('menu-item');
         });
    };

    RT.LifecycleViewerInteractive = Interactive;
});

