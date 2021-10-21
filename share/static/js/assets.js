jQuery(function() {
    var showModal = function(html) {
        var modal = jQuery("<div class='modal'></div>");
        modal.append(html).appendTo("body");
        modal.bind('modal:close', function(ev) { modal.remove(); })
        modal.on('hide.bs.modal', function(ev) { modal.remove(); })
        modal.modal('show');

        // We need to refresh the select picker plugin on AJAX calls
        // since the plugin only runs on page load.
        jQuery('.selectpicker').selectpicker('refresh');
    };

    jQuery(".ticket-assets form").submit(function(){
        var input = jQuery("[name*=RefersTo]", this);
        if (input.val())
            input.val(input.val().match(/\S+/g)
                                 .map(function(x){return "asset:"+x})
                                 .join(" "));
    });
    jQuery("#page-actions-create-linked-ticket").click(function(ev){
        ev.preventDefault();
        var url = this.href.replace(/\/Asset\/CreateLinkedTicket\.html\?/g,
                                    '/Asset/Helpers/CreateLinkedTicket?');
        jQuery.get(
            url,
            showModal
        );
    });
    jQuery("#bulk-update-create-linked-ticket").click(function(ev){
        ev.preventDefault();
        var chkArray = [];

        jQuery("input[name='UpdateAsset']:checked").each(function() {
            chkArray.push(jQuery(this).val());
        });

        var selected = '';
        for (var i = 0; i < chkArray.length; i++) {
            selected += 'Asset=' + chkArray[i] + '&';
        }
        /* selected = chkArray.join(','); */
        var url = RT.Config.WebHomePath + '/Asset/Helpers/CreateLinkedTicket?' + selected;
        jQuery.post(
            url,
            showModal
        );
    });
});
