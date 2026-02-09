/* Visibility */

function show(id) { delClass( id, 'hidden' ) }
function hide(id) { addClass( id, 'hidden' ) }

/* Transaction Filter Functions */

function transactionFilterSelectAll(clickedLink, event) {
    if (event) {
        event.preventDefault();
        event.stopPropagation();
    }
    var form = jQuery(clickedLink).closest('.transaction-filter-form');
    var checkboxes = form.find('input[name="FilterTxnTypes"]:checkbox');
    checkboxes.prop('checked', true);
    return false;
}

function transactionFilterSelectNone(clickedLink, event) {
    if (event) {
        event.preventDefault();
        event.stopPropagation();
    }
    var form = jQuery(clickedLink).closest('.transaction-filter-form');
    var checkboxes = form.find('input[name="FilterTxnTypes"]:checkbox');
    checkboxes.prop('checked', false);
    return false;
}

function hideshow(id) { return toggleVisibility( id ) }
function toggleVisibility(id) {
    var e = jQuery('#' + id);

    if ( e.hasClass('hidden') ) {
        e.removeClass('hidden');
    }
    else {
        e.addClass('hidden');
    }

    return false;
}

function setVisibility(id, visibility) {
    if ( visibility ) show(id);
    else hide(id);
}

function switchVisibility(id1, id2) {
    // Show both and then hide the one we want
    show(id1);
    show(id2);
    hide(id2);
    return false;
}

function toggle_upgrade_history(widget, selector) {
    jQuery(selector).toggle();
    jQuery(widget).toggleClass("rolled-up");
}

/* Classes */
function jQueryWrap( id ) {
    return typeof id == 'object' ? jQuery(id) : jQuery('#'+id);
}

function addClass(id, value) {
    jQueryWrap(id).addClass(value);
}

function delClass(id, value) {
    jQueryWrap(id).removeClass(value);
}

/* other utils */

function getClosestInputElements(input) {
    // Find inputs within the current form or collection list, whichever is closest.
    var container = jQuery(input).closest("form, table.collection-as-table").get(0);
    if ( container ) {
        return container.getElementsByTagName('input');
    }
    else {
        return [];
    }
}

function setCheckbox(input, name, val, fireClickHandler) {
    if (val == null) val = input.checked;

    var is_set_event = false;
    if ( !name ) {
        name = input.name || input.attr('name');
        is_set_event = true;
    }
    else if (input.name) {
        var allfield = jQuery('input[name=' + input.name + ']');
        allfield.prop('checked', val);
    }

    var checked_count = 0;
    var field_count = 0;
    var myfield = getClosestInputElements(input);
    for ( var i = 0; i < myfield.length; i++ ) {
        if ( myfield[i].type != 'checkbox' ) continue;
        if ( name ) {
            if ( name instanceof RegExp ) {
                if ( ! myfield[i].name.match( name ) ) continue;
            }
            else {
                if ( myfield[i].name != name ) continue;
            }

        }

        if ( is_set_event ) {
            field_count++;
            if ( myfield[i].checked ) {
                checked_count++;
            }
        }
        else {
            // if we're changing the checked state
            if (!(myfield[i].checked) != !val) {
                if (fireClickHandler) {
                    jQuery(myfield[i]).trigger('click');
                }
                else {
                    myfield[i].checked = val;
                }
            }
        }
    }

    if ( is_set_event ) {
        var allfield = jQuery('input[name=' + name + 'All' + ']');
        if (field_count == checked_count) {
            allfield.prop('checked', true);
        }
        else {
            allfield.prop('checked', false);
        }
    }
}

/* apply callback to nodes or elements */

function walkChildNodes(parent, callback)
{
    if( !parent || !parent.childNodes ) return;
    var list = parent.childNodes;
    for( var i = 0; i < list.length; i++ ) {
        callback( list[i] );
    }
}

function walkChildElements(parent, callback)
{
    walkChildNodes( parent, function(node) {
        if( node.nodeType != 1 ) return;
        return callback( node );
    } );
}

/* shredder things */

function showShredderPluginTab( plugin )
{
    var plugin_tab_id = 'shredder-plugin-'+ plugin +'-tab';
    var root = jQuery('#shredder-plugin-tabs');
    
    root.children(':not(.hidden)').addClass('hidden');
    root.children('#' + plugin_tab_id).removeClass('hidden');

    if( plugin ) {
        show('shredder-submit-button');
    } else {
        hide('shredder-submit-button');
    }
}

function checkAllObjects()
{
    var check = jQuery('#shredder-select-all-objects-checkbox').prop('checked');
    var elements = jQuery('#shredder-search-form :checkbox[name=WipeoutObject]');

    if( check ) {
        elements.prop('checked', true);
    } else {
        elements.prop('checked', false);
    }
}

function checkboxToInput(target,checkbox,val){    
    var tar = jQuery('#' + escapeCssSelector(target));
    var box = jQuery('#' + escapeCssSelector(checkbox));

    var emails = jQuery.grep(tar.val().split(/,\s*/), function(email) {
        return email.match(/\S/) ? true : false;
    });

    if(box.prop('checked')){
        if ( emails.indexOf(val) == -1 ) {
            emails.push(val);
        }
    }
    else{
        emails = jQuery.grep(emails, function(email) {
            return email != val;
        });
    }
    jQuery('#UpdateIgnoreAddressCheckboxes').val(true);

    var tomselect = tar[0].tomselect;
    if ( tomselect ) {
        if( box.prop('checked') ) {
            tomselect.createItem(val);
            tomselect.addItem(val, true);
        }
        else {
            tomselect.removeItem(val, true);
        }
    }
    tar.val(emails.join(', ')).change();
}

function checkboxesToInput(target,checkboxes) {
    var tar = jQuery('#' + escapeCssSelector(target));

    var emails = jQuery.grep(tar.val().split(/,\s*/), function(email) {
        return email.match(/\S/) ? true : false;
    });

    var tomselect = tar[0].tomselect;
    var added = [];
    var removed = [];

    jQuery(checkboxes).each(function(index, checkbox) {
        var val = jQuery(checkbox).attr('data-address');
        if(jQuery(checkbox).prop('checked')){
            if ( emails.indexOf(val) == -1 ) {
                emails.push(val);
                added.push(val);
            }
        }
        else{
            emails = jQuery.grep(emails, function(email) {
                return email != val;
            });
            removed.push(val);
        }
    });

    if ( tomselect ) {

        // Add new items in one call to avoid triggering
        // ticketSyncOneTimeCheckboxes multiple times during the update
        // as it could wrongly sync the incomplete input values back to
        // checkboxes.

        tomselect.addItems(added, true);
        for ( const item of removed ) {
            tomselect.removeItem(item, true);
        }
    }

    jQuery('#UpdateIgnoreAddressCheckboxes').val(true);
    tar.val(emails.join(', ')).change();
}

// ahah for back compatibility as plugins may still use it
function ahah( url, id ) {
    jQuery('#'+id).load(url);
}

