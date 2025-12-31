htmx.onLoad(function(elt) {
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
});
