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
        elem = jQuery('body');
    }

    var opts = {
        dateFormat: 'yy-mm-dd',
        constrainInput: false,
        showButtonPanel: true,
        changeMonth: true,
        changeYear: true,
        showOtherMonths: true,
        showOn: 'none',
        selectOtherMonths: true,
        onClose: function() {
            jQuery(this).trigger('datepicker:close');
        }
    };
    elem.find(".datepicker").focus(function() {
        var val = jQuery(this).val();
        jQuery(this).datepicker('show');
    });
    elem.find(".datepicker:not(.withtime)").datepicker(opts);
    elem.find(".datepicker.withtime").datetimepicker( jQuery.extend({}, opts, {
        stepHour: 1,
        // We fake this by snapping below for the minute slider
        //stepMinute: 5,
        hourGrid: 6,
        minuteGrid: 15,
        showSecond: false,
        timeFormat: 'HH:mm:ss',
        // datetimepicker doesn't reset time part when input value is cleared,
        // so we reset it here
        beforeShow: function(input, dp, tp) {
            if ( jQuery(this).val() == '' ) {
                tp.hour = tp._defaults.hour || 0;
                tp.minute = tp._defaults.minute || 0;
                tp.second = tp._defaults.second || 0;
                tp.millisec = tp._defaults.millisec || 0;
            }
        }
    }) ).each(function(index, el) {
        var tp = jQuery.datepicker._get( jQuery.datepicker._getInst(el), 'timepicker');
        if (!tp) return;

        // Hook after _injectTimePicker so we can modify the minute_slider
        // right after it's first created
        tp._base_injectTimePicker = tp._injectTimePicker;
        tp._injectTimePicker = function() {
            this._base_injectTimePicker.apply(this, arguments);

            // Now that we have minute_slider, modify it to be stepped for mouse movements
            var slider = jQuery.data(this.minute_slider[0], "ui-slider");
            slider._base_normValueFromMouse = slider._normValueFromMouse;
            slider._normValueFromMouse = function() {
                var value           = this._base_normValueFromMouse.apply(this, arguments);
                var old_step        = this.options.step;
                this.options.step   = 5;
                var aligned         = this._trimAlignValue( value );
                this.options.step   = old_step;
                return aligned;
            };
        };
    });
}

htmx.onLoad(function(elt) {
    initDatePicker(jQuery(elt));
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
        render: {
            loading: function(data,escape) {
                return '<div class="spinner-border spinner-border-sm ms-3"></div>';
            }
        }
    };

    if ( elt.options && elt.options.length < RT.Config.SelectLiveSearchLimit ) {
        // Under the config limit, don't show the search input box,
        // just a regular dropdown.
        settings.controlInput = null;
    }

    new TomSelect(elt,settings);
}

// Initialize the tom-select library
function initializeSelectElements(elt) {

    // The selectpicker class was used by the bootstrap-select
    // JS library as the default. We retained it because tom-select
    // allows you to set any class value and all of the RT dropdowns
    // already had 'selectpicker'.

    elt.querySelectorAll('select.selectpicker:not(.tomselected)').forEach(initializeSelectElement);
}

function ReplaceAllTextareas(elt) {
    window.CKEDITOR ||= { "instances": {} };

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

            ClassicEditor
                .create( textArea, initArgs )
                .then(editor => {
                    CKEDITOR.instances[editor.sourceElement.name] = editor;
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
                                return CKEDITOR.instances[this.name] && name_filter_regex.test(this.name);
                            }).not(jQuery(editor.sourceElement)).each(function () {
                                if ( CKEDITOR.instances[this.name].getData() !== value ) {
                                    CKEDITOR.instances[this.name].setData(value);
                                };
                            });
                        });
                    }
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

function refreshCollectionListRow(tr, table, success, error) {
    var params = {
        DisplayFormat : table.data('display-format'),
        ObjectClass   : table.data('class'),
        MaxItems      : table.data('max-items'),
        InlineEdit    : table.hasClass('inline-edit'),

        i             : tr.data('index'),
        ObjectId      : tr.data('record-id'),
        Warning       : tr.data('warning')
    };

    tr.addClass('refreshing');

    jQuery.ajax({
        url    : RT.Config.WebHomePath + '/Helpers/CollectionListRow',
        method : 'GET',
        data   : params,
        success: function (response) {
            var index = tr.data('index');
            tr.replaceWith(response);
            // Get the new replaced tr
            tr = table.find('tr[data-index=' + index + ']');
            initDatePicker(tr);
            RT.Autocomplete.bind(tr);
            if (success) { success(response) }
        },
        error: error
    });
}

