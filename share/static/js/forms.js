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
window.onload = function () {
    document.onkeydown = function (e) {
        if (e.keyCode == 13 && e.ctrlKey) { // keyCode 13 is Enter
            document.getElementById("SubmitTicketButton").click(); // submit the form by hitting ctrl + enter
            return false; // preventing default action
        }
    }
}
