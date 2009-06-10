%# BEGIN BPS TAGGED BLOCK {{{
%# 
%# COPYRIGHT:
%#  
%# This software is Copyright (c) 1996-2009 Best Practical Solutions, LLC 
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
/* $(...)
    Returns DOM node or array of nodes (if more then one argument passed).
    If argument is node object allready then do nothing.
    // Stolen from Prototype
*/
function $() {
    var elements = new Array();

    for (var i = 0; i < arguments.length; i++) {
        var element = arguments[i];
        if (typeof element == 'string')
            element = document.getElementById(element);

        if (arguments.length == 1)
            return element;

        elements.push(element);
    }

    return elements;
}

/* Visibility */

function show(id) { delClass( id, 'hidden' ) }
function hide(id) { addClass( id, 'hidden' ) }

function hideshow(id) { return toggleVisibility( id ) }
function toggleVisibility(id) {
    var e = $(id);

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
    var e = $(id);
    if ( e.className.match( new RegExp('\b'+ value +'\b') ) )
        return;
    e.className += e.className? ' '+value : value;
}

function delClass(id, value) {
    var e = $(id);
    e.className = e.className.replace( new RegExp('\\s?\\b'+ value +'\\b', 'g'), '' );
}

/* Rollups */

function rollup(id) {
    var e   = $(id);
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


/* onload handlers */

var onLoadStack     = new Array();
var onLoadLastStack = new Array();
var onLoadExecuted  = 0;

function onLoadHook(commandStr) {
    if(typeof(commandStr) == "string") {
        onLoadStack[ onLoadStack.length ] = commandStr;
        return true;
    }
    return false;
}

// some things *really* need to be done after everything else
function onLoadLastHook(commandStr) {
    if(typeof(commandStr) == "string"){
        onLoadLastStack[onLoadLastStack.length] = commandStr;
        return true;
    }
    return false;
}

function doOnLoadHooks() {
    if(onLoadExecuted) return;

    var i;
    for ( i in onLoadStack ) { 
        eval( onLoadStack[i] );
    }
    for ( i in onLoadLastStack ) { 
        eval( onLoadLastStack[i] );
    }
    onLoadExecuted = 1;
}

window.onload = doOnLoadHooks;

/* calendar functions */

function openCalWindow(field) {
    var objWindow = window.open('<%$RT::WebPath%>/Helpers/CalPopup.html?field='+field, 
                                'RT_Calendar', 
                                'height=235,width=285,scrollbars=1');
    objWindow.focus();
}

function createCalendarLink(input) {
    var e = $(input);
    if (e) {
        var link = document.createElement('a');
        link.setAttribute('href', '#');

        clickevent = function clickevent(e) { openCalWindow(input); return false; };
        if (! addEvent(link, "click", clickevent)) {
            return false;
        }
        
        var text = document.createTextNode('<% loc("Choose a date") %>');
        link.appendChild(text);

        var space = document.createTextNode(' ');
        
        e.parentNode.insertBefore(link, e.nextSibling);
        e.parentNode.insertBefore(space, e.nextSibling);

        return true;
    }
    return false;
}

/* other utils */

function focusElementById(id) {
    var e = $(id);
    if (e) e.focus();
}

function updateParentField(field, value) {
    if (window.opener) {
        window.opener.$(field).value = value;
        window.close();
    }
}

function addEvent(obj, sType, fn) {
    if (obj.addEventListener) {
        obj.addEventListener(sType, fn, false);
    } else if (obj.attachEvent) {
        var r = obj.attachEvent("on"+sType, fn);
    } else {
        return false;
    }
    return true;
}

function setCheckbox(form, name, val) {
    var myfield = form.getElementsByTagName('input');
    for ( var i = 0; i < myfield.length; i++ ) {
        if ( name && myfield[i].name != name ) continue;
        if ( myfield[i].type != 'checkbox' ) continue;

        myfield[i].checked = val;
    }
}

