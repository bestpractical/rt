function fold_message_stanza(e,showmsg, hidemsg) {
    var box = jQuery(e).next("br").next('.message-stanza');
    if ( box.css('display') == 'none') {
        box.css('display', 'block');
        jQuery(e).addClass('open');
        jQuery(e).removeClass('closed');
        jQuery(e).text( hidemsg);
    } else {
        box.css('display', 'none');
        jQuery(e).addClass('closed');
        jQuery(e).removeClass('open');
        jQuery(e).text( showmsg);
    }
}