// only for back compatibility, please JQuery() instead
function doOnLoad( js ) {
    jQuery(js);
}

function initDatePicker(elem) {
    if ( !elem ) {
        elem = document.querySelector('body');
    }

    const today = new Date();
    today.setHours(0, 0, 0, 0); // Set default time to 00:00:00

    const icons = {
        type: 'sprites',
        time: RT.Config.WebPath + '/NoAuth/css/icons.svg#clock',
        date: RT.Config.WebPath + '/NoAuth/css/icons.svg#calendar-week',
        up: RT.Config.WebPath + '/NoAuth/css/icons.svg#arrow-up',
        down: RT.Config.WebPath + '/NoAuth/css/icons.svg#arrow-down',
        previous: RT.Config.WebPath + '/NoAuth/css/icons.svg#left',
        next: RT.Config.WebPath + '/NoAuth/css/icons.svg#right',
        today: RT.Config.WebPath + '/NoAuth/css/icons.svg#calendar-check',
        clear: RT.Config.WebPath + '/NoAuth/css/icons.svg#trash',
        close: RT.Config.WebPath + '/NoAuth/css/icons.svg#close',
    };

    const opts = {
        date: {
            useCurrent: false,
            display: {
                icons: icons,
                calendarWeeks: false,
                viewMode: 'calendar',
                toolbarPlacement: 'bottom',
                keepOpen: false,
                buttons: {
                    today: true,
                    clear: true,
                    close: true
                },
                components: {
                    calendar: true,
                    date: true,
                    month: true,
                    year: true,
                    decades: true,
                    clock: false
                },
                inline: false,
                theme: document.querySelector('html').getAttribute('data-bs-theme')
            },
            localization: {
                ...(RT.I18N.Catalog.date_time_picker),
                format: "yyyy-MM-dd"
            }
        },
        datetime: {
            useCurrent: false,
            viewDate: today,
            promptTimeOnDateChange: true,
            display: {
                icons: icons,
                sideBySide: false,
                calendarWeeks: false,
                viewMode: 'calendar',
                toolbarPlacement: 'bottom',
                keepOpen: false,
                buttons: {
                    today: true,
                    clear: true,
                    close: true
                },
                components: {
                    calendar: true,
                    date: true,
                    month: true,
                    year: true,
                    decades: true,
                    clock: true,
                    hours: true,
                    minutes: true,
                    seconds: false,
                },
                inline: false,
                theme: document.querySelector('html').getAttribute('data-bs-theme')
            },
            localization: {
                ...(RT.I18N.Catalog.date_time_picker),
                format: "yyyy-MM-dd HH:mm:ss",
                hourCycle: 'h23'
            }
        }
    };
    elem.querySelectorAll(".datepicker").forEach(elt => {
        if ( elt.classList.contains("withtime") ) {
            elt.tempusDominus = new tempusDominus.TempusDominus(elt, opts.datetime);
        }
        else {
            elt.tempusDominus = new tempusDominus.TempusDominus(elt, opts.date);
        }

        // Fired when date selection is changed
        elt.addEventListener('change.td', (event) => {
            jQuery(event.target).closest('form').data('changed', true);
        });
    });
}

function textToHTML(value) {
    return value.replace(/&/g,    "&amp;")
                .replace(/</g,    "&lt;")
                .replace(/>/g,    "&gt;")
                .replace(/-- \n/g,"--&nbsp;\n")
                .replace(/\n/g,   "\n<br />");
};


// Initialize the tom-select library
function initializeSelectElement(elt) {
    let settings = {
        allowEmptyOption: true,
        maxOptions: null,
        plugins: {},
        render: {
            loading: function(data,escape) {
                return '<div class="spinner-border spinner-border-sm ms-3"></div>';
            }
        }
    };

    settings.onDropdownOpen = function (dropdown) {
        // Hide the dropdown temporarily to avoid the possible flash when dropdown becomes dropup.
        dropdown.style.visibility = 'hidden';
        setTimeout(function() {
            let bounding = dropdown.getBoundingClientRect();
            // Use dropup if there's room above and dropdown extends below viewport or document bottom
            // dropup shows above the control element (.ts-control), so we need to subtract its height
            const top = bounding.top - dropdown.previousElementSibling.offsetHeight;
            if ((top > bounding.height && bounding.bottom > window.innerHeight) ||
                (top + window.scrollY > bounding.height && bounding.bottom + window.scrollY > document.documentElement.scrollHeight)) {
                dropdown.classList.add('dropup');
            }
            dropdown.style.visibility = 'visible';
        }, 0);
    };

    settings.onDropdownClose = function (dropdown) {
        // Remove focus after a value is selected
        this.blur();
        dropdown.classList.remove('dropup');
        // If dropdown was closed by Tab, move focus to the next/previous element
        if (this._closingByTab) {
            const shiftKey = this._closingByTabShift;
            this._closingByTab = false;
            this._closingByTabShift = false;
            // Use setTimeout to let tom-select finish its focus handling first
            setTimeout(() => {
                // Find all focusable elements, excluding tom-select's hidden elements
                const focusable = Array.from(document.querySelectorAll(
                    'a[href], button:not([disabled]), input:not([disabled]):not([type="hidden"]), select:not([disabled]):not(.tomselected), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'
                )).filter(el => el.offsetParent !== null && !el.closest('.ts-dropdown')); // visible and not in dropdown
                const currentIndex = focusable.indexOf(this.control);
                if (currentIndex !== -1) {
                    const nextIndex = shiftKey ? currentIndex - 1 : currentIndex + 1;
                    if (nextIndex >= 0 && nextIndex < focusable.length) {
                        focusable[nextIndex].focus();
                    }
                }
            }, 0);
        }
    };

    if ( elt.options && elt.options.length < RT.Config.SelectLiveSearchLimit ) {
        // Under the config limit, don't show the search input box,
        // just a regular dropdown.
        settings.controlInput = null;
    }
    else {
        settings.plugins["dropdown_input"] = {};
    }

    if (elt.classList.contains('rt-autocomplete')) {
        settings.placeholder = elt.getAttribute('placeholder');
        settings.closeAfterSelect = true;
        settings.allowEmptyOption = false;
        if (elt.hasAttribute('data-autocomplete-multiple')) {
            settings.delimiter = ",  ";
            settings.plugins['remove_button'] = {};
        }
        else {
            settings.maxItems = 1;
            settings.plugins['clear_button'] = {
                html: function () {
                    return '<div class="clear-button" title="' + RT.I18N.Catalog['remove'] + '">×</div>';
                }
            };
        }

        if (elt.getAttribute('data-autocomplete-create')) {
            settings.create = elt.getAttribute('data-autocomplete-create') == 0 ? false : true;
        }
        else {
            settings.create = true;
        }

        if ( elt.getAttribute('data-options') ) {
            settings.options = JSON.parse(elt.getAttribute('data-options'));
        }
        else if ( elt.getAttribute('data-options-source') ) {
            settings.load = function(query, callback) {
                if (!query.length) return callback();
                jQuery.ajax({
                    url: elt.getAttribute('data-options-source'),
                    type: 'GET',
                    dataType: 'json',
                    data: {
                        term: query
                    },
                    error: function() {
                        callback();
                    },
                    success: function(res) {
                        elt.tomselect.clearOptions();
                        callback(res);
                    }
                });
            };
            settings.labelField = 'label';
            settings.searchField = []; // disable local filtering
        }
        else {
            return; // No options mean not ready to initialize yet
        }
    }

    const ts = new TomSelect(elt, settings);

    // Track Tab key to allow single-Tab navigation through dropdowns
    // with dropdown_input plugin
    if (ts.control_input) {
        ts.control_input.addEventListener('keydown', function (e) {
            if (e.key === 'Tab') {
                ts._closingByTab = true;
                ts._closingByTabShift = e.shiftKey;
            }
        });
    }

    // If the default value is not in the options, add it.
    const value = elt.value || elt.getAttribute('data-value');
    if ( value ) {
        let values = [];
        if ( Array.isArray(value) ) {
            values = value;
        }
        else {
            if ( elt.hasAttribute('data-autocomplete-multiple') ) {
                values = value.split(",  ");
            }
            else {
                values = [ value ];
            }
        }
        values.forEach(value => {
            if ( !elt.tomselect.getItem(value) ) {
                elt.tomselect.createItem(value, true);
                elt.tomselect.addItem(value, true);
            }
        });
    }
}

