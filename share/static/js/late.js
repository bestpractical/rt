htmx.onLoad(function(elt) {
    var parse_cf = /^Object-([\w:]+)-(\d*)-CustomField(?::\w+)?-(\d+)-(.*)$/;
    elt.querySelectorAll("input,textarea:not(.richtext),select").forEach(function(elt) {
        var elem = jQuery(elt);
        var parsed = parse_cf.exec(elem.attr("name"));
        if (parsed == null)
            return;
        if (/-Magic$/.test(parsed[4]))
            return;
        var name_filter_regex = new RegExp(
            "^Object-"+parsed[1]+"-"+parsed[2]+
             "-CustomField(?::\\w+)?-"+parsed[3]+"-"+parsed[4]+"$"
        );

        var trigger_func = function() {
            var update_elems = jQuery("input,textarea:not(.richtext),select").filter(function () {
                return name_filter_regex.test(jQuery(this).attr("name"));
            }).not(elem);
            if (update_elems.length == 0)
                return;

            var curval = elem.val();
            if ((elem.attr("type") == "checkbox") || (elem.attr("type") == "radio")) {
                curval = [ ];
                jQuery('[name="'+elem.attr("name")+'"]:checked').each( function() {
                    curval.push( jQuery(this).val() );
                });
            }
            update_elems.val(curval);
            update_elems.filter(function(index, elt) {
                return elt.tomselect;
            }).each(function (index, elt) {
                const tomselect = elt.tomselect;
                if (Array.isArray(curval)) {
                    curval.forEach(val => {
                        if (!tomselect.getItem(val)) {
                            tomselect.createItem(val, true);
                        }
                    });
                }
                else if (!tomselect.getItem(curval)) {
                    tomselect.createItem(curval, true);
                }
                tomselect.setValue(curval, true);
            });
        };
        if ((elem.attr("type") == "text") || (elem.get(0).tagName == "TEXTAREA"))
            elem.keyup( trigger_func );

        elem.change( trigger_func );
    });
});
