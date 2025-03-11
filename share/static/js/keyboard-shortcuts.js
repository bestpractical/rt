/*
    We need to override the default stopCallback logic to also check if we are
    inside a tom select control.

    Code copied from devel/third-party/mousetrap-1.5.3.js and then custom code
    was added.
*/
(function() {
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

        var is_search = jQuery('body#comp-Search-Results').length > 0;
        var is_bulk_update = jQuery('body#comp-Search-Bulk').length > 0;
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

    Mousetrap.bind('g b', goBack);
    Mousetrap.bind('g f', goForward);
    Mousetrap.bind('g h', goHome);
    Mousetrap.bind('/', simpleSearch);
    Mousetrap.bind('?', openHelp);
});

htmx.onLoad(function() {
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
