document.addEventListener('htmx:configRequest', function(evt) {
    for ( const param in evt.detail.parameters ) {
        if ( evt.detail.parameters[param + 'Type'] === 'text/html' && RT.CKEditor.instances[param] ) {
            evt.detail.parameters[param] = RT.CKEditor.instances[param].getData();
        }
    }
});

document.addEventListener('htmx:beforeRequest', function(evt) {
    if ( evt.detail.boosted ) {
        document.getElementById('hx-boost-spinner').classList.remove('invisible');
        document.querySelector('.main-container').classList.add('refreshing');
        jQuery.jGrowl('close');

        // Highlight active top menu
        if ( evt.detail.elt.tagName === 'A' ) {
            const href = evt.detail.elt.getAttribute('href');
            document.querySelectorAll('#app-nav a.menu-item.active:not([href="' + href + '"]').forEach(function(elt) {
                elt.classList.remove('active');
            });
            document.querySelectorAll('#app-nav a.menu-item[href="' + href + '"]').forEach(function(elt) {
                elt.classList.add('active');
                let parent = elt.closest('ul').previousElementSibling;
                while ( parent ) {
                    parent.classList.add('active');
                    parent = parent.closest('ul').previousElementSibling;
                }
            });
        }
    }
});

document.addEventListener('htmx:afterRequest', function(evt) {
    if ( evt.detail.boosted ) {
        document.getElementById('hx-boost-spinner').classList.add('invisible');
        document.querySelector('.main-container').classList.remove('refreshing');
    }

    if ( evt.detail.elt.classList.contains('htmx-load-widget') ) {
        // hx-vals is only used to load the widget initially. Here we unset it to prevent it from being inherited by children.
        evt.detail.elt.removeAttribute('hx-vals');
    }

    if ( evt.detail.requestConfig.elt.classList.contains('search-results-filter') ) {
        // Clear the modal after a search filter
        const modalElt = evt.detail.requestConfig.elt.closest('.modal.search-results-filter');
        bootstrap.Modal.getInstance(modalElt)?.hide();

        // Clean up any stray backdrop
        document.querySelectorAll('.modal-backdrop').forEach(el => el.remove());
    }

    // Close the dropdown after successful form submission
    if ( evt.target.classList.contains('transaction-filter-form') ) {
        const txn_filter_dropdown = evt.target.querySelector('.transaction-filter');
        if ( txn_filter_dropdown ) {
            bootstrap.Dropdown.getInstance(txn_filter_dropdown)?.hide();
        }
    }
});

document.addEventListener('htmx:beforeHistorySave', function(evt) {
    if ( RT.loadListeners ) {
        RT.loadListeners.forEach((func) => {
            htmx.off('htmx:load', func);
        });
        RT.loadListeners = [];
    }

    evt.detail.historyElt.querySelector('#hx-boost-spinner').classList.add('invisible');
    evt.detail.historyElt.querySelector('.main-container').classList.remove('refreshing');
    evt.detail.historyElt.querySelectorAll('textarea.richtext').forEach(function(elt) {
        RT.CKEditor.instances[elt.name]?.destroy();
    });
    evt.detail.historyElt.querySelector('.ck-body-wrapper')?.remove();

    evt.detail.historyElt.querySelectorAll('.tomselected').forEach(elt => elt.tomselect?.destroy());
    evt.detail.historyElt.querySelectorAll('.dropzone-init').forEach(elt => elt.dropzone?.destroy());
    evt.detail.historyElt.querySelectorAll('.datepicker').forEach(elt => elt.tempusDominus?.dispose());
    disposeCombobox(evt.detail.historyElt);
});

document.addEventListener('htmx:beforeCleanupElement', function(evt) {
    const elt = evt.detail.elt;

    // elt might be a plain string
    if ( ! (elt instanceof Element) ) return;
    const toggles = [
        { selector: '[data-bs-toggle="tooltip"]', component: 'Tooltip' },
        { selector: '[data-bs-toggle="popover"]', component: 'Popover' },
        { selector: '[data-bs-toggle="dropdown"]', component: 'Dropdown' },
        { selector: '.modal', component: 'Modal' },
    ];
    for ( item of toggles ) {
        if (elt.matches(item.selector)) {
            const instance = bootstrap[item.component].getInstance(elt);
            if (instance) {
                // _isShown is a boolean for Modal components and a function for others.
                if (instance._isShown) {
                    if (typeof instance._isShown === 'function') {
                        if (instance._isShown()) {
                            instance.hide();
                        }
                    }
                    else {
                        instance.hide();
                    }
                }

                let interval;
                interval = setInterval(function () {
                    if (!instance._isTransitioning) {
                        instance.dispose();
                        clearInterval(interval);
                    }
                }, 200);
            }
            return;
        }
    }

    if ( elt.matches('textarea.richtext') ) {
        RT.CKEditor.instances[elt.name]?.destroy();
    }
    else if ( elt.matches('.tomselected') ) {
        elt.tomselect?.destroy();
    }
    else if ( elt.matches('.dropzone-init') ) {
        elt.dropzone?.destroy();
    }
    else if ( elt.matches('.datepicker') ) {
        elt.tempusDominus?.dispose();
    }
    else if (elt.matches('.combobox-wrapper')) {
        disposeCombobox(elt);
    }
});

