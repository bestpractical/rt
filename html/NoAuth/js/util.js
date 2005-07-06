% $r->content_type('application/x-javascript');

function hideshow(id) {
    e = document.getElementById(id);
    
    if (e.className.match(/\bhidden\b/))
        e.className = e.className.replace(/\s?\bhidden\b/, '');
    else {
        if (e.className)
            e.className += ' hidden';
        else
            e.className = 'hidden';
    }
    return false;
}   

function openCalWindow(field) {
    var objWindow = window.open('<%$RT::WebPath%>/CalPopup.html?field='+field, 'Pick', 'height=400,width=400,scrollbars=1');
    objWindow.focus();
}

% $m->abort;
