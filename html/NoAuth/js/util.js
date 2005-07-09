function rollup(id) {
    var e    = document.getElementById(id);
    var link = document.getElementById(id+"-link");
    
    if (e.className.match(/\bhidden\b/)) {
        set_rollup_state(e,link,'shown');
        createCookie(id,1,365);
    }
    else {
        set_rollup_state(e,link,'hidden');
        createCookie(id,0,365);
    }
    return false;
}

function set_rollup_state(e,link,state) {
    if (e && link) {
        if (state == 'shown') {
            show(e);
            link.className = link.className.replace(/\s?\brolled-up\b/, '');
        }
        else if (state == 'hidden') {
            hide(e);
            if (link.className)
                link.className += ' rolled-up';
            else
                link.className = 'rolled-up';
        }
    }
}

function hideshow(id) {
    var e = document.getElementById(id);
    
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
    show(document.getElementById(id1));
    show(document.getElementById(id2));
    
    hide(document.getElementById(id2));
    
    return false;
}

function setFocus(id) {
    var e = document.getElementById(id);
    if (e) e.focus();
}

function openCalWindow(field) {
    var objWindow = window.open('<%$RT::WebPath%>/CalPopup.html?field='+field, 'Pick', 'height=400,width=400,scrollbars=1');
    objWindow.focus();
}
