jQuery(function() {
    var reply_from_selection = function(ev) {
        var link = jQuery(this);

        var selection;
        if (window.getSelection)
            selection = window.getSelection();
        else if (document.getSelection)
            selection = document.getSelection();
        else if (document.selection)
            selection = document.selection.createRange().text;

        if (selection.toString)
            selection = selection.toString();

        if (typeof(selection) !== "string" || selection.length < 3)
            return;

        selection = encodeURIComponent(selection);

        if ( !link.prop('data-href') ) {
            link.prop('data-href', link.attr('href'));
        }
        link.attr("href", link.prop("data-href").concat("&ContentFromQuote=1&UpdateContent=" + selection));
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
