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
});
