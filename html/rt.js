/*
% $r->content_type('application/x-javascript');
*/

function hideshow(num) {
    idstring = "element-" + num;
    chunk = document.getElementById(idstring);
    if ( chunk.style.display == "none")  {
    chunk.style.display = chunk.style.tag;
    } else {
        chunk.style.tag = chunk.style.display;
        chunk.style.display = "none";
    }
}   

function openCalWindow(field) {
    var objWindow = window.open('<%$RT::WebPath%>/CalPopup.html?field='+field, 'Pick', 'height=400,width=400,scrollbars=1');
    objWindow.focus();
}

% $m->abort;
