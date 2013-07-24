function loc_key(key) {
    if (arguments.length > 1 && console && console.log)
        console.log("loc_key() does not support substitution! (for key: " + key + ")")

    var msg;
    if (RT.I18N && RT.I18N.Catalog)
        msg = RT.I18N.Catalog[key];

    if (msg == null && console && console.log) {
        console.log("I18N key '" + key + "' not found in catalog");
        msg = "(no translation for key: " + key + ")";
    }

    return msg;
}
