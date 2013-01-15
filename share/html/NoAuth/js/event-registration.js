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
