Behaviour.register({
    "#setupwizard .reveal-hints .form_field .widget": function(e) {
        jQuery(e).focus(
            function(){
                var thisdoc = jQuery(this).parent().find(".hints");

                // Slide up everything else and slide down this doc
                jQuery('#setupwizard .reveal-hints .form_field .hints').not(thisdoc).slideUp();
                thisdoc.slideDown();
            }
        );
    },
    "#setupwizard .reveal-hints .form_field .hints": function(e) {
        jQuery(e).hide();
    }
});

jQuery(function() {
    jQuery('#setupwizard .form_field .widget')[0].focus();
});

