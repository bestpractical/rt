htmx.onLoad(function(elt) {
    var showModal = function(html) {
        var modal = jQuery("<div class='modal'></div>");
        modal.append(html).appendTo("body");
        modal.bind('modal:close', function(ev) { modal.remove(); })
        modal.on('hide.bs.modal', function(ev) { modal.remove(); })
        modal.modal('show');

        // We need to refresh the select picker plugin on AJAX calls
        // since the plugin only runs on page load.
        refreshSelectpicker();
    };

    const form = elt.closest(".ticket-assets") ? jQuery(elt).find("form") : jQuery(elt).find(".ticket-assets form");
    form.each(function(){
        this.addEventListener('htmx:configRequest', function(evt) {
            for ( const param in evt.detail.parameters ) {
                if ( param.match(/RefersTo/) && evt.detail.parameters[param] ) {
                    evt.detail.parameters[param] = evt.detail.parameters[param]
                                                      .match(/\S+/g)
                                                      .map(function(x){return "asset:"+x})
                                                      .join(" ");
                }
            }
        });
    });
    jQuery(elt).find(".asset-create-linked-ticket").click(function(ev){
        ev.preventDefault();
        var url = this.href.replace(/\/Asset\/CreateLinkedTicket\.html\?/g,
                                    '/Asset/Helpers/CreateLinkedTicket?');
        jQuery.get(
            url,
            showModal
        );
    });
    jQuery(elt).find("#bulk-update-create-linked-ticket").click(function(ev){
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