// disable submit on enter in autocomplete boxes
htmx.onLoad(function() {
    jQuery('input[data-autocomplete], input.ui-autocomplete-input').each(function() {
        var input = jQuery(this);

        input.on('keypress', function(event) {
            if (event.keyCode === 13 && jQuery('ul.ui-autocomplete').is(':visible')) {
                return false;
            }
        });
    });
});

function escapeCssSelector(str) {
    return str.replace(/([^A-Za-z0-9_-])/g,'\\$1');
}

function escapeRegExp(str) {
    return str.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"); // $& means the whole matched string
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

function loadCollapseStates() {
    var cookies = document.cookie.split(/;\s*/);
    var len     = cookies.length;

    for (var i = 0; i < len; i++) {
        var c = cookies[i].split('=');

        if (c[0].match(/^(TitleBox--|accordion-)/)) {
            var e   = document.getElementById(c[0]);
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
            if ( evt.detail.parameters[param + 'Type'] === 'text/html' && CKEDITOR.instances[param] ) {
                evt.detail.parameters[param] = CKEDITOR.instances[param].getData();
            }
        }
    });

    document.body.addEventListener('htmx:beforeRequest', function(evt) {
        if ( evt.detail.boosted ) {
            document.querySelectorAll('.ui-helper-hidden-accessible, ul[id^="ui-id-"], .cke_autocomplete_panel, #ui-datepicker-div').forEach(function(elt) {
               elt.remove();
            });
            document.getElementById('hx-boost-spinner').classList.remove('d-none');

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
            document.getElementById('hx-boost-spinner').classList.add('d-none');
        }
    });

    document.body.addEventListener('htmx:beforeHistorySave', function(evt) {
        if ( RT.loadListeners ) {
            RT.loadListeners.forEach((func) => {
                htmx.off('htmx:load', func);
            });
            RT.loadListeners = [];
        }

        evt.detail.historyElt.querySelector('#hx-boost-spinner').classList.add('d-none');
        evt.detail.historyElt.querySelectorAll('textarea.richtext').forEach(function(elt) {
            CKEDITOR.instances[elt.name].destroy();
        });
        evt.detail.historyElt.querySelectorAll('.hasDatepicker').forEach(function(elt) {
            elt.classList.remove('hasDatepicker');
        });
        document.querySelectorAll('.tomselected').forEach(elt => elt.tomselect.destroy());
    });

    // Detect 400/500 errors
    document.body.addEventListener('htmx:beforeSwap', function(evt) {
        const status = evt.detail.xhr.status.toString();
        if (status.match(/^[45]/)) {
            if (evt.target && evt.detail.requestConfig.verb === "get") {
                evt.detail.shouldSwap = true;
            }
            else {
                // Fall back to general 400/500 errors for 4XX/5XX errors without specific messages
                const message = RT.I18N.Catalog['http_message_' + status] || RT.I18N.Catalog['http_message_' + status.substr(0, 1) + '00'];
                if (message) {
                    alertError(message);
                }
            }
        }
    });

    // Detect network errors
    document.body.addEventListener('htmx:sendError', function(evt) {
        if ( RT.I18N.Catalog['http_message_network'] ) {
            alertError(RT.I18N.Catalog['http_message_network']);
        }
    });

    document.body.addEventListener('actionsChanged', function(evt) {
        if ( evt.detail.value ) {
            for ( const action of evt.detail.value ) {
                jQuery.jGrowl(action, { themeState: 'none' });
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
                                jQuery.jGrowl(reason, { sticky: true, themeState: 'none' });
                            }
                        });
                    }
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

    jQuery(elt).find("#articles-create, .article-create-modal").click(function(ev){
        ev.preventDefault();
        htmx.ajax('GET', RT.Config.WebHomePath + "/Articles/Helpers/CreateInClass", '#dynamic-modal').then(() => {
            bootstrap.Modal.getOrCreateInstance('#dynamic-modal').show();
        });
    });

    jQuery(elt).find(".card .card-header .toggle").each(function() {
        var e = jQuery(jQuery(this).attr('data-bs-target'));
        e.on('hide.bs.collapse', function () {
            createCookie(e.attr('id'),0,365);
            e.closest('div.titlebox').find('div.card-header span.right').addClass('invisible');
        });
        e.on('show.bs.collapse', function () {
            createCookie(e.attr('id'),1,365);
            e.closest('div.titlebox').find('div.card-header span.right').removeClass('invisible');
        });
    });

    jQuery(elt).find(".card .accordion-item .toggle").each(function() {
        var e = jQuery(jQuery(this).attr('data-bs-target'));
        e.on('hide.bs.collapse', function () {
            createCookie(e.attr('id'),0,365);
        });
        e.on('show.bs.collapse', function () {
            createCookie(e.attr('id'),1,365);
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

    loadCollapseStates();

    if ( window.location.href.indexOf('/Admin/Lifecycles/Advanced.html') != -1 || window.location.href.indexOf('/Admin/PageLayouts/Advanced.html') != -1 ) {
        var validate_json = function (str) {
            try {
                JSON.parse(str);
            } catch (e) {
                return false;
            }
            return true;
        };

        jQuery(elt).find('[name=Config], [name=Maps]').bind('input propertychange', function() {
            var form = jQuery(this).closest('form');
            if ( validate_json(jQuery(this).val()) ) {
                form.find('input[type=submit]').prop('disabled', false);
                form.find('.invalid-json').addClass('hidden');
            }
            else {
                form.find('input[type=submit]').prop('disabled', true);
                form.find('.invalid-json').removeClass('hidden');
            }
        });
    }

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
        if ( new_value.hasClass('ui-autocomplete-input') ) {
            var source = new_value.autocomplete( "option" ).source;
            new_value = new_value.clone();
            new_value.autocomplete({ source: source });
        }
        else {
            new_value = new_value.clone();
        }

        new_value.attr('id', null).removeClass('tomselected ts-hidden-accessible');
        row.children('div.rt-search-value').children().remove();
        row.children('div.rt-search-value').append(new_value);
        if ( new_value.hasClass('datepicker') ) {
            new_value.removeClass('hasDatepicker');
            initDatePicker(row);
        }
        initializeSelectElements(row.get(0));
    });

    jQuery(elt).find(".search-filter").click(function(ev){
        ev.preventDefault();
        var modal = jQuery(this).closest('th').find('.modal.search-results-filter');
        modal.css('top', jQuery(this).offset().top);
        var left = jQuery(this).offset().left;
        modal.find('div.modal-content').css('max-height', jQuery(window).height() - jQuery(this).offset().top - 10);
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
        });

        modal.modal('show');
    });

    jQuery(elt).closest('form, body').find('input[name=QueueChanged]').each(function() {
        var form = jQuery(this).closest('form');
        var mark_changed = function(name) {
            if ( !form.find('input[name=ChangedField][value="' + name +'"]').length ) {
                jQuery('<input type="hidden" name="ChangedField" value="' + name + '">').appendTo(form);
            }
        };

        form.find(':input[name!=ChangedField]:not(.mark-changed)').each(function() {
            jQuery(this).addClass('.mark-changed');
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
                if (CKEDITOR.instances && CKEDITOR.instances[messageBoxName]) {
                    const richTextEditor = CKEDITOR.instances[messageBoxName];
                    richTextEditor.model.document.on( 'change:data', () => {
                        mark_changed(plainMessageBox.attr('name'));
                    });
                    clearInterval(interval);
                }
            }, 200);
        }
    });

    // Handle implicit form submissions like hitting Return/Enter on text inputs
    jQuery(elt).find('form[name=search-results-filter]').submit(filterSearchResults);
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

    // Submit all forms only once.
    // This stops all forms of double-clicking or double
    // enter/return key.
    jQuery(elt).find('form').each(function() {
        var form = jQuery(this);
        form.on('submit', function (e) {
            // Prevent if already submitting
            if (form.hasClass('rt-form-submitted')) {
                e.preventDefault();
            }

            // Add class to hook our visual indicator on
            form.addClass('rt-form-submitted');
        });
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
    jQuery(elt).find('div.time-tracking input[name=Date], div.time-tracking input[name=User]').change( function() {
        jQuery(this).closest('form').submit();
    });

    jQuery(elt).find("div.time-tracking input[name=UserString]").on("autocompleteselect", function( event, ui ) {
        jQuery(this).closest('form').find('input[name=User]').val(ui.item.id).change();
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
});

function filterSearchResults (type) {
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

    var refresh_form = jQuery('div.refresh form');
    var base_query = refresh_form.find('input[name=BaseQuery]').val();

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

    refresh_form.find('input[name=Query]').val(query);
    htmx.trigger(refresh_form.get(0), 'submit');
    return false;
};

/* inline edit */
jQuery(function () {
    var inlineEditEnabled = true;

    var escapeKeyHandler = null;

    var beginInlineEdit = function (cell) {
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

        editor.css('top', top);
        editor.css('left', left);

        editor.css('width', cell.width() > 100 ? cell.width() : 100 );
        cell.addClass('editing');

        // Editor's height is bigger than viewer. Here we lift it up so editor can better take the viewer's position
        editor.css('margin-top', (cell.height() - editor.height())/2);

        editor.find(':input:visible:enabled:first').focus();
        setTimeout( function(){
            editor.find('select.selectpicker')[0].tomselect.open();
        }, 100);

        jQuery('body').addClass('inline-editing');

        escapeKeyHandler = function (e) {
            if (e.keyCode == 27) {
                e.preventDefault();
                cancelInlineEdit(editor);
            }
        };
        jQuery(document).keyup(escapeKeyHandler);
    };

    var cancelInlineEdit = function (editor) {
        var cell = editor.closest('div');

        cell.removeClass('editing');
        editor.get(0).reset();

        jQuery('body').removeClass('inline-editing');

        if (escapeKeyHandler) {
            jQuery(document).off('keyup', escapeKeyHandler);
        }
    };

    var submitInlineEdit = function (editor, cell) {
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

        var tr = cell.closest('tr');
        var table = tr.closest('table');

        if (!cell.hasClass('editing')) {
            return;
        }

        var params = editor.serialize();

        editor.find(':input').attr('disabled', 'disabled');
        cell.removeClass('editing').addClass('loading');
        jQuery('body').removeClass('inline-editing');
        tr.addClass('refreshing');

        var renderError = function (error) {
            jQuery.jGrowl(error, { sticky: true, themeState: 'none' });
            cell.removeClass('loading');
            tr.removeClass('refreshing');
            editor.find(':input').removeAttr('disabled');
            var errorMessage = jQuery('<div>'+loc_key('error')+'</div>')
                .addClass('error text-danger').hide();
            var fadeTime = 250;
            cell.find('div.value').fadeOut(fadeTime,function () {
                cell.append(errorMessage);
                errorMessage.fadeIn(fadeTime, function () {
                    setTimeout(function () {
                        errorMessage.fadeOut(fadeTime, function () {
                            errorMessage.remove();
                            cell.find('div.value').fadeIn(fadeTime);
                        });
                    }, 2000);
                });
            });
            jQuery(document).off('keyup', escapeKeyHandler);
        };
        jQuery.ajax({
            url     : editor.attr('action'),
            method  : 'POST',
            data    : params,
            dataType: "json",
            success : function (results) {
                jQuery.each(results.actions, function (i, action) {
                    jQuery.jGrowl(action, { themeState: 'none' });
                });

                refreshCollectionListRow(
                    tr,
                    table,
                    function () {
                        jQuery(document).off('keyup', escapeKeyHandler);
                        clipContent(table);
                    },
                    function (xhr, error) {
                        renderError(error);
                    }
                );
            },
            error   : function (xhr, error) {
                renderError(error);
            }
        });
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
                document.querySelector('#dynamic-modal form').addEventListener('submit', function(evt) {
                    evt.preventDefault();

                    document.querySelectorAll('#dynamic-modal form textarea.richtext').forEach((textarea) => {
                        const name = textarea.name;
                        if ( CKEDITOR.instances[name] ) {
                            if ( CKEDITOR.instances[name].getData() !== textarea.value ) {
                                CKEDITOR.instances[name].updateSourceElement();
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

    jQuery(document).on('submit', 'div.editable.editing form', function (e) {
        e.preventDefault();
        submitInlineEdit(jQuery(this));
    });

    jQuery(document).on('click', 'div.editable .cancel', function (e) {
        cancelInlineEdit(jQuery(this).closest('form'));
    });

    jQuery(document).on('click', 'div.editable .submit', function (e) {
        submitInlineEdit(jQuery(this).closest('form'));
    });

    jQuery(document).on('change', 'div.editable.editing form select', function () {
        submitInlineEdit(jQuery(this).closest('form'));
    });

    jQuery(document).on('datepicker:close', 'div.editable.editing form .datepicker', function () {
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

    var toggle_inline_edit = function (link) {
        link.siblings('.inline-edit-toggle').removeClass('hidden');
        link.addClass('hidden');
        link.closest('.titlebox').toggleClass('editing');
    }

    jQuery(elt).find('.inline-edit-toggle').click(function (e) {
        e.preventDefault();
        toggle_inline_edit(jQuery(this));
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
        toggle_inline_edit(container.find('.inline-edit-toggle:visible'));
    });

    jQuery(elt).find('form.inline-edit').submit(function (e) {
        toggle_inline_edit(jQuery(this).closest('.titlebox').find('.inline-edit-toggle:visible'));
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
        jQuery.jGrowl(userMessages[key], { sticky: true, themeState: 'none' });
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
            if ( jQuery(this).children().height() > max_height ) {
                jQuery(this).children().wrapAll('<div class="clip">');
                var height = '' + max_height + 'px';
                jQuery(this).children('div.clip').attr('clip-height', height).height(height);
                jQuery(this).append('<a href="#" class="unclip button btn btn-primary">' + loc_key('unclip') + '</a>');
                jQuery(this).append('<a href="#" class="reclip button btn btn-primary" style="display: none;">' + loc_key('clip') + '</a>');
            }
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
<div id="rt-content-fetch-errors-network" class="p-3 text-danger-emphasis bg-danger-subtle border border-danger-subtle rounded-3">
  <span class="danger-text-emphasis">${message}</span>
</div>`, { sticky: true, themeState: 'none' });
}
