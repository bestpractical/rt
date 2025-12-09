/*
    We need to override the default stopCallback logic to also check if we are
    inside a tom select control.

    Code copied from devel/third-party/mousetrap-1.5.3.js and then custom code
    was added.
*/
(function() {
if (!RT.Config.EnableKeyboardShortcuts) return;
Mousetrap.prototype.stopCallback = function(e, element) {
    var self = this;

    // if the element has the class "mousetrap" then no need to stop
    if ((' ' + element.className + ' ').indexOf(' mousetrap ') > -1) {
        return false;
    }

    if (_belongsTo(element, self.target)) {
        return false;
    }

    // CUSTOM CODE START
    // if the element has the class "ts-control" then stop
    if ((' ' + element.className + ' ').indexOf(' ts-control ') > -1) {
        return true;
    }
    // CUSTOM CODE END

    // stop for input, select, and textarea
    return element.tagName == 'INPUT' || element.tagName == 'SELECT' || element.tagName == 'TEXTAREA' || element.isContentEditable;
};

// required for stopCallback
function _belongsTo(element, ancestor) {
    if (element === null || element === document) {
        return false;
    }

    if (element === ancestor) {
        return true;
    }

    return _belongsTo(element.parentNode, ancestor);
}
})();

htmx.onLoad(function() {
    if (!RT.Config.EnableKeyboardShortcuts) return;
    var goBack = function() {
        window.history.back();
    };

    var goForward = function() {
        window.history.forward();
    };

    var goHome = function() {
        var homeLink = jQuery('a#home');
        window.location.href = homeLink.attr('href');
    };

    var simpleSearch = function() {
        var searchInput = jQuery('#simple-search').find('input');
        if (!searchInput.length) { // try SelfService simple search
            searchInput = jQuery('#GotoTicket').find('input');
        }
        if (!searchInput.length) return;

        searchInput.focus();
        searchInput.select();

        return false; // prevent '/' character from being typed in search box
    };

    var openHelp = function() {
        var modal = jQuery('.modal.keyboard-shortcuts');
        if (modal.length) {
            jQuery.modal.close();
            return;
        }

        var is_search = jQuery('.main-container#comp-Search-Results').length > 0;
        var is_bulk_update = jQuery('.main-container#comp-Search-Bulk').length > 0;
        var is_ticket_reply = jQuery('a#page-actions-reply').length > 0;
        var is_ticket_comment = jQuery('a#page-actions-comment').length > 0;

        var url = RT.Config.WebHomePath + '/Helpers/ShortcutHelp' +
                  '?show_search=' + ( is_search || is_bulk_update ? '1' : '0' ) +
                  '&show_bulk_update=' + ( is_bulk_update ? '1' : '0' ) +
                  '&show_ticket_reply=' + ( is_ticket_reply ? '1' : '0' ) +
                  '&show_ticket_comment=' + ( is_ticket_comment ? '1' : '0' );

        htmx.ajax('GET', url, '#dynamic-modal').then(() => {
            bootstrap.Modal.getOrCreateInstance('#dynamic-modal').show();
        });
    };

    const reloadContainer = function() {
        htmx.trigger('.main-container', 'reload');
    };

    Mousetrap.bind('g b', goBack);
    Mousetrap.bind('g f', goForward);
    Mousetrap.bind('g h', goHome);
    Mousetrap.bind('g r', reloadContainer);
    Mousetrap.bind('/', simpleSearch);
    Mousetrap.bind('?', openHelp);
});

