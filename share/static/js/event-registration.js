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