// Detect 400/500 errors
document.addEventListener('htmx:beforeSwap', function(evt) {
    const status = evt.detail.xhr.status.toString();
    if (status.match(/^[45]/)) {
        // 422 means rt validation error and is handled in other places.
        if ( status === '422' ) return;

        if (!evt.detail.boosted && evt.target && evt.detail.requestConfig.verb === "get") {
            evt.detail.shouldSwap = true;
        }
        else {
            if ( evt.detail.serverResponse ) {
                const error = jQuery(evt.detail.serverResponse).find('#body div.error').html();
                if (error) {
                    alertError(error);
                    return;
                }
            }
            // Fall back to general 400/500 errors for 4XX/5XX errors without specific messages
            const message = RT.I18N.Catalog['http_message_' + status] || RT.I18N.Catalog['http_message_' + status.substr(0, 1) + '00'];
            if (message) {
                alertError(escapeHTML(message));
            }
        }
    }
    else if (evt.detail.boosted) {
        const error = evt.detail.xhr.getResponseHeader('HX-Boosted-Error');
        if (error) {
            const message = JSON.parse(error)?.message;
            if ( message ) {
                alertError(escapeHTML(message));
            }
            console.error("Error fetching " + evt.detail.pathInfo.requestPath + ': ' + message);
            evt.detail.shouldSwap = false;
        }
    }
});

// Detect network errors
document.addEventListener('htmx:sendError', function(evt) {
    const message = RT.I18N.Catalog['http_message_network_' + evt.detail.requestConfig.verb] || RT.I18N.Catalog['http_message_network'];
    if (message) {
        alertError(escapeHTML(message));
    }

    if (evt.detail.requestConfig.verb === 'get') {
        setTimeout(function() {
            if ( evt.detail.boosted ) {
                window.location = evt.detail.requestConfig.path;
            }
            else {
                window.location.reload();
            }
        }, 2000);
    }
});

document.addEventListener('userWarnings', function(evt) {
    if ( evt.detail.value ) {
        for ( const item of evt.detail.value ) {
            alertWarning(escapeHTML(item));
        }
    }
});

document.addEventListener('actionsChanged', function(evt) {
    jQuery.jGrowl('close');
    evt.detail.messages ||= evt.detail.value; // .value contains messages if it's passed as "actionsChanged => [$msg]"
    if ( evt.detail.messages ) {
        for ( const message of evt.detail.messages ) {
            if ( evt.detail.isWarning ) {
                alertWarning(escapeHTML(message));
            }
            else {
                jQuery.jGrowl(escapeHTML(message), { themeState: 'none' });
            }
        }
    }

    // Clear the form after a successful update so the previous values are not
    // still in form elements if the user clicks to update again.
    const form = evt.detail.elt;

    // Only clear on success. Leave any values on "isWarning"
    if ( form && form instanceof HTMLFormElement && !evt.detail.isWarning ) {
        form.reset();
    }
});

document.addEventListener('CSRFDetected', function(evt) {
    jQuery.jGrowl(escapeHTML(evt.detail.value), { themeState: 'none' });
});

document.addEventListener('collectionsChanged', function(evt) {
    document.querySelectorAll('table.collection-as-table[data-display-format][data-class="' + evt.detail.class + '"]').forEach(table => {
        const tr = table.querySelector('tr[data-record-id="' + evt.detail.id + '"]');
        if ( tr ) {
            htmx.ajax(
                'POST', RT.Config.WebHomePath + '/Helpers/CollectionListRow',
                {
                    source: tr,
                    target: tr,
                    swap: 'outerHTML',
                    values: {
                        DisplayFormat : table.getAttribute('data-display-format'),
                        ObjectClass   : table.getAttribute('data-class'),
                        MaxItems      : table.getAttribute('data-max-items') || 0,
                        InlineEdit    : table.classList.contains('inline-edit') ? 1 : 0,
                        i             : tr.getAttribute('data-index'),
                        ObjectId      : tr.getAttribute('data-record-id'),
                        Warning       : tr.getAttribute('data-warning') || 0
                    }
                }
            );
        }
    });
});

