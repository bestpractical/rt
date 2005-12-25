function filter_cascade (id, val) {
    var select = document.getElementById(id);
    if (!select) { return };
    var i;
    var children = select.childNodes;
    for (i in children) {
        if ( val == '' || children[i].label.substr(0, val.length) == val) {
            show(children[i]);
            continue;
        }
        hide(children[i]);
    }
}
