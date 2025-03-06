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
            const options = input.attr('data-options');
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
        if (input.get(0).tomselect)
            return;

        const options = {};
        const queryargs = {};
        const source = RT.Config.WebHomePath + "/Helpers/Autocomplete/" + what;

        if ( wants ) {
            queryargs.return = wants;
        }

        if (what == 'Queues') {
            options.minLength = 2;
            options.delay = 2;
        }
        else if (what == 'Owners') {
            options.minLength = 2;
        }

        if (input.is('[data-autocomplete-privileged]')) {
            queryargs.privileged = 1;
        }

        if (input.is('[data-autocomplete-include-nobody]')) {
            queryargs.include_nobody = 1;
        }

        if (input.is('[data-autocomplete-include-system]')) {
            queryargs.include_system = 1;
        }

        if (input.is('[data-autocomplete-multiple]')) {
            if ( what != 'Tickets' && what != 'LinkTargets' ) {
                queryargs.delim = ',';
            }
            else {
                options.delimiter = '  '; // Intentionally use 2 spaces so we can search things with spaces in them
            }
            options.plugins = ['remove_button'];
        }
        else {
            options.maxItems = 1;
        }

        if (input.attr("data-autocomplete-autosubmit")) {
            options.onChange = function(value) {
                if ( value ) {
                    var form = input.closest("form");
                    if ( what === 'Queues' ) {
                        form.find('input[name=QueueChanged]').val(1);
                    }
                    htmx.trigger(form.get(0), 'submit');
                }
            };
        }

        if (input.is('[data-autocomplete-create]')) {
            options.create = input.attr('data-autocomplete-create') == 0 ? false : true;
        }
        else {
            options.create = true;
        }

        var queue = input.attr("data-autocomplete-queue");
        if (queue) queryargs.queue = queue;

        var checkRight = input.attr("data-autocomplete-checkright");
        if (checkRight) queryargs.right = checkRight;

        var exclude = input.attr('data-autocomplete-exclude');
        if (exclude) {
            queryargs.exclude = exclude;
        }

        var limit = input.attr("data-autocomplete-limit");
        if (limit) {
            queryargs.limit = limit;
        }

        input.addClass('autocompletes-' + window.RT.Autocomplete.Classes[what] );
        new TomSelect(input.get(0),
            {
                valueField: 'value',
                labelField: 'label',
                searchField: [], // disable local filtering
                closeAfterSelect: true,
                allowEmptyOption: false,
                openOnFocus: false,
                selectOnTab: true,
                placeholder: input.attr('placeholder'),
                render: {
                    loading: function(data,escape) {
                        return '<div class="spinner-border spinner-border-sm ms-3"></div>';
                    }
                },
                load: function(query, callback) {
                    if (!query.length) return callback();
                    queryargs.term = query;
                    jQuery.ajax({
                        url: source,
                        type: 'GET',
                        dataType: 'json',
                        data: queryargs,
                        error: function() {
                            callback();
                        },
                        success: function(res) {
                            input[0].tomselect.clearOptions();
                            callback(res);
                        }
                    });
                },
                onFocus: function() {
                    // On focus, show an empty input to make it less confusing
                    // to start typing immediately to find a new value
                    // with autocomplete.
                    if (this.settings.maxItems === 1) { // single select
                        this.currentValue = this.getValue();
                        this.setValue(null, true);
                    }
                },
                onChange: function(value) {
                    if (this.settings.maxItems === 1) {
                        delete this.currentValue;
                    }
                },
                onBlur: function() {
                    if (this.settings.maxItems === 1 && this.hasOwnProperty('currentValue')) {
                        // If no new value was selected, restore the original value
                        this.setValue(this.currentValue, true);
                        delete this.currentValue;
                    }
                },
                ...options
            }
        );
    });
};

}

htmx.onLoad(function(elt){ RT.Autocomplete.bind(elt) });