// Initialize the tom-select library
function initializeSelectElements(elt) {

    // The selectpicker class was used by the bootstrap-select
    // JS library as the default. We retained it because tom-select
    // allows you to set any class value and all of the RT dropdowns
    // already had 'selectpicker'.

    elt.querySelectorAll('select.selectpicker:not(.tomselected)').forEach(initializeSelectElement);
    elt.querySelectorAll('input.rt-autocomplete:not(.tomselected)').forEach(initializeSelectElement);
}

function ReplaceAllTextareas(elt) {
    window.RT.CKEditor ||= { "instances": {} };

    elt ||= document;
    // replace all content and signature message boxes
    var allTextAreas = elt.getElementsByTagName("textarea");

    for ( const textArea of allTextAreas ) {
        if (textArea.classList.contains("richtext")) {
            // Turn the original plain text content into HTML
            const type = document.querySelector('[name="'+textArea.name+'Type"]').value;
            if (type != "text/html")
                textArea.value = textToHTML(textArea.value);

            // Set the type
            type.value = "text/html";

            let height;
            if ( textArea.classList.contains('messagebox') ) {
                // * The "messagebox" class is used for ticket correspondence/comment content.
                // * For a long time this was the only use of the CKEditor and it was given its own
                //   user/system configuration option.
                // * Continue using this config option for those CKEditor instances
                height = RT.Config.MessageBoxRichTextHeight + 'px';
            }
            else if ( textArea.name == 'Description') {
                // The Description edit box on ticket display loads hidden, so textArea.offsetHeight
                // is 0, which means the calculations below don't work.
                // Get rows directly and convert them to ems as a rough translation for row height.
                height = textArea.rows + 'em';
            }
            else {
                // * For all CKEditor instances without the "messagebox" class we instead base the
                //   (editable) height on the size of the textarea element it's replacing.
                //   The height does not include any toolbars, the status bar, or other "overhead".
                // * The CKEditor box adds some additional padding around the edit area.
                // * Specifically, in one browser/styling:
                //   * there's 42px more top/bottom margin in the CKEditor than there is in the textarea
                //   * the gap between lines is 3px taller in the CKEditor than it is in the textarea
                //   + each new paragraph in the CKEditor adds an additional 13px to the gap between lines
                //   So an adjustment of 54 px is added to create an area that will hold about 4/5
                //   lines of text, similar to the plain text box. It will not scale the same for textareas
                //   with different number of rows
                height = textArea.offsetHeight + 54;
                height += 'px';
            }

            // Customize shouldNotGroupWhenFull based on textarea width
            const initArgs = JSON.parse(JSON.stringify(RT.Config.MessageBoxRichTextInitArguments));
            initArgs.toolbar.shouldNotGroupWhenFull = textArea.offsetWidth >= 600 ? true : false;

            // Load core CKEditor plugins
            const corePlugins = [];
            for (const plugin of initArgs.plugins || []) {
                if (CKEDITOR?.[plugin]) {
                    corePlugins.push(CKEDITOR[plugin]);
                } else {
                    console.error(`Core CKEditor plugin "${plugin}" not found.`);
                }
            }

            // Load extra plugins
            // The source JS must already be loaded by the extension.
            const thirdPartyPlugins = [];
            for (const plugin of initArgs.extraPlugins || []) {
                if (window[plugin]?.[plugin]) {
                    thirdPartyPlugins.push(window[plugin][plugin]);
                } else {
                    console.error(`Extra CKEditor plugin "${plugin}" not found.`);
                }
            }

            // Combine core and third-party plugins
            initArgs.plugins = [...corePlugins, ...thirdPartyPlugins];
            initArgs.extraPlugins = []; // Clear extraPlugins as they're now included

            initArgs.emoji.definitionsUrl = RT.Config.WebURL + initArgs.emoji.definitionsUrl;

            CKEDITOR.ClassicEditor
                .create( textArea, initArgs )
                .then(editor => {
                    RT.CKEditor.instances[editor.sourceElement.name] = editor;
                    // the height of element(.ck-editor__editable_inline) is reset on focus,
                    // here we set height of its parent(.ck-editor__main) instead.
                    editor.ui.view.editable.element.parentNode.style.height = height;
                    AddAttachmentWarning(editor);

                    const parse_cf = /^Object-([\w:]+)-(\d*)-CustomField(?::\w+)?-(\d+)-(.*)$/;
                    const parsed = parse_cf.exec(editor.sourceElement.name);
                    if (parsed) {
                        const name_filter_regex = new RegExp(
                            "^Object-" + parsed[1] + "-" + parsed[2] +
                            "-CustomField(?::\\w+)?-" + parsed[3] + "-" + parsed[4] + "$"
                        );
                        editor.model.document.on('change:data', () => {
                            const value = editor.getData();
                            jQuery('textarea.richtext').filter(function () {
                                return RT.CKEditor.instances[this.name] && name_filter_regex.test(this.name);
                            }).not(jQuery(editor.sourceElement)).each(function () {
                                if ( RT.CKEditor.instances[this.name].getData() !== value ) {
                                    RT.CKEditor.instances[this.name].setData(value);
                                };
                            });
                        });
                    }
                    editor.on('destroy', () => {
                        if (RT.CKEditor.instances[editor.sourceElement.name]) {
                            delete RT.CKEditor.instances[editor.sourceElement.name];
                        }
                    });
                })
                .catch( error => {
                    console.error( error );
                } );
        }
    }
};


