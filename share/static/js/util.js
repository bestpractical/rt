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

var showModal = function(html) {
    var modal = jQuery("<div class='modal'></div>");
    modal.append(html).appendTo("body");
    modal.bind('modal:close', function(ev) { modal.remove(); })
    modal.on('hide.bs.modal', function(ev) { modal.remove(); })
    modal.modal('show');

    // We need to refresh the select picker plugin on AJAX calls
    // since the plugin only runs on page load.
    jQuery('.selectpicker').selectpicker('refresh');
};

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

    var selectize = tar[0].selectize;
    if ( selectize ) {
        if( box.prop('checked') ) {
            selectize.createItem(val, false);
        }
        else {
            selectize.removeItem(val, true);
        }
    }
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
        if ( !val.match(/[a-z]/i) ) {
            jQuery(this).datepicker('show');
        }
    });
    elem.find(".datepicker:not(.withtime)").datepicker(opts);
    elem.find(".datepicker.withtime").datetimepicker( jQuery.extend({}, opts, {
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
}

jQuery(function() {
    initDatePicker();
    jQuery('td.collection-as-table:not(.editable)').each( function() {
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
    jQuery('a.unclip').click(function() {
        jQuery(this).siblings('div.clip').css('height', 'auto');
        jQuery(this).hide();
        jQuery(this).siblings('a.reclip').show();
        return false;
    });
    jQuery('a.reclip').click(function() {
        var clip_div = jQuery(this).siblings('div.clip');
        clip_div.height(clip_div.attr('clip-height'));
        jQuery(this).siblings('a.unclip').show();
        jQuery(this).hide();
        return false;
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
    if (plainMessageBox.hasClass('suppress-attachment-warning')) return;

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

function refreshCollectionListRow(tbody, table, success, error) {
    var params = {
        DisplayFormat : table.data('display-format'),
        ObjectClass   : table.data('class'),
        MaxItems      : table.data('max-items'),
        InlineEdit    : table.hasClass('inline-edit'),

        i             : tbody.data('index'),
        ObjectId      : tbody.data('record-id'),
        Warning       : tbody.data('warning')
    };

    tbody.addClass('refreshing');

    jQuery.ajax({
        url    : RT.Config.WebHomePath + '/Helpers/CollectionListRow',
        method : 'GET',
        data   : params,
        success: function (response) {
            var index = tbody.data('index');
            tbody.replaceWith(response);
            // Get the new replaced tbody
            tbody = table.find('tbody[data-index=' + index + ']');
            initDatePicker(tbody);
            tbody.find('.selectpicker').selectpicker();
            if (success) { success(response) }
        },
        error: error
    });
}

function escapeCssSelector(str) {
    return str.replace(/([^A-Za-z0-9_-])/g,'\\$1');
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

    document.cookie = name+"="+value+expires+"; path="+path;
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

    jQuery("#articles-create, .article-create-modal").click(function(ev){
        ev.preventDefault();
        jQuery.get(
            RT.Config.WebHomePath + "/Articles/Helpers/CreateInClass",
            showModal
        );
    });

    jQuery(".card .card-header .toggle").each(function() {
        var e = jQuery(jQuery(this).attr('data-target'));
        e.on('hide.bs.collapse', function () {
            createCookie(e.attr('id'),0,365);
            e.closest('div.titlebox').find('div.card-header span.right').addClass('invisible');
        });
        e.on('show.bs.collapse', function () {
            createCookie(e.attr('id'),1,365);
            e.closest('div.titlebox').find('div.card-header span.right').removeClass('invisible');
        });
    });

    jQuery(".card .accordion-item .toggle").each(function() {
        var e = jQuery(jQuery(this).attr('data-target'));
        e.on('hide.bs.collapse', function () {
            createCookie(e.attr('id'),0,365);
        });
        e.on('show.bs.collapse', function () {
            createCookie(e.attr('id'),1,365);
        });
    });

    jQuery(".card .card-body .toggle").each(function() {
        var e = jQuery(jQuery(this).attr('data-target'));
        e.on('hide.bs.collapse', function (event) {
            event.stopPropagation();
        });
        e.on('show.bs.collapse', function (event) {
            event.stopPropagation();
        });
    });

    if ( jQuery('.combobox').combobox ) {
        jQuery('.combobox').combobox({ clearIfNoMatch: false });
        jQuery('.combobox-wrapper').each( function() {
            jQuery(this).find('input[type=text]').prop('name', jQuery(this).data('name')).prop('value', jQuery(this).data('value'));
        });
    }

    /* Show selected file name in UI */
    jQuery('.custom-file input').change(function (e) {
        jQuery(this).next('.custom-file-label').html(e.target.files[0].name);
    });

    jQuery('#assets-accordion span.collapsed').find('ul.toplevel:not(.sf-menu)').addClass('sf-menu sf-js-enabled sf-shadow').superfish({ dropShadows: false, speed: 'fast', delay: 0 }).supposition().find('a').click(function(ev){
      ev.stopPropagation();
      return true;
    });

    loadCollapseStates();
    Chart.platform.disableCSSInjection = true;

    if ( window.location.href.indexOf('/Admin/Lifecycles/Advanced.html') != -1 ) {
        var validate_json = function (str) {
            try {
                JSON.parse(str);
            } catch (e) {
                return false;
            }
            return true;
        };

        jQuery('[name=Config]').bind('input propertychange', function() {
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

    if ( RT.Config.WebDefaultStylesheet.match(/dark/) ) {

        // Add action type into iframe to customize default font color
        jQuery(['action-response', 'action-comment']).each(function(index, class_name) {
            jQuery('.' + class_name).on('DOMNodeInserted', 'iframe', function(e) {
                setTimeout(function() {
                    jQuery(e.target).contents().find('.cke_editable').addClass(class_name);
                }, 100);
            });
        });

        // Toolbar dropdowns insert iframes, we can apply css files there.
        jQuery('body').on('DOMNodeInserted', '.cke_panel', function(e) {
            setTimeout( function(){
                var content = jQuery(e.target).find('iframe').contents();
                content.find('head').append('<link rel="stylesheet" type="text/css" href="' + RT.Config.WebPath + '/static/RichText/contents-dark.css" media="screen">');
            }, 0);
        });

        // "More colors" in color toolbars insert content directly into main DOM.
        // This is to rescue colored elements from global dark bg color.
        jQuery('body').on('DOMNodeInserted', '.cke_dialog_container', function(e) {
            if ( !jQuery(e.target).find('.ColorCell:visible').length ) return;

            // Override global dark bg color
            jQuery(e.target).find('.ColorCell:visible').each(function() {
                var style = jQuery(this).attr('style').replace(/background-color:([^;]+);/, 'background-color: $1 !important');
                jQuery(this).attr('style', style);
            });

            // Sync highlight color on hover
            var sync_highlight = function(e) {
                var bg = jQuery(e).css('background-color');
                setTimeout(function() {
                    var style = jQuery('[id^=cke_][id$=_hicolor]:visible').attr('style').replace(/background-color:[^;]+;/, 'background-color: ' + bg + ' !important');
                    jQuery('[id^=cke_][id$=_hicolor]:visible').attr('style', style);
                }, 0);
            };

            jQuery(e.target).find('.ColorCell:visible').hover(function() {
                sync_highlight(this);
            });

            // Sync highlight and selected color on click
            jQuery(e.target).find('.ColorCell:visible').click(function() {
                sync_highlight(this);
                var style = jQuery('[id^=cke_][id$=_selhicolor]:visible').attr('style').replace(/background-color:([^;]+);/, 'background-color: $1 !important');
                jQuery('[id^=cke_][id$=_selhicolor]:visible').attr('style', style);
            });
        });
    }
});

/* inline edit */
jQuery(function () {
    var inlineEditEnabled = true;
    var disableInlineEdit = function () {
        inlineEditEnabled = false;
        jQuery('.editable').removeClass('editing').removeClass('loading');
        jQuery('table.inline-edit').removeClass('inline-edit');
    };

    var escapeKeyHandler = null;

    var beginInlineEdit = function (cell) {
        if (!inlineEditEnabled) {
            return;
        }

        var editor = cell.find('.editor');

        if (jQuery('td.editable.editing').length) {
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
        editor.css('margin-top', (cell.closest('tr').height() - editor.height()) / 2);

        editor.find(':input:visible:enabled:first').focus();
        setTimeout( function(){
            editor.find('.selectpicker').selectpicker('toggle');
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
        var cell = editor.closest('td');
        cell.find('[data-toggle=tooltip]').tooltip('hide');

        cell.removeClass('editing');
        editor.get(0).reset();

        jQuery('body').removeClass('inline-editing');

        if (escapeKeyHandler) {
            jQuery(document).off('keyup', escapeKeyHandler);
        }
    };

    var submitInlineEdit = function (editor) {
        var cell = editor.closest('td');
        cell.find('[data-toggle=tooltip]').tooltip('hide');

        if (!inlineEditEnabled) {
            return;
        }

        // Make sure input's state has been updated
        editor.find('input:focus').blur();

        if (!editor.data('changed')) {
            cancelInlineEdit(editor);
            return;
        }

        var tbody = cell.closest('tbody');
        var table = tbody.closest('table');

        if (!cell.hasClass('editing')) {
            return;
        }

        var params = editor.serialize();

        editor.find(':input').attr('disabled', 'disabled');
        cell.removeClass('editing').addClass('loading');
        jQuery('body').removeClass('inline-editing');
        tbody.addClass('refreshing');

        var renderError = function (error) {
            jQuery.jGrowl(error, { sticky: true, themeState: 'none' });
            cell.addClass('error text-danger').html(loc_key('error'));
            jQuery(document).off('keyup', escapeKeyHandler);
            disableInlineEdit();
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
                    tbody,
                    table,
                    function () {
                        jQuery(document).off('keyup', escapeKeyHandler);
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

    jQuery(document).on('click', 'table.inline-edit td.editable .edit-icon', function (e) {
        var cell = jQuery(this).closest('td');
        if ( jQuery('td.editable.editing form').length ) {
            cancelInlineEdit(jQuery('td.editable.editing form'));
        }
        beginInlineEdit(cell);
    });

    jQuery(document).on('change', 'td.editable.editing form :input', function () {
        jQuery(this).closest('form').data('changed', true);
    });

    jQuery(document).on('submit', 'td.editable.editing form', function (e) {
        e.preventDefault();
        submitInlineEdit(jQuery(this));
    });

    jQuery(document).on('click', 'td.editable .cancel', function (e) {
        cancelInlineEdit(jQuery(this).closest('form'));
    });

    jQuery(document).on('click', 'td.editable .submit', function (e) {
        submitInlineEdit(jQuery(this).closest('form'));
    });

    jQuery(document).on('change', 'td.editable.editing form select', function () {
        submitInlineEdit(jQuery(this).closest('form'));
    });

    jQuery(document).on('datepicker:close', 'td.editable.editing form .datepicker', function () {
        submitInlineEdit(jQuery(this).closest('form'));
    });

    /* inline edit on ticket display */
    var toggle_inline_edit = function (link) {
        link.siblings('.inline-edit-toggle').removeClass('hidden');
        link.addClass('hidden');
        link.closest('.titlebox').toggleClass('editing');
    }

    jQuery('.inline-edit-toggle').click(function (e) {
        e.preventDefault();
        toggle_inline_edit(jQuery(this));
    });

    jQuery('.titlebox[data-inline-edit-behavior="click"] > .titlebox-content').click(function (e) {
        if (jQuery(e.target).is('a, input, select, textarea')) {
            return;
        }

        e.preventDefault();
        var container = jQuery(this).closest('.titlebox');
        if (container.hasClass('editing')) {
            return;
        }
        toggle_inline_edit(container.find('.inline-edit-toggle:visible'));
    });

    /* on submit, pull in all the other inline edit forms' fields into
     * the currently-being-submitted form. that way we don't lose user
     * input */
    jQuery('form.inline-edit').submit(function (e) {
        var currentForm = jQuery(this);

        /* limit to currently-editing forms, since cancelling inline
         * edit merely hides the form */
        jQuery('.titlebox.editing form.inline-edit').each(function () {
            var siblingForm = jQuery(this);

            if (siblingForm.is(currentForm)) {
                return;
            }

            siblingForm.find(':input').each(function () {
                var field = jQuery(this);

                if (field.attr('name') == "") {
                    return;
                }

                /* skip duplicates, such as ticket id */
                if (currentForm.find('[name="' + field.attr('name') + '"]').length > 0) {
                    return;
                }

                var clone = field.clone().hide().appendTo(currentForm);

                /* "For performance reasons, the dynamic state of certain
                 * form elements (e.g., user data typed into textarea
                 * and user selections made to a select) is not copied
                 * to the cloned elements", so manually copy them */
                if (clone.is('select, textarea')) {
                    clone.val(field.val());
                }
            });
        });
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
jQuery(function() {
    jQuery("body").tooltip({
        selector: '[data-toggle=tooltip]',
        trigger: 'hover focus'
    });
});

// toggle bookmark for Ticket/Elements/Bookmark.
// before replacing the bookmark content, hide then dispose of the existing tooltip to
// ensure the tooltips are cycled correctly.
function toggle_bookmark(url, id) {
    jQuery.get(url, function(data) {
        var bs_tooltip = jQuery('div[id^="tooltip"]');
        bs_tooltip.tooltip('hide');
        bs_tooltip.tooltip('dispose');
        jQuery('.toggle-bookmark-' + id).replaceWith(data);
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

    var diff = details_div.find('.diff td.value');
    if (!diff.children().length) {
        diff.load(RT.Config.WebHomePath + '/Helpers/TextDiff', {
            TransactionId: txn_div.attr('data-transaction-id')
        });
    }

    return false;
}

