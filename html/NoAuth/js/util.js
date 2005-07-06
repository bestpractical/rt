% $r->content_type('application/x-javascript');

function rollup(link, id) {
    var e = document.getElementById(id);
    
    if (e.className.match(/\bhidden\b/)) {
        show(e);
        link.className = link.className.replace(/\s?\brolled-up\b/, '');
    }
    else {
        hide(e);
        if (link.className)
            link.className += ' rolled-up';
        else
            link.className = 'rolled-up';
    }
    link.focus(0);
    return false;
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
    var tmp = (document.getElementsByName(id));
    if (tmp.length > 0) tmp[tmp.length-1].focus();
}

function openCalWindow(field) {
    var objWindow = window.open('<%$RT::WebPath%>/CalPopup.html?field='+field, 'Pick', 'height=400,width=400,scrollbars=1');
    objWindow.focus();
}

% $m->abort;
