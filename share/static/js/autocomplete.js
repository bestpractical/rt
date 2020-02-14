if (!window.RT)              window.RT = {}
if (!window.RT.Autocomplete) window.RT.Autocomplete = {}

window.RT.Autocomplete.Classes = {
    Users: 'user',
    Groups: 'group',
    Tickets: 'tickets',
    Queues: 'queues',
    Articles: 'articles'
};

Selectize.define('rt_drag_drop', function(options) {
    this.require('drag_drop');
    var self = this;
    self.setup = (function() {
        var original = self.setup;
        return function() {
            original.apply(this, arguments);
            self.$control.sortable('option', 'connectWith', '.selectize-input');
            self.$control.on('sortreceive', function(e, ui) {
                var input = jQuery(e.target).parent().prev('input');
                var self = input.selectize()[0].selectize;
                var value = ui.item.attr('data-value');
                self.createItem(value, false);
                self.getItem(value).children('span').text(ui.item.children('span').text());
                self.getItem(value).insertBefore(ui.item);
                ui.item.remove();
                self.setCaret(self.items.length);
            });
            self.$control.on('sortremove', function(e, ui) {
                var input = jQuery(e.target).parent().prev('input');
                var self = input.selectize()[0].selectize;
                var value = ui.item.attr('data-value');
                self.removeItem(value, true);
                self.trigger('item_remove', value, ui.item);
            });
        };
    })();
});

window.RT.Autocomplete.bind = function(from) {

    jQuery("input[data-autocomplete]", from).each(function(){
        var input = jQuery(this);
        var what  = input.attr("data-autocomplete");
        var wants = input.attr("data-autocomplete-return");

        if (!what || !window.RT.Autocomplete.Classes[what])
            return;

        if (what === 'Users' && input.is('[data-autocomplete-multiple]')) {
            var options = input.attr('data-options');
            var items = input.attr('data-items');
            input.selectize({
                plugins: ['remove_button', 'rt_drag_drop'],
                options: options ? JSON.parse(options) : null,

                // If input value contains multiple items, selectize only
                // renders the first item somehow. Here we explicitly set
                // items to get around this issue.
                items: items ? JSON.parse(items) : null,
                valueField: 'value',
                labelField: 'label',
                searchField: ['label', 'value', 'text'],
                create: true,
                closeAfterSelect: true,
                maxItems: null,
                allowEmptyOption: false,
                openOnFocus: false,
                selectOnTab: true,
                placeholder: input.attr('placeholder'),
                render: {
                    option_create: function(data, escape) {
                        return '<div class="create"><strong>' + escape(data.input) + '</strong></div>';
                    },
                    option: function(data, escape) {
                        return '<div class="option">' + (data.selectize_option || escape(data.label)) + '</div>';
                    },
                    item: function(data, escape) {
                        return '<div class="item"><span>' + (data.selectize_item || escape(data.label)) + '</span></div>';
                    }
                },
                onItemRemove: function(value) {
                    // We do not want dropdown to show on removing items, but there is no such option.
                    // Here we temporarily lock the selectize to achieve it.
                    var self = input[0].selectize;
                    self.lock();
                    setTimeout( function() {
                        self.unlock();
                    },100);
                },
                load: function(input, callback) {
                    if (!input.length) return callback();
                    jQuery.ajax({
                        url: RT.Config.WebPath + '/Helpers/Autocomplete/Users',
                        type: 'GET',
                        dataType: 'json',
                        data: {
                            delim: ',',
                            term: input,
                            return: wants
                        },
                        error: function() {
                            callback();
                        },
                        success: function(res) {
                            callback(res);
                        }
                    });
                }
            });
            return;
        }

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
                if ( what == 'Tickets' ) {
                    // remove non-integers in case subject search with spaces in (like "foo bar")
                    var new_terms = [];
                    for ( var i = 0; i < terms.length; i++ ) {
                        if ( terms[i].match(/\D/) ) {
                            break; // Items after the first non-integers are all parts of search string
                        }
                        new_terms.push(terms[i]);
                    }
                    terms = new_terms;
                }
                terms.push( ui.item.value );    // add selected item
                terms.push(''); // add trailing delimeter so user can input another value directly
                this.value = terms.join(what == 'Tickets' ? ' ' : ", ");
                jQuery(this).change();

                return false;
            }
        }

        if (input.attr("data-autocomplete-autosubmit")) {
            options.select = function( event, ui ) {
                jQuery(event.target).val(ui.item.value);
                var form = jQuery(event.target).closest("form");
                if ( what === 'Queues' ) {
                    form.find('input[name=QueueChanged]').val(1);
                }
                form.submit();
            };
        }

        var queue = input.attr("data-autocomplete-queue");
        if (queue) queryargs.push("queue=" + queue);

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
