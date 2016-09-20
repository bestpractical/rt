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

function setCheckbox(input, name, val) {
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
            myfield[i].checked = val;
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
        selectOtherMonths: true,
        onClose: function() {
            jQuery(this).trigger('datepicker:close');
        }
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
            tbody.replaceWith(response);
            if (success) { success(response) }
        },
        error: error
    });
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
        jQuery.post('/Helpers/Upload/Delete', { Name: name, Token: token }, function(data) {
            if ( data.status == 'success' ) {
                parent.remove();
            }
        }, 'json');
        return false;
    });
});

/* inline edit */
jQuery(function () {
    var inlineEditEnabled = true;
    var disableInlineEdit = function () {
        inlineEditEnabled = false;
        jQuery('.editable').removeClass('editing').removeClass('loading');
        jQuery('table.inline-edit').removeClass('inline-edit');
    };

    var inlineEditingDate = false;
    var scrollHandler = null;
    var escapeKeyHandler = null;
    var inlineEditFormPristine = null;

    var beginInlineEdit = function (cell) {
        if (!inlineEditEnabled) {
            return;
        }

        var value = cell.find('.value');
        var editor = cell.find('.editor');

        if (jQuery('td.editable.editing').length) {
            return;
        }

        inlineEditPristineForm = cell.find('form').clone();
        var height = cell.height();

        cell.addClass('editing');
        jQuery('body').addClass('inline-editing');

        if (editor.find('textarea').length || editor[0].clientWidth > cell[0].clientWidth) {
            cell.attr('height', height);

            var rect = editor[0].getBoundingClientRect();
            editor.addClass('wide');
            var top = rect.top - parseInt(editor.css('padding-top')) - parseInt(editor.css('border-top-width'));
            var left = rect.left - parseInt(editor.css('padding-left')) - parseInt(editor.css('border-left-width'));
            editor.css({ top: top, left: left });

            var $window = jQuery(window);
            var initialScrollTop = top + $window.scrollTop();

            scrollHandler = function (e) {
                editor.css('top', initialScrollTop - $window.scrollTop());
            };
            jQuery(window).scroll(scrollHandler);
        }

        escapeKeyHandler = function (e) {
            if (e.keyCode == 27) {
                e.preventDefault();
                cancelInlineEdit(editor);
            }
        };
        jQuery(document).keyup(escapeKeyHandler);

        editor.find(':input:visible:enabled:first').focus();

        if (editor.find('.datepicker').length) {
            inlineEditingDate = true;
        }
    };

    var cancelInlineEdit = function (editor) {
        var cell = editor.closest('td');

        inlineEditingDate = false;
        cell.removeClass('editing').removeAttr('height');
        editor.removeClass('wide');
        jQuery('body').removeClass('inline-editing');

        cell.find('form').replaceWith(inlineEditPristineForm);
        inlineEditPristineForm = null;

        if (scrollHandler) {
            jQuery(window).off('scroll', scrollHandler);
        }
        if (escapeKeyHandler) {
            jQuery(document).off('keyup', escapeKeyHandler);
        }
    };

    var submitInlineEdit = function (editor) {
        if (!inlineEditEnabled) {
            return;
        }

        inlineEditingDate = false;

        if (!editor.data('changed')) {
            cancelInlineEdit(editor);
            return;
        }

        var cell = editor.closest('td');
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
        inlineEditPristineForm = null;

        var renderError = function (error) {
            jQuery.jGrowl(error, { sticky: true, themeState: 'none' });
            cell.addClass('error').html(loc_key('error'));
            jQuery(window).off('scroll', scrollHandler);
            jQuery(document).off('keyup', escapeKeyHandler);
            disableInlineEdit();
        };

        jQuery.ajax({
            url     : editor.attr('action'),
            method  : 'POST',
            data    : params,
            success : function (results) {
                jQuery.each(results.actions, function (i, action) {
                    jQuery.jGrowl(action, { themeState: 'none' });
                });

                refreshCollectionListRow(
                    tbody,
                    table,
                    function () {
                        jQuery(window).off('scroll', scrollHandler);
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

    // stop propagation when we click a hyperlink (e.g. ticket subject) so that
    // the td.editable onclick handler doesn't also fire
    jQuery(document).on('click', 'td.editable a', function (e) {
        e.stopPropagation();
    });

    jQuery(document).on('click', 'table.inline-edit td.editable', function (e) {
        var cell = jQuery(this);
        beginInlineEdit(cell);
    });

    jQuery(document).on('change', 'td.editable.editing form :input', function () {
        jQuery(this).closest('form').data('changed', true);
    });

    jQuery(document).on('submit', 'td.editable.editing form', function (e) {
        e.preventDefault();
        submitInlineEdit(jQuery(this));
    });

    jQuery(document).on('focusout', 'td.editable.editing form', function () {
        var editor = jQuery(this);
        if (!inlineEditingDate) {
            // delay submit to give the `td.editable a.cancel` click handler
            // a chance to run
            setTimeout(function () {
                submitInlineEdit(editor);
            }, 100);
        }
    });

    jQuery(document).on('click', 'td.editable a.cancel', function (e) {
        e.preventDefault();
        cancelInlineEdit(jQuery(this).closest('form'));
    });

    jQuery(document).on('change', 'td.editable.editing form select', function () {
        submitInlineEdit(jQuery(this).closest('form'));
    });

    jQuery(document).on('datepicker:close', 'td.editable.editing form .datepicker', function () {
        var editor = jQuery(this);
        editor.closest('form').trigger('submit');
    });

    jQuery('table.collection-as-table').each(function () {
        var table = jQuery(this);
        var cols = table.find('colgroup col');
        if (cols.length == 0) {
            return;
        }

        cols.each(function () {
            var col = jQuery(this);
            col.attr('width', col.width());
        });
        table.css('table-layout', 'fixed');
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
