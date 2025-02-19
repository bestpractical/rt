pageLayout = {
    dragstart: function(e) {
        e.dataTransfer.setData("text/plain", e.target.id);
        e.effectAllowed = "copy";

        e.target.classList.add('current');

        bootstrap.Tooltip.getInstance(e.target.querySelector('span.content'))?.dispose();
    },

    dragend: function(e) {
        e.target.classList.remove('current');
        document.querySelector('.pagelayout-widget-placeholder.active')?.classList.remove('active');
        document.querySelector('.pagelayout-content.active')?.classList.remove('active');
    },

    dragenter: function(e) {
        e.preventDefault();
        e.target.querySelector(':scope > .pagelayout-widget-placeholder')?.classList.add('active');
        document.querySelectorAll('.pagelayout-content').forEach((elt) => {
            if (elt == e.target.closest('.pagelayout-content')) {
                elt.classList.add('active');
            }
            else {
                elt.classList.remove('active');
            }
        });
    },

    dragleave: function(e) {
        e.target.querySelector(':scope > .pagelayout-widget-placeholder.active')?.classList.remove('active');
        if (e.target.classList.contains('pagelayout-content')) {
            e.target.classList.remove('active');
        }
    },

    dragover: function(e) {
        e.preventDefault();
    },

    drop: function(e) {

        let source = document.getElementById(e.dataTransfer.getData("text/plain"));
        if (source.closest('.row') && source.closest('.row').closest('.pagelayout-content')) {
            source = source.parentNode;
        }

        let sibling = e.target.closest('.pagelayout-widget');
        let area = e.target.closest('.pagelayout-content');
        let source_copy;
        const from_content = source.closest('.pagelayout-content') ? true : false;
        const row = area.closest('.row-container');

        if (row.hasAttribute('data-title')) {
            if (row.getAttribute('data-separated-columns') == 1) {
                if (!source.classList.contains('pagelayout-widget')) {
                    new_source = source.children[0].cloneNode(true);
                    source.remove();
                    source_copy = new_source;
                }
            }
            else {
                area = area.children[0];
                if (sibling) {
                    sibling = sibling.parentNode;
                }

                if (source.classList.contains('pagelayout-widget')) {
                    const new_source = document.createElement('div');
                    new_source.appendChild(source.cloneNode(true));
                    if (source.closest('.pagelayout-form')) {
                        source.remove();
                    }
                    source_copy = new_source;
                }
            }
        }

        if (!source_copy && source.closest('.pagelayout-content') === area.closest('.pagelayout-content')) {
            if (sibling) {
                area.insertBefore(source, sibling);
            }
            else {
                // Support bare widgets that are added to the top level(i.e no row wrapper)
                if (area.classList.contains('pagelayout-content')) {
                    area.insertBefore(source, area.children[area.children.length - 2]);
                }
                else {
                    area.appendChild(source);
                }
            }
        }
        else {
            if (!source_copy) {
                source_copy = source.cloneNode(true);
            }

            let old_id;
            let new_id = 'pagelayout-widget-' + Date.now();
            const modal_id = new_id + '-modal';
            if (source_copy.classList.contains('pagelayout-widget')) {
                old_id = source_copy.id;
                source_copy.id = new_id;
                source_copy.classList.remove('current');
                pageLayout.registerDrag(source_copy);
            }
            else {
                old_id = source_copy.children[0].id;
                source_copy.children[0].id = new_id;
                source_copy.children[0].classList.remove('current');
                pageLayout.registerDrag(source_copy.children[0]);
            }

            source_copy.querySelector('a.edit')?.setAttribute('data-bs-target', '#' + modal_id);
            source_copy.querySelector('a.remove').addEventListener('click', pageLayout.deleteWidget);

            if (sibling) {
                area.insertBefore(source_copy, sibling);
            }
            else {
                // Support bare widgets that are added to the top level(i.e no row wrapper)
                if (area.classList.contains('pagelayout-content')) {
                    area.insertBefore(source_copy, area.children[area.children.length - 2]);
                }
                else {
                    area.appendChild(source_copy);
                }
            }


            if (from_content) {
                const modal = document.querySelector('#' + old_id + '-modal');
                if (modal) {
                    modal.setAttribute('id', modal_id);
                    if (modal.parentNode !== row) {
                        row.appendChild(modal);
                    }
                }
            }
            else {
                const modal_copy = document.querySelector('#' + old_id + '-modal')?.cloneNode(true);
                if (modal_copy) {
                    modal_copy.setAttribute('id', modal_id);
                    area.closest('.row-container').appendChild(modal_copy);
                    document.querySelector('#' + modal_id + ' form.pagelayout-widget-form').addEventListener('submit', pageLayout.widgetSubmit);
                    bootstrap.Modal.getOrCreateInstance('#' + modal_id).show();
                }
            }

            if (source?.closest('.pagelayout-form')) {
                source.remove();
            }
        }

        if (area.classList.contains('row')) {
            const layout = area.closest('.row-container').getAttribute('data-layout');
            if (layout) {
                const classes = layout.split(/\s*,\s*/);
                const cols = area.querySelectorAll(':scope > div');
                for (let i = 0; i < cols.length; i++) {
                    cols[i].className = classes[i % classes.length];
                }
            }
        }
        pageLayout.syncChanges();
    },
    registerDrag: function(elt) {
        for (let event of ['drag', 'dragstart', 'dragend']) {
            elt.addEventListener(event, pageLayout[event]);
        }
    },
    registerDrop: function(elt) {
        for (let event of ['dragenter', 'dragover', 'dragleave', 'drop']) {
            elt.addEventListener(event, pageLayout[event]);
        }
    },

    widgetSubmit: function(e) {
        e.preventDefault();
        const form = this;
        const modal = form.closest('.pagelayout-widget-modal');
        const widget = document.querySelector('#' + modal.getAttribute('id').replace(/-modal$/, ''));
        if (JSON.parse(widget.getAttribute('data-value')).match(/^CustomFieldCustomGroupings\b/)) {
            const options = form.querySelector('select[name=Groupings]').options;
            const groupings = Array.from(options).filter((option) => option.selected).map((option) => option.value);
            if (groupings.length) {

                widget.setAttribute('data-value', JSON.stringify('CustomFieldCustomGroupings:' + groupings.join(',')));
                bootstrap.Tooltip.getOrCreateInstance(widget.querySelector('svg.bi-info')).setContent({
                    '.tooltip-inner': groupings.join(',')
                });
                widget.querySelector('svg.bi-info.hidden')?.classList.remove('hidden');
            }
            else {
                widget.setAttribute('data-value', JSON.stringify('CustomFieldCustomGroupings'));
                widget.querySelector('svg.bi-info')?.classList.add('hidden');
            }
        }
        bootstrap.Modal.getInstance(form.closest('.pagelayout-widget-modal')).hide();
        pageLayout.syncChanges();
    },

    rowSubmit: function(e) {
        e.preventDefault();
        const form = this;
        bootstrap.Modal.getInstance(form.closest('.modal')).hide();
        const row = form.closest('.row-container');

        const new_title = form.querySelector('input[name=Title]').value;
        if (row.getAttribute('data-title') != new_title) {
            row.setAttribute('data-title', new_title);
            row.querySelector('.titlebox-title span.left').innerText = new_title;
        }

        const new_layout = form.querySelector('input[name=Layout]').value || 'col-12';
        const classes = new_layout.split(/\s*,\s*/);
        const separated_columns = form.querySelector('input[name=SeparatedColumns]').checked ? 1 : 0;

        if (row.getAttribute('data-separated-columns') != separated_columns) {
            row.setAttribute('data-separated-columns', separated_columns);
            if (separated_columns) {
                const card_body = row.querySelector('.card-body:has(.pagelayout-widget-empty-room)');

                const widgets = card_body.querySelectorAll('.pagelayout-widget');
                card_body.querySelector('div.pagelayout-content').remove();

                let cols = pageLayout.calculateColumns(new_layout);
                const inner_row = document.createElement('div');
                inner_row.className = "row";
                for (let i = 0; i < cols; i++) {
                    const template = document.querySelector('#pagelayout-separated-columns-template').children[0].cloneNode(true);
                    template.className = classes[i % classes.length];
                    pageLayout.registerDrop(template);
                    inner_row.appendChild(template);
                }
                card_body.appendChild(inner_row);

                const contents = card_body.querySelectorAll(':scope > div.row .pagelayout-content');
                for (let i = 0; i < widgets.length; i++) {
                    contents[i % contents.length].insertBefore(widgets[i], contents[i % contents.length].children[contents[i % contents.length].children.length - 1]);
                }
            }
            else {
                const widgets = row.querySelectorAll('.pagelayout-widget');
                const card_body = row.querySelector('.card-body:has(.pagelayout-widget-empty-room)');
                card_body.querySelector('div.row').remove();

                const template = document.querySelector('#pagelayout-connected-columns-template').children[0].cloneNode(true);
                pageLayout.registerDrop(template);
                card_body.appendChild(template);

                const inner_row = card_body.querySelector('div.row');

                let cols = pageLayout.calculateColumns(new_layout);

                for (let i = 0; i < widgets.length; i++) {
                    const col = document.createElement('div');
                    col.className = classes[i % classes.length];
                    col.appendChild(widgets[i]);
                    inner_row.appendChild(col);
                }
            }
        }

        if (row.getAttribute('data-layout') != new_layout) {
            row.setAttribute('data-layout', new_layout);
            if (separated_columns) {
                let cols = pageLayout.calculateColumns(new_layout);
                const card_body = row.querySelector('.card-body:has(.pagelayout-widget-empty-room)');
                const inner_row = card_body.querySelector('div.row');
                let contents = inner_row.children;

                if (contents.length > cols) {
                    for (let i = cols; i < contents.length; i++) {
                        contents[i].remove();
                    }
                }
                else if (contents.length < cols) {
                    for (let i = contents.length; i < cols; i++) {
                        const template = document.querySelector('#pagelayout-separated-columns-template').children[0].cloneNode(true);
                        template.className = classes[i % classes.length];
                        pageLayout.registerDrop(template);
                        inner_row.appendChild(template);
                    }
                }

                contents = card_body.querySelectorAll('.pagelayout-content');
                for (let i = 0; i < contents.length; i++) {
                    contents[i].parentNode.className = classes[i % classes.length];
                }
            }
            else {
                const cols = row.querySelectorAll('div.pagelayout-content div.row > div');
                for (let i = 0; i < cols.length; i++) {
                    cols[i].className = classes[i % classes.length];
                }
            }
        }

        pageLayout.syncChanges();
    },

    syncChanges: function(e) {
        const form = e ? e.target : document.querySelector('#pagelayout-form-modify');
        const content = [];

        document.querySelectorAll('.pagelayout-form .row-container').forEach((row) => {
            if (row.querySelector('.titlebox')) {
                const row_content = {
                    Layout: row.getAttribute('data-layout')
                };

                if (row.getAttribute('data-title')) {
                    row_content.Title = row.getAttribute('data-title');
                }

                const widgets = [];
                row.querySelectorAll('.pagelayout-content').forEach((elt) => {
                    const items = [];
                    elt.querySelectorAll('.pagelayout-widget').forEach((elt) => {
                        items.push(JSON.parse(elt.getAttribute('data-value')));
                    });
                    widgets.push(items);
                });
                if (row.getAttribute('data-separated-columns') == 0) {
                    row_content.Elements = widgets[0];
                }
                else {
                    row_content.Elements = widgets;
                }
                content.push(row_content);
            }
            else {
                row.querySelectorAll('.pagelayout-widget').forEach((elt) => {
                    content.push(JSON.parse(elt.getAttribute('data-value')));
                });
            }
        });

        const serialized_content = JSON.stringify(content);
        if (!form.hasAttribute('data-old-value')) {
            form.setAttribute('data-old-value', serialized_content);
        }
        else if (serialized_content === form.getAttribute('data-old-value')) {
            document.querySelector('.pagelayout-form .pending-changes').classList.add('hidden');
        }
        else {
            document.querySelector('.pagelayout-form .pending-changes').classList.remove('hidden');
        }
        form.querySelector('input[name=Content]').value = serialized_content;
    },

    deleteWidget: function(e) {
        e.preventDefault();
        let widget = e.target.closest('.pagelayout-widget');
        widget.querySelectorAll('[data-bs-toggle=tooltip]').forEach((elt) => {
            bootstrap.Tooltip.getInstance(elt)?.hide();
        });
        document.getElementById(widget.id + '-modal')?.remove();
        if (widget.closest('div.row') && widget.closest('div.row').closest('div.pagelayout-content')) {
            widget = widget.parentNode;
        }
        widget.remove();
        pageLayout.syncChanges();
        return false;
    },

    refreshSource: function() {
        let searchTerm = this.value.toLowerCase();
        if (searchTerm.length) {
            document.querySelectorAll('.pagelayout-widget-menu .pagelayout-widget').forEach((elt) => {
                if (elt.querySelector('span.content').innerText.toLowerCase().indexOf(searchTerm) > -1) {
                    elt.classList.remove('hidden');
                }
                else {
                    elt.classList.add('hidden');
                }
            });
        }
        else {
            document.querySelectorAll('.pagelayout-widget-menu .pagelayout-widget').forEach((elt) => {
                elt.classList.remove('hidden');
            });
        }
    },

    calculateColumns: function(layout = 'col-12') {
        const classes = layout.split(/\s*,\s*/);
        let cols = 0;
        let total = 0;
        for (let i = 0; i < classes.length; i++) {
            const col = parseInt(classes[i].match(/^col-(?:.*?)(\d+)/)[1]);
            total += col;
            cols++;
            if (total == 12) {
                break;
            }
            else if (total > 12) {
                cols--;
                layout = classes.slice(0, i).join(',');
                break;
            }
        }

        if (total < 12) {
            const col = parseInt(classes[0].match(/col-(?:.*?)(\d+)/)[1]);
            while (total < 12) {
                total += col;
                cols++;
                if (total === 12) {
                    break;
                }
                else if (total > 12) {
                    cols--;
                    break;
                }
            }
        }
        return cols;
    }
};

