function passkeyModal(title, bodyBuilder, footerBuilder) {
    return new Promise(function (resolve) {
        var modal = jQuery(
            '<div class="modal" tabindex="-1" role="dialog">'
          +   '<div class="modal-dialog modal-dialog-centered" role="document">'
          +     '<div class="modal-content">'
          +       '<div class="modal-header">'
          +         '<h5 class="modal-title"></h5>'
          +         '<a href="javascript:void(0)" class="close" data-dismiss="modal" aria-label="Close">'
          +           '<span aria-hidden="true">&times;</span>'
          +         '</a>'
          +       '</div>'
          +       '<div class="modal-body"></div>'
          +       '<div class="modal-footer"></div>'
          +     '</div>'
          +   '</div>'
          + '</div>'
        );
        modal.find('.modal-title').text(title);
        var body   = modal.find('.modal-body');
        var footer = modal.find('.modal-footer');
        var ctx    = { modal: modal, resolve: resolve };
        bodyBuilder(body, ctx);
        footerBuilder(footer, ctx);
        modal.appendTo('body');
        modal.on('shown.bs.modal',  function () { ctx.shown  && ctx.shown();  });
        modal.on('hidden.bs.modal', function () {
            modal.remove();
            resolve(ctx.result);
        });
        modal.modal('show');
    });
}

function passkeyAlert(title, message) {
    return passkeyModal(
        title,
        function (body) { body.text(message); },
        function (footer, ctx) {
            jQuery('<button type="button" class="button btn btn-primary"></button>')
                .text(RT.I18N.Catalog.ok)
                .on('click', function () { ctx.modal.modal('hide'); })
                .appendTo(footer);
        }
    );
}

function passkeyConfirm(title, message) {
    return passkeyModal(
        title,
        function (body) { body.text(message); },
        function (footer, ctx) {
            jQuery('<button type="button" class="button btn btn-secondary mr-2"></button>')
                .text(RT.I18N.Catalog.cancel)
                .on('click', function () { ctx.modal.modal('hide'); })
                .appendTo(footer);
            jQuery('<button type="button" class="button btn btn-primary"></button>')
                .text(RT.I18N.Catalog.ok)
                .on('click', function () {
                    ctx.result = true;
                    ctx.modal.modal('hide');
                })
                .appendTo(footer);
        }
    );
}

function passkeyPrompt(title, label, options) {
    options = options || {};
    var inputType = options.type === 'password' ? 'password' : 'text';
    var required = options.required ? true : false;
    return passkeyModal(
        title,
        function (body, ctx) {
            jQuery('<label class="d-block mb-2"></label>').text(label).appendTo(body);
            var input = jQuery('<input class="form-control" />')
                .attr('type', inputType)
                .val(options.value || '');
            if (required) input.attr('required', true);
            var resolveIfValid = function () {
                if (required && !input[0].checkValidity()) {
                    input[0].reportValidity();
                    return;
                }
                ctx.result = input.val();
                ctx.modal.modal('hide');
            };
            input.on('keydown', function (e) {
                if (e.key === 'Enter') {
                    e.preventDefault();
                    resolveIfValid();
                }
            });
            input.appendTo(body);
            ctx.shown = function () { input.trigger('focus'); };
            ctx.input = input;
            ctx.resolveIfValid = resolveIfValid;
        },
        function (footer, ctx) {
            jQuery('<button type="button" class="button btn btn-secondary mr-2"></button>')
                .text(RT.I18N.Catalog.cancel)
                .on('click', function () { ctx.modal.modal('hide'); })
                .appendTo(footer);
            jQuery('<button type="button" class="button btn btn-primary"></button>')
                .text(RT.I18N.Catalog.ok)
                .on('click', function () { ctx.resolveIfValid(); })
                .appendTo(footer);
        }
    );
}

