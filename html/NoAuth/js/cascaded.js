function filter_cascade (id, val) {
    var select = document.getElementById(id);
    if (!select) { return };
    var i;
    var children = select.childNodes;
    for (i in children) {
        var style = children[i].style;
        if (!style) { continue };
        if (val == '') {
            style.display = 'block';
            continue;
        }
        if (children[i].label.substr(0, val.length) == val) {
            style.display = 'block';
            continue;
        }
        style.display = 'none';
    }
}
