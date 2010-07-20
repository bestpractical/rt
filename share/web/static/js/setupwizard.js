Behaviour.register({
    ".config-field .widget": function(e) {
        jQuery(e).focus(
            function(){
                var thisdoc = jQuery(this).parent().parent().find(".doc");

                // Slide up everything else and slide down this doc
                jQuery('.config-field .doc').not(thisdoc).not(".static-doc").slideUp();
                thisdoc.not(".static-doc").slideDown();
            }
        );
    },
    ".config-field .doc": function(e) {
        jQuery(e).not(".static-doc").hide();
    }
});

jQuery(function() {
    jQuery('.config-field .widget')[0].focus();
});