// Base64url helpers operating on ArrayBuffer / Uint8Array.
function b64urlEncode(bytes) {
    const arr = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
    let s = '';
    for (let i = 0; i < arr.length; i++) s += String.fromCharCode(arr[i]);
    return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
function b64urlDecode(str) {
    const pad = '='.repeat((4 - (str.length % 4)) % 4);
    const raw = atob(str.replace(/-/g, '+').replace(/_/g, '/') + pad);
    const out = new Uint8Array(raw.length);
    for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
    return out.buffer;
}

// Detect WebAuthn support. Used by the Login button and the Prefs panel.
function passkeySupported() {
    return !!window.PublicKeyCredential;
}

// JSON helper using fetch.
async function passkeyAjax(url, params) {
    const body = new URLSearchParams(params).toString();
    const res = await fetch(url, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Accept': 'application/json',
        },
        body: body,
        credentials: 'same-origin',
    });
    const json = await res.json().catch(() => ({ error: RT.I18N.Catalog.passkey_invalid_response }));
    return { status: res.status, json: json };
}

// Wraps passkeyAjax with step-up reauth: if the server says reauth is
// required, prompt for the password, hit /Helpers/Passkey/Reauth, then
// retry the original call once. Used by every state-changing helper.
async function passkeyAjaxWithReauth(url, params) {
    let result = await passkeyAjax(url, params);
    if (!(result.json && result.json.reauth)) return result;

    const pw = await passkeyPrompt(
        RT.I18N.Catalog.passkey_modal_reauth,
        RT.I18N.Catalog.passkey_reauth_prompt,
        { type: 'password' }
    );
    if (pw === undefined || pw === '') {
        return { status: 403, json: { error: RT.I18N.Catalog.passkey_reauth_cancelled } };
    }
    const reauth = await passkeyAjax(
        RT.Config.WebPath + '/Helpers/Passkey/Reauth',
        { password: pw }
    );
    if (!(reauth.json && reauth.json.ok)) {
        return { status: reauth.status,
                 json: { error: (reauth.json && reauth.json.error) || RT.I18N.Catalog.passkey_reauth_failed } };
    }
    return await passkeyAjax(url, params);
}

// === Login ceremony ===
async function passkeyLogin() {
    try {
        const { status, json: opts } = await passkeyAjax(
            RT.Config.WebPath + '/NoAuth/Helpers/Passkey/Login',
            { action: 'challenge' }
        );
        if (status !== 200 || opts.error) throw new Error(opts.error || 'No challenge');

        const credential = await navigator.credentials.get({
            publicKey: {
                challenge: b64urlDecode(opts.challenge),
                rpId: opts.rpId,
                allowCredentials: [],
                userVerification: opts.userVerification || 'required',
                timeout: opts.timeout || 60000,
            },
        });
        if (!credential) throw new Error(RT.I18N.Catalog.passkey_no_credential);

        const r = credential.response;
        const params = {
            action:             'verify',
            credential_id:      credential.id,
            client_data_json:   b64urlEncode(r.clientDataJSON),
            authenticator_data: b64urlEncode(r.authenticatorData),
            signature:          b64urlEncode(r.signature),
            user_handle:        r.userHandle ? b64urlEncode(r.userHandle) : '',
        };
        const next = new URLSearchParams(window.location.search).get('next');
        if (next) params.next = next;

        const { json: result } = await passkeyAjax(
            RT.Config.WebPath + '/NoAuth/Helpers/Passkey/Login',
            params
        );
        if (result.error) throw new Error(result.error);
        window.location = result.redirect || RT.Config.WebPath + '/';
    } catch (e) {
        passkeyAlert(
            RT.I18N.Catalog.passkey_modal_error,
            RT.I18N.Catalog.passkey_login_failed_prefix + ' ' + (e.message || e)
        );
    }
}

