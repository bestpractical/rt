// a list of entries to process for the page
var pagePopupHelpItems = [
	{ selector: "[data-help]", action: helpify }  // by default, anything with data-help attributes gets processed
]

// add one or more items to the list of help entries to process for the page
function addPopupHelpItems() {
	const args = [].slice.call(arguments).reduce(function(acc,val) { return acc.concat(val) }, [] )
	pagePopupHelpItems = pagePopupHelpItems || []
	pagePopupHelpItems = pagePopupHelpItems.concat(args)
}

function applySelectorQueryOrFunc( sel ) {
	if ( sel ) {
		if ( typeof(sel) === "string" ) {
			return jQuery(sel)
		} else if ( typeof(sel) === "function" ) {
			return sel(jQuery)
		}
	}
}

function getPopupHelpAction( entry={} ) {
	entry.action = entry.action || "append"
	if ( typeof(entry.action) === "string" ) {
		const funcMap = {
			"before": beforePopupHelp,
			"after": afterPopupHelp,
			"append": appendPopupHelp,
			"prepend": prependPopupHelp,
			"offset": offsetPopupHelp,
			"replace": replacePopupHelp
		}
		if (funcMap.hasOwnProperty(entry.action)) {
			return funcMap[entry.action]
		} else {
			console.error("Unknown action '" + entry.action + "' using 'after' instead")
			return funcMap.after
		}
	} else if ( typeof(entry.action) === "function" ) {
		return entry.action
	}
}

function getPopupHelpActionArgs( entry={}, $els ) {
	return entry.actionArgs ? [ $els, entry, entry.actionArgs ] : [ $els, entry ]
}

function beforePopupHelp( $els, item={}, options={} ) {
	item.action = options.action = "before"
	return helpify( $els, item, options )
}

function afterPopupHelp( $els, item={}, options={} ) {
	item.action = options.action = "after"
	return helpify( $els, item, options )
}

function appendPopupHelp( $els, item={}, options={} ) {
	item.action = options.action = "append"
	return helpify( $els, item, options )
}

function prependPopupHelp( $els, item={}, options={} ) {
	item.action = options.action = "prepend"
	return helpify( $els, item, options )
}

function offsetPopupHelp( $els, item={}, options={} ) {
	item.action = options.action = "offset"
	return helpify( $els, item, options )
}

function replacePopupHelp( $els, item={}, options={} ) {
	item.action = options.action = "replace"
	return helpify( $els, item, options )
}

function helpify($els, item={}, options={}) {
	$els.each(function(index) {
		const $el = jQuery($els.get(index))
		const action = $el.data("action") || item.action || options.action
		const title = $el.data("title") || item.title || $el.data("help")
		const content = $el.data("content") || item.content
		switch(action) {
			case "before":
				$el.before( buildPopupHelpHtml( title, content ) )
				break
			case "prepend":
				$el.prepend( buildPopupHelpHtml( title, content ) )
				break
			case "offset":
				$el.append( buildPopupHelpHtml( title, content ) ).offset( options )
				break
			case "replace":
				$el.replaceWith( buildPopupHelpHtml( title, content ) )
				break
			case "append":
				$el.append( buildPopupHelpHtml( title, content ) )
				break
			case "after":  // intentionally fallthrough, as 'after' is the default
			default:
				$el.parent().append( buildPopupHelpHtml( title, content ) )
		}
	})
}

function buildPopupHelpHtml(title, content) {
	// TODO configurable glyph
	var icon = '/static/images/question'
	icon += (RT.Config.WebDefaultStylesheet.match(/-dark$/)) ? '-white.svg' : '.svg'
	const contentAttr = content ? ' data-content="' + content + '" ' : ''
	return '<a class="popup-help" tabindex="0" role="button" data-toggle="popover" title="' + title + '" data-trigger="focus" ' + contentAttr + '><img src="' + icon + '" /></a>'
}

function applyPopupHelpAction( entry, $els ) {
	if ( entry ) {
		const fn = getPopupHelpAction( entry )
		const args = getPopupHelpActionArgs( entry, $els )
		fn.apply(this, args)
	}
}

// Dynamically load the help topic corresponding to a DOM element using AJAX
// Should be called with the DOM element as the 'this' context of the function,
// making it directly compatible with the 'content' property of the popper.js
// popover() method, which is its primary purpose
const popupHelpAjax = function() {
    const isDefined = function(x) { return typeof x !== "undefined" }
    const buildUrl = function(key) { return RT.Config.WebHomePath + "/Helpers/HelpTopic?key=" + encodeURIComponent(key) }
    const boolVal = function(str) {
        try {
            return !!JSON.parse(str)
        }
        catch {
            return false
        }
    }

    const $el = jQuery(this)
    const key = $el.data("help") || $el.data("title") || $el.data("originalTitle")
    var content = $el.data("content")
    if (content) {
        return content
    } else {
        const isAsync = isDefined($el.data("async")) ? boolVal($el.data("async")) : true
        if (isAsync) {
            const tmpId = "tmp-id-" + jQuery.now()
            jQuery.ajax({
                url: buildUrl(key), dataType: "html",
                dataType: "html",
                success: function(response, statusText, xhr) {
                    jQuery("#" + tmpId).html(xhr.responseText)
                },
                error: function(e) {
                    jQuery("#" + tmpId).html("<div class='text-danger'>Error loading help for '" + key + "': " + e)
                }
            })
            return "<div id='" + tmpId + "'>Loading...</div>"
        } else {
            return "<div class='text-danger'>No help content available for '" + key + "'.</div>"
        }
    }
}

// render all the help icons and popover-ify them
function renderPopupHelpItems( list ) {
    list = list || pagePopupHelpItems
    if (list && Array.isArray(list) && list.length) {
        list.forEach(function(entry) {
            console.log("processing entry:", entry)
            const $els = applySelectorQueryOrFunc(entry.selector)
            if ( $els ) {
                applyPopupHelpAction( entry, $els )
            }
        })
        jQuery('[data-toggle="popover"]').popover({
            trigger: 'focus',
            html: true,
            content: popupHelpAjax
        })
    }
}
