%# BEGIN BPS TAGGED BLOCK {{{
%#
%# COPYRIGHT:
%#
%# This software is Copyright (c) 1996-2011 Best Practical Solutions, LLC
%#                                          <sales@bestpractical.com>
%#
%# (Except where explicitly superseded by other copyright notices)
%#
%#
%# LICENSE:
%#
%# This work is made available to you under the terms of Version 2 of
%# the GNU General Public License. A copy of that license should have
%# been provided with this software, but in any event can be snarfed
%# from www.gnu.org.
%#
%# This work is distributed in the hope that it will be useful, but
%# WITHOUT ANY WARRANTY; without even the implied warranty of
%# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
%# General Public License for more details.
%#
%# You should have received a copy of the GNU General Public License
%# along with this program; if not, write to the Free Software
%# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
%# 02110-1301 or visit their web page on the internet at
%# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
%#
%#
%# CONTRIBUTION SUBMISSION POLICY:
%#
%# (The following paragraph is not intended to limit the rights granted
%# to you to modify and distribute this software under the terms of
%# the GNU General Public License and is only of importance to you if
%# you choose to contribute your changes and enhancements to the
%# community by submitting them to Best Practical Solutions, LLC.)
%#
%# By intentionally submitting any modifications, corrections or
%# derivatives to this work, or any other work intended for use with
%# Request Tracker, to Best Practical Solutions, LLC, you confirm that
%# you are the copyright holder for those contributions and you grant
%# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
%# royalty-free, perpetual, license to use, copy, create derivative
%# works based on those contributions, and sublicense and distribute
%# those contributions and any derivatives thereof.
%#
%# END BPS TAGGED BLOCK }}}
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

function focusElementById(id) {
    var e = jQuery('#'+id);
    if (e) e.focus();
}

function setCheckbox(form, name, val) {
    var myfield = form.getElementsByTagName('input');
    for ( var i = 0; i < myfield.length; i++ ) {
        if ( name && myfield[i].name != name ) continue;
        if ( myfield[i].type != 'checkbox' ) continue;

        myfield[i].checked = val;
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
    var check = jQuery('#shredder-select-all-objects-checkbox').attr('checked');
    var elements = jQuery('#shredder-search-form :checkbox[name=WipeoutObject]');

    if( check ) {
        elements.attr('checked', true);
    } else {
        elements.attr('checked', false);
    }
}

function checkboxToInput(target,checkbox,val){    
    var tar = jQuery('#' + escapeCssSelector(target));
    var box = jQuery('#' + escapeCssSelector(checkbox));
    if(box.attr('checked')){
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
    jQuery(".ui-datepicker:not(.withtime)").datepicker( {
        dateFormat: 'yy-mm-dd',
        constrainInput: false
    } );

    jQuery(".ui-datepicker.withtime").datepicker( {
        dateFormat: 'yy-mm-dd',
        constrainInput: false,
        onSelect: function( dateText, inst ) {
            // trigger timepicker to get time
            var button = document.createElement('input');
            button.setAttribute('type',  'button');
            jQuery(button).width('5em');
            jQuery(button).insertAfter(this);
            jQuery(button).timepickr({val: '00:00'});
            var date_input = this;

            jQuery(button).blur( function() {
                var time = jQuery(button).val();
                if ( ! time.match(/\d\d:\d\d/) ) {
                    time = '00:00';
                }
                jQuery(date_input).val(  dateText + ' ' + time + ':00' );
                jQuery(button).remove();
            } );

            jQuery(button).focus();
        }
    } );
});

function textToHTML(value) {
    return value.replace(/&/g,    "&amp;")
                .replace(/</g,    "&lt;")
                .replace(/>/g,    "&gt;")
                .replace(/-- \n/g,"--&nbsp;\n")
                .replace(/\n/g,   "\n<br />");
};

function ReplaceAllTextareas(encoded) {
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
        if (jQuery(textArea).hasClass("messagebox")) {
            // Turn the original plain text content into HTML
            if (encoded == 0) {
                textArea.value = textToHTML(textArea.value);
            }
            // For this javascript
            var CKeditorEncoded = document.createElement('input');
            CKeditorEncoded.setAttribute('type', 'hidden');
            CKeditorEncoded.setAttribute('name', 'CKeditorEncoded');
            CKeditorEncoded.setAttribute('value', '1');
            textArea.parentNode.appendChild(CKeditorEncoded);

            // For fckeditor
            var typeField = document.createElement('input');
            typeField.setAttribute('type', 'hidden');
            typeField.setAttribute('name', textArea.name + 'Type');
            typeField.setAttribute('value', 'text/html');
            textArea.parentNode.appendChild(typeField);


            CKEDITOR.replace(textArea.name,{width:'100%',height:'<% RT->Config->Get('MessageBoxRichTextHeight') %>'});
            CKEDITOR.basePath = "<%RT->Config->Get('WebPath')%>/NoAuth/RichText/";

            jQuery("#" + textArea.name + "___Frame").addClass("richtext-editor");
        }
    }
};

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
    h3.html( h3.text().replace(/: .*$/,'') + ": " + title );
}

// when a value is selected from the autocompleter
function addprincipal_onselect(ev, ui) {
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
