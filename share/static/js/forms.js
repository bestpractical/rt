/**
 * RT.selectionBox - Drag-and-Drop Helper Object
 *
 * This module provides methods to handle drag-and-drop interactions for list items,
 * such as selection boxes or sortable lists.
 *
 * How to Use:
 *
 *   Make sure the draggable elements are <li> and have the 'draggable' attribute
 *   set to 'true'.
 *
 *   Example HTML:
 *       <li draggable="true" class="my-draggable-item-class">....</li>
 *
 *   To make an element a drop target, add the 'destination' class to the
 *   container. This will ensure that the dragged element will be duplicated
 *   when dropped if it is comming from another container without the
 *   'destination' class, and also ensure that the dragged element will be moved
 *   if it is already within a destination container. It also needs to have a
 *   child <ul> element to contain the list items and a child <p> element with
 *   the 'rt-drop-placeholder' class to indicate the drop location:
 *
 *       <div class="destination">
 *         <ul>
 *           ....
 *           <p class="rt-drop-placeholder m-1 p-2 border rounded"><&|/l&>Place here</&></p>
 *         </ul>
 *       </div>
 *
 *       or
 *
 *       <div class="destination">
 *         <div>
 *           ...
 *           <ul>
 *             ...
 *             <p class="rt-drop-placeholder m-1 p-2 border rounded"><&|/l&>Place here</&></p>
 *           </ul>
 *         </div>
 *       </div>
 *
 *   To initialize the drag-and-drop functionality, register the draggables elements:
 *
 *       jQuery('.my-draggable-item-class').each(function() {
 *         RT.selectionBox.registerDrag(this);
 *       });
 *
 *   And register the drop targets:
 *
 *       jQuery('.destination').each(function() {
 *         RT.selectionBox.registerDrop(this);
 *       });
 *
 *   Finally, attach a function to handle the drop event if you need:
 *
 *       jQuery('.destination').on('dragend', function() {
 *         yourFunctionToHandleDropEvent();
 *       });
 *
 * Utility Methods:
 *
 *   registerDrag(elt):
 *     - Registers the 'dragstart' and 'dragend' events on the specified element.
 *
 *   registerDrop(elt):
 *     - Registers the 'dragenter', 'dragover', 'dragleave', and 'drop' events
 *       on the specified container.
 *
 *   deleteItem(elt):
 *     - Removes the list item from the DOM.
 *     - Hides any associated Bootstrap tooltips before removal.
 *
 */
(function(){
let dragged;
const selectionBox = RT.selectionBox ||= {
    dragstart: function(e) {
        dragged = e.target;
        e.effectAllowed = "copy";

        e.target.classList.add('current');

        bootstrap.Tooltip.getInstance(e.target.querySelector('span.content'))?.dispose();
    },

    dragend: function(e) {
        e.target.classList.remove('current');
        document.querySelector('.rt-drop-placeholder.active')?.classList.remove('active');
    },

    dragenter: function(e) {
        e.preventDefault();
        const area = e.target.closest('ul');
        const placeholder = area.querySelector('.rt-drop-placeholder');
        if ( e.target.closest('li') ) {
            if ( e.target.closest('li') === dragged ) {
                placeholder.classList.remove('active');
                return;
            }
            area.insertBefore(placeholder, e.target.closest('li'));
        }
        else if ( e.target === area ) {
            area.insertBefore(placeholder, null);
        }
        placeholder.classList.add('active');
    },

    dragleave: function(e) {},

    dragover: function(e) {
        e.preventDefault();
    },

    drop: function(e) {

        let source;
        if (dragged.closest('.destination')) {
            source = dragged;
        }
        else {
            source = dragged.cloneNode(true);
            source.querySelector('a.remove').addEventListener('click', selectionBox.deleteItem);
            selectionBox.registerDrag(source);
        }

        let sibling = e.target.closest('li') || e.target.closest('.rt-drop-placeholder')?.nextSibling;
        let area = e.target.closest('ul');

        if (sibling) {
            area.insertBefore(source, sibling);
        }
        else {
            area.appendChild(source);
        }
    },
    registerDrag: function(elt) {
        for (let event of ['dragstart', 'dragend']) {
            elt.addEventListener(event, selectionBox[event]);
        }
    },
    registerDrop: function(elt) {
        for (let event of ['dragenter', 'dragover', 'dragleave', 'drop']) {
            elt.addEventListener(event, selectionBox[event]);
        }
    },

    deleteItem: function(e) {
        e.preventDefault();
        let item = e.target.closest('li');
        item.querySelectorAll('[data-bs-toggle=tooltip]').forEach((elt) => {
            bootstrap.Tooltip.getInstance(elt)?.hide();
        });
        item.remove();
        return false;
    }
};

htmx.onLoad(function(elt) {

    elt.querySelectorAll('.selectionbox-js').forEach(editor => {
        editor.querySelectorAll('.contents li').forEach((elt) => {
            selectionBox.registerDrag(elt);
            elt.querySelector('a.remove').addEventListener('click', selectionBox.deleteItem);
        });
        selectionBox.registerDrop(editor.querySelector('.destination ul'));
    });
});

htmx.onLoad(function() {
    jQuery('.selectionbox-js').each(function () {
        var container = jQuery(this);
        var source = container.find('.source');
        var form = container.closest('form');
        var submit = form.find('input[name=UpdateSearches]');

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
                    const item = jQuery(this).data();
                    form.append('<input type="hidden" name="' + name + '" value="' + item.type + '-' + (item.id || item.name) + '" />');
                });
            });

            return true;
        });
    });
});

})();
