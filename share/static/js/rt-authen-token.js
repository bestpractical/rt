jQuery(function() {
    var refreshTokenList = function () {
        var list = jQuery('.authtoken-list');
        jQuery.post(
            RT.Config.WebHomePath + "/Helpers/AuthToken/List",
            list.data(),
            function (data) {
                list.replaceWith(data);
            }
        );
    };

    var submitForm = function (form, extraParams) {
        var payload = form.serializeArray();
        var name = extraParams[0].name;

        if (extraParams) {
            Array.prototype.push.apply(payload, extraParams);
        }

        form.addClass('submitting');
        form.find('input').attr('disabled', true);

        var renderResult = function(name, html) {
            if ( name === 'CreateToken' ) {
                var form = jQuery('.modal .authtoken-form');
                if (form.length) {
                    form.replaceWith(html);
                }
                else {
                    jQuery('#body').append(html);
                }
            }
            else {
                jQuery('#auth-token-messages').replaceWith(html);
            }
            refreshTokenList();
        };

        jQuery.ajax({
            method: 'POST',
            url: form.data('ajax-url'),
            data: payload,
            timeout: 30000, /* 30 seconds */
            success: function (data, status) {
                renderResult(name, data);
            },
            error: function (xhr, status, error) {
                renderResult("<p>An error has occurred. Please refresh the page and try again.<p>");
            }
        });
    };

    jQuery('body').on('click', '.authtoken-form button, .authtoken-form input[type=submit]', function (e) {
        e.preventDefault();
        var button = jQuery(this);

        var params = [{ name: button.attr('name'), value: button.attr('value') }];
        submitForm(button.closest('form'), params);
    });

    jQuery('body').on('submit', '.authtoken-form', function (e) {
        e.preventDefault();
        submitForm(jQuery(this));
    });
});

