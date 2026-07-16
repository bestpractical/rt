document.addEventListener('htmx:afterSwap', function(evt) {
    const popup = evt.detail.elt;
    if (popup.classList && popup.classList.contains('calendar-event-detail')) {
        const entry = popup.closest('.ticket-entry');
        if (entry) positionCalendarPopup(entry);
    }
});

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
    evt.detail.historyElt.querySelectorAll('.lifecycle-viewer').forEach(elt => elt.lifecycleViewer?.destroy());
    evt.detail.historyElt.querySelectorAll('.lifecycle-ui').forEach(elt => elt.lifecycleEditor?.destroy());
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
    for ( const item of toggles ) {
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
    else if ( elt.matches('.lifecycle-viewer') ) {
        elt.lifecycleViewer?.destroy();
    }
    else if ( elt.matches('.lifecycle-ui') ) {
        elt.lifecycleEditor?.destroy();
    }
});

// Detect 400/500 errors
document.addEventListener('htmx:beforeSwap', function(evt) {
    const status = evt.detail.xhr.status.toString();
    if (status.match(/^[45]/)) {
        // 422 means rt validation error and is handled in other places.
        if ( status === '422' ) return;

        // Retry: for a non-boosted GET whose element can re-issue itself via a
        // `reload` trigger, show a retry toast instead of dumping the error response
        // into the target. Keying off the reload trigger means we only offer retry
        // where htmx.trigger(elt, 'reload') will actually re-run the request.
        if (!evt.detail.boosted && evt.detail.requestConfig.verb === "get"
            && (evt.detail.requestConfig.elt.getAttribute('hx-trigger') || '')
                .split(',').some(spec => spec.trim().split(/[\s\[]/)[0] === 'reload')) {
            evt.detail.shouldSwap = false;
            const elt = evt.detail.requestConfig.elt;
            // Capture params now; htmx:afterRequest will strip hx-vals before the retry fires.
            const retryVals = JSON.stringify(evt.detail.requestConfig.parameters);
            let message = '';
            if ( evt.detail.serverResponse ) {
                message = jQuery(evt.detail.serverResponse).find('#body div.error').text().trim();
            }
            message = message
                || RT.I18N.Catalog['http_message_' + status]
                || RT.I18N.Catalog['http_message_' + status.substr(0, 1) + '00']
                || RT.I18N.Catalog['error'];
            showRetryToast(message, function() { elt.setAttribute('hx-vals', retryVals); htmx.trigger(elt, 'reload'); });
            return;
        }

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

document.addEventListener('htmx:load', function(evt) {
    const elt = evt.detail.elt;

    const prefix = elt.closest('[data-name-prefix]')?.getAttribute('data-name-prefix');
    if (prefix) {
        elt.querySelectorAll('input, textarea, select, label').forEach(input => {
            ['id', 'for', 'name'].forEach(attr => {
                if (input.getAttribute(attr)) {
                    input.setAttribute(attr, prefix + input.getAttribute(attr));
                }
            });
        })
    }

    jQuery(elt).find(".card .card-header .toggle").each(function() {
        var e = jQuery(jQuery(this).attr('data-bs-target'));
        e.on('hide.bs.collapse', function (evt) {
            evt.stopPropagation();
            createCookie(evt.target.id,0,365);
            e.closest('div.titlebox').find('div.card-header span.right').addClass('invisible');
        });
        e.on('show.bs.collapse', function (evt) {
            evt.stopPropagation();
            createCookie(evt.target.id,1,365);
            e.closest('div.titlebox').find('div.card-header span.right').removeClass('invisible');
        });
    });

    jQuery(elt).find(".card .accordion-item .toggle").each(function() {
        var e = jQuery(jQuery(this).attr('data-bs-target'));
        e.on('hide.bs.collapse', function (evt) {
            evt.stopPropagation();
            createCookie(evt.target.id,0,365);
        });
        e.on('show.bs.collapse', function (evt) {
            evt.stopPropagation();
            createCookie(evt.target.id,1,365);
        });
    });

    jQuery(elt).find(".card .card-body .toggle").each(function() {
        var e = jQuery(jQuery(this).attr('data-bs-target'));
        e.on('hide.bs.collapse', function (event) {
            event.stopPropagation();
        });
        e.on('show.bs.collapse', function (event) {
            event.stopPropagation();
        });
    });

    if ( jQuery(elt).find('.combobox').combobox ) {
        jQuery(elt).find('.combobox').combobox({ clearIfNoMatch: false });
        jQuery(elt).find('.combobox-wrapper').each( function() {
            jQuery(this).find('input[type=text]').prop('name', jQuery(this).data('name')).prop('value', jQuery(this).data('value'));
        });
    }


    /* Code to support the rights editor for global rights, queue rights, etc. */
    if ( elt.querySelector('.rights-editor') ) {
        const editor = elt.querySelector('.rights-editor');
        function sync_anchor(hash) {
            if (!hash.length) return;
            window.location.hash = hash;
            editor.querySelector("input[name=Anchor]").value = hash;
        }
        sync_anchor(editor.querySelector("input[name=Anchor]").value);
        jQuery(editor).find('.principal-tabs a[data-bs-toggle="tab"]').on('shown.bs.tab', function (e) {
            const anchor = jQuery(this).attr('href').replace('#acl-', '#');
            sync_anchor(anchor);
            jQuery(editor).find('.category-tabs a[data-bs-toggle="tab"]:visible:first').tab('show');
            if (anchor == '#AddPrincipal') {
                jQuery(editor).find('li.add-principal input').focus();
            }
        });

        jQuery(editor).find('li.add-principal input').focus(function () {
            jQuery(editor).find('.principal-tabs a[data-bs-toggle="tab"][href="#acl-AddPrincipal"]').tab('show');
        });

        const anchor = editor.querySelector('input[name=Anchor]').value;
        if (anchor && jQuery(editor).find('.principal-tabs a[data-bs-toggle="tab"][href="' + anchor.replace('#', '#acl-') + '"]').length) {
            jQuery(editor).find('.principal-tabs a[data-bs-toggle="tab"][href="' + anchor.replace('#', '#acl-') + '"]').tab('show');
        }
        else {
            jQuery(editor).find('.principal-tabs a[data-bs-toggle="tab"]:first').tab('show');
        }

        jQuery(editor).find('.category-tabs a[data-bs-toggle="tab"]').on('shown.bs.tab', function (e) {
            createCookie('rights-category-tab', jQuery(this).attr('href'));
        });

        const category_tab = getCookie('rights-category-tab');
        if (category_tab && jQuery(category_tab).length) {
            jQuery(editor).find('.category-tabs a[data-bs-toggle="tab"][href="' + category_tab + '"]').tab('show');
        }
        else {
            jQuery(editor).find('.category-tabs a[data-bs-toggle="tab"]:visible:first').tab('show');
        };

        // "rights" checkbox state cache...
        const check_counts = {};

        // Before page loads we need to initialize our "rights" checkbox state
        // cache.
        jQuery(editor).find("div.category-tabs input[type=checkbox]").each(function (index, element) {
            // Evaluating each checkbox and its current check state is the same
            // as evaluating a check event once the page is loaded. However, we
            // must indicate to the process_check_event that we are initializing
            // the cache. That is, we musn't decrement values from count
            // totals for checkboxes that aren't checked. That only happens when
            // a user actually unchecks a box, not when we are initially counting
            // checked or unchecked boxes.
            process_check_event(element, true);
        });

        jQuery("div.category-tabs input[type=checkbox]").change(function () {
            process_check_event(this, false);
        });

        // parameters:
        //   checkbox           - DOM checkbox element that was checked
        //   initializing_cache - a boolean that defines whether or not this
        //                        function was called with the purpose of
        //                        initializing the contents of the check_counts
        //                        cache.
        function process_check_event(checkbox, initializing_cache) {
            var category_tab = checkbox.getAttribute('data-category-tab');
            var principal_tab = checkbox.getAttribute('data-principal-tab');

            classify_tab(checkbox.checked, category_tab, initializing_cache);
            classify_tab(checkbox.checked, principal_tab, initializing_cache);
        }

        function classify_tab(checked, tab_id, initializing_cache) {
            if (typeof check_counts[tab_id] == 'undefined') {
                check_counts[tab_id] = 0;
            }

            if (checked) {
                check_counts[tab_id]++;
                if (check_counts[tab_id] == 1) {
                    // Then this is the first check and we need to add a class
                    // to the tab.
                    jQuery('#' + tab_id).addClass("tab-aggregates-checked-rights");
                }
            }
            else if (!initializing_cache) {
                check_counts[tab_id]--;
                if (check_counts[tab_id] == 0) {
                    // Then this is the last uncheck and we need to remove a
                    // class from the tab.
                    jQuery('#' + tab_id).removeClass("tab-aggregates-checked-rights");
                }
            }
        }

        let auto_set_own_dashboards;
        jQuery(editor).find('input[value="ModifySelf"]').change(function () {
            var form = jQuery(this).closest('form');
            if (jQuery(this).is(':checked')) {
                if (form.find('input[value$="OwnDashboard"]:visible:not(:checked)').length) {
                    jQuery('#grant-own-dashboard-rights-modal').modal('show');
                }
            }
            else {
                if (auto_set_own_dashboards) {
                    form.find('input[value$="OwnDashboard"]:visible:checked').prop('checked', false);
                    auto_set_own_dashboards = false;
                }
            }
        });

        jQuery('#grant-own-dashboard-rights-confirm').click(function () {
            var form = jQuery(this).closest('form');
            form.find('input[value$="OwnSavedSearch"]:visible:not(:checked)').prop('checked', true);
            form.find('input[value$="OwnDashboard"]:visible:not(:checked)').prop('checked', true);
            jQuery('#grant-own-dashboard-rights-modal').modal('hide');
            auto_set_own_dashboards = true;
        });

        const type = editor.getAttribute('data-add-principal');
        if (type) {
            jQuery(editor).find("#AddPrincipalForRights-" + type).keyup(function () {
                toggle_addprincipal_validity(this, true);
            }).keydown(function (event) {
                event.stopPropagation() // Disable tabs keyboard nav
            });

            jQuery("#AddPrincipalForRights-" + type).on("autocompleteselect", addprincipal_onselect);
            jQuery("#AddPrincipalForRights-" + type).on("autocompletechange", addprincipal_onchange);
        }
    }
    /* End code to support the rights editor */

    // Automatically sync to uncheck use file config checkbox
    jQuery(elt).find('form[name=EditConfig] input[name$="-file"]').each(function () {
        var file_input = jQuery(this);
        var form = file_input.closest('form');
        var file_name = file_input.attr('name');
        var db_name = file_name.replace(/-file$/, '');
        var db_input = form.find(':input[name=' + db_name + ']');
        db_input.change(function() {
            file_input.prop('checked', false);
        });
    });

    jQuery(elt).closest('form, body').find('input[name=QueueChanged]').each(function() {
        var form = jQuery(this).closest('form');
        var mark_changed = function(name) {
            if ( !form.find('input[name=ChangedField][value="' + name +'"]').length ) {
                jQuery('<input type="hidden" name="ChangedField" value="' + name + '">').appendTo(form);
            }
        };

        form.find(':input[name!=ChangedField]:not(.mark-changed):not(.richtext)').each(function() {
            jQuery(this).addClass('mark-changed');
            jQuery(this).change(function() {
                mark_changed(jQuery(this).attr('name'));
            });
        });

        form.find('textarea.richtext:not(.mark-changed)').each(function() {
            const plainMessageBox = jQuery(this);
            const messageBoxName = plainMessageBox.attr('name');
            if ( messageBoxName ) {
                plainMessageBox.addClass('mark-changed');
                let interval;
                interval = setInterval(function() {
                    if (RT.CKEditor.instances && RT.CKEditor.instances[messageBoxName]) {
                        const richTextEditor = RT.CKEditor.instances[messageBoxName];
                        richTextEditor.model.document.on( 'change:data', () => {
                            mark_changed(messageBoxName);
                        });
                        clearInterval(interval);
                    }
                }, 200);
            }
        });
    });

    // Cytoscape loads from a separate <script>; poll briefly until it (and the
    // lifecycle class) is ready, then initialize. Bail out after a fixed number
    // of attempts so a failed load doesn't leave a timer running forever.
    const whenCytoscapeReady = function (isReady, init) {
        if (isReady()) { init(); return; }
        let attempts = 0;
        const timer = setInterval(function () {
            if (isReady()) {
                clearInterval(timer);
                init();
            }
            else if (++attempts >= 100) {   // ~5s at 50ms
                clearInterval(timer);
                if (window.console) console.warn('Cytoscape did not load in time; lifecycle graph not initialized.');
            }
        }, 50);
    };

    if (elt.querySelectorAll('.lifecycle-ui').length) {
        whenCytoscapeReady(
            function () { return window.cytoscape && RT.NewLifecycleEditor; },
            function () {
                elt.querySelectorAll('.lifecycle-ui').forEach(function (editorEl) {
                    if (editorEl.__editorInitialized) return;
                    if (!document.contains(editorEl)) return;   // swapped out while cytoscape loaded
                    editorEl.__editorInitialized = true;
                    // Stash the instance so the htmx teardown hooks can destroy()
                    // it when this admin page is navigated away from.
                    editorEl.lifecycleEditor = new RT.NewLifecycleEditor(editorEl, JSON.parse(editorEl.getAttribute('data-config')), JSON.parse(editorEl.getAttribute('data-maps')), editorEl.getAttribute('data-layout') ? JSON.parse(editorEl.getAttribute('data-layout')) : null);
                });
            }
        );
    }

    if (elt.querySelectorAll('.lifecycle-viewer').length) {
        whenCytoscapeReady(
            function () { return window.cytoscape && RT.LifecycleViewer; },
            function () {
                elt.querySelectorAll('.lifecycle-viewer').forEach(function (viewerEl) {
                    if (viewerEl.__viewerInitialized) return;
                    if (!document.contains(viewerEl)) return;   // swapped out while cytoscape loaded
                    viewerEl.__viewerInitialized = true;
                    // Stash the instance so the htmx teardown hooks can destroy()
                    // it when this portlet is refreshed/swapped out.
                    viewerEl.lifecycleViewer = new RT.LifecycleViewer(viewerEl);
                });
            }
        );
    }

    elt.querySelectorAll('[data-bs-toggle="popover"]').forEach(function(elt) {
        new bootstrap.Popover(elt, {
            trigger: 'hover focus',
            html: true,
            sanitize: true
        });
    });

    const parse_cf = /^Object-([\w:]+)-(\d*)-CustomField(?::\w+)?-(\d+)-(.*)$/;
    elt.querySelectorAll("input,textarea:not(.richtext),select").forEach(function(elt) {
        const elem = jQuery(elt);
        const parsed = parse_cf.exec(elem.attr("name"));
        if (parsed == null)
            return;
        if (/-Magic$/.test(parsed[4]))
            return;
        const name_filter_regex = new RegExp(
            "^Object-"+parsed[1]+"-"+parsed[2]+
             "-CustomField(?::\\w+)?-"+parsed[3]+"-"+parsed[4]+"$"
        );

        const trigger_func = function() {
            const update_elems = jQuery("input,textarea:not(.richtext),select").filter(function () {
                return name_filter_regex.test(jQuery(this).attr("name"));
            }).not(elem);
            if (update_elems.length == 0)
                return;

            let curval = elem.val();
            if ((elem.attr("type") == "checkbox") || (elem.attr("type") == "radio")) {
                curval = [ ];
                jQuery('[name="'+elem.attr("name")+'"]:checked').each( function() {
                    curval.push( jQuery(this).val() );
                });
            }
            update_elems.val(curval);
            update_elems.filter(function(index, elt) {
                return elt.tomselect;
            }).each(function (index, elt) {
                const tomselect = elt.tomselect;
                if (Array.isArray(curval)) {
                    curval.forEach(val => {
                        if (!tomselect.getItem(val)) {
                            tomselect.createItem(val, true);
                        }
                    });
                }
                else if (!tomselect.getItem(curval)) {
                    tomselect.createItem(curval, true);
                }
                tomselect.setValue(curval, true);
            });
        };
        if ((elem.attr("type") == "text") || (elem.get(0).tagName == "TEXTAREA"))
            elem.keyup( trigger_func );

        elem.change( trigger_func );
    });

    if (window.location.hash) {
        const hash = window.location.hash;
        if (hash.match(/#txn-\d+$/)) {
            if ( document.querySelector('#deferred_ticket_history a.show-ticket-history') ) {
                htmx.trigger(document.querySelector('a.show-ticket-history'), 'click');
            }
            else {
                revealHistoryWidget();
            }
        }

        // Automatically scroll to the specified element
        if (elt.querySelector(hash) || elt.querySelector('[name="' + hash.substring(1) + '"]')) {
            location.href = location.href;
        }
    }

    /* inline edit on ticket display */
    jQuery('.titlebox[data-inline-edit-behavior="link"], .titlebox[data-inline-edit-behavior="click"]').each(function() {
        // If there are only id/submit, there are no fields to edit
        if ( jQuery(this).find('form.inline-edit :input').length <= 2 ) {
            jQuery(this).data('inline-edit-behavior', 'hide');
            jQuery(this).find('.inline-edit-toggle').addClass('hide');
        }
    });

    jQuery('.titlebox[data-inline-edit-behavior="always"]').each(function() {
        // If there are only id/submit, there are no fields to edit
        if ( jQuery(this).find('form.inline-edit :input').length <= 2 ) {
            jQuery(this).find('form.inline-edit :input[type=submit]').closest('div.row').addClass('hide');
        }
    });

    // Register triggers for cf changes
    elt.querySelectorAll('.show-custom-fields-container[hx-get], .edit-custom-fields-container[hx-get]').forEach(function (elt) {
        let events = [];
        if ( elt.classList.contains('show-custom-fields-container') ) {
            elt.querySelectorAll('.row.custom-field').forEach(function (elt) {
                const id = elt.id.match(/CF-(\d+)/)[1];
                events.push('customField-' + id + 'Changed from:body');
            });
        }
        else {
            elt.querySelectorAll('input[type=hidden][name*=-CustomField][name$="-Magic"]').forEach(function (elt) {
                let id = elt.name.match(/CustomField.*-(\d+)-.*-Magic$/)[1];
                events.push('customField-' + id + 'Changed from:body');
            });
        }

        if ( events.length ) {
            let orig_trigger = elt.getAttribute('hx-trigger');
            if ( orig_trigger && orig_trigger !== 'none' ) {
                events.push(orig_trigger);
            }
            elt.setAttribute('hx-trigger', events.join(', '));
            htmx.process(elt);
        }
    });

    elt.querySelectorAll('.transaction-filter-form a.history-reverse-order').forEach(elt => {
        elt.addEventListener('click', (evt) => {
            const form = evt.target.closest('.transaction-filter-form');
            const input = form.querySelector('input[name=ReverseTxns]');
            if (input) {
                input.value = input.value === 'ASC' ? 'DESC' : 'ASC';
                htmx.trigger(form, 'submit');
                const dropdown = evt.target.closest('.dropdown').querySelector('[data-bs-toggle=dropdown]');
                if ( dropdown ) {
                    bootstrap.Dropdown.getInstance(dropdown)?.hide();
                }
                evt.preventDefault();
                evt.stopPropagation();
            }
        });
    });


    elt.querySelectorAll('.transaction-filter-form a.history-show-headers').forEach(elt => {
        elt.addEventListener('click', (evt) => {
            const form = evt.target.closest('.transaction-filter-form');
            const input = form.querySelector('input[name=ShowHeaders]');
            if (input) {
                input.value = input.value == 1 ? 0 : 1;
                evt.target.innerText = evt.target.getAttribute('data-history-headers-' + (input.value == 1 ? 'brief' : 'full'));
                htmx.trigger(form, 'submit');
                const dropdown = evt.target.closest('.dropdown').querySelector('[data-bs-toggle=dropdown]');
                if ( dropdown ) {
                    bootstrap.Dropdown.getInstance(dropdown)?.hide();
                }
                evt.preventDefault();
                evt.stopPropagation();
            }
        });
    });

    const show_quoted_elt = elt.closest('.history')?.querySelector('.toggle-quoted-text');
    if (show_quoted_elt) {
        const show_quoted = show_quoted_elt.getAttribute('data-direction');
        if ( show_quoted !== 'open' ) {
            elt.querySelectorAll('.message-stanza-folder.closed').forEach(elt => {
                elt.click();
            });
        }
    }

    if ( elt.querySelector(".tablesorter") ) {
        let checkTableSorterAttempts = 0;
        const checkTableSorter = setInterval(function() {
            if ( !document.contains(elt) || ++checkTableSorterAttempts >= 100 ) {
                clearInterval(checkTableSorter);
                return;
            }
            if ( jQuery.tablesorter ) {
                jQuery(elt).find(".tablesorter").tablesorter();
                clearInterval(checkTableSorter);
            }
        }, 50);
    }

    // Clear orphaned tooltips
    document.querySelectorAll('body > div.tooltip[id^=tooltip]').forEach(elt => {
        if ( !document.querySelector(`[aria-describedby="${elt.id}"]`) ) {
            elt.remove();
        }
    });

    // enable bootstrap tooltips
    elt.querySelectorAll('[data-bs-toggle=tooltip]').forEach(elt => {
        new bootstrap.Tooltip(elt, {
            trigger: 'hover focus'
        });
    });

    // Use Growl to show any UserMessages written to the page
    var userMessages = RT.UserMessages;
    for (var key in userMessages) {
        jQuery.jGrowl(escapeHTML(userMessages[key]), { sticky: true, themeState: 'none' });
    }
    RT.UserMessages = {};

    initDatePicker(elt);
    clipContent(elt);
    loadCollapseStates(elt);
    initializeSelectElements(elt);
    ReplaceAllTextareas(elt);
    AddAttachmentWarning();

    // Wire up calendar status filter dropdown to the toolbar funnel icon.
    // The container is a sibling of calendar-wrapper in the htmx-loaded content,
    // so we check if elt itself is the container or contains one.
    const filterContainer = elt.classList?.contains('calendar-status-filter-container')
        ? elt : elt.querySelector('.calendar-status-filter-container');
    if (filterContainer) {
        // Find the titlebox header that contains the funnel icon
        const titlebox = filterContainer.closest('.card');
        if (titlebox) {
            const iconSpan = titlebox.querySelector('.calendar-status-filter-icon');
            if (iconSpan) {
                // Move the dropdown menu into the icon span
                const dropdownMenu = filterContainer.querySelector('.calendar-status-filter-dropdown');
                if (dropdownMenu) {
                    // Remove any existing dropdown from a previous load
                    const oldDropdown = iconSpan.querySelector('.calendar-status-filter-dropdown');
                    if (oldDropdown) oldDropdown.remove();

                    iconSpan.appendChild(dropdownMenu);
                    iconSpan.classList.add('dropdown');

                    // Set up the anchor as a dropdown toggle
                    const anchor = iconSpan.querySelector('a');
                    if (anchor) {
                        // Dispose stale Bootstrap Dropdown instance from previous load
                        const existingDropdown = bootstrap.Dropdown.getInstance(anchor);
                        if (existingDropdown) existingDropdown.dispose();

                        // Remove tooltip to avoid conflict with dropdown
                        const existingTooltip = bootstrap.Tooltip.getInstance(anchor);
                        if (existingTooltip) existingTooltip.dispose();
                        anchor.removeAttribute('data-bs-title');
                        anchor.setAttribute('data-bs-toggle', 'dropdown');
                        anchor.setAttribute('data-bs-auto-close', 'outside');
                        anchor.setAttribute('data-bs-boundary', 'viewport');
                        anchor.setAttribute('aria-haspopup', 'true');
                        anchor.setAttribute('aria-expanded', 'false');

                        new bootstrap.Dropdown(anchor);
                    }
                }
            }
            // Remove the now-empty container
            filterContainer.remove();
        }
    }

    expandCalendar(elt);

    // Delay calendar popup requests so that mousing across the calendar
    // does not fire a request for every ticket the cursor passes over.
    // Also calculate popup position from viewport bounds rather than
    // relying on CSS row/column heuristics.
    elt.querySelectorAll('.ticket-entry[hx-trigger]').forEach(function(el) {
        el.addEventListener('mouseenter', function() {
            positionCalendarPopup(el);
            el._calendarHoverTimer = setTimeout(() => htmx.trigger(el, 'calendar-hover'), 200);
        });
        el.addEventListener('mouseleave', function() {
            clearTimeout(el._calendarHoverTimer);
        });
    });
});

/* Load the owner dropdown when the user clicks the pencil in basics */
jQuery(document).on('click', '.ticket-info-basics .inline-edit-toggle.edit .rt-inline-icon', function (e) {
    loadOwnerDropdownDelay(jQuery('div.ticket-info-basics div.select-owner-dropdown-delay:not(.loaded)'));
});

jQuery(document).on('click', '.inline-edit-toggle', function (e) {
    e.preventDefault();
    e.stopPropagation();
    toggleInlineEdit(jQuery(this));
});

jQuery(document).on('click', '.titlebox[data-inline-edit-behavior="click"] > .titlebox-content', function (e) {
    if (jQuery(e.target).is('input, select, textarea')) {
        return;
    }

    // Bypass links, buttons and radio/checkbox controls too
    if (jQuery(e.target).closest('a, button, div.custom-radio, div.custom-checkbox').length) {
        return;
    }

    var container = jQuery(this).closest('.titlebox');
    if (container.hasClass('editing')) {
        return;
    }

    e.preventDefault();
    e.stopPropagation();
    toggleInlineEdit(container.find('.inline-edit-toggle:visible'));
});


// Hide the tooltip everywhere when the element is clicked
jQuery(document).on('click', '[data-bs-toggle="tooltip"]', function (e) {
    jQuery('[data-bs-toggle="tooltip"]').tooltip("hide");
});

jQuery(document).on('click', 'a.delete-attach', function() {
    var parent = jQuery(this).closest('div');
    var name = jQuery(this).attr('data-name');
    var token = jQuery(this).closest('form').find('input[name=Token]').val();
    jQuery.post( RT.Config.WebHomePath + '/Helpers/Upload/Delete', { Name: name, Token: token }, function(data) {
        if ( data.status == 'success' ) {
            parent.remove();
        }
    }, 'json');
    return false;
});

/* Show selected file name in UI */
jQuery(document).on('change', '.custom-file input', function (e) {
    jQuery(this).next('.custom-file-label').html(e.target.files[0].name);
});


jQuery(document).on('input propertychange', ':input[data-type=json]', function() {
    var form = jQuery(this).closest('form');
    try {
        JSON.parse(jQuery(this).val());
        form.find('input[type=submit]').prop('disabled', false);
        form.find('.invalid-json').addClass('hidden');
    } catch (e) {
        form.find('input[type=submit]').prop('disabled', true);
        form.find('.invalid-json').removeClass('hidden');
    }
});

jQuery(document).on('click', 'a.permalink', function () {
    htmx.ajax('GET', RT.Config.WebPath + "/Helpers/Permalink", {
        target: '#dynamic-modal',
        values: {
            Code: this.getAttribute('data-code'),
            URL: this.getAttribute('data-url')
        },
    }).then(() => {
        bootstrap.Modal.getOrCreateInstance('#dynamic-modal').show();
    });
    return false;
});

// My Week auto submit
jQuery(document).on('change change.td', 'div.time-tracking input[name=Date]', function () {
    htmx.trigger(this.closest('form'), 'submit');
});

jQuery(document).on('change', 'div.time-tracking input[name=UserString]', function () {
    this.closest('form').querySelector('input[name=User]').value = this.value;
    htmx.trigger(this.closest('form'), 'submit');
});

jQuery(document).on('click', 'a.search-filter', function (e) {
    const target = document.querySelector(e.target.closest('.search-filter').getAttribute('hx-target'));
    if (target.children.length > 0) {
        bootstrap.Modal.getOrCreateInstance(target.closest('.modal.search-results-filter')).show();
    }
    else {
        htmx.trigger(e.target.closest('.search-filter'), 'manual');
    }
    return false;
});

// Automatically reveal history widget so anchor links like #txn-586 can work
jQuery(document).on('click', 'a.jump-to-unread', function (evt) {
    const widget = document.querySelector('.htmx-load-widget[hx-get$="/Widgets/Display/History"]');
    if (widget) {
        const history_mode = widget.querySelector('[data-history-mode]')?.getAttribute('data-history-mode');
        // For paginated history, we need to reload widget if the specified txn is not on current page
        if ( history_mode === 'page' && widget.getAttribute('data-hx-revealed') === 'true' ) {
            const matched = evt.target.getAttribute('href').match(/#(txn-(\d+))$/);
            if ( matched && !document.querySelector('[name="' + matched[1] + '"]') ) {
                // Update location first so widget can retrieve the txn id from hash in URL
                location.href = evt.target.getAttribute('href');
                const filter_form = widget.querySelector('form.transaction-filter-form');
                if (filter_form) {
                    filter_form.querySelector('input[name=focusTransactionId]').value = matched[2];
                    htmx.trigger(filter_form, 'submit');
                    setTimeout(function() {
                        filter_form.querySelector('input[name=focusTransactionId]').value = '';
                    }, 100);
                }
            }
        }
        else if ( widget.querySelector('#deferred_ticket_history a.show-ticket-history') ) {
            location.href = evt.target.getAttribute('href');
            htmx.trigger(widget.querySelector('a.show-ticket-history'), 'click');
        }
        else {
            revealHistoryWidget();
        }
    }
});

// Clip content
jQuery(document).on('click', 'a.unclip', function() {
    jQuery(this).siblings('div.clip').css('height', 'auto');
    jQuery(this).hide();
    jQuery(this).siblings('a.reclip').show();
    return false;
});

jQuery(document).on('click', 'a.reclip', function() {
    var clip_div = jQuery(this).siblings('div.clip');
    clip_div.height(clip_div.attr('clip-height'));
    jQuery(this).siblings('a.unclip').show();
    jQuery(this).hide();
    return false;
});

jQuery(document).on('click', '.asset-create-linked-ticket', function (e) {
    e.preventDefault();
    var url = this.href.replace(/\/Asset\/CreateLinkedTicket\.html\?/g,
        '/Asset/Helpers/CreateLinkedTicket?');

    htmx.ajax('GET', url, '#dynamic-modal').then(() => {
        bootstrap.Modal.getOrCreateInstance('#dynamic-modal').show();
    });
});
jQuery(document).on('click', '#bulk-update-create-linked-ticket', function (e) {
    e.preventDefault();
    var chkArray = [];

    jQuery("input[name='UpdateAsset']:checked").each(function () {
        chkArray.push(jQuery(this).val());
    });

    var selected = '';
    for (var i = 0; i < chkArray.length; i++) {
        selected += 'Asset=' + chkArray[i] + '&';
    }
    /* selected = chkArray.join(','); */
    var url = RT.Config.WebHomePath + '/Asset/Helpers/CreateLinkedTicket?' + selected;
    htmx.ajax('GET', url, '#dynamic-modal').then(() => {
        bootstrap.Modal.getOrCreateInstance('#dynamic-modal').show();
    });
});

// Disable chosing individual objects when a scrip is applied globally
jQuery(document).on('change', 'form[name=AddRemoveScrip] input[type=checkbox][name^=AddScrip-][value=0], form input[type=checkbox][name^=AddCustomField-][value=0]', function () {
    var self = jQuery(this);
    var checked = self.prop("checked");

    self.closest("form")
        .find("table.collection input[type=checkbox]")
        .prop("disabled", checked);
});

jQuery(document).on('change', 'input[type=file]', function () {
    var input = jQuery(this);
    var warning = input.next(".invalid");

    if (!input.val().match(/"/)) {
        warning.hide();
    } else {
        if (warning.length) {
            warning.show();
        } else {
            input.val("");
            jQuery("<span class='invalid'>")
                .text(loc_key("quote_in_filename"))
                .insertAfter(input);
        }
    }
});

jQuery(document).on('change', '#UpdateType', function (e) {
    jQuery(".messagebox-container")
        .removeClass("action-response action-private")
        .addClass("action-" + e.target.value);
});

jQuery(document).on('click', '.toggle-txn-details', function (e) {
    return toggleTransactionDetails.apply(this);
});

jQuery(document).on('click', '.toggle-contrast-link', function (e) {
    e.preventDefault();
    jQuery(this).closest('.rt-inline-icon').toggleClass('active');
    var txn = jQuery(this).closest('.transaction');
    txn.find('.messagebody').toggleClass('toggle-contrast');
});

jQuery(document).on('change', '.article-basics [name="Type"]', function () {
    if (jQuery(this).val() == 'Content') {
        jQuery('#article-type-links').addClass('hidden');
        jQuery('#article-type-content').removeClass('hidden');
    }
    else {
        jQuery('#article-type-content').addClass('hidden');
        jQuery('#article-type-links').removeClass('hidden');
    }
});

jQuery(document).on('focus', '[name^="article-link-"]', function () {
    // if input focus in last row add another row of inputs
    const link_div = jQuery(this).parent().parent();
    const links_div = link_div.parent();
    if (link_div.attr('data-link-number') == links_div.attr('data-link-count')) {
        const link_count = parseInt(links_div.attr('data-link-count')) + 1;
        links_div.attr('data-link-count', link_count);
        let new_link_div = link_div.clone();
        new_link_div.attr('data-link-number', link_count);
        new_link_div.find('[name^="article-link-"]').each(function () {
            var oldName = jQuery(this).attr('name');
            var newName = oldName.replace(/-\d+$/, '-' + link_count);
            jQuery(this).attr('name', newName);
        });
        links_div.append(new_link_div);
    }
});

// Automatically sync to set input values to ones in config files.
jQuery(document).on('change', 'form[name=EditConfig] input[name$="-file"]', function (e) {
    var file_input = jQuery(this);
    var form = file_input.closest('form');
    var file_name = file_input.attr('name');
    var file_value = form.find('input[name=' + file_name + '-Current]').val();
    var checked = jQuery(this).is(':checked') ? 1 : 0;
    if ( !checked ) return;

    var db_name = file_name.replace(/-file$/, '');
    var db_input = form.find(':input[name=' + db_name + ']');
    var db_input_type = db_input.attr('type') || db_input.prop('tagName').toLowerCase();
    if ( db_input_type == 'radio' ) {
        db_input.filter('[value=' + (file_value || 0) + ']').prop('checked', true);
    }
    else if ( db_input_type == 'select' ) {
        // Silently update value, otherwise the radio would be unchecked again because of select's change event.
        db_input.get(0).tomselect.setValue(file_value.length ? file_value : '__empty_value__', true);
    }
    else {
        db_input.val(file_value);
    }
});

jQuery(document).on('change', 'form[name=BuildQuery] select[name^=SelectCustomField]', function() {
    var form = jQuery(this).closest('form');
    var row = jQuery(this).closest('div.row');
    var val = jQuery(this).val();

    var new_operator = form.find(':input[name="' + val + 'Op"]:first').clone();
    new_operator.attr('id', null).removeClass('tomselected ts-hidden-accessible');
    row.children('div.rt-search-operator').children().remove();
    row.children('div.rt-search-operator').append(new_operator);

    var new_value = form.find(':input[name="ValueOf' + val + '"]:first');
    new_value = new_value.clone();

    new_value.attr('id', null).removeClass('tomselected ts-hidden-accessible');
    row.children('div.rt-search-value').children().remove();
    row.children('div.rt-search-value').append(new_value);
    if ( new_value.hasClass('datepicker') ) {
        initDatePicker(row.get(0));
    }
    initializeSelectElements(row.get(0));
});

// Inline edit listeners
jQuery(document).on('click', 'table.inline-edit div.editable .edit-icon', function (e) {
    var cell = jQuery(this).closest('div.editable');
    if ( jQuery('div.editable.editing form').length ) {
        cancelInlineEdit(jQuery('div.editable.editing form'));
    }
    const modal_info = cell.get(0).querySelector('.inline-edit-modal[data-link]');
    if ( modal_info ) {
        htmx.ajax('GET', modal_info.getAttribute('data-link'), '#dynamic-modal').then(() => {
            bootstrap.Modal.getOrCreateInstance('#dynamic-modal').show();
            jQuery(document).off('change', '#dynamic-modal form :input').on('change', '#dynamic-modal form :input', function () {
                jQuery(this).closest('form').data('changed', true);
            });
            jQuery(document).off('click', '#dynamic-modal form .submit').on('click', '#dynamic-modal form .submit', function (evt) {
                evt.preventDefault();
                document.querySelectorAll('#dynamic-modal form textarea.richtext').forEach((textarea) => {
                    const name = textarea.name;
                    if ( RT.CKEditor.instances[name] ) {
                        if ( RT.CKEditor.instances[name].getData() !== textarea.value ) {
                            RT.CKEditor.instances[name].updateSourceElement();
                            jQuery(textarea.closest('form')).data('changed', true);
                        }
                    }
                });
                if ( jQuery('#dynamic-modal form').data('changed') ) {
                    cell.addClass('editing');
                    submitInlineEdit(jQuery('#dynamic-modal form'), cell);
                }
                else {
                    bootstrap.Modal.getInstance('#dynamic-modal')?.hide();
                }
            });
        });
    }
    else {
        beginInlineEdit(cell);
    }
});

jQuery(document).on('mouseenter', 'table.inline-edit div.editable .edit-icon', function (e) {
    const owner_dropdown_delay = jQuery(this).closest('.editable').find('div.select-owner-dropdown-delay:not(.loaded)');
    loadOwnerDropdownDelay(owner_dropdown_delay);
});

jQuery(document).on('change', 'div.editable.editing form :input', function () {
    jQuery(this).closest('form').data('changed', true);
});

jQuery(document).on('click', 'div.editable .cancel', function (e) {
    cancelInlineEdit(jQuery(this).closest('form'));
});

jQuery(document).on('click', 'div.editable .submit', function (e) {
    submitInlineEdit(jQuery(this).closest('form'));
});

// We want to call submitInlineEdit to do some pre-checks and massage
// css classes before making htmx requests. Can't bind it to form.submit
// event as preventDefault() there can't stop htmx actions.
jQuery(document).on('keydown', 'div.editable.editing form input[type=text], div.editable.editing form input:not([type])', function (e) {
    if (e.key === 'Enter') {
        e.preventDefault();
        submitInlineEdit(jQuery(this).closest('form'));
    }
});

jQuery(document).on('change', 'div.editable.editing form select:not([multiple])', function () {
    submitInlineEdit(jQuery(this).closest('form'));
});

jQuery(function () {

    // Make actions dropdown scrollable in case screen is too short
    jQuery(window).resize(function() {
        jQuery('#li-page-actions > ul').css('max-height', jQuery(window).height() - jQuery('#rt-header-container').height());
    }).resize();

    let expandCalendarResizeTimeout;
    window.addEventListener('resize', () => {
        clearTimeout(expandCalendarResizeTimeout);
        expandCalendarResizeTimeout = setTimeout(() => {
            expandCalendar(document);
        }, 150);
    });

    const html = document.querySelector('html');
    if ( html.getAttribute('data-bs-theme') === 'auto' ) {
        if ( window.matchMedia("(prefers-color-scheme:dark)").matches ) {
            html.setAttribute('data-bs-theme', 'dark');
        }
        else {
            html.setAttribute('data-bs-theme', 'light');
        }
    }

});
