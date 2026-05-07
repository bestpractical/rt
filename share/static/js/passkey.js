function passkeyModal(title, bodyBuilder, footerBuilder) {
    return new Promise(function (resolve) {
        const modal = document.createElement('div');
        modal.className = 'modal';
        modal.tabIndex = -1;
        modal.setAttribute('role', 'dialog');
        modal.innerHTML =
            '<div class="modal-dialog modal-dialog-centered" role="document">'
          +   '<div class="modal-content">'
          +     '<div class="modal-header">'
          +       '<h5 class="modal-title"></h5>'
          +       '<a href="javascript:void(0)" class="close" data-bs-dismiss="modal" aria-label="Close">'
          +         '<span aria-hidden="true">&times;</span>'
          +       '</a>'
          +     '</div>'
          +     '<div class="modal-body"></div>'
          +     '<div class="modal-footer"></div>'
          +   '</div>'
          + '</div>';
        modal.querySelector('.modal-title').textContent = title;
        const instance = bootstrap.Modal.getOrCreateInstance(modal);
        const ctx = { hide: function () { instance.hide(); } };
        bodyBuilder(modal.querySelector('.modal-body'), ctx);
        footerBuilder(modal.querySelector('.modal-footer'), ctx);
        document.body.appendChild(modal);
        modal.addEventListener('shown.bs.modal', function () { ctx.shown && ctx.shown(); });
        modal.addEventListener('hidden.bs.modal', function () {
            instance.dispose();
            modal.remove();
            resolve(ctx.result);
        });
        instance.show();
    });
}

function passkeyButton(className, text, onClick) {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'btn ' + className;
    button.textContent = text;
    button.addEventListener('click', onClick);
    return button;
}

function passkeyAlert(title, message) {
    return passkeyModal(
        title,
        function (body) { body.textContent = message; },
        function (footer, ctx) {
            footer.append(passkeyButton('btn-primary', RT.I18N.Catalog.ok, ctx.hide));
        }
    );
}

function passkeyConfirm(title, message) {
    return passkeyModal(
        title,
        function (body) { body.textContent = message; },
        function (footer, ctx) {
            footer.append(
                passkeyButton('btn-secondary me-2', RT.I18N.Catalog.cancel, ctx.hide),
                passkeyButton('btn-primary', RT.I18N.Catalog.ok, function () {
                    ctx.result = true;
                    ctx.hide();
                })
            );
        }
    );
}

function passkeyPrompt(title, label, options) {
    options = options || {};
    const required = !!options.required;
    return passkeyModal(
        title,
        function (body, ctx) {
            const labelElt = document.createElement('label');
            labelElt.className = 'd-block mb-2';
            labelElt.textContent = label;
            labelElt.htmlFor = 'passkey-prompt-input';

            const input = document.createElement('input');
            input.id = 'passkey-prompt-input';
            input.className = 'form-control';
            if (options.type === 'password') {
                input.type = 'password';
                input.autocomplete = 'current-password';
            }
            else {
                input.type = 'text';
            }
            input.value = options.value || '';
            input.required = required;

            ctx.resolveIfValid = function () {
                if (required && !input.checkValidity()) {
                    input.reportValidity();
                    return;
                }
                ctx.result = input.value;
                ctx.hide();
            };
            input.addEventListener('keydown', function (e) {
                if (e.key === 'Enter' && !e.isComposing) {
                    e.preventDefault();
                    ctx.resolveIfValid();
                }
            });
            body.append(labelElt, input);
            ctx.shown = function () { input.focus(); };
        },
        function (footer, ctx) {
            footer.append(
                passkeyButton('btn-secondary me-2', RT.I18N.Catalog.cancel, ctx.hide),
                passkeyButton('btn-primary', RT.I18N.Catalog.ok, function () { ctx.resolveIfValid(); })
            );
        }
    );
}

// Base64url helpers operating on ArrayBuffer / Uint8Array.
function passkeyB64urlEncode(bytes) {
    const arr = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
    let s = '';
    for (let i = 0; i < arr.length; i++) s += String.fromCharCode(arr[i]);
    return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
function passkeyB64urlDecode(str) {
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

// Server errors are complete messages, so they are shown without the
// client-side prefix
function passkeyServerError(message) {
    const error = new Error(message);
    error.fromServer = true;
    return error;
}

function passkeyErrorText(prefix, error) {
    return error.fromServer ? error.message : prefix + ' ' + (error.message || error);
}

// JSON helper using fetch.
async function passkeyAjax(url, params) {
    const body = new URLSearchParams(params).toString();
    let res;
    try {
        res = await fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
                'Accept': 'application/json',
            },
            body: body,
            credentials: 'same-origin',
        });
    }
    catch (e) {
        return { status: 0, json: { error: RT.I18N.Catalog.passkey_network_error } };
    }
    const json = await res.json().catch(() => ({ error: RT.I18N.Catalog.passkey_invalid_response }));
    return { status: res.status, json: json };
}