function AddAttachmentWarning(richTextEditor) {
    var plainMessageBox  = jQuery('.messagebox');
    if (plainMessageBox.hasClass('suppress-attachment-warning')) return;

    var warningMessage   = jQuery('.messagebox-attachment-warning');
    var ignoreMessage    = warningMessage.find('.ignore');
    var dropzoneElement  = jQuery('#attach-dropzone');
    var fallbackElement  = jQuery('.old-attach');
    var reuseElements    = jQuery('#reuse-attachments');

    var messageBoxName = plainMessageBox.attr('name');
    var regex = new RegExp(loc_key("attachment_warning_regex"), "i");

    // if the quoted text or signature contains the magic word
    // then we can't do much here, because the user can make any text
    // changes they want and there's no real way to track the provenance of
    // the word "attachment"
    var ignoreMessageText = ignoreMessage.text();
    if (ignoreMessageText && ignoreMessageText.match(regex)) {
        return;
    }

    // a true value for instant means no CSS animation, for displaying the
    // warning at page load time
    var toggleAttachmentWarning = function (instant) {
        var text;
        if (richTextEditor) {
            text = richTextEditor.getData();
        }
        else {
            text = plainMessageBox.val();
        }

        // look for checked reuse attachment checkboxes
        var has_reused_attachments = reuseElements
                                        .find('input[type=checkbox]:checked')
                                        .length;

        // if the word "attach" appears and there are no attachments in flight
        var needsWarning = text &&
                           text.match(regex) &&
                           !dropzoneElement.hasClass('has-attachments') &&
                           !jQuery('a.delete-attach').length &&
                           !has_reused_attachments;

        if (needsWarning) {
            warningMessage.show(instant ? 1 : 'fast');
        }
        else {
            warningMessage.hide(instant ? 1 : 'fast');
        }
    };

    // don't run all the machinery (including regex matching a potentially very
    // long message) several times per keystroke
    var timer;
    var delayedAttachmentWarning = function () {
        if (timer) {
            return;
        }

        timer = setTimeout(function () {
            timer = 0;
            toggleAttachmentWarning();
        }, 200);
    };

    var listenForAttachmentEvents = function () {
        if (richTextEditor) {
            richTextEditor.model.document.on( 'change:data', () => {
                delayedAttachmentWarning();
            });
        }
        else {
            plainMessageBox.bind('input', function () {
                delayedAttachmentWarning();
            });
        }

        dropzoneElement.on('attachment-change', function () {
            toggleAttachmentWarning();
        });

        reuseElements.on('change', 'input[type=checkbox]',
            function () {
                toggleAttachmentWarning();
            }
        );
    };

    // if dropzone has already tried and failed, don't show spurious warnings
    if (!fallbackElement.hasClass('hidden')) {
        return;
    }
    // if dropzone has already attached...
    else if (dropzoneElement.hasClass('dropzone-init')) {
        listenForAttachmentEvents();

        // also need to display the warning on initial page load
        toggleAttachmentWarning(1);
    }
    // otherwise, wait for dropzone to initialize and then add attachment
    // warnings
    else {
        dropzoneElement.on('dropzone-fallback', function () {
            // do nothing. no dropzone = no attachment warnings
        });

        dropzoneElement.on('dropzone-init', function () {
            listenForAttachmentEvents();
            toggleAttachmentWarning(1);
        });
    }
}


function toggle_addprincipal_validity(input, good, title) {
    if (good) {
        jQuery(input).nextAll(".invalid-feedback").addClass('hidden');
        jQuery(input).removeClass('is-invalid');
        jQuery("#acl-AddPrincipal input[type=checkbox]").removeAttr("disabled");
    } else {
        jQuery(input).nextAll(".invalid-feedback").removeClass('hidden');
        jQuery(input).addClass('is-invalid');
        jQuery("#acl-AddPrincipal input[type=checkbox]").attr("disabled", "disabled");
    }

    if (title == null)
        title = jQuery(input).val();

    update_addprincipal_title( title );
}

function update_addprincipal_title(title) {
    var h3 = jQuery("#acl-AddPrincipal h3");
    h3.text( h3.text().replace(/: .*$/,'') + ": " + title );
}

// when a value is selected from the autocompleter
function addprincipal_onselect(ev, ui) {

    // if principal link exists, we shall go there instead
    var principal_link = jQuery(ev.target).closest('form').find('a[href="#acl-' + ui.item.id + '"]:first');
    if (principal_link.length) {
        jQuery(this).val('').blur();
        update_addprincipal_title( '' ); // reset title to blank for #acl-AddPrincipal
        principal_link.click();
        return false;
    }

    // pass the item's value along as the title since the input's value
    // isn't actually updated yet
    toggle_addprincipal_validity(this, true, ui.item.value);
}

// when the input is actually changed, through typing or autocomplete
function addprincipal_onchange(ev, ui) {
    // if we have a ui.item, then they selected from autocomplete and it's good
    if (!ui.item) {
        var input = jQuery(this);
        // Check using the same autocomplete source if the value typed would
        // have been autocompleted and is therefore valid
        jQuery.ajax({
            url: input.autocomplete("option", "source"),
            data: {
                op: "=",
                term: input.val()
            },
            dataType: "json",
            success: function(data) {
                if (data)
                    toggle_addprincipal_validity(input, data.length ? true : false );
                else
                    toggle_addprincipal_validity(input, true);
            }
        });
    } else {
        toggle_addprincipal_validity(this, true);
    }
}

function escapeCssSelector(str) {
    return str.replace(/([^A-Za-z0-9_-])/g,'\\$1');
}

function escapeRegExp(str) {
    return str.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"); // $& means the whole matched string
}