pageLayout.order = {
    dragstart: function(e) {
        e.dataTransfer.setData("text/plain", e.target.id);
        e.target.classList.add('current');
        e.effectAllowed = "move";
    },

    dragend: function(e) {
        e.target.closest('div').querySelector('.pagelayout-order-placeholder.active')?.classList.remove('active');
        e.target.classList.remove('current');
    },

    dragenter: function(e) {
        e.preventDefault();
        e.target.querySelector(':scope > .pagelayout-order-placeholder')?.classList.add('active');
    },

    dragleave: function(e) {
        e.target.querySelector(':scope > .pagelayout-order-placeholder.active')?.classList.remove('active');
    },

    dragover: function(e) {
        e.preventDefault();
    },

    drop: function(e) {
        const source = document.getElementById(e.dataTransfer.getData('text/plain'));
        source.classList.remove('current');
        const div = e.target.closest('div');
        const sibling = e.target.closest('span.pagelayout-order') || div.querySelector(':scope > .pagelayout-order-placeholder');
        div.insertBefore(source, sibling);
        div.previousElementSibling.value = Array.from(div.querySelectorAll('span.pagelayout-order')).map((elt) => {
            return elt.getAttribute('data-index');
        }).join(',');
    },

    registerDrag: function(elt) {
        for (let event of ['drag', 'dragstart', 'dragend']) {
            elt.addEventListener(event, pageLayout.order[event]);
        }
    },

    registerDrop: function(elt) {
        for (let event of ['dragenter', 'dragover', 'dragleave', 'drop']) {
            elt.addEventListener(event, pageLayout.order[event]);
        }
    },
};

