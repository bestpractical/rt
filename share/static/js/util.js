/* Visibility */

function show(id) { delClass( id, 'hidden' ) }
function hide(id) { addClass( id, 'hidden' ) }

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
            new tempusDominus.TempusDominus(elt, opts.datetime);
        }
        else {
            new tempusDominus.TempusDominus(elt, opts.date);
        }

        // Fired when date selection is changed
        elt.addEventListener('change.td', (event) => {
            jQuery(elt).closest('form').data('changed', true);
        });
    });
}

htmx.onLoad(function(elt) {
    initDatePicker(elt);
    clipContent(elt);
});

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

    settings.onDropdownClose = function () {
        // Remove focus after a value is selected
        this.blur();
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

    const value = elt.value || elt.getAttribute('data-value');
    new TomSelect(elt,settings);

    // If the default value is not in the options, add it.
    if ( value ) {
        (Array.isArray(value) ? value : [value]).forEach(value => {
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
            // the propertychange event is for IE
            plainMessageBox.bind('input propertychange', function () {
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

jQuery(function() {
    // Override toggle so when user clicks the dropdown button, current value won't be cleared.
    var orig_toggle = jQuery.fn.combobox.Constructor.prototype.toggle;
    jQuery.fn.combobox.Constructor.prototype.toggle = function () {
        if ( !this.disabled && !this.$container.hasClass('combobox-selected') && !this.shown && this.$element.val() ) {
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

    // Trigger change event to update ValidationHint accordingly
    jQuery.fn.combobox.Constructor.prototype.clearElement = function () {
        this.$element.val('').change().focus();
    };

    // Make actions dropdown scrollable in case screen is too short
    jQuery(window).resize(function() {
        jQuery('#li-page-actions > ul').css('max-height', jQuery(window).height() - jQuery('#rt-header-container').height());
    }).resize();

    document.body.addEventListener('htmx:configRequest', function(evt) {
        for ( const param in evt.detail.parameters ) {
            if ( evt.detail.parameters[param + 'Type'] === 'text/html' && RT.CKEditor.instances[param] ) {
                evt.detail.parameters[param] = RT.CKEditor.instances[param].getData();
            }
        }
    });

    document.body.addEventListener('htmx:beforeRequest', function(evt) {
        if ( evt.detail.boosted ) {
            document.getElementById('hx-boost-spinner').classList.remove('invisible');
            document.querySelector('.main-container').classList.add('refreshing');
            jQuery.jGrowl('close');

            // Highlight active top menu
            if ( evt.detail.elt.tagName === 'A' ) {
                const href = evt.detail.elt.getAttribute('href');
                document.querySelectorAll('#app-nav a.menu-item.active:not([href="' + href + '"]').forEach(function(elt) {
                    elt.classList.remove('active');
                });
                document.querySelectorAll('#app-nav a.menu-item[href="' + href + '"]').forEach(function(elt) {
                    elt.classList.add('active');
                    let parent = elt.closest('ul').previousElementSibling;
                    while ( parent ) {
                        parent.classList.add('active');
                        parent = parent.closest('ul').previousElementSibling;
                    }
                });
            }
        }
    });

    document.body.addEventListener('htmx:afterRequest', function(evt) {
        if ( evt.detail.boosted ) {
            document.getElementById('hx-boost-spinner').classList.add('invisible');
            document.querySelector('.main-container').classList.remove('refreshing');
        }

        if ( evt.detail.elt.classList.contains('htmx-load-widget') ) {
            // hx-vals is only used to load the widget initially. Here we unset it to prevent it from being inherited by children.
            evt.detail.elt.removeAttribute('hx-vals');
        }

        if ( evt.detail.requestConfig.elt.classList.contains('search-results-filter') ) {
            // Clear the modal after a search filter
            const modalElt = evt.detail.requestConfig.elt.closest('.modal.search-results-filter');
            bootstrap.Modal.getInstance(modalElt)?.hide();

            // Clean up any stray backdrop
            document.querySelectorAll('.modal-backdrop').forEach(el => el.remove());
        }
    });

    document.body.addEventListener('htmx:beforeHistorySave', function(evt) {
        if ( RT.loadListeners ) {
            RT.loadListeners.forEach((func) => {
                htmx.off('htmx:load', func);
            });
            RT.loadListeners = [];
        }

        evt.detail.historyElt.querySelector('#hx-boost-spinner').classList.add('invisible');
        evt.detail.historyElt.querySelector('.main-container').classList.remove('refreshing');
        evt.detail.historyElt.querySelectorAll('textarea.richtext').forEach(function(elt) {
            RT.CKEditor.instances[elt.name].destroy();
        });
        evt.detail.historyElt.querySelector('.ck-body-wrapper')?.remove();

        evt.detail.historyElt.querySelectorAll('.hasDatepicker').forEach(function(elt) {
            elt.classList.remove('hasDatepicker');
        });
        evt.detail.historyElt.querySelectorAll('.tomselected').forEach(elt => elt.tomselect.destroy());
        evt.detail.historyElt.querySelectorAll('.dropzone-init').forEach(elt => elt.dropzone?.destroy());
    });

    // Detect 400/500 errors
    document.body.addEventListener('htmx:beforeSwap', function(evt) {
        const status = evt.detail.xhr.status.toString();
        if (status.match(/^[45]/)) {
            // 422 means rt validation error and is handled in other places.
            if ( status === '422' ) return;

            if (!evt.detail.boosted && evt.target && evt.detail.requestConfig.verb === "get") {
                evt.detail.shouldSwap = true;
            }
            else {
                if ( evt.detail.serverResponse ) {
                    const error = jQuery(evt.detail.serverResponse).find('#body div.error').html();
                    if (error) {
                        alertError(error);
                        return;
                    }
                }
                // Fall back to general 400/500 errors for 4XX/5XX errors without specific messages
                const message = RT.I18N.Catalog['http_message_' + status] || RT.I18N.Catalog['http_message_' + status.substr(0, 1) + '00'];
                if (message) {
                    alertError(escapeHTML(message));
                }
            }
        }
        else if (evt.detail.boosted) {
            const error = evt.detail.xhr.getResponseHeader('HX-Boosted-Error');
            if (error) {
                const message = JSON.parse(error)?.message;
                if ( message ) {
                    alertError(escapeHTML(message));
                }
                console.error("Error fetching " + evt.detail.pathInfo.requestPath + ': ' + message);
                evt.detail.shouldSwap = false;
            }
        }
    });

    // Detect network errors
    document.body.addEventListener('htmx:sendError', function(evt) {
        const message = RT.I18N.Catalog['http_message_network_' + evt.detail.requestConfig.verb] || RT.I18N.Catalog['http_message_network'];
        if (message) {
            alertError(escapeHTML(message));
        }

        if (evt.detail.requestConfig.verb === 'get') {
            setTimeout(function() {
                if ( evt.detail.boosted ) {
                    window.location = evt.detail.requestConfig.path;
                }
                else {
                    window.location.reload();
                }
            }, 2000);
        }
    });

    document.body.addEventListener('actionsChanged', function(evt) {
        jQuery.jGrowl('close');
        evt.detail.messages ||= evt.detail.value; // .value contains messages if it's passed as "actionsChanged => [$msg]"
        if ( evt.detail.messages ) {
            for ( const message of evt.detail.messages ) {
                if ( evt.detail.isWarning ) {
                    alertWarning(escapeHTML(message));
                }
                else {
                    jQuery.jGrowl(escapeHTML(message), { themeState: 'none' });
                }
            }
        }

        // Clear the form after a successful update so the previous values are not
        // still in form elements if the user clicks to update again.
        const form = evt.detail.elt;

        // Only clear on success. Leave any values on "isWarning"
        if ( form && form instanceof HTMLFormElement && !evt.detail.isWarning ) {
            form.reset();
        }
    });

    document.body.addEventListener('CSRFDetected', function(evt) {
        jQuery.jGrowl(escapeHTML(evt.detail.value), { themeState: 'none' });
    });

    document.body.addEventListener('collectionsChanged', function(evt) {
        document.querySelectorAll('table.collection-as-table[data-display-format][data-class="' + evt.detail.class + '"]').forEach(table => {
            const tr = table.querySelector('tr[data-record-id="' + evt.detail.id + '"]');
            if ( tr ) {
                htmx.ajax(
                    'POST', RT.Config.WebHomePath + '/Helpers/CollectionListRow',
                    {
                        source: tr,
                        target: tr,
                        swap: 'outerHTML',
                        values: {
                            DisplayFormat : table.getAttribute('data-display-format'),
                            ObjectClass   : table.getAttribute('data-class'),
                            MaxItems      : table.getAttribute('data-max-items') || 0,
                            InlineEdit    : table.classList.contains('inline-edit') ? 1 : 0,
                            i             : tr.getAttribute('data-index'),
                            ObjectId      : tr.getAttribute('data-record-id'),
                            Warning       : tr.getAttribute('data-warning') || 0
                        }
                    }
                );
            }
        });
    });

    document.body.addEventListener('requestSucceeded', function(evt) {
        if ( evt.detail.elt.classList.contains('inline-edit') ) {
            toggleInlineEdit(jQuery(evt.detail.elt.closest('.titlebox')).find('.inline-edit-toggle:visible'));
        }
        else if ( evt.detail.elt.classList.contains('editor') ) {
            const cell = evt.detail.elt.closest('.editable');
            if ( cell ) {
                const tr = cell.closest('tr.collection-as-table');
                cell.classList.remove('loading');
                cell.classList.remove('editing');
                document.querySelector('body').classList.remove('inline-editing');
            }
        }

        const history_container = document.querySelector('.history-container');
        if ( history_container ) {
            if ( history_container.getAttribute('data-oldest-transactions-first') == 1 ) {
                history_container.removeAttribute('data-disable-scroll-loading');
            }
            else {
                const url = history_container.getAttribute('data-url');
                if ( url ) {
                    let queryString = '&mode=prepend&loadAll=1';
                    let lastTransaction = history_container.querySelector('.transaction');
                    if ( lastTransaction ) {
                        queryString += '&lastTransactionId=' + lastTransaction.dataset.transactionId;
                    }

                    jQuery.ajax({
                        url: url + queryString,
                        success: function(html) {
                            const transactions = jQuery(html).filter('div.transaction');
                            if( html && transactions.length ) {
                                jQuery(".history-container").prepend(html);
                            }
                        },
                        error: function(xhr, reason) {
                            jQuery.jGrowl(escapeHTML(reason), { sticky: true, themeState: 'none' });
                        }
                    });
                }
            }
        }
    });

    document.body.addEventListener('validationFailed', function(evt) {
        // Make hint text red if we found any errors on inline edit
        if ( evt.detail.value ) {
            evt.detail.elt.querySelectorAll('.is-invalid').forEach(elt => {
                elt.classList.remove('is-invalid');
                let hintSpan = document.getElementById(elt.getAttribute("aria-describedby"));
                if ( hintSpan ) {
                    hintSpan.classList.remove('invalid-feedback');
                }
            });

            for ( let field of evt.detail.value ) {
                let cfInputField = document.getElementById(field);
                cfInputField.classList.add('is-invalid');
                let hintSpan = document.getElementById(cfInputField.getAttribute("aria-describedby"));
                if ( hintSpan ) {
                    hintSpan.classList.add('invalid-feedback');
                }
            }

            if ( evt.detail.elt.classList.contains('editor') ) {
                const cell = evt.detail.elt.closest('.editable');
                if ( cell ) {
                    cell.classList.remove('loading');
                    cell.classList.add('editing');
                    cell.closest('tr').classList.remove('refreshing');
                }
            }
        }
    });

    document.body.addEventListener('titleChanged', function(evt) {
        document.title = evt.detail.value;
    });

    document.body.addEventListener('triggerChanged', function(evt) {
        evt.detail.elt.setAttribute('hx-trigger', evt.detail.value);
        htmx.process(evt.detail.elt);
    });

    document.body.addEventListener('widgetTitleChanged', function(evt) {
        const title = evt.detail.elt.closest('div.titlebox').querySelector('.titlebox-title a');
        if ( title ) {
            title.innerHTML = evt.detail.value;
        }
    });

    const html = document.querySelector('html');
    if ( html.getAttribute('data-bs-theme') === 'auto' ) {
        if ( window.matchMedia("(prefers-color-scheme:dark)").matches ) {
            html.setAttribute('data-bs-theme', 'dark');
        }
        else {
            html.setAttribute('data-bs-theme', 'light');
        }
    }

});

htmx.onLoad(function(elt) {
    initializeSelectElements(elt);
    ReplaceAllTextareas(elt);
    AddAttachmentWarning();
    jQuery(elt).find('a.delete-attach').click( function() {
        var parent = jQuery(this).closest('div');
        var name = jQuery(this).attr('data-name');
        var token = jQuery(this).closest('form').find('input[name=Token]').val();
        jQuery.post( RT.Config.WebHomePath + '/Helpers/Upload/Delete', { Name: name, Token: token }, function(data) {
            if ( data.status == 'success' ) {
                parent.remove();
            }
        }, 'json');
        return false;
    });

    jQuery(elt).find(".card .card-header .toggle").each(function() {
        var e = jQuery(jQuery(this).attr('data-bs-target'));
        e.on('hide.bs.collapse', function (evt) {
            evt.stopPropagation();
            createCookie(evt.target.id,0,365);
            e.closest('div.titlebox').find('div.card-header span.right').addClass('invisible');
        });
        e.on('show.bs.collapse', function (evt) {
            evt.stopPropagation();
            createCookie(evt.target.id,1,365);
            e.closest('div.titlebox').find('div.card-header span.right').removeClass('invisible');
        });
    });

    jQuery(elt).find(".card .accordion-item .toggle").each(function() {
        var e = jQuery(jQuery(this).attr('data-bs-target'));
        e.on('hide.bs.collapse', function (evt) {
            evt.stopPropagation();
            createCookie(evt.target.id,0,365);
        });
        e.on('show.bs.collapse', function (evt) {
            evt.stopPropagation();
            createCookie(evt.target.id,1,365);
        });
    });

    jQuery(elt).find(".card .card-body .toggle").each(function() {
        var e = jQuery(jQuery(this).attr('data-bs-target'));
        e.on('hide.bs.collapse', function (event) {
            event.stopPropagation();
        });
        e.on('show.bs.collapse', function (event) {
            event.stopPropagation();
        });
    });

    if ( jQuery(elt).find('.combobox').combobox ) {
        jQuery(elt).find('.combobox').combobox({ clearIfNoMatch: false });
        jQuery(elt).find('.combobox-wrapper').each( function() {
            jQuery(this).find('input[type=text]').prop('name', jQuery(this).data('name')).prop('value', jQuery(this).data('value'));
        });
    }

    /* Show selected file name in UI */
    jQuery(elt).find('.custom-file input').change(function (e) {
        jQuery(this).next('.custom-file-label').html(e.target.files[0].name);
    });

    loadCollapseStates(elt);


    jQuery(elt).find(':input[data-type=json]').bind('input propertychange', function() {
        var form = jQuery(this).closest('form');
        try {
            JSON.parse(jQuery(this).val());
            form.find('input[type=submit]').prop('disabled', false);
            form.find('.invalid-json').addClass('hidden');
        } catch (e) {
            form.find('input[type=submit]').prop('disabled', true);
            form.find('.invalid-json').removeClass('hidden');
        }
    });

    /* Code to support the rights editor for global rights, queue rights, etc. */
    if ( elt.querySelector('.rights-editor') ) {
        const editor = elt.querySelector('.rights-editor');
        function sync_anchor(hash) {
            if (!hash.length) return;
            window.location.hash = hash;
            editor.querySelector("input[name=Anchor]").value = hash;
        }
        sync_anchor(editor.querySelector("input[name=Anchor]").value);
        jQuery(editor).find('.principal-tabs a[data-bs-toggle="tab"]').on('shown.bs.tab', function (e) {
            const anchor = jQuery(this).attr('href').replace('#acl-', '#');
            sync_anchor(anchor);
            jQuery(editor).find('.category-tabs a[data-bs-toggle="tab"]:visible:first').tab('show');
            if (anchor == '#AddPrincipal') {
                jQuery(editor).find('li.add-principal input').focus();
            }
        });

        jQuery(editor).find('li.add-principal input').focus(function () {
            jQuery(editor).find('.principal-tabs a[data-bs-toggle="tab"][href="#acl-AddPrincipal"]').tab('show');
        });

        const anchor = editor.querySelector('input[name=Anchor]').value;
        if (anchor && jQuery(editor).find('.principal-tabs a[data-bs-toggle="tab"][href="' + anchor.replace('#', '#acl-') + '"]').length) {
            jQuery(editor).find('.principal-tabs a[data-bs-toggle="tab"][href="' + anchor.replace('#', '#acl-') + '"]').tab('show');
        }
        else {
            jQuery(editor).find('.principal-tabs a[data-bs-toggle="tab"]:first').tab('show');
        }

        jQuery(editor).find('.category-tabs a[data-bs-toggle="tab"]').on('shown.bs.tab', function (e) {
            createCookie('rights-category-tab', jQuery(this).attr('href'));
        });

        const category_tab = getCookie('rights-category-tab');
        if (category_tab && jQuery(category_tab).length) {
            jQuery(editor).find('.category-tabs a[data-bs-toggle="tab"][href="' + category_tab + '"]').tab('show');
        }
        else {
            jQuery(editor).find('.category-tabs a[data-bs-toggle="tab"]:visible:first').tab('show');
        };

        // "rights" checkbox state cache...
        const check_counts = {};

        // Before page loads we need to initialize our "rights" checkbox state
        // cache.
        jQuery(editor).find("div.category-tabs input[type=checkbox]").each(function (index, element) {
            // Evaluating each checkbox and its current check state is the same
            // as evaluating a check event once the page is loaded. However, we
            // must indicate to the process_check_event that we are initializing
            // the cache. That is, we musn't decrement values from count
            // totals for checkboxes that aren't checked. That only happens when
            // a user actually unchecks a box, not when we are initially counting
            // checked or unchecked boxes.
            process_check_event(element, true);
        });

        jQuery("div.category-tabs input[type=checkbox]").change(function () {
            process_check_event(this, false);
        });

        // parameters:
        //   checkbox           - DOM checkbox element that was checked
        //   initializing_cache - a boolean that defines whether or not this
        //                        function was called with the purpose of
        //                        initializing the contents of the check_counts
        //                        cache.
        function process_check_event(checkbox, initializing_cache) {
            var category_tab = checkbox.getAttribute('data-category-tab');
            var principal_tab = checkbox.getAttribute('data-principal-tab');

            classify_tab(checkbox.checked, category_tab, initializing_cache);
            classify_tab(checkbox.checked, principal_tab, initializing_cache);
        }

        function classify_tab(checked, tab_id, initializing_cache) {
            if (typeof check_counts[tab_id] == 'undefined') {
                check_counts[tab_id] = 0;
            }

            if (checked) {
                check_counts[tab_id]++;
                if (check_counts[tab_id] == 1) {
                    // Then this is the first check and we need to add a class
                    // to the tab.
                    jQuery('#' + tab_id).addClass("tab-aggregates-checked-rights");
                }
            }
            else if (!initializing_cache) {
                check_counts[tab_id]--;
                if (check_counts[tab_id] == 0) {
                    // Then this is the last uncheck and we need to remove a
                    // class from the tab.
                    jQuery('#' + tab_id).removeClass("tab-aggregates-checked-rights");
                }
            }
        }

        let auto_set_own_dashboards;
        jQuery(editor).find('input[value="ModifySelf"]').change(function () {
            var form = jQuery(this).closest('form');
            if (jQuery(this).is(':checked')) {
                if (form.find('input[value$="OwnDashboard"]:visible:not(:checked)').length) {
                    jQuery('#grant-own-dashboard-rights-modal').modal('show');
                }
            }
            else {
                if (auto_set_own_dashboards) {
                    form.find('input[value$="OwnDashboard"]:visible:checked').prop('checked', false);
                    auto_set_own_dashboards = false;
                }
            }
        });

        jQuery('#grant-own-dashboard-rights-confirm').click(function () {
            var form = jQuery(this).closest('form');
            form.find('input[value$="OwnSavedSearch"]:visible:not(:checked)').prop('checked', true);
            form.find('input[value$="OwnDashboard"]:visible:not(:checked)').prop('checked', true);
            jQuery('#grant-own-dashboard-rights-modal').modal('hide');
            auto_set_own_dashboards = true;
        });

        const type = editor.getAttribute('data-add-principal');
        if (type) {
            jQuery(editor).find("#AddPrincipalForRights-" + type).keyup(function () {
                toggle_addprincipal_validity(this, true);
            }).keydown(function (event) {
                event.stopPropagation() // Disable tabs keyboard nav
            });

            jQuery("#AddPrincipalForRights-" + type).on("autocompleteselect", addprincipal_onselect);
            jQuery("#AddPrincipalForRights-" + type).on("autocompletechange", addprincipal_onchange);
        }
    }
    /* End code to support the rights editor */

    // Automatically sync to set input values to ones in config files.
    jQuery(elt).find('form[name=EditConfig] input[name$="-file"]').change(function (e) {
        var file_input = jQuery(this);
        var form = file_input.closest('form');
        var file_name = file_input.attr('name');
        var file_value = form.find('input[name=' + file_name + '-Current]').val();
        var checked = jQuery(this).is(':checked') ? 1 : 0;
        if ( !checked ) return;

        var db_name = file_name.replace(/-file$/, '');
        var db_input = form.find(':input[name=' + db_name + ']');
        var db_input_type = db_input.attr('type') || db_input.prop('tagName').toLowerCase();
        if ( db_input_type == 'radio' ) {
            db_input.filter('[value=' + (file_value || 0) + ']').prop('checked', true);
        }
        else if ( db_input_type == 'select' ) {
            db_input.get(0).tomselect.setValue(file_value.length ? file_value : '__empty_value__');
        }
        else {
            db_input.val(file_value);
        }
    });

    // Automatically sync to uncheck use file config checkbox
    jQuery(elt).find('form[name=EditConfig] input[name$="-file"]').each(function () {
        var file_input = jQuery(this);
        var form = file_input.closest('form');
        var file_name = file_input.attr('name');
        var db_name = file_name.replace(/-file$/, '');
        var db_input = form.find(':input[name=' + db_name + ']');
        db_input.change(function() {
            file_input.prop('checked', false);
        });
    });

    jQuery(elt).find('form[name=BuildQuery] select[name^=SelectCustomField]').change(function() {
        var form = jQuery(this).closest('form');
        var row = jQuery(this).closest('div.row');
        var val = jQuery(this).val();

        var new_operator = form.find(':input[name="' + val + 'Op"]:first').clone();
        new_operator.attr('id', null).removeClass('tomselected ts-hidden-accessible');
        row.children('div.rt-search-operator').children().remove();
        row.children('div.rt-search-operator').append(new_operator);

        var new_value = form.find(':input[name="ValueOf' + val + '"]:first');
        new_value = new_value.clone();

        new_value.attr('id', null).removeClass('tomselected ts-hidden-accessible');
        row.children('div.rt-search-value').children().remove();
        row.children('div.rt-search-value').append(new_value);
        if ( new_value.hasClass('datepicker') ) {
            new_value.removeClass('hasDatepicker');
            initDatePicker(row.get(0));
        }
        initializeSelectElements(row.get(0));
    });

    jQuery(elt).closest('form, body').find('input[name=QueueChanged]').each(function() {
        var form = jQuery(this).closest('form');
        var mark_changed = function(name) {
            if ( !form.find('input[name=ChangedField][value="' + name +'"]').length ) {
                jQuery('<input type="hidden" name="ChangedField" value="' + name + '">').appendTo(form);
            }
        };

        form.find(':input[name!=ChangedField]:not(.mark-changed):not(.messagebox.richtext)').each(function() {
            jQuery(this).addClass('mark-changed');
            jQuery(this).change(function() {
                mark_changed(jQuery(this).attr('name'));
            });
        });

        var plainMessageBox = form.find('.messagebox.richtext:not(.mark-changed)');
        var messageBoxName = plainMessageBox.attr('name');
        if ( messageBoxName ) {
            plainMessageBox.addClass('mark-changed');
            let interval;
            interval = setInterval(function() {
                if (RT.CKEditor.instances && RT.CKEditor.instances[messageBoxName]) {
                    const richTextEditor = RT.CKEditor.instances[messageBoxName];
                    richTextEditor.model.document.on( 'change:data', () => {
                        mark_changed(plainMessageBox.attr('name'));
                    });
                    clearInterval(interval);
                }
            }, 200);
        }
    });

    jQuery(elt).find('a.permalink').click(function() {
        htmx.ajax('GET', RT.Config.WebPath + "/Helpers/Permalink", {
            target: '#dynamic-modal',
            values: {
                Code: this.getAttribute('data-code'),
                URL: this.getAttribute('data-url')
            },
        }).then(() => {
            bootstrap.Modal.getOrCreateInstance('#dynamic-modal').show();
        });
        return false;
    });

    // Toggle dropdown on hover
    elt.querySelectorAll('nav a.menu-item').forEach(function(link) {
        const elem = link.parentElement;
        let timeout;

        elem.addEventListener('mouseenter', event => {
            if ( elem.classList.contains('has-children') ) {
                const toggle = bootstrap.Dropdown.getOrCreateInstance(link);
                toggle._inNavbar = false; // Bootstrap disables popper for dropdowns in nav, we want it to re-position submenus

                // Manually set toggle attribute to close dropdown on click.
                // Can't set it before creating instances as it would toggle
                // dropdown on click(default behavior), which we don't want.
                if ( !link.getAttribute('data-bs-toggle') ) {
                    link.setAttribute('data-bs-toggle', 'dropdown');
                }
                toggle.show();
            }



            if ( timeout ) {
                clearTimeout(timeout);
            }

            if ( !elem.parentElement ) {
                return;
            }

            // Hide other dropdowns
            elem.parentElement.querySelectorAll(':scope > li').forEach(function(sibling) {
                if ( elem === sibling ) return;
                const link = sibling.querySelector('a.dropdown-toggle');
                if ( link ) {
                    link.blur(); // Remove css styles applied to :focus
                }

                const toggle = bootstrap.Dropdown.getInstance(link);
                if ( toggle ) {
                    toggle.hide();
                }
            });

            // Highlight parent nodes
            let parent = elem;
            let ul;
            while ( ul = ( parent && parent.parentElement ) ) {
                ul.querySelectorAll(':scope > li').forEach(function(sibling) {
                    if ( parent === sibling ) {
                        parent.querySelector('a.menu-item').classList.add('hovered');
                    }
                    else {
                        sibling.querySelector('a.menu-item').classList.remove('hovered');
                    }
                });
                parent = ul.closest('li');
            }
        });

        elem.addEventListener('mouseleave', event => {
            const toggle = bootstrap.Dropdown.getInstance(link);
            if ( toggle ) {
                link.blur();  // Remove css styles applied to :focus

                // Delay a little bit so that the user can hover to the submenu more easily
                timeout = setTimeout(function () {
                    toggle.hide();
                }, 500);
            }
        });

        // Clean up obsolete highlighted children items
        link.addEventListener('hidden.bs.dropdown', event => {
            const elem = link.parentElement;
            elem.querySelectorAll('.hovered').forEach(function(item) {
                item.classList.remove('hovered');
            });
        });
    });

    // Lower dropdown menus in page-menu a bit, to fully show the border
    elt.querySelectorAll('#page-navigation .nav-item.has-children').forEach(function(elem) {
        const link = elem.querySelector('a.dropdown-toggle');
        const ul = elem.querySelector('ul.dropdown-menu');
        link.addEventListener('shown.bs.dropdown', event => {
            setTimeout(function() {
                ul.style.marginTop = '1px';
            }, 0);
        });
    });

    // My Week auto submit
    jQuery(elt).find('div.time-tracking input[name=Date]').change(function() {
        htmx.trigger(this.closest('form'), 'submit');
    });

    jQuery(elt).find('div.time-tracking input[name=UserString]').change(function() {
        this.closest('form').querySelector('input[name=User]').value = this.value;
        htmx.trigger(this.closest('form'), 'submit');
    });

    if (elt.querySelectorAll('.lifecycle-ui').length) {
        const checkLifecycleEditor = setInterval(function () {
            if (d3 && RT.NewLifecycleEditor) {
                clearInterval(checkLifecycleEditor);
                elt.querySelectorAll('.lifecycle-ui').forEach(elt => {
                    new RT.NewLifecycleEditor(elt, JSON.parse(elt.getAttribute('data-config')), JSON.parse(elt.getAttribute('data-maps')), elt.getAttribute('data-layout') ? JSON.parse(elt.getAttribute('data-layout')) : null);
                });
            }
        }, 50);
    }

    elt.querySelectorAll('[data-bs-toggle="popover"]').forEach(function(elt) {
        new bootstrap.Popover(elt, {
            trigger: 'hover focus',
            html: true,
            sanitize: true
        });
    });

    const parse_cf = /^Object-([\w:]+)-(\d*)-CustomField(?::\w+)?-(\d+)-(.*)$/;
    elt.querySelectorAll("input,textarea:not(.richtext),select").forEach(function(elt) {
        const elem = jQuery(elt);
        const parsed = parse_cf.exec(elem.attr("name"));
        if (parsed == null)
            return;
        if (/-Magic$/.test(parsed[4]))
            return;
        const name_filter_regex = new RegExp(
            "^Object-"+parsed[1]+"-"+parsed[2]+
             "-CustomField(?::\\w+)?-"+parsed[3]+"-"+parsed[4]+"$"
        );

        const trigger_func = function() {
            const update_elems = jQuery("input,textarea:not(.richtext),select").filter(function () {
                return name_filter_regex.test(jQuery(this).attr("name"));
            }).not(elem);
            if (update_elems.length == 0)
                return;

            let curval = elem.val();
            if ((elem.attr("type") == "checkbox") || (elem.attr("type") == "radio")) {
                curval = [ ];
                jQuery('[name="'+elem.attr("name")+'"]:checked').each( function() {
                    curval.push( jQuery(this).val() );
                });
            }
            update_elems.val(curval);
            update_elems.filter(function(index, elt) {
                return elt.tomselect;
            }).each(function (index, elt) {
                const tomselect = elt.tomselect;
                if (Array.isArray(curval)) {
                    curval.forEach(val => {
                        if (!tomselect.getItem(val)) {
                            tomselect.createItem(val, true);
                        }
                    });
                }
                else if (!tomselect.getItem(curval)) {
                    tomselect.createItem(curval, true);
                }
                tomselect.setValue(curval, true);
            });
        };
        if ((elem.attr("type") == "text") || (elem.get(0).tagName == "TEXTAREA"))
            elem.keyup( trigger_func );

        elem.change( trigger_func );
    });

    elt.querySelectorAll('a.search-filter').forEach(function(link) {
        link.addEventListener('click', (evt) => {
            evt.preventDefault();
            const target = elt.querySelector(link.getAttribute('hx-target'));
            if ( target.children.length > 0 ) {
                bootstrap.Modal.getOrCreateInstance(target.closest('.modal.search-results-filter')).show();
            }
            else {
                htmx.trigger(link, 'manual');
            }
            return false;
        });
    });
});

function fixupSearchFilterModal(elt,evt) {
    var modal = jQuery(elt).closest('.modal.search-results-filter');
    var filterLink = jQuery(elt).closest('th').find('a.search-filter');

    modal.css('top', jQuery(filterLink).offset().top);
    var left = jQuery(filterLink).offset().left;
    modal.find('div.modal-content').css('max-height', jQuery(window).height() - jQuery(filterLink).offset().top - 10);
    modal.on('shown.bs.modal', function() {
        var label = modal.find('div.label');
        // Check if label text is too long and needs more room
        // The labels in the first row have 0.5 more width than the labels
        // in the second row, so we need to add this to the width check
        if ( label[0].scrollWidth > (0.5 + label.outerWidth()) ) {
            modal.find('.modal-dialog').removeClass('modal-sm').addClass('modal-md');
            label.css('text-wrap', 'wrap');
        }
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

/* inline edit */
jQuery(function () {
    var inlineEditEnabled = true;

    var escapeKeyHandler = null;

    const beginInlineEdit = function (cell) {
        if (!inlineEditEnabled) {
            return;
        }

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

        escapeKeyHandler = function (e) {
            if (e.keyCode == 27) {
                e.preventDefault();
                cancelInlineEdit(editor);
            }
        };
        jQuery(document).keyup(escapeKeyHandler);
    };

    const cancelInlineEdit = function (editor) {
        var cell = editor.closest('div');

        cell.removeClass('editing');
        editor.get(0).reset();

        jQuery('body').removeClass('inline-editing');

        if (escapeKeyHandler) {
            jQuery(document).off('keyup', escapeKeyHandler);
        }
    };

    const submitInlineEdit = function (editor, cell) {
        cell ||= editor.closest('div');

        if (!inlineEditEnabled) {
            return;
        }

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

    jQuery(document).on('click', 'table.inline-edit div.editable .edit-icon', function (e) {
        var cell = jQuery(this).closest('div.editable');
        if ( jQuery('div.editable.editing form').length ) {
            cancelInlineEdit(jQuery('div.editable.editing form'));
        }
        const modal_info = cell.get(0).querySelector('span.inline-edit-modal[data-link]');
        if ( modal_info ) {
            htmx.ajax('GET', modal_info.getAttribute('data-link'), '#dynamic-modal').then(() => {
                bootstrap.Modal.getOrCreateInstance('#dynamic-modal').show();
                jQuery(document).on('change', '#dynamic-modal form :input', function () {
                    jQuery(this).closest('form').data('changed', true);
                });
                jQuery(document).on('click', '#dynamic-modal form .submit', function (evt) {
                    evt.preventDefault();

                    document.querySelectorAll('#dynamic-modal form textarea.richtext').forEach((textarea) => {
                        const name = textarea.name;
                        if ( RT.CKEditor.instances[name] ) {
                            if ( RT.CKEditor.instances[name].getData() !== textarea.value ) {
                                RT.CKEditor.instances[name].updateSourceElement();
                                jQuery(textarea.closest('form')).data('changed', true);
                            }
                        }
                    });
                    if ( jQuery('#dynamic-modal form').data('changed') ) {
                        cell.addClass('editing');
                        submitInlineEdit(jQuery('#dynamic-modal form'), cell);
                    }
                });
            });
        }
        else {
            beginInlineEdit(cell);
        }
    });

    jQuery(document).on('mouseenter', 'table.inline-edit div.editable .edit-icon', function (e) {
        const owner_dropdown_delay = jQuery(this).closest('.editable').find('div.select-owner-dropdown-delay:not(.loaded)');
        loadOwnerDropdownDelay(owner_dropdown_delay);
    });

    jQuery(document).on('change', 'div.editable.editing form :input', function () {
        jQuery(this).closest('form').data('changed', true);
    });

    jQuery(document).on('click', 'div.editable .cancel', function (e) {
        cancelInlineEdit(jQuery(this).closest('form'));
    });

    jQuery(document).on('click', 'div.editable .submit', function (e) {
        submitInlineEdit(jQuery(this).closest('form'));
    });

    // We want to call submitInlineEdit to do some pre-checks and massage
    // css classes before making htmx requests. Can't bind it to form.submit
    // event as preventDefault() there can't stop htmx actions.
    jQuery(document).on('keydown', 'div.editable.editing form input[type=text], div.editable.editing form input:not([type])', function (e) {
        if (e.key === 'Enter') {
            e.preventDefault();
            submitInlineEdit(jQuery(this).closest('form'));
        }
    });

    jQuery(document).on('change', 'div.editable.editing form select:not([multiple])', function () {
        submitInlineEdit(jQuery(this).closest('form'));
    });
});

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

htmx.onLoad(function(elt) {

    /* inline edit on ticket display */
    jQuery('.titlebox[data-inline-edit-behavior="link"], .titlebox[data-inline-edit-behavior="click"]').each(function() {
        // If there are only id/submit, there are no fields to edit
        if ( jQuery(this).find('form.inline-edit :input').length <= 2 ) {
            jQuery(this).data('inline-edit-behavior', 'hide');
            jQuery(this).find('.inline-edit-toggle').addClass('hide');
        }
    });

    /* Load the owner dropdown when the user clicks the pencil in basics */
    jQuery(elt).on('click', '.ticket-info-basics .inline-edit-toggle.edit .rt-inline-icon', function (e) {
        /* htmx will run for many portlets. Only run for ticket-info-basics to avoid multiple
           calls to the helper for the same dropdown. */
        if ( e.delegateTarget.className === "ticket-info-basics" ) {
            var owner_dropdown_delay = jQuery('div.ticket-info-basics.editing').find('div.select-owner-dropdown-delay:not(.loaded)');
            loadOwnerDropdownDelay(owner_dropdown_delay);
        }
    });

    jQuery('.titlebox[data-inline-edit-behavior="always"]').each(function() {
        // If there are only id/submit, there are no fields to edit
        if ( jQuery(this).find('form.inline-edit :input').length <= 2 ) {
            jQuery(this).find('form.inline-edit :input[type=submit]').closest('div.row').addClass('hide');
        }
    });

    jQuery(elt).find('.inline-edit-toggle').click(function (e) {
        e.preventDefault();
        toggleInlineEdit(jQuery(this));
    });

    jQuery(elt).find('.titlebox[data-inline-edit-behavior="click"] > .titlebox-content').click(function (e) {
        if (jQuery(e.target).is('input, select, textarea')) {
            return;
        }

        // Bypass links, buttons and radio/checkbox controls too
        if (jQuery(e.target).closest('a, button, div.custom-radio, div.custom-checkbox').length) {
            return;
        }

        e.preventDefault();
        var container = jQuery(this).closest('.titlebox');
        if (container.hasClass('editing')) {
            return;
        }
        toggleInlineEdit(container.find('.inline-edit-toggle:visible'));
    });

    // Register triggers for cf changes
    elt.querySelectorAll('.show-custom-fields-container[hx-get], .edit-custom-fields-container[hx-get]').forEach(function (elt) {
        let events = [];
        if ( elt.classList.contains('show-custom-fields-container') ) {
            elt.querySelectorAll('.row.custom-field').forEach(function (elt) {
                const id = elt.id.match(/CF-(\d+)/)[1];
                events.push('customField-' + id + 'Changed from:body');
            });
        }
        else {
            elt.querySelectorAll('input[type=hidden][name*=-CustomField][name$="-Magic"]').forEach(function (elt) {
                let id = elt.name.match(/CustomField.*-(\d+)-.*-Magic$/)[1];
                events.push('customField-' + id + 'Changed from:body');
            });
        }

        if ( events.length ) {
            let orig_trigger = elt.getAttribute('hx-trigger');
            if ( orig_trigger && orig_trigger !== 'none' ) {
                events.push(orig_trigger);
            }
            elt.setAttribute('hx-trigger', events.join(', '));
            htmx.process(elt);
        }
    });
});

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

// enable bootstrap tooltips
htmx.onLoad(function(elt) {
    // Clear orphaned tooltips
    document.querySelectorAll('body > div.tooltip[id^=tooltip]').forEach(elt => {
        if ( !document.querySelector(`[aria-describedby="${elt.id}"]`) ) {
            elt.remove();
        }
    });

    jQuery(elt).tooltip({
        selector: '[data-bs-toggle=tooltip]',
        trigger: 'hover focus'
    });

    // Hide the tooltip everywhere when the element is clicked
    jQuery(elt).find('[data-bs-toggle="tooltip"]').click(function () {
        jQuery('[data-bs-toggle="tooltip"]').tooltip("hide");
    });
});

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

// Targeting IE11 in CSS isn't the cleanest or easiest to do.
// If the browser is IE11, add a class to the body to easily detect.
// This could easily be added to for other browser versions if need.
jQuery(function() {
    var ua = window.navigator.userAgent;
    if (ua.indexOf('Trident/') > 0) {
        var rv = ua.indexOf('rv:');
        var version = parseInt(ua.substring(rv + 3, ua.indexOf('.', rv)), 10);

        if (version === 11) {
            document.body.classList.add('IE11');
        }
    }
});

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

// Use Growl to show any UserMessages written to the page
htmx.onLoad( function() {
    var userMessages = RT.UserMessages;
    for (var key in userMessages) {
        jQuery.jGrowl(escapeHTML(userMessages[key]), { sticky: true, themeState: 'none' });
    }
    RT.UserMessages = {};
} );

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
                if (JSON.stringify(payload) === previous_data) {
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
    jQuery(elt).find('a.unclip').click(function() {
        jQuery(this).siblings('div.clip').css('height', 'auto');
        jQuery(this).hide();
        jQuery(this).siblings('a.reclip').show();
        return false;
    });
    jQuery(elt).find('a.reclip').click(function() {
        var clip_div = jQuery(this).siblings('div.clip');
        clip_div.height(clip_div.attr('clip-height'));
        jQuery(this).siblings('a.unclip').show();
        jQuery(this).hide();
        return false;
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

htmx.config.includeIndicatorStyles = false;