htmx.onLoad(function() {
    if (!RT.Config.EnableKeyboardShortcuts) return;
    // Only load these shortcuts if there is a ticket list on the page
    var hasTicketList = jQuery('table.ticket-list').length;
    if (!hasTicketList) return;

    var currentRow;

    var nextTicket = function() {
        var nextRow;
        var searchResultsTable = jQuery('.ticket-list.collection-as-table');
        if (!currentRow || !(nextRow = currentRow.next('tr.list-item')).length) {
            nextRow = searchResultsTable.find('tr.list-item').first();
        }
        setNewRow(nextRow);
    };

    var setNewRow = function(newRow) {
        if (currentRow) currentRow.removeClass('table-active');
        currentRow = newRow;
        currentRow.addClass('table-active');
        scrollToJQueryObject(currentRow);
    };

    var prevTicket = function() {
        var prevRow, searchResultsTable = jQuery('.ticket-list.collection-as-table');
        if (!currentRow || !(prevRow = currentRow.prev('tr.list-item')).length) {
            prevRow = searchResultsTable.find('tr.list-item').last();
        }
        setNewRow(prevRow);
    };

    var generateTicketLink = function(ticketId) {
        if (!ticketId) return '';
        return RT.Config.WebHomePath + '/Ticket/Display.html?id=' + ticketId;
    };

    var generateUpdateLink = function(ticketId, action) {
        if (!ticketId) return '';
        return RT.Config.WebHomePath + '/Ticket/Update.html?Action=' + action + '&id=' + ticketId;
    };

    var navigateToCurrentTicket = function() {
        if (!currentRow) return;

        var ticketId = currentRow.closest('tr').data('recordId');
        var ticketLink = generateTicketLink(ticketId);
        if (!ticketLink) return;

        window.location.href = ticketLink;
    };

    var toggleTicketCheckbox = function() {
        if (!currentRow) return;
        var ticketCheckBox = currentRow.find('input[type=checkbox]');
        if (!ticketCheckBox.length) return;
        ticketCheckBox.prop("checked", !ticketCheckBox.prop("checked"));
    };

    var replyToTicket = function() {
        if (!currentRow) return;

        var ticketId = currentRow.closest('tr').data('recordId');
        var replyLink = generateUpdateLink(ticketId, 'Respond');
        if (!replyLink) return;

        window.location.href = replyLink;
    };

    var commentOnTicket = function() {
        if (!currentRow) return;

        var ticketId = currentRow.closest('tr').data('recordId');
        var commentLink = generateUpdateLink(ticketId, 'Comment');
        if (!commentLink) return;

        window.location.href = commentLink;
    };

    Mousetrap.bind('j', nextTicket);
    Mousetrap.bind('k', prevTicket);
    Mousetrap.bind(['enter','o'], navigateToCurrentTicket);
    Mousetrap.bind('r', replyToTicket);
    Mousetrap.bind('c', commentOnTicket);
    Mousetrap.bind('x', toggleTicketCheckbox);
});

htmx.onLoad(function() {
    if (!RT.Config.EnableKeyboardShortcuts) return;
    // Only load these shortcuts if reply or comment action is on page
    var ticket_reply = jQuery('a#page-actions-reply');
    var ticket_comment = jQuery('a#page-actions-comment');
    if (!ticket_reply.length && !ticket_comment.length) return;

    var replyToTicket = function() {
        if (!ticket_reply.length) return;
        window.location.href = ticket_reply.attr('href');
    };

    var commentOnTicket = function() {
        if (!ticket_comment.length) return;
        window.location.href = ticket_comment.attr('href');
    };

    Mousetrap.bind('r', replyToTicket);
    Mousetrap.bind('c', commentOnTicket);
});

// =============================================================================
// Menu Navigation (Mouse and Keyboard)
// =============================================================================
// Handles all navigation controls for menus (top navbar and page menus).
//
// Mouse navigation:
//   - Hover over menu item with children opens its submenu
//   - Moving mouse away closes submenu after a short delay
//   - Parent menu items are highlighted when hovering over submenu items
//
// Tab/Focus navigation:
//   - Tab to menu item with children opens its submenu
//   - Tab moves through submenu items sequentially
//   - Tabbing to next top-level menu closes previous submenu
//
// Arrow key navigation:
//   - Arrow Left/Right: Move between top-level menu items (skip submenus)
//   - Arrow Down: Open submenu and focus first item, or move down within submenu
//   - Arrow Up: Move up within submenu
//   - Escape: Close current submenu and return focus to parent menu item
// =============================================================================