htmx.onLoad(function(elt) {
    const editor = elt.querySelector('.pagelayout-editor');
    if (editor) {
        editor.querySelectorAll('.pagelayout-form .delete-row').forEach((elt) => {
            elt.addEventListener('click', (e) => {
                bootstrap.Tooltip.getInstance(elt)?.hide();
                elt.closest('.row-container').remove();
                pageLayout.syncChanges();
                return false;
            });
        });
        const add_row_modal = editor.querySelector('#pagelayout-create-row-modal');
        if (add_row_modal) {
            editor.querySelector('#pagelayout-create-row-modal')?.querySelector('form').addEventListener('submit', (e) => {
                bootstrap.Modal.getInstance(add_row_modal).hide();
            });
        }

        editor.querySelectorAll('.pagelayout-widget-form').forEach((elt) => {
            elt.addEventListener('submit', pageLayout.widgetSubmit);
        });

        editor.querySelectorAll('.pagelayout-content').forEach((elt) => {
            pageLayout.registerDrop(elt);
        });

        editor.querySelectorAll('.pagelayout-widget').forEach((elt) => {
            pageLayout.registerDrag(elt);
            elt.querySelector('a.remove').addEventListener('click', pageLayout.deleteWidget);
        });

        editor.querySelectorAll('.pagelayout-row-form select[name=Columns]').forEach((elt) => {
            elt.addEventListener('change', (e) => {
                e.target.closest('form').querySelector('input[name=Layout]').value = 'col-' + (12 / e.target.value);
            });
        });

        editor.querySelectorAll('.pagelayout-row-form input[name=Layout]').forEach((elt) => {
            const columns = elt.closest('form').querySelector('[name=Columns]');
            if (elt.value) {
                columns.value = pageLayout.calculateColumns(elt.value);
            }
        });

        editor.querySelectorAll('.row-container .pagelayout-row-form').forEach((form) => {
            form.addEventListener('submit', pageLayout.rowSubmit);
        });

        editor.querySelector('.pagelayout-widget-menu input[name=search]').addEventListener('input', pageLayout.refreshSource);

        pageLayout.syncChanges();
    }

    const create_form = elt.querySelector('.pagelayout-create');
    if (create_form) {
        const updateClone = function(e) {
            const cls = create_form.querySelector('select[name=Class]').value;
            const page = create_form.querySelector('select[name=Page]').value;
            create_form.querySelectorAll('.clone').forEach((elt) => {
                if (cls === elt.getAttribute('data-class') && page === elt.getAttribute('data-page')) {
                    elt.classList.remove('hidden');
                }
                else {
                    elt.classList.add('hidden');
                }
            });
            create_form.querySelector('input[name=Clone][value=""]').checked = true;
        }
        create_form.querySelector('select[name=Class]').addEventListener('change', updateClone);
        create_form.querySelector('select[name=Page]').addEventListener('change', updateClone);
    };

    const mapping_form = elt.querySelector('.pagelayout-mapping');
    if (mapping_form?.querySelector('.pagelayout-order-container')) {
        pageLayout.order.registerDrop(mapping_form.querySelector('.pagelayout-order-container'));
        mapping_form.querySelectorAll('.pagelayout-order-container span.pagelayout-order:not(.default)').forEach((elt) => {
            pageLayout.order.registerDrag(elt);
        });
    }
});
