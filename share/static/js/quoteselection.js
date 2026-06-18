if (RT.Config.QuoteSelectedText) {
    const add_sub_container = function (container, tagName) {
        const sub = document.createElement(tagName);
        container.appendChild(sub);
        return sub;
    };

    const range_html = function (range) {
        const topContainer = document.createElement('div');
        const fragment = range.cloneContents();
        const child = fragment.firstElementChild;

        let container = topContainer;

        if (child) {
            var tn = child.tagName;
            if (tn == "LI") {
                container = add_sub_container(container, 'ul');
            } else if (tn == "DT" || tn == "DD") {
                container = add_sub_container(container, 'dl');
            } else if (tn == "TD" || tn == "TH") {
                container = add_sub_container(container, 'table');
                container = add_sub_container(container, 'tbody');
                container = add_sub_container(container, 'tr');
            } else if (tn == "TR") {
                container = add_sub_container(container, 'table');
                container = add_sub_container(container, 'tbody');
            } else if (tn == "TBODY" || tn == "THEAD" || tn == "TFOOT") {
                container = add_sub_container(container, 'table');
            }
        }

        container.appendChild(fragment);
        return topContainer.innerHTML;
    };

    jQuery(function () {
        document.body.addEventListener('htmx:configRequest', function (evt) {
            if (evt.target?.getAttribute('data-quote-selection')) {
                let selection;
                let activeElement;
                if (window.getSelection) {
                    selection = window.getSelection();
                } else {
                    return;
                }

                if (selection.rangeCount) {
                    activeElement = selection.getRangeAt(0);
                } else {
                    return;
                }

                // check if selection has commonAncestorContainer with class 'messagebody'
                const commonAncestor = activeElement.commonAncestorContainer;
                if (commonAncestor) {
                    let isMessageBody = false;
                    let parent = commonAncestor.parentNode;
                    while (parent) {
                        if (parent.className && parent.className.indexOf('messagebody') != -1) {
                            isMessageBody = true;
                            break;
                        }
                        parent = parent.parentNode;
                    }
                    if (!isMessageBody) {
                        return;
                    }
                }

                if (RT.Config.MessageBoxRichText) {
                    selection = range_html(activeElement);
                }
                else {
                    if (selection.toString) {
                        selection = selection.toString();
                    }
                    selection = selection.concat("\n\n");
                }
                if (typeof (selection) !== "string" || selection.length < 3) {
                    return;
                }
                evt.detail.parameters['QuoteContent'] = selection;
                // POST the selection in the request body so it never appears in the URL
                evt.detail.verb = 'post';
                evt.detail.useUrlParams = false;
                evt.detail.headers['Content-Type'] = 'application/x-www-form-urlencoded';
            }
        });
    });

    htmx.onLoad(function (elt) {
        elt.querySelectorAll(
            ".reply-link, " +
            ".comment-link, " +
            "#page-actions-reply, " +
            "#page-actions-comment"
        ).forEach(elt => {
            elt.setAttribute('data-quote-selection', true);
        });
    });
}
