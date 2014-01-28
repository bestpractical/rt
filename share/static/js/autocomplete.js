if (!window.RT)              window.RT = {}
if (!window.RT.Autocomplete) window.RT.Autocomplete = {}

window.RT.Autocomplete.Classes = {
    Users: 'user',
    Groups: 'group',
    Tickets: 'tickets',
    Queues: 'queues'
};

window.RT.Autocomplete.bind = function(from) {

    jQuery("input[data-autocomplete]", from).each(function(){
        var input = jQuery(this);
        var what  = input.attr("data-autocomplete");
        var wants = input.attr("data-autocomplete-return");

        if (!what || !window.RT.Autocomplete.Classes[what])
            return;

        // Don't re-bind the autocompleter
        if (input.data("ui-autocomplete"))
            return;

        var queryargs = [];
        var options = {
            source: RT.Config.WebHomePath + "/Helpers/Autocomplete/" + what
        };

        if ( wants ) {
            queryargs.push("return=" + wants);
        }

        if (what == 'Queues') {
            options.minLength = 2;
            options.delay = 2;
        }

        if (input.is('[data-autocomplete-privileged]')) {
            queryargs.push("privileged=1");
        }

        if (input.is('[data-autocomplete-include-nobody]')) {
            queryargs.push("include_nobody=1");
        }

        if (input.is('[data-autocomplete-include-system]')) {
            queryargs.push("include_system=1");
        }

        if (input.is('[data-autocomplete-multiple]')) {
            if ( what != 'Tickets' ) {
                queryargs.push("delim=,");
            }

            options.focus = function () {
                // prevent value inserted on focus
                return false;
            }

            options.select = function(event, ui) {
                var terms = this.value.split(what == 'Tickets' ? /\s+/ : /,\s*/);
                terms.pop();                    // remove current input
                terms.push( ui.item.value );    // add selected item
                if ( what == 'Tickets' ) {
                    // remove non-integers in case subject search with spaces in (like "foo bar")
                    terms = jQuery.grep(terms, function(term) {
                        var str = term + ''; // stringify integers to call .match
                        return str.match(/^\d+$/);
                    } );
                }
                terms.push(''); // add trailing delimeter so user can input another value directly
                this.value = terms.join(what == 'Tickets' ? ' ' : ", ");
                jQuery(this).change();

                return false;
            }
        }

        if (input.attr("data-autocomplete-autosubmit")) {
            options.select = function( event, ui ) {
                jQuery(event.target).val(ui.item.value);
                jQuery(event.target).closest("form").submit();
            };
        }

        var checkRight = input.attr("data-autocomplete-checkright");
        if (checkRight) queryargs.push("right=" + checkRight);

        var exclude = input.attr('data-autocomplete-exclude');
        if (exclude) {
            queryargs.push("exclude="+exclude);
        }

        if (queryargs.length)
            options.source += "?" + queryargs.join("&");

        input.addClass('autocompletes-' + window.RT.Autocomplete.Classes[what] )
            .autocomplete(options)
            .data("ui-autocomplete")
            ._renderItem = function(ul, item) {
                var rendered = jQuery("<a/>");

                if (item.html == null)
                    rendered.text( item.label );
                else
                    rendered.html( item.html );

                return jQuery("<li/>")
                    .data( "item.autocomplete", item )
                    .append( rendered )
                    .appendTo( ul );
            };
    });
};
jQuery(function(){ RT.Autocomplete.bind(document) });
