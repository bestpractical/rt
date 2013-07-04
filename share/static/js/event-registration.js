// Disable chosing individual objects when a scrip is applied globally
jQuery(function() {
    var global_checkboxes = [
        "form[name=AddRemoveScrip] input[type=checkbox][name^=AddScrip-][value=0]",
        "form input[type=checkbox][name^=AddCustomField-][value=0]"
    ];
    jQuery(global_checkboxes.join(", "))
        .change(function(){
            var self    = jQuery(this);
            var checked = self.attr("checked");

            self.closest("form")
                .find("table.collection input[type=checkbox]")
                .attr("disabled", checked ? "disabled" : "");
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
        jQuery('option[value="' + selected + '"]', groups).attr("selected", "selected");

        // Wire it all up
        groups.change(function(){
            var name     = this.name.replace(/-Groups$/, '');
            var field    = jQuery(this);
            var subfield = field.next("select[name=" + name + "]");
            var complete = subfield.next("select[name=" + name + "-Complete]");
            var value    = field.val();
            filter_cascade( subfield[0], complete[0], value, true );
        }).change();
    });
});