// === Registration ceremony ===
async function passkeyRegister(name) {
    try {
        const { json: opts } = await passkeyAjaxWithReauth(
            RT.Config.WebPath + '/Helpers/Passkey/Register',
            { action: 'challenge', name: name || '' }
        );
        if (opts.error) throw new Error(opts.error);

        const credential = await navigator.credentials.create({
            publicKey: {
                challenge: b64urlDecode(opts.challenge),
                rp: opts.rp,
                user: {
                    id:          b64urlDecode(opts.user.id),
                    name:        opts.user.name,
                    displayName: opts.user.displayName,
                },
                pubKeyCredParams:       opts.pubKeyCredParams,
                excludeCredentials:     (opts.excludeCredentials || []).map(c => ({
                    type: c.type,
                    id:   b64urlDecode(c.id),
                })),
                authenticatorSelection: opts.authenticatorSelection,
                attestation:            opts.attestation,
                timeout:                opts.timeout,
            },
        });
        if (!credential) throw new Error(RT.I18N.Catalog.passkey_no_credential_created);

        const r = credential.response;

        const { json: result } = await passkeyAjaxWithReauth(
            RT.Config.WebPath + '/Helpers/Passkey/Register',
            {
                action:             'verify',
                client_data_json:   b64urlEncode(r.clientDataJSON),
                attestation_object: b64urlEncode(r.attestationObject),
            }
        );
        if (result.error) throw new Error(result.error);
        return result;
    } catch (e) {
        if (e.name === 'InvalidStateError') {
            throw new Error(RT.I18N.Catalog.passkey_already_registered);
        }
        if (e.name === 'NotAllowedError') {
            throw new Error(RT.I18N.Catalog.passkey_registration_cancelled);
        }
        throw e;
    }
}

// === Manage ===
async function passkeyManageRename(id, name, userId) {
    const params = { action: 'rename', id: id, name: name };
    if (userId) params.user_id = userId;
    const { json } = await passkeyAjax(RT.Config.WebPath + '/Helpers/Passkey/Manage', params);
    return json;
}
async function passkeyManageDelete(id, userId) {
    const params = { action: 'delete', id: id };
    if (userId) params.user_id = userId;
    const { json } = await passkeyAjax(RT.Config.WebPath + '/Helpers/Passkey/Manage', params);
    return json;
}
async function passkeyManageDeleteAll(userId) {
    const params = { action: 'delete_all' };
    if (userId) params.user_id = userId;
    const { json } = await passkeyAjax(RT.Config.WebPath + '/Helpers/Passkey/Manage', params);
    return json;
}

// Bind on DOMContentLoaded.
document.addEventListener('DOMContentLoaded', function () {
    // jGrowl any message stashed by a prior passkey action that ended in
    // a page reload (e.g. successful enrollment).
    try {
        const flash = sessionStorage.getItem('passkeyFlash');
        if (flash) {
            sessionStorage.removeItem('passkeyFlash');
            jQuery.jGrowl(flash, { themeState: 'none' });
        }
    } catch (e) { /* sessionStorage unavailable */ }

    const loginBtn = document.getElementById('passkey-login-btn');
    if (loginBtn && passkeySupported()) {
        const container = loginBtn.closest('.passkey-login');
        if (container) container.style.display = '';
        loginBtn.addEventListener('click', function (e) {
            e.preventDefault();
            passkeyLogin();
        });
    }

    const addBtn = document.getElementById('passkey-add-btn');
    if (addBtn && passkeySupported()) {
        addBtn.style.display = '';
        addBtn.addEventListener('click', async function (e) {
            e.preventDefault();
            const name = await passkeyPrompt(
                RT.I18N.Catalog.passkey_modal_add,
                RT.I18N.Catalog.passkey_name_prompt,
                { required: true }
            );
            if (name === undefined) return;
            passkeyRegister(name).then(function () {
                try {
                    // jGrowl renders messages as HTML, so the toast is a
                    // static localized string rather than including the
                    // user-supplied passkey name.
                    sessionStorage.setItem('passkeyFlash', RT.I18N.Catalog.passkey_added);
                } catch (e) { /* ignore */ }
                window.location.reload();
            }).catch(function (err) {
                passkeyAlert(
                    RT.I18N.Catalog.passkey_modal_error,
                    RT.I18N.Catalog.passkey_register_failed_prefix + ' ' + (err.message || err)
                );
            });
        });
    }
});
