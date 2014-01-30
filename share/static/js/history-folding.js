function fold_message_stanza(e,showmsg, hidemsg) {
    var box = jQuery(e).next('.message-stanza');
    if ( box.hasClass('closed') ) {
        jQuery([e, box[0]]).removeClass('closed').addClass('open');
        jQuery(e).text( hidemsg);
    } else {
        jQuery([e, box[0]]).addClass('closed').removeClass('open');
        jQuery(e).text( showmsg);
    }
}

function toggle_all_folds(e, showmsg, hidemsg) {
    var link    = jQuery(e);
    var history = link.closest(".history");
    var dir     = link.attr('data-direction');

    if (dir == 'open') {
        history.find(".message-stanza-folder.closed").click();
        link.attr('data-direction', 'closed').text(hidemsg);
    }
    else if (dir == 'closed') {
        history.find(".message-stanza-folder.open").click();
        link.attr('data-direction', 'open').text(showmsg);
    }
    return false;
}