function escapeHTML(str) {
    if (!str) {
        return str;
    }

    return str
        .replace(/&/g, "&#38;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/\(/g, "&#40;")
        .replace(/\)/g, "&#41;")
        .replace(/"/g, "&#34;")
        .replace(/'/g, "&#39;");
}

function createCookie(name,value,days) {
    var path = RT.Config.WebPath ? RT.Config.WebPath : "/";

    if (days) {
        var date = new Date();
        date.setTime(date.getTime()+(days*24*60*60*1000));
        var expires = "; expires="+date.toGMTString();
    }
    else
        expires = "";

    document.cookie = name+"="+encodeURIComponent(value)+expires+"; path="+path+";SameSite=lax";
}

function getCookie(name) {
    return decodeURIComponent(document.cookie.split(/;\s*/).find((row) => row.startsWith(name + "="))?.split("=")[1]);
}

function loadCollapseStates(elt) {
    var cookies = document.cookie.split(/;\s*/);
    var len     = cookies.length;

    for (var i = 0; i < len; i++) {
        var c = cookies[i].split('=');

        if (c[0].match(/^(TitleBox--|accordion-)/)) {
            var e   = elt.querySelector('[id="' + c[0] + '"]');
            if (e) {
                if (c[1] != 0) {
                    jQuery(e).collapse('show');
                }
                else {
                    jQuery(e).collapse('hide');
                }
            }
        }
    }
}

function expandCalendar(elt) {
    // Expand multi-day calendar events
    // Use batched reads/writes to avoid layout thrashing
    elt.querySelectorAll('table.rt-calendar tr').forEach(row => {
        const firstDays = Array.from(row.querySelectorAll('div.ticket-entry.first-day:not(.last-day)'));

        // Phase 1: Batch all DOM reads to avoid forced reflows
        const measurements = firstDays.map(firstDayElt => {
            const class_selector = '.' + Array.from(firstDayElt.classList).filter(name => ( name !== 'first-day' ) && ( name !== 'first-day-week' ) ).join('.');
            const entries = row.querySelectorAll(class_selector + '[data-object="' + firstDayElt.getAttribute('data-object') + '"]');

            if (entries.length > 1) {
                const lastDay = entries[entries.length - 1];
                // if last div has last-day class adjust width so right side border shows
                const lastDayAdjustment = lastDay.classList.contains('last-day')
                    ? parseFloat(window.getComputedStyle(lastDay).borderRightWidth)
                    : 0;
                const width = lastDay.getBoundingClientRect().right - firstDayElt.getBoundingClientRect().left - lastDayAdjustment;

                return {
                    element: firstDayElt,
                    width: width
                };
            }
            return null;
        }).filter(Boolean);

        // Phase 2: Batch all DOM writes
        measurements.forEach(({ element, width }) => {
            element.style.width = width + 'px';
        });
    });
}

// Debounced resize handler to avoid excessive reflows during window resize
let expandCalendarResizeTimeout;
window.addEventListener('resize', () => {
    clearTimeout(expandCalendarResizeTimeout);
    expandCalendarResizeTimeout = setTimeout(() => {
        expandCalendar(document);
    }, 150);
});

function revealHistoryWidget() {
    document.querySelector('.htmx-load-widget[hx-get$="/Widgets/Display/History"]:not([data-hx-revealed="true"])')
        ?.scrollIntoView({
            behavior: 'instant',
            block: 'start'
        });
}

function fixupSearchFilterModal(elt,evt) {
    var modal = jQuery(elt).closest('.modal.search-results-filter');
    var filterLink = jQuery(elt).closest('th').find('a.search-filter');

    modal.css('top', jQuery(filterLink).offset().top);
    var left = jQuery(filterLink).offset().left;
    modal.find('div.modal-content').css('max-height', jQuery(window).height() - jQuery(filterLink).offset().top - 10);
    modal.on('shown.bs.modal', function() {
        // 10 is extra space to move modal a bit away from edge
        if ( left + modal.width() + 10 > jQuery('body').width() ) {
            left = jQuery('body').width() - modal.width() - 10;
        }
        modal.css('left', left);
        // Mark modal as left or right based on position, so we can apply different styles on tomselect dropdowns.
        if ( left + 0.5 * modal.width() <= 0.5 * jQuery('body').width() ) {
            modal.addClass('modal-left').removeClass('modal-right');
        }
        else {
            modal.addClass('modal-right').removeClass('modal-left');
        }

        if ( modal.find('[data-autocomplete], .selectpicker').length ) {
            modal.find('.modal-dialog-scrollable').removeClass('modal-dialog-scrollable');
        }
    });

    // Do not show the modal if it's triggered by initial load
    if ( evt.detail.requestConfig.triggeringEvent ) {
        modal.modal('show');
    }
};

// Process the added filter criteria and update the Query
function filterSearchResults(evt,type) {
    var clauses = [];

    if ( type === 'RT::Tickets' ) {

        var queue_clauses = [];
        jQuery('.search-results-filter input[name=Queue]:checked').each(function() {
            queue_clauses.push( 'Queue = ' + '"' + jQuery(this).val() + '"' );
        });

        if ( queue_clauses.length ) {
            clauses.push( '( ' + queue_clauses.join( ' OR ' ) + ' )' );
        }

        var sla_clauses = [];
        jQuery('.search-results-filter input[name=SLA]:checked').each(function() {
            var value = jQuery(this).val();
            if ( value == 'NULL' ) {
                sla_clauses.push( 'SLA IS NULL' );
            }
            else {
                sla_clauses.push( 'SLA = ' + '"' + value + '"' );
            }
        });

        var type_clauses = [];
        jQuery('.search-results-filter input[name=Type]:checked').each(function() {
            type_clauses.push('Type = ' + '"' + jQuery(this).val() + '"' );
        });

        if ( type_clauses.length ) {
            clauses.push( '( ' + type_clauses.join( ' OR ' ) + ' )' );
        }

        var subject = jQuery('.search-results-filter input[name=Subject]').val();
        if ( subject && subject.match(/\S/) ) {
            clauses.push( '( Subject LIKE "' + subject.replace(/(["\\])/g, "\\$1") + '" )' );
        }

        const description = jQuery('.search-results-filter input[name=Description]').val();
        if ( description && description.match(/\S/) ) {
            clauses.push( '( Description LIKE "' + description.replace(/(["\\])/g, "\\$1") + '" )' );
        }

        jQuery('.search-results-filter :input[name=Owner]').each(function() {
            var value = jQuery(this).val();
            if ( value && value.match(/\S/) ) {
                clauses.push( 'Owner.Name = ' + '"' + value + '"' );
            }
        });

        [ 'Requestors', 'Requestor', 'Cc', 'AdminCc' ].forEach( function(role) {
            var value = jQuery('.search-results-filter input[name=' + role + ']').val();
            if ( value && value.match(/\S/) ) {
                clauses.push( role + '.EmailAddress = ' + "'" + value + "'" );
            }
        });


        [ 'Told', 'Starts', 'Started', 'Due', 'Resolved', 'Priority', 'InitialPriority', 'FinalPriority', 'TimeWorked', 'TimeEstimated', 'TimeLeft' ].forEach(function(type) {
            var subs = [];
            [ 'EqualTo', 'GreaterThan', 'LessThan' ].forEach( function(op) {
                var value = jQuery('.search-results-filter :input[name=' + type + op + ']').val();
                if ( value && value.match(/\S/) ) {
                    if ( value.match(/\D/) ) {
                        value = "'" + value + "'";
                    }

                    if ( op == 'EqualTo' ) {
                        subs.push( type + ' = ' + value  );
                    }
                    else if ( op == 'GreaterThan' ) {
                        subs.push( type + ' > ' + value  );
                    }
                    else {
                        subs.push( type + ' < ' + value  );
                    }
                }
            });
            if ( subs.length ) {
                clauses.push( '( ' + subs.join( ' AND ' ) + ' )' );
            }
        });
    }
    else if ( type === 'RT::Assets' ) {

        var catalog_clauses = [];
        jQuery('.search-results-filter input[name=Catalog]:checked').each(function() {
            catalog_clauses.push( 'Catalog = ' + '"' + jQuery(this).val() + '"' );
        });

        if ( catalog_clauses.length ) {
            clauses.push( '( ' + catalog_clauses.join( ' OR ' ) + ' )' );
        }

        [ 'Owner', 'HeldBy', 'Contact' ].forEach( function(role) {
            var value = jQuery('.search-results-filter input[name=' + role + ']').val();
            if ( value && value.match(/\S/) ) {
                if ( value.match(/@/) ) {
                    clauses.push( role + '.EmailAddress = ' + "'" + value + "'" );
                }
                else {
                    clauses.push( role + '.Name = ' + "'" + value + "'" );
                }
            }
        });

        [ 'Name', 'Description' ].forEach( function(item) {
            var value = jQuery('.search-results-filter input[name=' + item + ']').val();
            if ( value && value.match(/\S/) ) {
                clauses.push( '( ' + item + ' LIKE "' + value.replace(/(["\\])/g, "\\$1") + '" )' );
            }
        });
    }


    var status_clauses = [];
    jQuery('.search-results-filter input[name=Status]:checked').each(function() {
        status_clauses.push('Status = ' + '"' + jQuery(this).val() + '"' );
    });

    if ( status_clauses.length ) {
        clauses.push( '( ' + status_clauses.join( ' OR ' ) + ' )' );
    }

    jQuery('.search-results-filter input[name^=CustomRole]').each(function() {
        var role = jQuery(this).attr('name');
        var value = jQuery(this).val();
        if ( value && value.match(/\S/) ) {
            clauses.push( role + '.EmailAddress = ' + '"' + value + '"' );
        }
    });

    [ 'Creator', 'LastUpdatedBy' ].forEach( function(role) {
        var value = jQuery('.search-results-filter input[name=' + role + ']').val();
        if ( value && value.match(/\S/) ) {
            var subs = [];
            clauses.push( role + ' = "' + value + '"' );
        }
    });

    [ 'id', 'Created', 'LastUpdated' ].forEach(function(type) {
        var subs = [];
        [ 'EqualTo', 'GreaterThan', 'LessThan' ].forEach( function(op) {
            var value = jQuery('.search-results-filter :input[name=' + type + op + ']').val();
            if ( value && value.match(/\S/) ) {
                if ( value.match(/\D/) ) {
                    value = "'" + value + "'";
                }

                if ( op == 'EqualTo' ) {
                    subs.push( type + ' = ' + value  );
                }
                else if ( op == 'GreaterThan' ) {
                    subs.push( type + ' > ' + value  );
                }
                else {
                    subs.push( type + ' < ' + value  );
                }
            }
        });
        if ( subs.length ) {
            clauses.push( '( ' + subs.join( ' AND ' ) + ' )' );
        }
    });

    jQuery('.search-results-filter input[name^=CustomField]:not(:checkbox)').each(function() {
        var name = jQuery(this).attr('name');
        var value = jQuery(this).val();
        if ( value && value.match(/\S/) ) {
            clauses.push( "( '" + name + "'" + ' LIKE "' + value.replace(/(["\\])/g, "\\$1") + '" )' );
        }
    });

    var cf_select = {};
    jQuery('.search-results-filter input[name^=CustomField]:checkbox:checked').each(function() {
        var name = jQuery(this).attr('name');
        var value = jQuery(this).val();
        if ( !cf_select[name] ) {
            cf_select[name] = [];
        }
        cf_select[name].push(value);
    });
    jQuery.each(cf_select, function(name, values) {
        var subs = [];
        values.forEach(function(value) {
            subs.push( "'" + name + "'" + ' = ' + '"' + value + '"' );
        });
        clauses.push( '( ' + subs.join( ' OR ' ) + ' )' );
    });

    const base_query = JSON.parse(evt.detail.elt.getAttribute('hx-vals')).BaseQuery;

    var query;
    if ( clauses.length ) {
        if ( base_query.match(/^\s*\(.+\)\s*$/) ) {
            query = base_query + " AND " + clauses.join( ' AND ' );
        }
        else {
            query = '( ' + base_query + " ) AND " + clauses.join( ' AND ' );
        }
    }
    else {
        query = base_query;
    }

    // htmx has already loaded the values from the form in the DOM,
    // so update the query in the htmx data structure. This updated
    // value will then be submitted.
    evt.detail.parameters['Query'] = query;
};

// Reset the form if the user cancels the search filter operation

function resetSearchFilterForm(form) {
    // Remove the form contents we loaded via htmx. We'll reload again
    // if they click to filter again.
    const children = Array.from(form.children);

    // Keep the div "modal-content", remove everything else
    children.forEach(child => {
        if (!child.classList.contains('modal-content')) {
            form.removeChild(child);
        }
    });
}

function loadOwnerDropdownDelay(owner_dropdown_delay) {
    if ( owner_dropdown_delay.length ) {
        owner_dropdown_delay.load(RT.Config.WebHomePath + '/Helpers/SelectOwnerDropdown', {
            Name: owner_dropdown_delay.attr('data-name'),
            Default: owner_dropdown_delay.attr('data-default'),
            DefaultValue: owner_dropdown_delay.attr('data-default-value'),
            DefaultLabel: owner_dropdown_delay.attr('data-default-label'),
            ValueAttribute: owner_dropdown_delay.attr('data-value-attribute'),
            Size: owner_dropdown_delay.attr('data-size'),
            Objects: owner_dropdown_delay.attr('data-objects')
        }, function () {
            owner_dropdown_delay.addClass('loaded');
            initializeSelectElements(owner_dropdown_delay.get(0));
            RT.Autocomplete.bind(owner_dropdown_delay);
        });
    }
}

function toggleInlineEdit(link) {
    if (!link) return;
    link.siblings('.inline-edit-toggle').removeClass('hidden');
    link.addClass('hidden');
    link.closest('.titlebox').toggleClass('editing');
}

// focus jquery object in window, only moving the screen when necessary
function scrollToJQueryObject(obj) {
    if (!obj.length) return;

    var viewportHeight = jQuery(window).height(),
        currentScrollPosition = jQuery(window).scrollTop(),
        currentItemPosition = obj.offset().top,
        currentItemSize = obj.height() + ( obj.next().height() ? obj.next().height() : 0 );

    if (currentScrollPosition + viewportHeight < currentItemPosition + currentItemSize) {
        jQuery('html, body').scrollTop(currentItemPosition - viewportHeight + currentItemSize);
    } else if (currentScrollPosition > currentItemPosition) {
        jQuery('html, body').scrollTop(currentItemPosition);
    }
}

function toggle_hide_unset(e) {
    var link      = jQuery(e);
    var container = link.closest(".unset-fields-container");
    container.toggleClass('unset-fields-hidden');

    if (container.hasClass('unset-fields-hidden')) {
        link.text(link.data('show-label'));
    }
    else {
        link.text(link.data('hide-label'));
    }

    return false;
}

// toggle bookmark for Ticket/Elements/Bookmark.
// before replacing the bookmark content, dispose of the existing tooltip to
// ensure the tooltips are cycled correctly.
function toggle_bookmark(url, id) {
    jQuery.get(url, function(data) {
        jQuery('[data-bs-toggle="tooltip"]').tooltip("hide");
        jQuery('.toggle-bookmark-' + id).replaceWith(data);
        if ( document.querySelector('.toggle-bookmark-' + id).closest('.has-overflow') ) {
            const link = document.querySelector('.toggle-bookmark-' + id + ' a.nav-link');
            if ( link ) {
                link.classList.remove('nav-link');
                link.classList.add('dropdown-item');
            }
        }
    });
}

function toggleTransactionDetails () {

    var txn_div = jQuery(this).closest('div.transaction[data-transaction-id]');
    var details_div = txn_div.find('div.details');

    if (details_div.hasClass('hidden')) {
        details_div.removeClass('hidden');
        jQuery(this).text(RT.I18N.Catalog['hide_details']);
    }
    else {
        details_div.addClass('hidden');
        jQuery(this).text(RT.I18N.Catalog['show_details']);
    }

    var diff = details_div.find('.diff div.value');
    if (!diff.children().length) {
        diff.load(RT.Config.WebHomePath + '/Helpers/TextDiff', {
            TransactionId: txn_div.attr('data-transaction-id')
        });
    }

    return false;
}

function checkRefreshState(elt) {
    if ( elt.querySelector('.editing') ) {
        return false;
    }
    else {
        return true;
    }
}

[ticketUpdateRecipients, ticketUpdateScrips] = ((...widgets) => {
    const functions = [];
    widgets.forEach((widget) => {
        let preparing = 0;
        let previous_data;
        functions.push(function (evt) {
            if (evt && evt.type === 'htmx:load') {
                if (document.querySelector('.htmx-indicator')) {
                    return;
                }
                else if (RT.loadListeners) {
                    // Remove it from loadListeners as it's supposed to run once after all widgets have been rendered.
                    const index = RT.loadListeners.indexOf(arguments.callee);
                    if (index === -1) {
                        return;
                    }
                    else {
                        RT.loadListeners.splice(index, 1);
                    }
                }
                else {
                    return;
                }
            }

            var syncCheckboxes = function (ev) {
                var target = ev.target;
                jQuery("input[name=TxnSendMailTo]").filter(function () {
                    return this.value == target.value;
                }).prop("checked", jQuery(target).prop('checked'));
            };

            // In case there are multiple changes at the same time, we just want to update scrips once if possible
            if (preparing) {
                return;
            }
            preparing = 1;

            // Wait a little bit in case user leaves related inputs(which
            // could fire ticketUpdate...) by checking/unchecking recipient
            // checkboxes, this is to get checkboxes' latest status
            setTimeout(function () {
                preparing = 0;
                var payload = jQuery('form[name=TicketUpdate]').serializeArray();
                // Do not shortcircuit for inline messages as users might click the same Reply/Comment button multiple times.
                if (!payload.some(item => item.name === 'InlineAddMessage' && item.value == 1) && JSON.stringify(payload) === previous_data) {
                    return;
                }
                previous_data = JSON.stringify(payload);
                const parent = jQuery(widget.element);
                parent.find('div.titlebox-content').addClass('refreshing');

                parent.find('div.titlebox-content div.card-body').load(RT.Config.WebPath + widget.url,
                    payload,
                    function () {
                        parent.find('div.titlebox-content').removeClass('refreshing');
                        var txn_send_field = parent.find("input[name=TxnSendMailTo]");
                        txn_send_field.change(function (ev) {
                            syncCheckboxes(ev);
                            setCheckbox(this);
                        });
                        parent.find("input[name=TxnSendMailToAll]").click(function () {
                            setCheckbox(this, 'TxnSendMailTo');
                        });
                        if (txn_send_field.length > 0) {
                            setCheckbox(txn_send_field[0]);
                        }
                    }
                );
            }, 100);
        });
    });
    return functions;
})({ element: '.ticket-info-recipients', url: '/Helpers/ShowSimplifiedRecipients' }, { element: '.ticket-info-preview-scrips', url: '/Helpers/PreviewScrips' });

ticketUpdateScrips = (() => {
    let _ticket_preparing_scrips = 0;
    let _ticket_update_scrips_data;
    return function (evt) {
        if ( evt && evt.type === 'htmx:load' ) {
            if ( document.querySelector('.htmx-indicator') ) {
                return;
            }
            else if ( RT.loadListeners ) {
                // Remove it from loadListeners as it's supposed to run once after all widgets have been rendered.
                const index = RT.loadListeners.indexOf(arguments.callee);
                if ( index === -1 ) {
                    return;
                }
                else {
                    RT.loadListeners.splice(index, 1);
                }
            }
            else {
                return;
            }
        }

        var syncCheckboxes = function(ev) {
            var target = ev.target;
            jQuery("input[name=TxnSendMailTo]").filter(function() {
                return this.value == target.value;
            }).prop("checked", jQuery(target).prop('checked'));
        };

        // In case there are multiple changes at the same time, we just want to update scrips once if possible
        if ( _ticket_preparing_scrips ) {
            return;
        }
        _ticket_preparing_scrips = 1;


        // Wait a little bit in case user leaves related inputs(which
        // could fire ticketUpdate...) by checking/unchecking recipient
        // checkboxes, this is to get checkboxes' latest status
        setTimeout(function() {
            _ticket_preparing_scrips = 0;
            var payload = jQuery('form[name=TicketUpdate]').serializeArray();
            if ( JSON.stringify(payload) === _ticket_update_scrips_data ) {
                return;
            }
            _ticket_update_scrips_data = JSON.stringify(payload);
            jQuery('.ticket-info-preview-scrips div.titlebox-content').addClass('refreshing');

            jQuery('.ticket-info-preview-scrips div.titlebox-content div.card-body').load(RT.Config.WebPath + '/Helpers/PreviewScrips',
                payload,
                function() {
                    jQuery('.ticket-info-preview-scrips div.titlebox-content').removeClass('refreshing');
                    var txn_send_field = jQuery(".ticket-info-preview-scrips input[name=TxnSendMailTo]");
                    txn_send_field.change(function(ev) {
                        syncCheckboxes(ev);
                        setCheckbox(this);
                    });
                    jQuery(".ticket-info-preview-scrips input[name=TxnSendMailToAll]").click(function() {
                        setCheckbox(this, 'TxnSendMailTo');
                    });
                    if (txn_send_field.length > 0) {
                        setCheckbox(txn_send_field[0]);
                    }
                }
            );
        }, 100);
    }
})();


function ticketSyncOneTimeCheckboxes () {
    var emails = jQuery(this).val().split(/,\s*/);
    var prefix = jQuery(this).attr('id');
    var type = prefix.replace('Update', '');
    var checked = 0;
    var unchecked = 0;
    jQuery('input:checkbox[name^=' + prefix + ']').each(function() {
        var name = jQuery(this).attr('name');
        name = escapeRegExp(name.replace(prefix + '-', ''));

        var filter_function = function(n, i) {
            return n.match(new RegExp('^\\s*' + name + '\\s*$', 'i')) || n.match(new RegExp('<\\s*' + name + '\\s*>', 'i'));
        };
        if (jQuery.grep(emails, filter_function).length == 0) {
            unchecked++;
            if (jQuery(this).prop('checked')) {
                jQuery(this).prop('checked', false);
            }
        }
        else {
            checked++;
            if (!jQuery(this).prop('checked')) {
                jQuery(this).prop('checked', true);
                if (jQuery('#UpdateIgnoreAddressCheckboxes').val() == 0) {
                    jQuery('#UpdateIgnoreAddressCheckboxes').val(1);
                }
            }
        }
    });

    if (unchecked > 0) {
        if (jQuery('#AllSuggested' + type).is(':checked')) {
            jQuery('#AllSuggested' + type).prop('checked', false);
        }
    }
    else if (checked > 0 && unchecked == 0) {
        if (!jQuery('#AllSuggested' + type).is(':checked')) {
            jQuery('#AllSuggested' + type).prop('checked', true);
        }
    }
}

function registerLoadListener(func) {
    htmx.on('htmx:load', func);
    RT.loadListeners ||= [];
    RT.loadListeners.push(func);
}

function clipContent(elt) {
    jQuery(elt).find('td.collection-as-table').each( function() {
        if ( jQuery(this).children() ) {
            var max_height = jQuery(this).css('line-height').replace('px', '') * 5;
            var height     = '' + max_height + 'px';
            jQuery(this).children().each(function () {
                if ( jQuery(this).height() > max_height ) {
                    jQuery(this).wrapAll('<div class="clip">');
                    jQuery(this).parent().wrapAll('<div class="clip-container">');
                    jQuery(this).parent().attr('clip-height', height).height(height);
                    jQuery(this).parent().parent().append(
                        '<a href="#" class="unclip button btn btn-primary">' + loc_key('unclip') + '</a>',
                        '<a href="#" class="reclip button btn btn-primary" style="display: none;">' + loc_key('clip') + '</a>'
                    );
                }
            });
        }
    });
}

function alertError(message) {
    jQuery.jGrowl(`
<div class="p-3 text-danger-emphasis bg-danger-subtle border border-danger-subtle rounded-3">
  <span>${message}</span>
</div>`, { sticky: true, themeState: 'none' });
}

function alertWarning(message) {
    jQuery.jGrowl(`
<div class="p-3 text-warning-emphasis bg-warning-subtle border border-warning-subtle rounded-3">
  <span>${message}</span>
</div>`, { sticky: true, themeState: 'none' });
}

function reloadElement(elt, args = {}) {
    if (args['hx-vals']) {
        elt.setAttribute('hx-vals', args['hx-vals']);
    }
    htmx.trigger(elt, args.action || 'reload');
}

function inlineAddMessageIncludeArticle() {
    const data = new FormData(document.querySelector('#dynamic-modal form'));
    htmx.ajax(
        'POST', RT.Config.WebHomePath + '/Helpers/AddTicketMessage',
        {
            target: '#dynamic-modal',
            values: data
        }
    );
};

function disposeCombobox(elt) {
    jQuery(elt).find('.combobox').each(function() {
        const $select = jQuery(this);
        $select.removeData('combobox');
        $select.off();
        $select.closest('.combobox-container').remove();
    });
}

function inlineEditEscapeKeyHandler (e) {
    if (e.keyCode == 27) {
        e.preventDefault();
        cancelInlineEdit(jQuery('div.editable.editing form'));
    }
};

function beginInlineEdit(cell) {
    var editor = cell.find('.editor');

    if (jQuery('div.editable.editing').length) {
        return;
    }

    /* form has absolute position, we need to calculate the offsets so
        * it could show in the cell */

    var top = cell.offset().top;
    var left = cell.offset().left;

    var relativeParent = cell.parents().filter(function() {
        return jQuery(this).css('position') === 'relative';
    });

    if ( relativeParent.length ) {
        top -= relativeParent.offset().top;
        left -= relativeParent.offset().left;
    }

    if ( editor.find('.tomselected').length ) {
        // With .item-placeholder, .ts-control width varies during operations when opening/closing dropdown.
        // Here we hardcoded min-width and remove .items-placeholder to avoid layout shift.
        editor.find('.ts-control').css('min-width', 100 );
        editor.find('.ts-control .items-placeholder').remove();

        // tomselected inputs need more space, 40 is to make sure close/check images are visible
        if ( left + editor.width() + 40 > jQuery('body').width() ) {
            left = jQuery('body').width() - editor.width() - 40;
        }
    }

    editor.css('top', top);
    editor.css('left', left);

    if ( left > 0.5 * jQuery('body').width() ) {
        editor.addClass('inline-edit-right');
    }

    if ( !editor.find('.tomselected').length ) {
        editor.css('width', cell.width() > 100 ? cell.width() : 100 );
    }
    cell.addClass('editing');

    // Editor's height is bigger than viewer. Here we lift it up so editor can better take the viewer's position
    editor.css('margin-top', (cell.height() - editor.height())/2);

    editor.find(':input:visible:enabled:first').focus();
    editor.find('select.selectpicker')[0]?.tomselect.open();
    jQuery('body').addClass('inline-editing');


    jQuery(document).keyup(inlineEditEscapeKeyHandler);
};

function cancelInlineEdit(editor) {
    var cell = editor.closest('div');

    cell.removeClass('editing');
    editor.get(0).reset();

    jQuery('body').removeClass('inline-editing');

    if (inlineEditEscapeKeyHandler) {
        jQuery(document).off('keyup', inlineEditEscapeKeyHandler);
    }
};

function submitInlineEdit(editor, cell) {
    cell ||= editor.closest('div');

    // Make sure input's state has been updated
    editor.find('input:focus').blur();

    if (!editor.data('changed')) {
        cancelInlineEdit(editor);
        return;
    }

    if (!cell.hasClass('editing')) {
        return;
    }

    cell.get(0).classList.add('loading');
    cell.get(0).classList.remove('editing');
    cell.get(0).closest('tr').classList.add('refreshing');
    htmx.trigger(editor.get(0), 'submit');
};

// Override toggle so when user clicks the dropdown button, current value won't be cleared.
(function () {
    var orig_toggle = jQuery.fn.combobox.Constructor.prototype.toggle;
    jQuery.fn.combobox.Constructor.prototype.toggle = function () {
        if (!this.disabled && !this.$container.hasClass('combobox-selected') && !this.shown && this.$element.val()) {
            // Show all the options
            var matcher = this.matcher;
            this.matcher = function () { return 1 };
            this.lookup();
            this.matcher = matcher;
        }
        else {
            orig_toggle.apply(this);
        }
    };
})();

// Trigger change event to update ValidationHint accordingly
jQuery.fn.combobox.Constructor.prototype.clearElement = function () {
    this.$element.val('').change().focus();
};

htmx.config.includeIndicatorStyles = false;
htmx.config.scrollBehavior = 'smooth';
