jQuery(function() {

    var cssClassMap = {
        Users: 'user',
        Groups: 'group'
    };

    jQuery("input[data-autocomplete]").each(function(){
        var input = jQuery(this);
        var what  = input.attr("data-autocomplete");
        var wants = input.attr("data-autocomplete-return");

        if (!what || !what.match(/^(Users|Groups)$/))
            return;

        var queryargs = [];
        var options = {
            source: RT.Config.WebHomePath + "/Helpers/Autocomplete/" + what
        };

        if ( wants ) {
            queryargs.push("return=" + wants);
        }

        if (input.is('[data-autocomplete-privileged]')) {
            queryargs.push("privileged=1");
        }

        if (input.is('[data-autocomplete-multiple]')) {
            queryargs.push("delim=,");

            options.focus = function () {
                // prevent value inserted on focus
                return false;
            }

            options.select = function(event, ui) {
                var terms = this.value.split(/,\s*/);
                terms.pop();                    // remove current input
                terms.push( ui.item.value );    // add selected item
                this.value = terms.join(", ");
                return false;
            }
        }

        var exclude = input.attr('data-autocomplete-exclude');
        if (exclude) {
            queryargs.push("exclude="+exclude);
        }

        if (queryargs.length)
            options.source += "?" + queryargs.join("&");

        input.addClass('autocompletes-' + cssClassMap[what] )
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
});
