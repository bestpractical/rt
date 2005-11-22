// Stolen from Prototype
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
            e2.className = e2.className.replace(/\s?\brolled-up\b/, '');
        }
        else if (state == 'hidden') {
            hide(e);
            if (e2.className)
                e2.className += ' rolled-up';
            else
                e2.className = 'rolled-up';
        }
    }
}

function hideshow(id) {
    var e = $(id);
    
    if (e.className.match(/\bhidden\b/))
        show(e);
    else
        hide(e);

    return false;
}

function show(e) {
    e.className = e.className.replace(/\s?\bhidden\b/, '');
}

function hide(e) { 
    if (e.className)
        e.className += ' hidden';
    else
        e.className = 'hidden';
}

function switchVisibility(id1, id2) {
    // Show both and then hide the one we want
    show($(id1));
    show($(id2));
    
    hide($(id2));
    
    return false;
}

function focusElementById(id) {
    var e = $(id);
    if (e) e.focus();
}

function openCalWindow(field) {
    var objWindow = window.open('<%$RT::WebPath%>/Helpers/CalPopup.html?field='+field, 
                                'RT_Calendar', 
                                'height=235,width=285,scrollbars=1');
    objWindow.focus();
}

function updateParentField(field, value) {
    if (window.opener) {
        window.opener.$(field).value = value;
        window.close();
    }
}

function addEvent(obj, sType, fn){
    if (obj.addEventListener){
        obj.addEventListener(sType, fn, false);
    } else if (obj.attachEvent) {
        var r = obj.attachEvent("on"+sType, fn);
    } else {
	return false;
    }
    return true;
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

// onload handlers

var onLoadStack     = new Array();
var onLoadLastStack = new Array();
var onLoadExecuted  = 0;

function onLoadHook(commandStr) {
    if(typeof(commandStr) == "string") {
        onLoadStack[onLoadStack.length] = commandStr;
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
    
    for (var x=0; x < onLoadStack.length; x++) { 
        eval(onLoadStack[x]);
    }
    for (var x=0; x < onLoadLastStack.length; x++) { 
        eval(onLoadLastStack[x]); 
    }
    onLoadExecuted = 1;
}

window.onload = doOnLoadHooks;