// Wraps passkeyAjax with step-up reauth: if the server says reauth is
// required, prompt for the password, hit /Helpers/Passkey/Reauth, then
// retry the original call once. Only registration needs it; rename and
// delete are exempt from step-up (see ReauthFresh).
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
        RT.Config.WebHomePath + '/Helpers/Passkey/Reauth',
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
        if (opts.error) throw passkeyServerError(opts.error);
        if (status !== 200) throw new Error(RT.I18N.Catalog.passkey_no_challenge);

        const credential = await navigator.credentials.get({
            publicKey: {
                challenge: passkeyB64urlDecode(opts.challenge),
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
            client_data_json:   passkeyB64urlEncode(r.clientDataJSON),
            authenticator_data: passkeyB64urlEncode(r.authenticatorData),
            signature:          passkeyB64urlEncode(r.signature),
            user_handle:        r.userHandle ? passkeyB64urlEncode(r.userHandle) : '',
        };
        const next = document.querySelector('form#login input[name="next"]')?.value;
        if (next) params.next = next;

        const { json: result } = await passkeyAjax(
            RT.Config.WebPath + '/NoAuth/Helpers/Passkey/Login',
            params
        );
        if (result.error) throw passkeyServerError(result.error);
        window.location = result.redirect || RT.Config.WebPath + '/';
    } catch (e) {
        // User dismissed the browser's passkey picker
        if (e.name === 'NotAllowedError') return;
        passkeyAlert(
            RT.I18N.Catalog.passkey_modal_error,
            passkeyErrorText(RT.I18N.Catalog.passkey_login_failed_prefix, e)
        );
    }
}