document.addEventListener('requestSucceeded', function(evt) {
    if ( evt.detail.elt.classList.contains('inline-edit') ) {
        toggleInlineEdit(jQuery(evt.detail.elt.closest('.titlebox')).find('.inline-edit-toggle:visible'));
    }
    else if ( evt.detail.elt.classList.contains('editor') ) {
        const cell = evt.detail.elt.closest('.editable');
        if ( cell ) {
            cell.closest('tr').classList.remove('refreshing');
            cell.classList.remove('loading');
            cell.classList.remove('editing');
            document.querySelector('body').classList.remove('inline-editing');
        }
    }
    else if (evt.detail.elt.closest('.modal')) {
        bootstrap.Modal.getInstance(evt.detail.elt.closest('.modal'))?.hide();
    }

    const history_container = document.querySelector('.history-container');
    if ( history_container ) {
        const filter_form = document.querySelector('.transaction-filter-form');
        if ( filter_form ) {
            htmx.trigger(filter_form, 'submit');
        }
        else if ( history_container.getAttribute('data-oldest-transactions-first') == 1 ) {
            history_container.removeAttribute('data-disable-scroll-loading');
        }
        else {
            const url = history_container.getAttribute('data-url');
            if ( url ) {
                let queryString = '&mode=prepend&loadAll=1';
                let lastTransaction = history_container.querySelector('.transaction');
                if ( lastTransaction ) {
                    queryString += '&lastTransactionId=' + lastTransaction.dataset.transactionId;
                }

                jQuery.ajax({
                    url: url + queryString,
                    success: function(html) {
                        const transactions = jQuery(html).filter('div.transaction');
                        if( html && transactions.length ) {
                            jQuery(".history-container").prepend(html);
                        }
                    },
                    error: function(xhr, reason) {
                        jQuery.jGrowl(escapeHTML(reason), { sticky: true, themeState: 'none' });
                    }
                });
            }
        }
    }
});

document.addEventListener('validationFailed', function(evt) {
    // Make hint text red if we found any errors on inline edit
    if ( evt.detail.value ) {
        evt.detail.elt.querySelectorAll('.is-invalid').forEach(elt => {
            elt.classList.remove('is-invalid');
            let hintSpan = document.getElementById(elt.getAttribute("aria-describedby"));
            if ( hintSpan ) {
                hintSpan.classList.remove('invalid-feedback');
            }
        });

        for ( let field of evt.detail.value ) {
            let cfInputField = document.getElementById(field);
            cfInputField.classList.add('is-invalid');
            let hintSpan = document.getElementById(cfInputField.getAttribute("aria-describedby"));
            if ( hintSpan ) {
                hintSpan.classList.add('invalid-feedback');
            }
        }

        if ( evt.detail.elt.classList.contains('editor') ) {
            const cell = evt.detail.elt.closest('.editable');
            if ( cell ) {
                cell.classList.remove('loading');
                cell.classList.add('editing');
                cell.closest('tr').classList.remove('refreshing');
            }
        }
        else if (evt.detail.elt.closest('.modal')) {
            // For Reply/Comment/Description updates on search result page
            const object_id = evt.detail.elt.querySelector('input[name=id]')?.value;
            if ( object_id ) {
                const tr = document.querySelector('tr.refreshing[data-record-id="' + object_id + '"]');
                if ( tr ) {
                    tr.classList.remove('refreshing');
                    tr.querySelector('div.editable.loading').classList.remove('loading');
                }
            }
        }
    }
});

document.addEventListener('titleChanged', function(evt) {
    document.title = evt.detail.value;
});

document.addEventListener('triggerChanged', function(evt) {
    evt.detail.elt.setAttribute('hx-trigger', evt.detail.value);
    htmx.process(evt.detail.elt);
});

document.addEventListener('widgetTitleChanged', function (evt) {
    const titlebox = evt.detail.elt.closest('div.titlebox');
    const leftSpan = titlebox.querySelector('.titlebox-title .left');
    if (leftSpan) {
        // Check if there's an anchor inside (privileged users have title links)
        const titleAnchor = leftSpan.querySelector('a');
        if (titleAnchor) {
            titleAnchor.innerHTML = evt.detail.value;
        } else {
            // For self-service, title is plain text in the span
            leftSpan.innerHTML = evt.detail.value;
        }
    }
});

document.addEventListener('reloadUrlChanged', function (evt) {
    // htmx puts the HX-Trigger event data directly on evt.detail (not evt.detail.value)
    // Server sends { id: htmx_id, url: reload_url }
    const id = evt.detail.id;
    const url = evt.detail.url;
    if (!id || !url) return;

    // Find the titlebox by the htmx target ID
    const targetEl = document.getElementById(id);
    if (!targetEl) return;

    const titlebox = targetEl.closest('div.titlebox');
    if (titlebox) {
        const reloadIcon = titlebox.querySelector('.titlebox-title a[hx-get*="Reload=1"]');
        if (reloadIcon) {
            reloadIcon.setAttribute('hx-get', url);
            htmx.process(reloadIcon);
        }
    }
});