(function() {
    // Track menu close timeout to allow cancellation
    var menu_timeout;

    // Toggle dropdown on hover
    jQuery(document).on('mouseenter', 'nav li:has(> a.menu-item)', function (evt) {
        const elem = this;
        const link = this.querySelector(':scope > a.menu-item');
        if (elem.classList.contains('has-children')) {
            const toggle = bootstrap.Dropdown.getOrCreateInstance(link);
            toggle._inNavbar = false; // Bootstrap disables popper for dropdowns in nav, we want it to re-position submenus

            // Manually set toggle attribute to close dropdown on click.
            // Can't set it before creating instances as it would toggle
            // dropdown on click(default behavior), which we don't want.
            if (!link.getAttribute('data-bs-toggle')) {
                link.setAttribute('data-bs-toggle', 'dropdown');
            }
            toggle.show();
        }

        if (menu_timeout) {
            clearTimeout(menu_timeout);
        }

        if (!elem.parentElement) {
            return;
        }

        // Hide other dropdowns
        elem.parentElement.querySelectorAll(':scope > li').forEach(function (sibling) {
            if (elem === sibling) return;
            const link = sibling.querySelector('a.dropdown-toggle');
            if (link) {
                link.blur(); // Remove css styles applied to :focus
            }

            const toggle = bootstrap.Dropdown.getInstance(link);
            if (toggle) {
                toggle.hide();
            }
        });

        // Highlight parent nodes
        let parent = elem;
        let ul;
        while (ul = (parent && parent.parentElement)) {
            ul.querySelectorAll(':scope > li').forEach(function (sibling) {
                if (parent === sibling) {
                    sibling.querySelector('a.menu-item').classList.add('hovered');
                }
                else {
                    sibling.querySelector('a.menu-item').classList.remove('hovered');
                }
            });
            parent = ul.closest('li');
        }
    });

    jQuery(document).on('mouseleave', 'nav li:has(> a.menu-item)', function (evt) {
        const link = this.querySelector(':scope > a.menu-item');
        const toggle = bootstrap.Dropdown.getInstance(link);
        if (toggle) {
            link.blur();  // Remove css styles applied to :focus

            // Delay a little bit so that the user can hover to the submenu more easily
            menu_timeout = setTimeout(function () {
                toggle.hide();
            }, 500);
        }
    });

    // Clean up obsolete highlighted children items
    jQuery(document).on('hidden.bs.dropdown', 'nav a.menu-item', function (evt) {
        const elem = this.parentElement;
        elem.querySelectorAll('.hovered').forEach(function (item) {
            item.classList.remove('hovered');
        });
    });

    // Open dropdown on keyboard focus (Tab navigation)
    jQuery(document).on('focusin', 'nav li.has-children > a.menu-item', function (evt) {
        const link = this;
        const elem = this.parentElement;

        if (menu_timeout) {
            clearTimeout(menu_timeout);
        }

        const toggle = bootstrap.Dropdown.getOrCreateInstance(link);
        toggle._inNavbar = false;

        if (!link.getAttribute('data-bs-toggle')) {
            link.setAttribute('data-bs-toggle', 'dropdown');
        }
        toggle.show();

        // Hide sibling dropdowns
        if (elem.parentElement) {
            elem.parentElement.querySelectorAll(':scope > li').forEach(function (sibling) {
                if (elem === sibling) return;
                const siblingLink = sibling.querySelector('a.dropdown-toggle');
                const siblingToggle = bootstrap.Dropdown.getInstance(siblingLink);
                if (siblingToggle) {
                    siblingToggle.hide();
                }
            });
        }
    });

    // Close dropdown when focus leaves the menu tree
    jQuery(document).on('focusout', 'nav li.has-children', function (evt) {
        const elem = this;
        const link = this.querySelector(':scope > a.menu-item');

        // Delay to allow focus to move to submenu items before checking
        menu_timeout = setTimeout(function () {
            // Only close if focus has left this menu tree entirely
            if (!elem.contains(document.activeElement)) {
                const toggle = bootstrap.Dropdown.getInstance(link);
                if (toggle) {
                    toggle.hide();
                }
            }
        }, 150);
    });

    // Keyboard navigation visual feedback
    // Add class to body when keyboard navigation is detected in menus
    // Remove class when mouse interaction is detected
    document.addEventListener('keydown', function (evt) {
        // Only activate for Tab or Arrow keys when focus is in or moving to nav menus
        if (evt.key === 'Tab' || evt.key === 'ArrowUp' || evt.key === 'ArrowDown' ||
            evt.key === 'ArrowLeft' || evt.key === 'ArrowRight') {
            const target = evt.target;
            if (target.closest('nav a.menu-item, nav a.dropdown-item')) {
                document.body.classList.add('keyboard-nav-active');
            }
        }
    }, true);

    // Remove keyboard nav styling when mouse enters menu
    jQuery(document).on('mouseenter', 'nav li:has(> a.menu-item)', function () {
        document.body.classList.remove('keyboard-nav-active');
    });

    // Arrow key navigation for menus
    // Use capture phase (true) to intercept events before Bootstrap's dropdown handlers
    document.addEventListener('keydown', function (evt) {
        const key = evt.key;
        if (key !== 'ArrowRight' && key !== 'ArrowLeft' && key !== 'ArrowDown' && key !== 'ArrowUp' && key !== 'Escape') {
            return;
        }

        const link = evt.target.closest('nav a.menu-item, nav a.dropdown-item');
        if (!link) return;

        const li = link.closest('li');
        const nav = link.closest('nav');
        if (!li || !nav) return;

        // Find the top-level menu container
        const topLevelList = nav.querySelector('ul.navbar-nav, ul.dropdown-menu');
        if (!topLevelList) return;

        // Determine if we're on a top-level item or in a submenu
        const isTopLevel = li.parentElement.classList.contains('navbar-nav') ||
                          li.parentElement.classList.contains('toplevel');
        const inSubmenu = !isTopLevel;

        if (key === 'ArrowRight' || key === 'ArrowLeft') {
            evt.preventDefault();
            evt.stopPropagation();

            // Find all top-level menu items
            const topLevelItems = Array.from(nav.querySelectorAll(
                'ul.navbar-nav > li > a.menu-item, ul.toplevel > li > a.menu-item'
            ));

            if (topLevelItems.length === 0) return;

            // Find the current top-level item (either current or parent)
            let currentTopLevelLink;
            if (isTopLevel) {
                currentTopLevelLink = link;
            } else {
                // Find the top-level ancestor
                const topLevelLi = li.closest('ul.navbar-nav > li, ul.toplevel > li');
                currentTopLevelLink = topLevelLi ? topLevelLi.querySelector(':scope > a.menu-item') : null;
            }

            if (!currentTopLevelLink) return;

            const currentIndex = topLevelItems.indexOf(currentTopLevelLink);
            if (currentIndex === -1) return;

            // Calculate next index with wrapping
            let nextIndex;
            if (key === 'ArrowRight') {
                nextIndex = (currentIndex + 1) % topLevelItems.length;
            } else {
                nextIndex = (currentIndex - 1 + topLevelItems.length) % topLevelItems.length;
            }

            // Close current dropdown if open
            const currentToggle = bootstrap.Dropdown.getInstance(currentTopLevelLink);
            if (currentToggle) {
                currentToggle.hide();
            }

            // Focus the next top-level item (focusin handler will open its submenu)
            topLevelItems[nextIndex].focus();
        }
        else if (key === 'ArrowDown') {
            evt.preventDefault();
            evt.stopPropagation();

            // If on a top-level item with children, open submenu and focus first item
            if (isTopLevel && li.classList.contains('has-children')) {
                const submenu = li.querySelector(':scope > ul.dropdown-menu');
                if (submenu) {
                    // Ensure submenu is open
                    const toggle = bootstrap.Dropdown.getOrCreateInstance(link);
                    if (!link.getAttribute('data-bs-toggle')) {
                        link.setAttribute('data-bs-toggle', 'dropdown');
                    }
                    toggle.show();

                    // Focus first focusable item in submenu
                    const firstItem = submenu.querySelector('a.dropdown-item, a.menu-item');
                    if (firstItem) {
                        firstItem.focus();
                    }
                }
            }
            // If in a submenu, move to next sibling
            else if (inSubmenu) {
                const siblings = Array.from(li.parentElement.querySelectorAll(':scope > li > a.dropdown-item, :scope > li > a.menu-item'));
                const currentIndex = siblings.indexOf(link);
                if (currentIndex !== -1 && currentIndex < siblings.length - 1) {
                    siblings[currentIndex + 1].focus();
                }
            }
        }
        else if (key === 'ArrowUp') {
            evt.preventDefault();
            evt.stopPropagation();

            if (inSubmenu) {
                // Find the previous sibling that has a menu link
                let prevLi = li.previousElementSibling;
                while (prevLi) {
                    const prevLink = prevLi.querySelector('a.dropdown-item, a.menu-item');
                    if (prevLink) {
                        prevLink.focus();
                        return;
                    }
                    prevLi = prevLi.previousElementSibling;
                }
                // No previous sibling with a link - return to parent menu
                const parentLi = li.closest('ul.dropdown-menu').closest('li');
                const parentLink = parentLi ? parentLi.querySelector(':scope > a.menu-item') : null;
                if (parentLink) {
                    const toggle = bootstrap.Dropdown.getInstance(parentLink);
                    if (toggle) {
                        toggle.hide();
                    }
                    parentLink.focus();
                }
            }
        }
        else if (key === 'Escape') {
            evt.preventDefault();
            evt.stopPropagation();

            // Close current submenu and return to parent
            if (inSubmenu) {
                const parentLi = li.closest('ul.dropdown-menu').closest('li');
                const parentLink = parentLi ? parentLi.querySelector(':scope > a.menu-item') : null;
                if (parentLink) {
                    const toggle = bootstrap.Dropdown.getInstance(parentLink);
                    if (toggle) {
                        toggle.hide();
                    }
                    parentLink.focus();
                }
            }
            // On top-level, close its submenu
            else if (li.classList.contains('has-children')) {
                const toggle = bootstrap.Dropdown.getInstance(link);
                if (toggle) {
                    toggle.hide();
                }
            }
        }
    }, true); // Use capture phase to run before Bootstrap's handlers
})();
