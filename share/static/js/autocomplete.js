if (!window.RT)              window.RT = {}
if (!window.RT.Autocomplete) window.RT.Autocomplete = {}

window.RT.Autocomplete.Classes = {
    Users: 'user',
    Owners: 'owner',
    Groups: 'group',
    Tickets: 'tickets',
    Queues: 'queues',
    Articles: 'articles',
    Assets: 'assets',
    Principals: 'principals',
    LinkTargets: 'link-targets'
};

{ // block scope to not expose drag_tomselect and drag_item

let drag_tomselect;
let drag_item;
TomSelect.define('rt_drag_drop', function () {
    let self = this;
    this.require('drag_drop');

    self.hook('after', 'setup', () => {
        const dragstart = function(e) {
            drag_item = e.target;
            drag_tomselect = e.target.closest('.ts-wrapper').previousSibling.tomselect;
        };

        const dragend = function(e) {
            drag_item.classList.remove('hidden');
            drop(e);
        };

        const dragenter = function(e) {
            e.preventDefault();
            if (e.target.classList.contains('ts-control')) {
                if ( drag_item.closest('.ts-control') != e.target ) {
                    drag_tomselect.removeItem(drag_item, true);
                    if ( !e.target.querySelector('.item[data-value="' + drag_item.getAttribute('data-value') + '"]') ) {
                        e.target.insertBefore(drag_item, e.target.querySelector('input'));
                    }
                }
            }
        };

        const dragover = function(e) {
            e.preventDefault();
        };

        const drop = function(e) {
            const tomselect = e.target.closest('.ts-wrapper')?.previousSibling.tomselect;
            if (tomselect && tomselect !== drag_tomselect) {
                drag_item.classList.add('hidden'); // Prevent a flash of an additional item from showing in some cases
                drag_tomselect.trigger('change', drag_tomselect.getValue());
                let values = [];
                tomselect.control.querySelectorAll('[data-value]').forEach(el => {
                    if (el.dataset.value) {
                        let value = el.dataset.value;
                        if (value) {
                            if ( value === drag_item.getAttribute('data-value') ) {
                                tomselect.createItem(value);
                            }
                            values.push(value);
                        }
                    }
                });
                tomselect.setValue(values);
            }
        };

        self.control.addEventListener('dragstart', dragstart);
        self.control.addEventListener('dragenter', dragenter);
        self.control.addEventListener('dragover', dragover);
        self.control.addEventListener('dragend', dragend);
        self.control.addEventListener('drop', drop);
    });
});

window.RT.Autocomplete.bind = function(from) {

    jQuery("input[data-autocomplete]", from).each(function(){
        var input = jQuery(this);
        var what  = input.attr("data-autocomplete");
        var wants = input.attr("data-autocomplete-return");

        if (!what || !window.RT.Autocomplete.Classes[what])
            return;

        if ( (what === 'Users' || what === 'Principals') && input.is('[data-autocomplete-multiple]')) {
            var options = input.attr('data-options');
            var items = input.attr('data-items');
            if ( input.hasClass('tomselected') ) {
                return;
            }
            new TomSelect(input.get(0),
                {
                    plugins: ['remove_button', 'rt_drag_drop'],
                    options: options ? JSON.parse(options) : null,
                    valueField: 'value',
                    labelField: 'label',
                    searchField: ['text'],
                    create: function(input) {
                        if ( input === drag_item?.getAttribute('data-value') ) {
                            return { label: drag_item?.childNodes[0].nodeValue || input, value: input };
                        }
                        return { label: input, value: input };
                    },
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
                        loading: function(data,escape) {
                            return '<div class="spinner-border spinner-border-sm ms-3"></div>';
                        }
                    },
                    load: function(query, callback) {
                        if (!query.length) return callback();
                        jQuery.ajax({
                            url: RT.Config.WebHomePath + '/Helpers/Autocomplete/' + what,
                            type: 'GET',
                            dataType: 'json',
                            data: {
                                delim: ',',
                                term: query,
                                return: wants
                            },
                            error: function() {
                                callback();
                            },
                            success: function(res) {
                                input[0].tomselect.clearOptions();
                                callback(res);
                            }
                        });
                    }
                }
            );
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
        else if (what == 'Owners') {
            options.minLength = 2;
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
            if ( what != 'Tickets' && what != 'LinkTargets' ) {
                queryargs.push("delim=,");
            }

            options.focus = function () {
                // prevent value inserted on focus
                return false;
            }

            options.select = function(event, ui) {
                var terms = this.value.split((what == 'Tickets' || what == 'LinkTargets') ? /\s+/ : /,\s*/);
                terms.pop();                    // remove current input
                if ( what == 'Tickets' || what == 'LinkTargets' ) {
                    // remove non-integers in case subject search with spaces in (like "foo bar")
                    var new_terms = [];
                    for ( var i = 0; i < terms.length; i++ ) {
                        if ( !terms[i].match(/^(?:(asset|a|group|user):)?\d+$/) ) {
                            break; // Items after the first non-integers are all parts of search string
                        }
                        new_terms.push(terms[i]);
                    }
                    terms = new_terms;
                }
                terms.push( ui.item.value );    // add selected item
                terms.push(''); // add trailing delimeter so user can input another value directly
                this.value = terms.join((what == 'Tickets' || what == 'LinkTargets') ? ' ' : ", ");
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

        var limit = input.attr("data-autocomplete-limit");
        if (limit) {
            queryargs.push("limit="+limit);
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

}

htmx.onLoad(function(){ RT.Autocomplete.bind(document) });
