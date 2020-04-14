jQuery(function() {
    // reset form submit info when user goes backward or forward for Safari
    // other browsers don't need this trick and they can work directly.
    if ( window.addEventListener ) {
        window.addEventListener("popstate", function(e) {
            jQuery('form').data('submitted', false);
        });
    }

    jQuery('form').submit(function(e) {
        var form = jQuery(this);
        if (form.data('submitted') === true) {
            e.preventDefault();
        } else {
            form.data('submitted', true);
        }
    });

    jQuery('.selectionbox-js').each(function () {
        var container = jQuery(this);
        var source = container.find('.source');
        var form = container.closest('form');
        var submit = form.find('input[name=UpdateSearches]');

        var copyHelper;
        var draggedIntoDestination;

        container.find('.destination ul').sortable({
            connectWith: '.destination ul',
            placeholder: 'placeholder',
            forcePlaceholderSize: true,
            cancel: '.remove',

            // drag a clone of the source item
            receive: function (e, ui) {
                draggedIntoDestination = true;
                copyHelper = null;
            },
           over: function () {
               removeIntent = false;
           },
           out: function () {
               removeIntent = true;
           },
           beforeStop: function (event, ui) {
               if(removeIntent == true){
                   ui.item.remove();
               }
           },
        }).on('click', '.remove', function (e) {
            e.preventDefault();
            jQuery(e.target).closest('li').remove();

            // dispose of the bootstrap tooltip.
            // without manually clearing here, the tooltip lingers after clicking remove.
            var bs_tooltip = jQuery('div[id^="tooltip"]');
            bs_tooltip.tooltip('hide');
            bs_tooltip.tooltip('dispose');

            return false;
        });

        source.find('ul').sortable({
            connectWith: '.destination ul',
            containment: container,
            placeholder: 'placeholder',
            forcePlaceholderSize: true,

            // drag a clone of the source item
            helper: function (e, li) {
                copyHelper = li.clone().insertAfter(li);
                return li.clone();
            },

            start: function (e, ui) {
                draggedIntoDestination = false;
            },

            stop: function (e, ui) {
                if (copyHelper) {
                    copyHelper.remove();
                }

                if (!draggedIntoDestination) {
                    jQuery(this).sortable('cancel');
                }
            }
        });

        var searchField = source.find('input[name=search]');
        var filterField = source.find('select[name=filter]');

        var refreshSource = function () {
            var searchTerm = searchField.val().toLowerCase();
            var filterType = filterField.val();

            source.find('.section').each(function () {
                var section = jQuery(this);
                var sectionLabel = section.find('h3').text();
                var sectionMatches = sectionLabel.toLowerCase().indexOf(searchTerm) > -1;

                var visibleItem = false;
                section.find('li').each(function () {
                    var item = jQuery(this);
                    var itemType = item.data('type');

                    if (filterType) {
                        // component and dashboard matches on data-type
                        if (filterType == 'component' || itemType == 'component' || filterType == 'dashboard' || itemType == 'dashboard') {
                            if (itemType != filterType) {
                                item.hide();
                                return;
                            }
                        }
                        // everything else matches on data-search-type
                        else {
                            var searchType = item.data('search-type');
                            if (searchType === '') { searchType = 'ticket' }

                            if (searchType.toLowerCase() != filterType) {
                                item.hide();
                                return;
                            }
                        }
                    }

                    if (sectionMatches || item.text().toLowerCase().indexOf(searchTerm) > -1) {
                        visibleItem = true;
                        item.show();
                    }
                    else {
                        item.hide();
                    }
                });

                if (visibleItem) {
                    section.show();
                }
                else {
                    section.hide();
                }
            });

            source.find('.contents').scrollTop(0);
        };

        searchField.on('propertychange change keyup paste input', function () {
            refreshSource();
        });
        filterField.on('change keyup', function () {
            refreshSource();
        });
        refreshSource();

        submit.click(function () {
            container.find('.destination').each(function () {
                var pane = jQuery(this);
                var name = pane.data('pane');

                pane.find('li').each(function () {
                    var item = jQuery(this).data();
                    delete item.sortableItem;
                    form.append('<input type="hidden" name="' + name + '" value="' + item.type + '-' + item.name + '" />');
                });
            });

            return true;
        });
    });
});
