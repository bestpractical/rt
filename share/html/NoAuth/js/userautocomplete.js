jQuery(function() {
    // inputs that accept multiple email addresses
    var multipleCompletion = new Array("Requestors", "To", "Bcc", "Cc", "AdminCc", "WatcherAddressEmail[123]", "UpdateCc", "UpdateBcc");

    // inputs with only a single email address allowed
    var singleCompletion   = new Array("(Add|Delete)Requestor", "(Add|Delete)Cc", "(Add|Delete)AdminCc");

    // build up the regexps we'll use to match
    var applyto  = new RegExp('^(' + multipleCompletion.concat(singleCompletion).join('|') + ')$');
    var acceptsMultiple = new RegExp('^(' + multipleCompletion.join('|') + ')$');

    var inputs = document.getElementsByTagName("input");

    for (var i = 0; i < inputs.length; i++) {
        var input = inputs[i];
        var inputName = input.getAttribute("name");

        if (!inputName || !inputName.match(applyto))
            continue;

        var options = {
            source: "<% RT->Config->Get('WebPath')%>/Helpers/Autocomplete/Users"
        };

        if (inputName.match(acceptsMultiple)) {
            options.source = options.source + "?delim=,";

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
        jQuery(input).autocomplete(options);
    }
});
