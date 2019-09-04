jQuery(function () {

    var form = jQuery('form#rights-inspector');
    var display = form.find('.results');
    var loading = form.find('.search .loading');

    var revoking = {};
    var existingRequest;
    var requestTimer;

    var buttonForAction = function (action) {
        return display.find('.revoke button[data-action="' + action + '"]');
    };

    var displayRevoking = function (button) {
        if (button.hasClass('ui-state-disabled')) {
            return;
        }

        button.addClass('ui-state-disabled').prop('disabled', true);
        button.after(loading.clone());
    };

    var displayError = function (message) {
        form.removeClass('awaiting-first-result').removeClass('continuing-load').addClass('error');
        display.empty();
        display.text('Error: ' + message);
    }

    var requestPage;
    requestPage = function (search, continueAfter) {
        search.continueAfter = continueAfter;

        if (requestTimer) {
            clearTimeout(requestTimer);
            requestTimer = null;
        }

        existingRequest = jQuery.ajax({
            url: form.attr('action'),
            data: search,
            timeout: 30000, /* 30 seconds */
            success: function (response) {
                if (response.error) {
                    displayError(response.error);
                    return;
                }

                form.removeClass('error');

                var items = response.results;

                /* change UI only after we find a result */
                if (items.length && form.hasClass('awaiting-first-result')) {
                    display.empty();
                    form.removeClass('awaiting-first-result').addClass('continuing-load');
                }

                jQuery.each(items, function (i, item) {
                    display.append( render_inspector_result( item ) );
                });

                jQuery.each(revoking, function (key, value) {
                    var revokeButton = buttonForAction(key);
                    displayRevoking(revokeButton);
                });

                if (response.continueAfter) {
                    requestPage(search, response.continueAfter);
                }
                else {
                    form.removeClass('continuing-load');

                    if (form.hasClass('awaiting-first-result')) {
                        display.empty();
                        form.removeClass('awaiting-first-result');
                        display.text('No results');
                    }
                }
            },
            error: function (xhr, reason) {
                if (reason == 'abort') {
                    return;
                }

                displayError(xhr.statusText);
            }
        });
    };

    var beginSearch = function (delay) {
        form.removeClass('continuing-load').addClass('awaiting-first-result');
        form.find('button').addClass('ui-state-disabled').prop('disabled', true);

        var serialized = form.serializeArray();
        var search = {};

        jQuery.each(serialized, function(i, field){
            search[field.name] = field.value;
        });

        if (requestTimer) {
            clearTimeout(requestTimer);
            requestTimer = null;
        }

        if (existingRequest) {
            existingRequest.abort();
        }

        if (delay) {
            requestTimer = setTimeout(function () {
                requestPage(search, 0);
            }, delay);
        }
        else {
            requestPage(search, 0);
        }
    };

    display.on('click', '.revoke button', function (e) {
        e.preventDefault();
        var button = jQuery(e.target);
        var action = button.data('action');

        displayRevoking(button);

        revoking[action] = 1;

        jQuery.ajax({
            url: action,
            timeout: 30000, /* 30 seconds */
            success: function (response) {
                button = buttonForAction(action);
                if (!button.length) {
                    alert(response.msg);
                }
                else {
                    button.closest('.revoke').text(response.msg);
                }
                delete revoking[action];
            },
            error: function (xhr, reason) {
                button = buttonForAction(action);
                button.closest('.revoke').text(reason);
                delete revoking[action];
                alert(reason);
            }
        });
    });

    form.find('.search input').on('input', function () {
        beginSearch(200);
    });

    beginSearch();
});


function render_inspector_record (record) {
    return '<span class="record ' + cond_text( record.disabled, 'disabled') + '">'
        +  '  <span class="name ' + cond_text( record.highlight, record.match) + '">'
        +       link_or_text( record.label_highlighted, record.url)
        +  '  </span>'
        +  '  <span class="detail">'
        +       link_or_text( record.detail_highlighted, record.detail_url)
        +       link_or_text( record.detail_extra, record.detail_extra_url)
        +       cond_text( record.disabled, '(disabled)')
        +  '  </span>'
        +     render_inspector_primary_record( record.primary_record)
        +  '</span>'
    ;

}

// rendering functions

function render_inspector_primary_record (primary_record) {
    return primary_record ? '<span class="primary">Contains ' + render_inspector_record( primary_record) + '</span>'
                          : '';
}

function link_or_text (text, url) {
    if( typeof text == 'undefined') {
        return '';
    }
    else if( url && url.length > 0 ) {
        return '<a target="_blank" href="' + url + '">' + text + '</a>';
    }
    else {
        return text;
    }
}

function render_inspector_result (item) {
    var revoke = item.disable_revoke ? 'class="ui-state-disabled" disabled="disabled"' : '';
    return '<div class="result row">'
        +  '  <div class="principal cell col-md-3">' + render_inspector_record( item.principal) + '</div>'
        +  '  <div class="object cell col-md-3">' + render_inspector_record( item.object) + '</div>'
        +  '  <div class="right cell col-md-3">' + item.right_highlighted + '</div>'
        +  '  <div class="revoke cell col-md-2">'
        +  '      <button type="button" data-action="/Helpers/RightsInspector/Revoke?id=' + item.ace.id + '" ' + revoke + '>Revoke</button>'
        + '  </div>'
        + '</div>'
    ;
}

function cond_text ( cond, text = '') {
    return cond ? text : '';
}

