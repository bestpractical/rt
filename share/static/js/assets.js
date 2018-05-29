jQuery(function() {
    var showModal = function(html) {
        jQuery("<div class='modal'></div>")
            .append(html).appendTo("body")
            .bind('modal:close', function(ev,modal) { modal.elm.remove(); })
            .modal();
    };

    var assets = jQuery("#assets-accordion");
    assets.accordion({
        // Open the accordion if there's only one fold, otherwise start with
        // all assets collapsed.
        active:         assets.find("h3").length == 1 ? 0 : false,
        collapsible:    true,
        heightStyle:    'content',
        header: "h3"
    }).find("h3 a.unlink-asset").click(function(ev){
        ev.stopPropagation();
        return true;
    });
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
    jQuery("#assets-create").click(function(ev){
        ev.preventDefault();
        jQuery.get(
            RT.Config.WebHomePath + "/Asset/Helpers/CreateInCatalog",
            showModal
        );
    });
});

var path = window.location.href;

if ( path.match( /Asset\/Search/ ) ) {
  jQuery(function() {
    var all_inputs = jQuery("#AssetSearch input, #AssetSearch select");
    all_inputs.each(function() {
      var elem = jQuery(this);
      var update_elems = all_inputs.filter(function () {
        return jQuery(this).attr("name") == elem.attr("name");
      }).not(elem);
      if (update_elems.length == 0) {
        return;
      }
      var trigger_func = function() { update_elems.val(elem.val()) };
      if (elem.attr("type") == "text") {
        elem.keyup( trigger_func );
      } else {
        elem.change( trigger_func );
      }
    });
  });
}
