jQuery(function() {
    if(RT.Config.QuoteSelectedText) {
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

            if (selection.toString)
                selection = selection.toString();

            if (typeof(selection) !== "string" || selection.length < 3)
                return;

            // TODO: wrap long lines before quoting
            selection = selection.replace(/^/gm, "> ");
            if ( RT.Config.MessageBoxRichText ) {
                selection = selection.replace(/\r?\n/g, "<br>");
                selection = selection.concat("<br><br>");
            }
            else {
                selection = selection.concat("\n\n");
            }
            selection = encodeURIComponent(selection);

            if ( !link.prop('data-href') ) {
                link.prop('data-href', link.attr('href'));
            }
            link.attr("href", link.prop("data-href").concat("&UpdateContent=" + selection));
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
    }
});
