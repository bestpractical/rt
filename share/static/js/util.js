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

/* Rollups */

function rollup(id) {
    var e = jQueryWrap(id);
    var e2  = e.parent();
    
    if (e.hasClass('hidden')) {
        set_rollup_state(e,e2,'shown');
        createCookie(id,1,365);
    }
    else {
        set_rollup_state(e,e2,'hidden');
        createCookie(id,0,365);
    }
    return false;
}

function set_rollup_state(e,e2,state) {
    if (e && e2) {
        if (state == 'shown') {
            show(e);
            delClass( e2, 'rolled-up' );
        }
        else if (state == 'hidden') {
            hide(e);
            addClass( e2, 'rolled-up' );
        }
    }
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
    if(box.prop('checked')){
        if (tar.val()==''){
            tar.val(val);
        }
        else{
            tar.val( val+', '+ tar.val() );        
        }
    }
    else{
        tar.val(tar.val().replace(val+', ',''));
        tar.val(tar.val().replace(val,''));
    }
    jQuery('#UpdateIgnoreAddressCheckboxes').val(true);
    tar.change();
}

// ahah for back compatibility as plugins may still use it
function ahah( url, id ) {
    jQuery('#'+id).load(url);
}

// only for back compatibility, please JQuery() instead
function doOnLoad( js ) {
    jQuery(js);
}

jQuery(function() {
    var opts = {
        dateFormat: 'yy-mm-dd',
        constrainInput: false,
        showButtonPanel: true,
        changeMonth: true,
        changeYear: true,
        showOtherMonths: true,
        showOn: 'none',
        selectOtherMonths: true
    };
    jQuery(".datepicker").focus(function() {
        var val = jQuery(this).val();
        if ( !val.match(/[a-z]/i) ) {
            jQuery(this).datepicker('show');
        }
    });
    jQuery(".datepicker:not(.withtime)").datepicker(opts);
    jQuery(".datepicker.withtime").datetimepicker( jQuery.extend({}, opts, {
        stepHour: 1,
        // We fake this by snapping below for the minute slider
        //stepMinute: 5,
        hourGrid: 6,
        minuteGrid: 15,
        showSecond: false,
        timeFormat: 'HH:mm:ss'
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
});

function textToHTML(value) {
    return value.replace(/&/g,    "&amp;")
                .replace(/</g,    "&lt;")
                .replace(/>/g,    "&gt;")
                .replace(/-- \n/g,"--&nbsp;\n")
                .replace(/\n/g,   "\n<br />");
};

CKEDITOR_BASEPATH=RT.Config.WebPath + "/static/RichText/";
function ReplaceAllTextareas() {
    var sAgent = navigator.userAgent.toLowerCase();
    if (!CKEDITOR.env.isCompatible ||
        sAgent.indexOf('iphone') != -1 ||
        sAgent.indexOf('ipad') != -1 ||
        sAgent.indexOf('android') != -1 )
        return false;

    if (RT.Config.MessageBoxUseSystemContextMenu) {
        CKEDITOR.config.removePlugins = 'liststyle,tabletools,scayt,menubutton,contextmenu';
    }

    // replace all content and signature message boxes
    var allTextAreas = document.getElementsByTagName("textarea");

    for (var i=0; i < allTextAreas.length; i++) {
        var textArea = allTextAreas[i];
        if (jQuery(textArea).hasClass("messagebox richtext")) {
            // Turn the original plain text content into HTML
            var type = jQuery("#"+textArea.name+"Type");
            if (type.val() != "text/html")
                textArea.value = textToHTML(textArea.value);

            // Set the type
            type.val("text/html");

            CKEDITOR.replace(textArea.name,{ width: '100%', height: RT.Config.MessageBoxRichTextHeight });

            jQuery("#" + textArea.name + "___Frame").addClass("richtext-editor");
        }
    }
};

function AddAttachmentWarning() {
    var plainMessageBox  = jQuery('.messagebox');
    var warningMessage   = jQuery('.messagebox-attachment-warning');
    var ignoreMessage    = warningMessage.find('.ignore');
    var dropzoneElement  = jQuery('#attach-dropzone');
    var fallbackElement  = jQuery('.old-attach');
    var reuseElements    = jQuery('#reuse-attachments');

    // there won't be a ckeditor when using the plain <textarea>
    var richTextEditor;
    var messageBoxId = plainMessageBox.attr('id');
    if (CKEDITOR.instances && CKEDITOR.instances[messageBoxId]) {
        richTextEditor = CKEDITOR.instances[messageBoxId];
    }

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
            richTextEditor.on('instanceReady', function () {
                // this set of events is imperfect. what I really want is:
                //     this.on('change', ...)
                // but ckeditor doesn't seem to provide that out of the box

                this.on('blur', function () {
                    toggleAttachmentWarning();
                });

                // we want to capture ~every keystroke type event; we only do the
                // full checking periodically to avoid overloading the browser
                this.document.on("keyup", function () {
                    delayedAttachmentWarning();
                });
                this.document.on("keydown", function () {
                    delayedAttachmentWarning();
                });
                this.document.on("keypress", function () {
                    delayedAttachmentWarning();
                });

                // hook into the undo/redo buttons in the ckeditor UI
                this.getCommand('undo').on('afterUndo', function () {
                    toggleAttachmentWarning();
                });
                this.getCommand('redo').on('afterRedo', function () {
                    toggleAttachmentWarning();
                });
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
        jQuery(input).nextAll(".warning").hide();
        jQuery("#acl-AddPrincipal input[type=checkbox]").removeAttr("disabled");
    } else {
        jQuery(input).nextAll(".warning").css("display", "block");
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
    var principal_link = jQuery(ev.target).closest('form').find('ul.ui-tabs-nav a[href="#acl-' + ui.item.id + '"]:first');
    if (principal_link.size()) {
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


jQuery(function() {
    jQuery(".user-accordion").each(function(){
        jQuery(this).accordion({
            active: (jQuery(this).find("h3").length == 1 ? 0 : false),
            collapsible: true,
            heightStyle: "content",
            header: "h3"
        }).find("h3 a.user-summary").click(function(ev){
            ev.stopPropagation();
            return true;
        });
    });
    ReplaceAllTextareas();
    jQuery('select.chosen.CF-Edit').chosen({ width: '20em', placeholder_text_multiple: ' ', no_results_text: ' ', search_contains: true });
    AddAttachmentWarning();
    jQuery('a.delete-attach').click( function() {
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
});

// focus jquery object in window, only moving the screen when necessary
function scrollToJQueryObject(obj) {
    if (!obj.length) return;

    var viewportHeight = jQuery(window).height(),
        currentScrollPosition = jQuery(window).scrollTop(),
        currentItemPosition = obj.offset().top,
        currentItemSize = obj.height() + obj.next().height();

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
