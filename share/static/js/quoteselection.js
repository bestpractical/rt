htmx.onLoad(function() {
    if(!RT.Config.QuoteSelectedText) {
        return;
    }

    var add_sub_container = function (container, tagName) {
        var sub = document.createElement(tagName);
        container.appendChild(sub);
        return sub;
    };

    var range_html = function (range) {
        var topContainer = document.createElement('div');
        var container = topContainer;

        var fragment = range.cloneContents();

        var child = fragment.firstElementChild;
        if (child) {
            var tn = child.tagName;
            if (tn == "LI") {
                container = add_sub_container(container, 'ul');
            } else if (tn == "DT" || tn == "DD") {
                container = add_sub_container(container, 'dl');
            } else if (tn == "TD" || tn == "TH") {
                container = add_sub_container(container, 'table');
                container = add_sub_container(container, 'tbody');
                container = add_sub_container(container, 'tr');
            } else if (tn == "TR") {
                container = add_sub_container(container, 'table');
                container = add_sub_container(container, 'tbody');
            } else if (tn == "TBODY" || tn == "THEAD" || tn == "TFOOT") {
                container = add_sub_container(container, 'table');
            }
        }

        container.appendChild(fragment);
        return topContainer.innerHTML;
    };

    var reply_from_selection = function(ev) {
        var link = jQuery(this);

        var selection;
        var activeElement;
        if (window.getSelection) {
            selection = window.getSelection();
        } else {
            return;
        }

        if (selection.rangeCount) {
            activeElement = selection.getRangeAt(0);
        } else {
            return;
        }

        // check if selection has commonAncestorContainer with class 'messagebody'
        var commonAncestor = activeElement.commonAncestorContainer;
        if (commonAncestor) {
            var isMessageBody = false;
            var parent = commonAncestor.parentNode;
            while (parent) {
                if (parent.className && parent.className.indexOf('messagebody') != -1) {
                    isMessageBody = true;
                    break;
                }
                parent = parent.parentNode;
            }
            if (!isMessageBody) {
                return;
            }
        }

        if ( RT.Config.MessageBoxRichText ) {
            selection = range_html(activeElement);
        }
        else {
            if (selection.toString)
                selection = selection.toString();

            selection = selection.concat("\n\n");
        }
        if (typeof(selection) !== "string" || selection.length < 3)
            return;

        selection = encodeURIComponent(selection);

        if ( !link.prop('data-href') ) {
            link.prop('data-href', link.attr('href'));
        }
        link.attr("href", link.prop("data-href").concat("&QuoteContent=" + selection));
    };

    var apply_quote = function() {
        var link = jQuery(this);
        if (link.data("quote-selection"))
            return;
        link.data("quote-selection",true);
        link.click(reply_from_selection);
    };

    jQuery(
        ".reply-link, "         +
        ".comment-link, "       +
        "#page-actions-reply, " +
        "#page-actions-comment"
    ).each(apply_quote);

    jQuery(document).ajaxComplete(function(ev){
        jQuery(".reply-link, .comment-link").each(apply_quote);
    });
});