// === Registration ceremony ===
async function passkeyRegister(name) {
    try {
        const { json: opts } = await passkeyAjaxWithReauth(
            RT.Config.WebHomePath + '/Helpers/Passkey/Register',
            { action: 'challenge', name: name || '' }
        );
        if (opts.error) throw passkeyServerError(opts.error);

        const credential = await navigator.credentials.create({
            publicKey: {
                challenge: passkeyB64urlDecode(opts.challenge),
                rp: opts.rp,
                user: {
                    id:          passkeyB64urlDecode(opts.user.id),
                    name:        opts.user.name,
                    displayName: opts.user.displayName,
                },
                pubKeyCredParams:       opts.pubKeyCredParams,
                excludeCredentials:     (opts.excludeCredentials || []).map(c => ({
                    type: c.type,
                    id:   passkeyB64urlDecode(c.id),
                })),
                authenticatorSelection: opts.authenticatorSelection,
                attestation:            opts.attestation,
                timeout:                opts.timeout,
            },
        });
        if (!credential) throw new Error(RT.I18N.Catalog.passkey_no_credential_created);

        const r = credential.response;

        const { json: result } = await passkeyAjaxWithReauth(
            RT.Config.WebHomePath + '/Helpers/Passkey/Register',
            {
                action:             'verify',
                client_data_json:   passkeyB64urlEncode(r.clientDataJSON),
                attestation_object: passkeyB64urlEncode(r.attestationObject),
            }
        );
        if (result.error) throw passkeyServerError(result.error);
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
    const { json } = await passkeyAjax(RT.Config.WebHomePath + '/Helpers/Passkey/Manage', params);
    return json;
}
async function passkeyManageDelete(id, userId) {
    const params = { action: 'delete', id: id };
    if (userId) params.user_id = userId;
    const { json } = await passkeyAjax(RT.Config.WebHomePath + '/Helpers/Passkey/Manage', params);
    return json;
}
async function passkeyManageDeleteAll(userId) {
    const params = { action: 'delete_all' };
    if (userId) params.user_id = userId;
    const { json } = await passkeyAjax(RT.Config.WebHomePath + '/Helpers/Passkey/Manage', params);
    return json;
}

// Bind on initial load and on each htmx swap (the body is hx-boosted).
htmx.onLoad(function (elt) {
    // jGrowl any message stashed by a prior passkey action that ended in
    // a page reload (e.g. successful enrollment).
    try {
        const flash = sessionStorage.getItem('passkeyFlash');
        if (flash) {
            sessionStorage.removeItem('passkeyFlash');
            jQuery.jGrowl(flash, { themeState: 'none' });
        }
    } catch (e) { /* sessionStorage unavailable */ }

    const loginBtn = elt.querySelector('#passkey-login-btn');
    if (loginBtn && passkeySupported()) {
        const container = loginBtn.closest('.passkey-login');
        if (container) container.classList.remove('d-none');
        loginBtn.addEventListener('click', async function (e) {
            e.preventDefault();
            // A second ceremony would replace the session's challenge and fail the first
            loginBtn.disabled = true;
            try {
                await passkeyLogin();
            }
            finally {
                loginBtn.disabled = false;
            }
        });
    }

    const addBtn = elt.querySelector('#passkey-add-btn');
    if (addBtn && passkeySupported()) {
        addBtn.classList.remove('d-none');
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
                    passkeyErrorText(RT.I18N.Catalog.passkey_register_failed_prefix, err)
                );
            });
        });
    }

    const unsupported = elt.querySelector('#passkey-unsupported');
    if (unsupported && !passkeySupported()) {
        unsupported.classList.remove('d-none');
    }

    elt.querySelectorAll('#passkey-list .passkey-rename-btn').forEach(function (btn) {
        btn.addEventListener('click', async function (e) {
            e.preventDefault();
            const row = btn.closest('.passkey-row');
            const oldName = row.getAttribute('data-name') || '';
            let name = await passkeyPrompt(
                RT.I18N.Catalog.passkey_modal_rename,
                RT.I18N.Catalog.passkey_rename_prompt,
                { required: true, value: oldName }
            );
            if (name === undefined) return;
            name = name.trim();
            if (name === oldName) return;
            const r = await passkeyManageRename(row.getAttribute('data-id'), name);
            if (r.error) {
                passkeyAlert(RT.I18N.Catalog.passkey_modal_error, r.error);
                return;
            }
            row.querySelector('strong').textContent = name;
            row.setAttribute('data-name', name);
            jQuery.jGrowl(RT.I18N.Catalog.passkey_renamed, { themeState: 'none' });
        });
    });

    elt.querySelectorAll('#passkey-list .passkey-delete-btn').forEach(function (btn) {
        btn.addEventListener('click', async function (e) {
            e.preventDefault();
            const row = btn.closest('.passkey-row');
            const confirmed = await passkeyConfirm(
                RT.I18N.Catalog.passkey_modal_remove,
                RT.I18N.Catalog.passkey_delete_confirm
            );
            if (!confirmed) return;
            const r = await passkeyManageDelete(row.getAttribute('data-id'));
            if (r.error) {
                passkeyAlert(RT.I18N.Catalog.passkey_modal_error, r.error);
                return;
            }
            const list = row.closest('#passkey-list');
            row.remove();
            if (!list.querySelector('.passkey-row')) {
                list.querySelector('.passkey-empty').classList.remove('d-none');
            }
            jQuery.jGrowl(RT.I18N.Catalog.passkey_deleted, { themeState: 'none' });
        });
    });

    const adminList = elt.querySelector('#admin-passkey-list');
    if (adminList) {
        const userId = adminList.getAttribute('data-user-id');
        const allBtn = elt.querySelector('#admin-passkey-delete-all-btn');
        const showEmptyState = function () {
            adminList.classList.add('d-none');
            if (allBtn) allBtn.classList.add('d-none');
            elt.querySelector('#admin-passkey-empty')?.classList.remove('d-none');
        };

        adminList.querySelectorAll('.passkey-admin-delete-btn').forEach(function (btn) {
            btn.addEventListener('click', async function (e) {
                e.preventDefault();
                const li = btn.closest('li');
                const confirmed = await passkeyConfirm(
                    RT.I18N.Catalog.passkey_modal_remove,
                    RT.I18N.Catalog.passkey_admin_delete_confirm
                );
                if (!confirmed) return;
                const r = await passkeyManageDelete(li.getAttribute('data-id'), userId);
                if (r.error) {
                    passkeyAlert(RT.I18N.Catalog.passkey_modal_error, r.error);
                    return;
                }
                li.remove();
                if (!adminList.querySelector('li')) showEmptyState();
                jQuery.jGrowl(RT.I18N.Catalog.passkey_deleted, { themeState: 'none' });
            });
        });

        if (allBtn) {
            allBtn.addEventListener('click', async function (e) {
                e.preventDefault();
                const confirmed = await passkeyConfirm(
                    RT.I18N.Catalog.passkey_modal_remove_all,
                    RT.I18N.Catalog.passkey_admin_delete_all_confirm
                );
                if (!confirmed) return;
                const r = await passkeyManageDeleteAll(userId);
                if (r.error) {
                    passkeyAlert(RT.I18N.Catalog.passkey_modal_error, r.error);
                    return;
                }
                adminList.innerHTML = '';
                showEmptyState();
                jQuery.jGrowl(RT.I18N.Catalog.passkeys_all_deleted, { themeState: 'none' });
            });
        }
    }
});
