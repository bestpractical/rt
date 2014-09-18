function filter_cascade_by_id (id, vals) {
    var element = document.getElementById(id);
    if (!element) { return };

    if ( element.tagName == 'SELECT' ) {
        var complete_select = document.getElementById(id + "-Complete" );
        filter_cascade_select(element, complete_select, vals );
        if ( jQuery(element).hasClass('chosen') ) {
            jQuery(element).trigger('chosen:updated');
        }
    }
    else {
        if ( !( vals instanceof Array ) ) {
            vals = [vals];
        }

        if ( vals.length == 0 || (vals.length == 1 && vals[0] == '') ) {
            // no category, leave it empty
            jQuery(element).find('div').hide();
        }
        else {
            jQuery(element).find('div').hide().find('input').prop('disabled', true);
            jQuery(element).find('div[data-name=]').show().find('input').prop('disabled', false);
            jQuery(element).find('div.none').show().find('input').prop('disabled',false);
            for ( var j = 0; j < vals.length; j++ ) {
                var match = jQuery(element).find('div[data-name]').filter(function(){
                    return jQuery(this).data('name').indexOf(vals[j]) == 0
                });
                match.show().find('input').prop('disabled', false);
            }
        }
    }
}

function filter_cascade_select (select, complete_select, vals) {
    if ( !( vals instanceof Array ) ) {
        vals = [vals];
    }

    if (!select) { return };
    var i;
    var children = select.childNodes;

    jQuery(select).children().remove();

    var complete_children = jQuery(complete_select).children();

    var cloned_labels = {};
    var cloned_empty_label;
    for ( var j = 0; j < vals.length; j++ ) {
        var val = vals[j];
        if ( val == '' ) {
            // no category, leave this set of options empty
        }
        else {
            var labels_to_clone = {};
            complete_children.each( function() {
                var label = jQuery(this).attr('label');
                var need_clone;
                if ( !label ) {
                    if ( !cloned_empty_label ) {
                        need_clone = true;
                    }
                }
                else if ( label == val ) {
                    if ( !cloned_labels[label] ) {
                        need_clone = true;
                    }
                }

                if ( need_clone ) {
                    jQuery(select).append(jQuery(this).clone());
                    cloned_labels[label] = true;
                }
            });

            if ( !cloned_empty_label )
                cloned_empty_label = true;
        }
    }
}
