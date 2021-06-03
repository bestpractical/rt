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
			"append": appendPopupHelp,
			"prepend": prependPopupHelp,
			"offset": offsetPopupHelp,
			"replace": replacePopupHelp
		}
		return funcMap[entry.action]
	} else if ( typeof(entry.action) === "function" ) {
		return entry.action
	}
}

function getPopupHelpActionArgs( entry={}, $els ) {
	return entry.actionArgs ? [ $els, entry, entry.actionArgs ] : [ $els, entry ]
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
		const title = $el.data("help") || $el.data("title") || item.title
		const content = $el.data("content") || item.content
		switch(action) {
			case "prepend":
				$el.parent().prepend( buildPopupHelpEl( title, content ) )
				break
			case "offset":
				$el.parent().append( buildPopupHelpEl( title, content ) ).offset( options )
				break
			case "replace":
				$el.replaceWith( buildPopupHelpEl( title, content ) )
				break
			case "append":  // intentionally fallthrough, as 'append' is the default
			default:
				$el.parent().append( buildPopupHelpEl( title, content ) )
		}
	})
}

function buildPopupHelpEl(title, content) {
	return '<a class="popup-help" tabindex="0" role="button" data-toggle="popover" title="' + title + '" data-content="' + quoteattr(content) + '" data-html="true" data-trigger="focus"><img src="/static/images/question.svg" /></a>'
}

function invokePopupHelpAction( entry, $els ) {
	if ( entry ) {
		const fn = getPopupHelpAction( entry )
		const args = getPopupHelpActionArgs( entry, $els )
		fn.apply(this, args)
	}
}

// a list of entries to process for the page
var pagePopupHelpItems = [
	{ selector: "[data-help]", action: helpify }  // by default, anything with data-help attributes gets processed
]

// add one or more items to the list of help entries to process for the page
function addPopupHelpItems() {
	const args = [].slice.call(arguments)
	pagePopupHelpItems = pagePopupHelpItems || []
	pagePopupHelpItems = pagePopupHelpItems.concat(args)	
}

// render all the help icons and popover-ify them
function renderPopupHelpItems( list ) {
	list = list || pagePopupHelpItems
	if (list && Array.isArray(list) && list.length) {
		list.forEach(function(entry) {
			const $els = applySelectorQueryOrFunc(entry.selector)
			if ( $els ) {
				invokePopupHelpAction( entry, $els )
			}
		})
        jQuery('[data-toggle="popover"]').popover({trigger: 'focus'})
	}
}
