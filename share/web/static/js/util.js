/*
%# BEGIN BPS TAGGED BLOCK {{{
%# 
%# COPYRIGHT:
%# 
%# This software is Copyright (c) 1996-2008 Best Practical Solutions, LLC
%#                                          <jesse@bestpractical.com>
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
*/

/* Visibility */

function show(id) { delClass( id, 'hidden' ) }
function hide(id) { addClass( id, 'hidden' ) }

function hideshow(id) { return toggleVisibility( id ) }
function toggleVisibility(id) {
    var e = jQuery('#'+id).get(0);

    if ( e.className.match( /\bhidden\b/ ) )
        show(e);
    else
        hide(e);

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

function addClass(id, value) {
    jQuery('#'+id).addClass(value);
}

function delClass(id, value) {
    jQuery('#'+id).removeClass(value);
}

/* Rollups */

function rollup(id) {
    /* this is broken because it's called with title bar which has
     * something like
     * TitleBox--_index.html------5b\\+r6YCf5bu656uL55Sz6KuL5Zau---0
     * and might require escaping for jquery*/
    var e   = jQuery('#'+id).get(0);
    var e2  = e.parentNode;
    if (e.className.match(/\bhidden\b/)) {
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

function doOnLoad(handler) {
    jQuery(handler);
}

/* other utils */

function focusElementById(id) {
    jQuery('#'+id).trigger('focus');
}

function updateParentField(field, value) {
    if (window.opener) {
        window.opener.jQuery('#'+field).value = value;
        window.close();
    }
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
	walkChildElements( root, function(node) {
		if( node.id == plugin_tab_id ) {
			show( node );
		} else {
			hide( node );
		}
	} );
	if( plugin ) {
		show('shredder-submit-button');
	} else {
		hide('shredder-submit-button');
	}
}

function checkAllObjects()
{
    var check = jQuery('#shredder-select-all-objects-checkbox').get(0).checked;
    var elements = jQuery('#shredder-search-form').get(0).elements;
	for( var i = 0; i < elements.length; i++ ) {
		if( elements[i].name != 'wipeout_object' ) {
			continue;
		}
		if( elements[i].type != 'checkbox' ) {
			continue;
		}
		if( check ) {
			elements[i].checked = true;
		} else {
			elements[i].checked = false;
		}
	}
}

function checkboxToInput(target,checkbox,val){    
    var tar = jQuery('#'+target).get(0);
    var box = jQuery('#'+checkbox).get(0);
    if(box.checked){
        if (tar.value==''){
            tar.value=val;
        }else{
            tar.value=val+', '+tar.value;        }
    }else{
        tar.value=tar.value.replace(val+', ','');
        tar.value=tar.value.replace(val,'');
    }
}

