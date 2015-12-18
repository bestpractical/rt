// Disable chosing individual objects when a scrip is applied globally
jQuery(function() {
    var global_checkboxes = [
        "form[name=AddRemoveScrip] input[type=checkbox][name^=AddScrip-][value=0]",
        "form input[type=checkbox][name^=AddCustomField-][value=0]"
    ];
    jQuery(global_checkboxes.join(", "))
        .change(function(){
            var self    = jQuery(this);
            var checked = self.prop("checked");

            self.closest("form")
                .find("table.collection input[type=checkbox]")
                .prop("disabled", checked);
        });
});

// Replace user references in history with the HTML versions
function ReplaceUserReferences() {
    var users = jQuery(".user[data-replace=user]");
    var ids   = users.map(function(){
        return "id=" + encodeURIComponent(jQuery(this).attr("data-user-id"))
    }).toArray().join(";");

    if (!ids.length)
        return

    jQuery.get(
        RT.Config.WebPath + "/Helpers/UserInfo?" + ids,
        function(json) {
            users.each(function() {
                var user = jQuery(this);
                var uid  = user.attr("data-user-id");
                if (!json[uid])
                    return
                user.removeAttr("data-replace")
                    .html( jQuery(json[uid]._html).html() );
            });
        }
    );
}
jQuery(ReplaceUserReferences);

// Cascaded selects
jQuery(function() {
    jQuery("select.cascade-by-optgroup").each(function(){
        var name = this.name;
        if (!name) return;

        // Generate elements for cascading based on the master <select> ...
        var complete = jQuery(this)
            .clone(true, true)
            .attr("name", name + "-Complete")
            .attr("disabled", "disabled")
            .hide()
            .insertAfter(this);

        var groups = jQuery(this)
            .clone(true, true)
            .attr("name", name + "-Groups")
            .find("option").remove().end()
            .find("optgroup").replaceWith(function(){
                return jQuery("<option>").val(this.label).text(this.label);
            }).end()
            .prepend( complete.find("option[value='']") )
            .insertBefore(this);

        // Synchronize the <select> we just generated
        var selected = jQuery("option[selected]", this).parent().attr("label");
        if (selected === undefined) selected = "";
        jQuery('option[value="' + selected + '"]', groups).attr("selected", "selected");

        // Wire it all up
        groups.change(function(){
            var name     = this.name.replace(/-Groups$/, '');
            var field    = jQuery(this);
            var subfield = field.next("select[name=" + name + "]");
            var complete = subfield.next("select[name=" + name + "-Complete]");
            var value    = field.val();
            filter_cascade_select( subfield[0], complete[0], value );
        }).change();
    });

    jQuery('[data-cascade-based-on-name]').each( function() {
        var based_on_name = jQuery(this).attr('data-cascade-based-on-name');
        var based_on = jQuery('[name^="' + based_on_name + '"][type!="hidden"]:input:not(.hidden)');
        var id = jQuery(this).attr('id');
        based_on.each( function() {
            var oldchange = jQuery(this).onchange;
            jQuery(this).change( function () {
                var vals;
                if ( jQuery(this).is('select') ) {
                    vals = based_on.first().val();
                }
                else {
                    vals = [];
                    jQuery(based_on).each( function() {
                        if ( jQuery(this).is(':checked') ) {
                            vals.push(jQuery(this).val());
                        }
                    });
                }
                filter_cascade_by_id( id, vals );
                if (oldchange != null)
                    oldchange();
            });
        });

        if ( based_on.is('select') ) {
            based_on.change();
        }
        else {
            based_on.first().change();
        }
    });
});

jQuery( function() {
    jQuery("input[type=file]").change( function() {
        var input = jQuery(this);
        var warning = input.next(".invalid");

        if ( !input.val().match(/"/) ) {
            warning.hide();
        } else {
            if (warning.length) {
                warning.show();
            } else {
                input.val("");
                jQuery("<span class='invalid'>")
                    .text(loc_key("quote_in_filename"))
                    .insertAfter(input);
            }
        }
    });
});

jQuery(function() {
    jQuery("#UpdateType").change(function(ev) {
        jQuery(".messagebox-container")
            .removeClass("action-response action-private")
            .addClass("action-"+ev.target.value);
    });
});
