document.addEventListener('htmx:configRequest', function(evt) {
    if ( !evt.detail.elt.closest('.ticket-assets form') ) return;
    for ( const param in evt.detail.parameters ) {
        if ( param.match(/RefersTo/) && evt.detail.parameters[param] ) {
            evt.detail.parameters[param] = evt.detail.parameters[param]
                                              .match(/\S+/g)
                                              .map(x => 'asset:' + x)
                                              .join(' ');
        }
    }
});
