// Lower the speed limit for hover intent event
jQuery.event.special.hover.speed = 80; // pixels per second

jQuery(function() { sync_grouped_custom_fields() } );
function sync_grouped_custom_fields() {
    var all_inputs = jQuery("input,textarea,select");
    var parse_cf = /^Object-([\w:]+)-(\d*)-CustomField(?::\w+)?-(\d+)-(.*)$/;
    all_inputs.each(function() {
        var elem = jQuery(this);
        var parsed = parse_cf.exec(elem.attr("name"));
        if (parsed == null)
            return;
        if (/-Magic$/.test(parsed[4]))
            return;
        var name_filter_regex = new RegExp(
            "^Object-"+parsed[1]+"-"+parsed[2]+
             "-CustomField(?::\\w+)?-"+parsed[3]+"-"+parsed[4]+"$"
        );
        var update_elems = all_inputs.filter(function () {
            return name_filter_regex.test(jQuery(this).attr("name"));
        }).not(elem);
        if (update_elems.length == 0)
            return;
        var trigger_func = function() {
            var curval = elem.val();
            if ((elem.attr("type") == "checkbox") || (elem.attr("type") == "radio")) {
                curval = [ ];
                jQuery('[name="'+elem.attr("name")+'"]:checked').each( function() {
                    curval.push( jQuery(this).val() );
                });
            }
            update_elems.val(curval);
        };
        if ((elem.attr("type") == "text") || (elem.attr("tagName") == "TEXTAREA"))
            elem.keyup( trigger_func );
        else
            elem.change( trigger_func );
    });
}
