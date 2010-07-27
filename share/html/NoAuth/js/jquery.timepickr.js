/*
 * jQuery UI 0.6.6
 *
 * Copyright (c) 2009 AUTHORS.txt (http://jqueryui.com/about)
 * Dual licensed under the MIT (MIT-LICENSE.txt)
 * and GPL (GPL-LICENSE.txt) licenses.
 *
 * http://docs.jquery.com/UI
 */
;jQuery.ui || (function($) {

var _remove = $.fn.remove,
	isFF2 = $.browser.mozilla && (parseFloat($.browser.version) < 1.9);

//Helper functions and ui object
$.ui = {
	version: "0.6.6",

	// $.ui.plugin is deprecated.  Use the proxy pattern instead.
	plugin: {
		add: function(module, option, set) {
			var proto = $.ui[module].prototype;
			for(var i in set) {
				proto.plugins[i] = proto.plugins[i] || [];
				proto.plugins[i].push([option, set[i]]);
			}
		},
		call: function(instance, name, args) {
			var set = instance.plugins[name];
			if(!set || !instance.element[0].parentNode) { return; }

			for (var i = 0; i < set.length; i++) {
				if (instance.options[set[i][0]]) {
					set[i][1].apply(instance.element, args);
				}
			}
		}
	},

	contains: function(a, b) {
		return document.compareDocumentPosition
			? a.compareDocumentPosition(b) & 16
			: a !== b && a.contains(b);
	},

	hasScroll: function(el, a) {

		//If overflow is hidden, the element might have extra content, but the user wants to hide it
		if ($(el).css('overflow') == 'hidden') { return false; }

		var scroll = (a && a == 'left') ? 'scrollLeft' : 'scrollTop',
			has = false;

		if (el[scroll] > 0) { return true; }

		// TODO: determine which cases actually cause this to happen
		// if the element doesn't have the scroll set, see if it's possible to
		// set the scroll
		el[scroll] = 1;
		has = (el[scroll] > 0);
		el[scroll] = 0;
		return has;
	},

	isOverAxis: function(x, reference, size) {
		//Determines when x coordinate is over "b" element axis
		return (x > reference) && (x < (reference + size));
	},

	isOver: function(y, x, top, left, height, width) {
		//Determines when x, y coordinates is over "b" element
		return $.ui.isOverAxis(y, top, height) && $.ui.isOverAxis(x, left, width);
	},

	keyCode: {
		BACKSPACE: 8,
		CAPS_LOCK: 20,
		COMMA: 188,
		CONTROL: 17,
		DELETE: 46,
		DOWN: 40,
		END: 35,
		ENTER: 13,
		ESCAPE: 27,
		HOME: 36,
		INSERT: 45,
		LEFT: 37,
		NUMPAD_ADD: 107,
		NUMPAD_DECIMAL: 110,
		NUMPAD_DIVIDE: 111,
		NUMPAD_ENTER: 108,
		NUMPAD_MULTIPLY: 106,
		NUMPAD_SUBTRACT: 109,
		PAGE_DOWN: 34,
		PAGE_UP: 33,
		PERIOD: 190,
		RIGHT: 39,
		SHIFT: 16,
		SPACE: 32,
		TAB: 9,
		UP: 38
	}
};

// WAI-ARIA normalization
if (isFF2) {
	var attr = $.attr,
		removeAttr = $.fn.removeAttr,
		ariaNS = "http://www.w3.org/2005/07/aaa",
		ariaState = /^aria-/,
		ariaRole = /^wairole:/;

	$.attr = function(elem, name, value) {
		var set = value !== undefined;

		return (name == 'role'
			? (set
				? attr.call(this, elem, name, "wairole:" + value)
				: (attr.apply(this, arguments) || "").replace(ariaRole, ""))
			: (ariaState.test(name)
				? (set
					? elem.setAttributeNS(ariaNS,
						name.replace(ariaState, "aaa:"), value)
					: attr.call(this, elem, name.replace(ariaState, "aaa:")))
				: attr.apply(this, arguments)));
	};

	$.fn.removeAttr = function(name) {
		return (ariaState.test(name)
			? this.each(function() {
				this.removeAttributeNS(ariaNS, name.replace(ariaState, ""));
			}) : removeAttr.call(this, name));
	};
}

//jQuery plugins
$.fn.extend({
	remove: function() {
		// Safari has a native remove event which actually removes DOM elements,
		// so we have to use triggerHandler instead of trigger (#3037).
		$("*", this).add(this).each(function() {
			$(this).triggerHandler("remove");
		});
		return _remove.apply(this, arguments );
	},

	enableSelection: function() {
		return this
			.attr('unselectable', 'off')
			.css('MozUserSelect', '')
			.unbind('selectstart.ui');
	},

	disableSelection: function() {
		return this
			.attr('unselectable', 'on')
			.css('MozUserSelect', 'none')
			.bind('selectstart.ui', function() { return false; });
	},

	scrollParent: function() {
		var scrollParent;
		if(($.browser.msie && (/(static|relative)/).test(this.css('position'))) || (/absolute/).test(this.css('position'))) {
			scrollParent = this.parents().filter(function() {
				return (/(relative|absolute|fixed)/).test($.curCSS(this,'position',1)) && (/(auto|scroll)/).test($.curCSS(this,'overflow',1)+$.curCSS(this,'overflow-y',1)+$.curCSS(this,'overflow-x',1));
			}).eq(0);
		} else {
			scrollParent = this.parents().filter(function() {
				return (/(auto|scroll)/).test($.curCSS(this,'overflow',1)+$.curCSS(this,'overflow-y',1)+$.curCSS(this,'overflow-x',1));
			}).eq(0);
		}

		return (/fixed/).test(this.css('position')) || !scrollParent.length ? $(document) : scrollParent;
	}
});


//Additional selectors
$.extend($.expr[':'], {
	data: function(elem, i, match) {
		return !!$.data(elem, match[3]);
	},

	focusable: function(element) {
		var nodeName = element.nodeName.toLowerCase(),
			tabIndex = $.attr(element, 'tabindex');
		return (/input|select|textarea|button|object/.test(nodeName)
			? !element.disabled
			: 'a' == nodeName || 'area' == nodeName
				? element.href || !isNaN(tabIndex)
				: !isNaN(tabIndex))
			// the element and all of its ancestors must be visible
			// the browser may report that the area is hidden
			&& !$(element)['area' == nodeName ? 'parents' : 'closest'](':hidden').length;
	},

	tabbable: function(element) {
		var tabIndex = $.attr(element, 'tabindex');
		return (isNaN(tabIndex) || tabIndex >= 0) && $(element).is(':focusable');
	}
});


// $.widget is a factory to create jQuery plugins
// taking some boilerplate code out of the plugin code
function getter(namespace, plugin, method, args) {
	function getMethods(type) {
		var methods = $[namespace][plugin][type] || [];
		return (typeof methods == 'string' ? methods.split(/,?\s+/) : methods);
	}

	var methods = getMethods('getter');
	if (args.length == 1 && typeof args[0] == 'string') {
		methods = methods.concat(getMethods('getterSetter'));
	}
	return ($.inArray(method, methods) != -1);
}

$.widget = function(name, prototype) {
	var namespace = name.split(".")[0];
	name = name.split(".")[1];

	// create plugin method
	$.fn[name] = function(options) {
		var isMethodCall = (typeof options == 'string'),
			args = Array.prototype.slice.call(arguments, 1);

		// prevent calls to internal methods
		if (isMethodCall && options.substring(0, 1) == '_') {
			return this;
		}

		// handle getter methods
		if (isMethodCall && getter(namespace, name, options, args)) {
			var instance = $.data(this[0], name);
			return (instance ? instance[options].apply(instance, args)
				: undefined);
		}

		// handle initialization and non-getter methods
		return this.each(function() {
			var instance = $.data(this, name);

			// constructor
			(!instance && !isMethodCall &&
				$.data(this, name, new $[namespace][name](this, options))._init());

			// method call
			(instance && isMethodCall && $.isFunction(instance[options]) &&
				instance[options].apply(instance, args));
		});
	};

	// create widget constructor
	$[namespace] = $[namespace] || {};
	$[namespace][name] = function(element, options) {
		var self = this;

		this.namespace = namespace;
		this.widgetName = name;
		this.widgetEventPrefix = $[namespace][name].eventPrefix || name;
		this.widgetBaseClass = namespace + '-' + name;

		this.options = $.extend({},
			$.widget.defaults,
			$[namespace][name].defaults,
			$.metadata && $.metadata.get(element)[name],
			options);

		this.element = $(element)
			.bind('setData.' + name, function(event, key, value) {
				if (event.target == element) {
					return self._setData(key, value);
				}
			})
			.bind('getData.' + name, function(event, key) {
				if (event.target == element) {
					return self._getData(key);
				}
			})
			.bind('remove', function() {
				return self.destroy();
			});
	};

	// add widget prototype
	$[namespace][name].prototype = $.extend({}, $.widget.prototype, prototype);

	// TODO: merge getter and getterSetter properties from widget prototype
	// and plugin prototype
	$[namespace][name].getterSetter = 'option';
};

$.widget.prototype = {
	_init: function() {},
	destroy: function() {
		this.element.removeData(this.widgetName)
			.removeClass(this.widgetBaseClass + '-disabled' + ' ' + this.namespace + '-state-disabled')
			.removeAttr('aria-disabled');
	},

	option: function(key, value) {
		var options = key,
			self = this;

		if (typeof key == "string") {
			if (value === undefined) {
				return this._getData(key);
			}
			options = {};
			options[key] = value;
		}

		$.each(options, function(key, value) {
			self._setData(key, value);
		});
	},
	_getData: function(key) {
		return this.options[key];
	},
	_setData: function(key, value) {
		this.options[key] = value;

		if (key == 'disabled') {
			this.element
				[value ? 'addClass' : 'removeClass'](
					this.widgetBaseClass + '-disabled' + ' ' +
					this.namespace + '-state-disabled')
				.attr("aria-disabled", value);
		}
	},

	enable: function() {
		this._setData('disabled', false);
	},
	disable: function() {
		this._setData('disabled', true);
	},

	_trigger: function(type, event, data) {
		var callback = this.options[type],
			eventName = (type == this.widgetEventPrefix
				? type : this.widgetEventPrefix + type);

		event = $.Event(event);
		event.type = eventName;

		// copy original event properties over to the new event
		// this would happen if we could call $.event.fix instead of $.Event
		// but we don't have a way to force an event to be fixed multiple times
		if (event.originalEvent) {
			for (var i = $.event.props.length, prop; i;) {
				prop = $.event.props[--i];
				event[prop] = event.originalEvent[prop];
			}
		}

		this.element.trigger(event, data);

		return !($.isFunction(callback) && callback.call(this.element[0], event, data) === false
			|| event.isDefaultPrevented());
	}
};

$.widget.defaults = {
	disabled: false
};


/** Mouse Interaction Plugin **/

$.ui.mouse = {
	_mouseInit: function() {
		var self = this;

		this.element
			.bind('mousedown.'+this.widgetName, function(event) {
				return self._mouseDown(event);
			})
			.bind('click.'+this.widgetName, function(event) {
				if(self._preventClickEvent) {
					self._preventClickEvent = false;
					event.stopImmediatePropagation();
					return false;
				}
			});

		// Prevent text selection in IE
		if ($.browser.msie) {
			this._mouseUnselectable = this.element.attr('unselectable');
			this.element.attr('unselectable', 'on');
		}

		this.started = false;
	},

	// TODO: make sure destroying one instance of mouse doesn't mess with
	// other instances of mouse
	_mouseDestroy: function() {
		this.element.unbind('.'+this.widgetName);

		// Restore text selection in IE
		($.browser.msie
			&& this.element.attr('unselectable', this._mouseUnselectable));
	},

	_mouseDown: function(event) {
		// don't let more than one widget handle mouseStart
		// TODO: figure out why we have to use originalEvent
		event.originalEvent = event.originalEvent || {};
		if (event.originalEvent.mouseHandled) { return; }

		// we may have missed mouseup (out of window)
		(this._mouseStarted && this._mouseUp(event));

		this._mouseDownEvent = event;

		var self = this,
			btnIsLeft = (event.which == 1),
			elIsCancel = (typeof this.options.cancel == "string" ? $(event.target).parents().add(event.target).filter(this.options.cancel).length : false);
		if (!btnIsLeft || elIsCancel || !this._mouseCapture(event)) {
			return true;
		}

		this.mouseDelayMet = !this.options.delay;
		if (!this.mouseDelayMet) {
			this._mouseDelayTimer = setTimeout(function() {
				self.mouseDelayMet = true;
			}, this.options.delay);
		}

		if (this._mouseDistanceMet(event) && this._mouseDelayMet(event)) {
			this._mouseStarted = (this._mouseStart(event) !== false);
			if (!this._mouseStarted) {
				event.preventDefault();
				return true;
			}
		}

		// these delegates are required to keep context
		this._mouseMoveDelegate = function(event) {
			return self._mouseMove(event);
		};
		this._mouseUpDelegate = function(event) {
			return self._mouseUp(event);
		};
		$(document)
			.bind('mousemove.'+this.widgetName, this._mouseMoveDelegate)
			.bind('mouseup.'+this.widgetName, this._mouseUpDelegate);

		// preventDefault() is used to prevent the selection of text here -
		// however, in Safari, this causes select boxes not to be selectable
		// anymore, so this fix is needed
		($.browser.safari || event.preventDefault());

		event.originalEvent.mouseHandled = true;
		return true;
	},

	_mouseMove: function(event) {
		// IE mouseup check - mouseup happened when mouse was out of window
		if ($.browser.msie && !event.button) {
			return this._mouseUp(event);
		}

		if (this._mouseStarted) {
			this._mouseDrag(event);
			return event.preventDefault();
		}

		if (this._mouseDistanceMet(event) && this._mouseDelayMet(event)) {
			this._mouseStarted =
				(this._mouseStart(this._mouseDownEvent, event) !== false);
			(this._mouseStarted ? this._mouseDrag(event) : this._mouseUp(event));
		}

		return !this._mouseStarted;
	},

	_mouseUp: function(event) {
		$(document)
			.unbind('mousemove.'+this.widgetName, this._mouseMoveDelegate)
			.unbind('mouseup.'+this.widgetName, this._mouseUpDelegate);

		if (this._mouseStarted) {
			this._mouseStarted = false;
			this._preventClickEvent = (event.target == this._mouseDownEvent.target);
			this._mouseStop(event);
		}

		return false;
	},

	_mouseDistanceMet: function(event) {
		return (Math.max(
				Math.abs(this._mouseDownEvent.pageX - event.pageX),
				Math.abs(this._mouseDownEvent.pageY - event.pageY)
			) >= this.options.distance
		);
	},

	_mouseDelayMet: function(event) {
		return this.mouseDelayMet;
	},

	// These are placeholder methods, to be overriden by extending plugin
	_mouseStart: function(event) {},
	_mouseDrag: function(event) {},
	_mouseStop: function(event) {},
	_mouseCapture: function(event) { return true; }
};

$.ui.mouse.defaults = {
	cancel: null,
	distance: 1,
	delay: 0
};

})(jQuery);
/*
  jQuery utils - 0.6.6
  http://code.google.com/p/jquery-utils/

  (c) Maxime Haineault <haineault@gmail.com> 
  http://haineault.com

  MIT License (http://www.opensource.org/licenses/mit-license.php

*/

(function($){
     $.extend($.expr[':'], {
        // case insensitive version of :contains
        icontains: function(a,i,m){return (a.textContent||a.innerText||jQuery(a).text()||"").toLowerCase().indexOf(m[3].toLowerCase())>=0;}
    });

    $.iterators = {
        getText:  function() { return $(this).text(); },
        parseInt: function(v){ return parseInt(v, 10); }
    };

	$.extend({ 

        // Returns a range object
        // Author: Matthias Miller
        // Site:   http://blog.outofhanwell.com/2006/03/29/javascript-range-function/
        range:  function() {
            if (!arguments.length) { return []; }
            var min, max, step;
            if (arguments.length == 1) {
                min  = 0;
                max  = arguments[0]-1;
                step = 1;
            }
            else {
                // default step to 1 if it's zero or undefined
                min  = arguments[0];
                max  = arguments[1]-1;
                step = arguments[2] || 1;
            }
            // convert negative steps to positive and reverse min/max
            if (step < 0 && min >= max) {
                step *= -1;
                var tmp = min;
                min = max;
                max = tmp;
                min += ((max-min) % step);
            }
            var a = [];
            for (var i = min; i <= max; i += step) { a.push(i); }
            return a;
        },

        // Taken from ui.core.js. 
        // Why are you keeping this gem for yourself guys ? :|
        keyCode: {
            BACKSPACE: 8, CAPS_LOCK: 20, COMMA: 188, CONTROL: 17, DELETE: 46, DOWN: 40,
            END: 35, ENTER: 13, ESCAPE: 27, HOME: 36, INSERT:  45, LEFT: 37,
            NUMPAD_ADD: 107, NUMPAD_DECIMAL: 110, NUMPAD_DIVIDE: 111, NUMPAD_ENTER: 108, 
            NUMPAD_MULTIPLY: 106, NUMPAD_SUBTRACT: 109, PAGE_DOWN: 34, PAGE_UP: 33, 
            PERIOD: 190, RIGHT: 39, SHIFT: 16, SPACE: 32, TAB: 9, UP: 38
        },
        
        keyIs: function(k, e) {
            return parseInt($.keyCode[k.toUpperCase()], 10) == parseInt((typeof(e) == 'number' )? e: e.keyCode, 10);
        },

        // Redirect to a specified url
        redirect: function(url) {
            window.location.href = url;
            return url;
        },

        // Stop event shorthand
        stop: function(e, preventDefault, stopPropagation) {
            if (preventDefault)  { e.preventDefault(); }
            if (stopPropagation) { e.stopPropagation(); }
            return preventDefault && false || true;
        },

        // Returns the basename of a path
        basename: function(path) {
            var t = path.split('/');
            return t[t.length] === '' && s || t.slice(0, t.length).join('/');
        },

        // Returns the filename of a path
        filename: function(path) {
            return path.split('/').pop();
        }, 

        // Returns a formated file size
        filesizeformat: function(bytes, suffixes){
            var b = parseInt(bytes, 10);
            var s = suffixes || ['byte', 'bytes', 'KB', 'MB', 'GB'];
            if (isNaN(b) || b === 0) { return '0 ' + s[0]; }
            if (b == 1)              { return '1 ' + s[0]; }
            if (b < 1024)            { return  b.toFixed(2) + ' ' + s[1]; }
            if (b < 1048576)         { return (b / 1024).toFixed(2) + ' ' + s[2]; }
            if (b < 1073741824)      { return (b / 1048576).toFixed(2) + ' '+ s[3]; }
            else                     { return (b / 1073741824).toFixed(2) + ' '+ s[4]; }
        },

        fileExtension: function(s) {
            var tokens = s.split('.');
            return tokens[tokens.length-1] || false;
        },
        
        // Returns true if an object is a String
        isString: function(o) {
            return typeof(o) == 'string' && true || false;
        },
        
        // Returns true if an object is a RegExp
		isRegExp: function(o) {
			return o && o.constructor.toString().indexOf('RegExp()') != -1 || false;
		},
        
        // Returns true if an object is an array
        // Mark Miller - http://blog.360.yahoo.com/blog-TBPekxc1dLNy5DOloPfzVvFIVOWMB0li?p=916
		isArray: function(o) {
            if (!o) { return false; }
            return o.constructor && Object.prototype.toString.apply(o.constructor.prototype) === '[object Array]';
		},

        isObject: function(o) {
            return (typeof(o) == 'object');
        },
        
        // Convert input to currency (two decimal fixed number)
		toCurrency: function(i) {
			i = parseFloat(i, 10).toFixed(2);
			return (i=='NaN') ? '0.00' : i;
		},

        /*-------------------------------------------------------------------- 
         * javascript method: "pxToEm"
         * by:
           Scott Jehl (scott@filamentgroup.com) 
           Maggie Wachs (maggie@filamentgroup.com)
           http://www.filamentgroup.com
         *
         * Copyright (c) 2008 Filament Group
         * Dual licensed under the MIT (filamentgroup.com/examples/mit-license.txt) and GPL (filamentgroup.com/examples/gpl-license.txt) licenses.
         *
         * Description: pxToEm converts a pixel value to ems depending on inherited font size.  
         * Article: http://www.filamentgroup.com/lab/retaining_scalable_interfaces_with_pixel_to_em_conversion/
         * Demo: http://www.filamentgroup.com/examples/pxToEm/	 	
         *							
         * Options:  	 								
                scope: string or jQuery selector for font-size scoping
                reverse: Boolean, true reverses the conversion to em-px
         * Dependencies: jQuery library						  
         * Usage Example: myPixelValue.pxToEm(); or myPixelValue.pxToEm({'scope':'#navigation', reverse: true});
         *
         * Version: 2.1, 18.12.2008
         * Changelog:
         *		08.02.2007 initial Version 1.0
         *		08.01.2008 - fixed font-size calculation for IE
         *		18.12.2008 - removed native object prototyping to stay in jQuery's spirit, jsLinted (Maxime Haineault <haineault@gmail.com>)
        --------------------------------------------------------------------*/

        pxToEm: function(i, settings){
            //set defaults
            settings = jQuery.extend({
                scope: 'body',
                reverse: false
            }, settings);
            
            var pxVal = (i === '') ? 0 : parseFloat(i);
            var scopeVal;
            var getWindowWidth = function(){
                var de = document.documentElement;
                return self.innerWidth || (de && de.clientWidth) || document.body.clientWidth;
            };	
            
            /* When a percentage-based font-size is set on the body, IE returns that percent of the window width as the font-size. 
                For example, if the body font-size is 62.5% and the window width is 1000px, IE will return 625px as the font-size. 	
                When this happens, we calculate the correct body font-size (%) and multiply it by 16 (the standard browser font size) 
                to get an accurate em value. */
                        
            if (settings.scope == 'body' && $.browser.msie && (parseFloat($('body').css('font-size')) / getWindowWidth()).toFixed(1) > 0.0) {
                var calcFontSize = function(){		
                    return (parseFloat($('body').css('font-size'))/getWindowWidth()).toFixed(3) * 16;
                };
                scopeVal = calcFontSize();
            }
            else { scopeVal = parseFloat(jQuery(settings.scope).css("font-size")); }
                    
            var result = (settings.reverse === true) ? (pxVal * scopeVal).toFixed(2) + 'px' : (pxVal / scopeVal).toFixed(2) + 'em';
            return result;
        }
	});

	$.extend($.fn, { 
        // Select a text range in a textarea
        selectRange: function(start, end){
            // use only the first one since only one input can be focused
            if ($(this).get(0).createTextRange) {
                var range = $(this).get(0).createTextRange();
                range.collapse(true);
                range.moveEnd('character',   end);
                range.moveStart('character', start);
                range.select();
            }
            else if ($(this).get(0).setSelectionRange) {
                $(this).bind('focus', function(e){
                    e.preventDefault();
                }).get(0).setSelectionRange(start, end);
            }
            return $(this);
        },

        /*-------------------------------------------------------------------- 
         * JQuery Plugin: "EqualHeights"
         * by:	Scott Jehl, Todd Parker, Maggie Costello Wachs (http://www.filamentgroup.com)
         *
         * Copyright (c) 2008 Filament Group
         * Licensed under GPL (http://www.opensource.org/licenses/gpl-license.php)
         *
         * Description: Compares the heights or widths of the top-level children of a provided element 
                and sets their min-height to the tallest height (or width to widest width). Sets in em units 
                by default if pxToEm() method is available.
         * Dependencies: jQuery library, pxToEm method	(article: 
                http://www.filamentgroup.com/lab/retaining_scalable_interfaces_with_pixel_to_em_conversion/)							  
         * Usage Example: $(element).equalHeights();
                Optional: to set min-height in px, pass a true argument: $(element).equalHeights(true);
         * Version: 2.1, 18.12.2008
         *
         * Note: Changed pxToEm call to call $.pxToEm instead, jsLinted (Maxime Haineault <haineault@gmail.com>)
        --------------------------------------------------------------------*/

        equalHeights: function(px){
            $(this).each(function(){
                var currentTallest = 0;
                $(this).children().each(function(i){
                    if ($(this).height() > currentTallest) { currentTallest = $(this).height(); }
                });
                if (!px || !$.pxToEm) { currentTallest = $.pxToEm(currentTallest); } //use ems unless px is specified
                // for ie6, set height since min-height isn't supported
                if ($.browser.msie && $.browser.version == 6.0) { $(this).children().css({'height': currentTallest}); }
                $(this).children().css({'min-height': currentTallest}); 
            });
            return this;
        },

        // Copyright (c) 2009 James Padolsey
        // http://james.padolsey.com/javascript/jquery-delay-plugin/
        delay: function(time, callback){
            jQuery.fx.step.delay = function(){};
            return this.animate({delay:1}, time, callback);
        }        
	});
})(jQuery);
/*
  jQuery strings - 0.3
  http://code.google.com/p/jquery-utils/
  
  (c) Maxime Haineault <haineault@gmail.com>
  http://haineault.com   

  MIT License (http://www.opensource.org/licenses/mit-license.php)

  Implementation of Python3K advanced string formatting
  http://www.python.org/dev/peps/pep-3101/

  Documentation: http://code.google.com/p/jquery-utils/wiki/StringFormat
  
*/
(function($){
    var strings = {
        strConversion: {
            // tries to translate any objects type into string gracefully
            __repr: function(i){
                switch(this.__getType(i)) {
                    case 'array':case 'date':case 'number':
                        return i.toString();
                    case 'object': 
                        var o = [];
                        for (x=0; x<i.length; i++) { o.push(i+': '+ this.__repr(i[x])); }
                        return o.join(', ');
                    case 'string': 
                        return i;
                    default: 
                        return i;
                }
            },
            // like typeof but less vague
            __getType: function(i) {
                if (!i || !i.constructor) { return typeof(i); }
                var match = i.constructor.toString().match(/Array|Number|String|Object|Date/);
                return match && match[0].toLowerCase() || typeof(i);
            },
            //+ Jonas Raoni Soares Silva
            //@ http://jsfromhell.com/string/pad [v1.0]
            __pad: function(str, l, s, t){
                var p = s || ' ';
                var o = str;
                if (l - str.length > 0) {
                    o = new Array(Math.ceil(l / p.length)).join(p).substr(0, t = !t ? l : t == 1 ? 0 : Math.ceil(l / 2)) + str + p.substr(0, l - t);
                }
                return o;
            },
            __getInput: function(arg, args) {
                 var key = arg.getKey();
                switch(this.__getType(args)){
                    case 'object': // Thanks to Jonathan Works for the patch
                        var keys = key.split('.');
                        var obj = args;
                        for(var subkey = 0; subkey < keys.length; subkey++){
                            obj = obj[keys[subkey]];
                        }
                        if (typeof(obj) != 'undefined') {
                            if (strings.strConversion.__getType(obj) == 'array') {
                                return arg.getFormat().match(/\.\*/) && obj[1] || obj;
                            }
                            return obj;
                        }
                        else {
                            // TODO: try by numerical index                    
                        }
                    break;
                    case 'array': 
                        key = parseInt(key, 10);
                        if (arg.getFormat().match(/\.\*/) && typeof args[key+1] != 'undefined') { return args[key+1]; }
                        else if (typeof args[key] != 'undefined') { return args[key]; }
                        else { return key; }
                    break;
                }
                return '{'+key+'}';
            },
            __formatToken: function(token, args) {
                var arg   = new Argument(token, args);
                return strings.strConversion[arg.getFormat().slice(-1)](this.__getInput(arg, args), arg);
            },

            // Signed integer decimal.
            d: function(input, arg){
                var o = parseInt(input, 10); // enforce base 10
                var p = arg.getPaddingLength();
                if (p) { return this.__pad(o.toString(), p, arg.getPaddingString(), 0); }
                else   { return o; }
            },
            // Signed integer decimal.
            i: function(input, args){ 
                return this.d(input, args);
            },
            // Unsigned octal
            o: function(input, arg){ 
                var o = input.toString(8);
                if (arg.isAlternate()) { o = this.__pad(o, o.length+1, '0', 0); }
                return this.__pad(o, arg.getPaddingLength(), arg.getPaddingString(), 0);
            },
            // Unsigned decimal
            u: function(input, args) {
                return Math.abs(this.d(input, args));
            },
            // Unsigned hexadecimal (lowercase)
            x: function(input, arg){
                var o = parseInt(input, 10).toString(16);
                o = this.__pad(o, arg.getPaddingLength(), arg.getPaddingString(),0);
                return arg.isAlternate() ? '0x'+o : o;
            },
            // Unsigned hexadecimal (uppercase)
            X: function(input, arg){
                return this.x(input, arg).toUpperCase();
            },
            // Floating point exponential format (lowercase)
            e: function(input, arg){
                return parseFloat(input, 10).toExponential(arg.getPrecision());
            },
            // Floating point exponential format (uppercase)
            E: function(input, arg){
                return this.e(input, arg).toUpperCase();
            },
            // Floating point decimal format
            f: function(input, arg){
                return this.__pad(parseFloat(input, 10).toFixed(arg.getPrecision()), arg.getPaddingLength(), arg.getPaddingString(),0);
            },
            // Floating point decimal format (alias)
            F: function(input, args){
                return this.f(input, args);
            },
            // Floating point format. Uses exponential format if exponent is greater than -4 or less than precision, decimal format otherwise
            g: function(input, arg){
                var o = parseFloat(input, 10);
                return (o.toString().length > 6) ? Math.round(o.toExponential(arg.getPrecision())): o;
            },
            // Floating point format. Uses exponential format if exponent is greater than -4 or less than precision, decimal format otherwise
            G: function(input, args){
                return this.g(input, args);
            },
            // Single character (accepts integer or single character string). 	
            c: function(input, args) {
                var match = input.match(/\w|\d/);
                return match && match[0] || '';
            },
            // String (converts any JavaScript object to anotated format)
            r: function(input, args) {
                return this.__repr(input);
            },
            // String (converts any JavaScript object using object.toString())
            s: function(input, args) {
                return input.toString && input.toString() || ''+input;
            }
        },

        format: function(str, args) {
            var end    = 0;
            var start  = 0;
            var match  = false;
            var buffer = [];
            var token  = '';
            var tmp    = (str||'').split('');
            for(start=0; start < tmp.length; start++) {
                if (tmp[start] == '{' && tmp[start+1] !='{') {
                    end   = str.indexOf('}', start);
                    token = tmp.slice(start+1, end).join('');
                    if (tmp[start-1] != '{' && tmp[end+1] != '}') {
                        var tokenArgs = (typeof arguments[1] != 'object')? arguments2Array(arguments, 2): args || [];
                        buffer.push(strings.strConversion.__formatToken(token, tokenArgs));
                    }
                    else {
                        buffer.push(token);
                    }
                }
                else if (start > end || buffer.length < 1) { buffer.push(tmp[start]); }
            }
            return (buffer.length > 1)? buffer.join(''): buffer[0];
        },

        calc: function(str, args) {
            return eval(format(str, args));
        },

        repeat: function(s, n) { 
            return new Array(n+1).join(s); 
        },

        UTF8encode: function(s) { 
            return unescape(encodeURIComponent(s)); 
        },

        UTF8decode: function(s) { 
            return decodeURIComponent(escape(s)); 
        },

        tpl: function() {
            var out = '', render = true;
            // Set
            // $.tpl('ui.test', ['<span>', helloWorld ,'</span>']);
            if (arguments.length == 2 && $.isArray(arguments[1])) {
                this[arguments[0]] = arguments[1].join('');
                return jQuery;
            }
            // $.tpl('ui.test', '<span>hello world</span>');
            if (arguments.length == 2 && $.isString(arguments[1])) {
                this[arguments[0]] = arguments[1];
                return jQuery;
            }
            // Call
            // $.tpl('ui.test');
            if (arguments.length == 1) {
                return $(this[arguments[0]]);
            }
            // $.tpl('ui.test', false);
            if (arguments.length == 2 && arguments[1] == false) {
                return this[arguments[0]];
            }
            // $.tpl('ui.test', {value:blah});
            if (arguments.length == 2 && $.isObject(arguments[1])) {
                return $($.format(this[arguments[0]], arguments[1]));
            }
            // $.tpl('ui.test', {value:blah}, false);
            if (arguments.length == 3 && $.isObject(arguments[1])) {
                return (arguments[2] == true) 
                    ? $.format(this[arguments[0]], arguments[1])
                    : $($.format(this[arguments[0]], arguments[1]));
            }
        }
    };

    var Argument = function(arg, args) {
        this.__arg  = arg;
        this.__args = args;
        this.__max_precision = parseFloat('1.'+ (new Array(32)).join('1'), 10).toString().length-3;
        this.__def_precision = 6;
        this.getString = function(){
            return this.__arg;
        };
        this.getKey = function(){
            return this.__arg.split(':')[0];
        };
        this.getFormat = function(){
            var match = this.getString().split(':');
            return (match && match[1])? match[1]: 's';
        };
        this.getPrecision = function(){
            var match = this.getFormat().match(/\.(\d+|\*)/g);
            if (!match) { return this.__def_precision; }
            else {
                match = match[0].slice(1);
                if (match != '*') { return parseInt(match, 10); }
                else if(strings.strConversion.__getType(this.__args) == 'array') {
                    return this.__args[1] && this.__args[0] || this.__def_precision;
                }
                else if(strings.strConversion.__getType(this.__args) == 'object') {
                    return this.__args[this.getKey()] && this.__args[this.getKey()][0] || this.__def_precision;
                }
                else { return this.__def_precision; }
            }
        };
        this.getPaddingLength = function(){
            var match = false;
            if (this.isAlternate()) {
                match = this.getString().match(/0?#0?(\d+)/);
                if (match && match[1]) { return parseInt(match[1], 10); }
            }
            match = this.getString().match(/(0|\.)(\d+|\*)/g);
            return match && parseInt(match[0].slice(1), 10) || 0;
        };
        this.getPaddingString = function(){
            var o = '';
            if (this.isAlternate()) { o = ' '; }
            // 0 take precedence on alternate format
            if (this.getFormat().match(/#0|0#|^0|\.\d+/)) { o = '0'; }
            return o;
        };
        this.getFlags = function(){
            var match = this.getString().matc(/^(0|\#|\-|\+|\s)+/);
            return match && match[0].split('') || [];
        };
        this.isAlternate = function() {
            return !!this.getFormat().match(/^0?#/);
        };
    };

    var arguments2Array = function(args, shift) {
        var o = [];
        for (l=args.length, x=(shift || 0)-1; x<l;x++) { o.push(args[x]); }
        return o;
    };
    $.extend(strings);
})(jQuery);
/*
  jQuery ui.dropslide - 0.4
  http://code.google.com/p/jquery-utils/

  (c) Maxime Haineault <haineault@gmail.com> 
  http://haineault.com

  MIT License (http://www.opensource.org/licenses/mit-license.php

*/

(function($) {
    $.widget('ui.dropslide', $.extend({}, $.ui.mouse, {
        getter: 'showLevel showNextLevel getSelection',
        _init: function() {
            var widget   = this;
            this.wrapper = this.element.next();

            this.element.bind(this.options.trigger +'.dropslide', function(){
                widget.show();
            });
            this.wrapper
                .data('dropslide', this)
                .css({width:this.options.width})
                .find('li, li ol li')
                    .bind('mouseover.dropslide', function(e){
                        $(this).siblings().removeClass('hover')
                            .find('ol').hide().end()
                            .find('span').removeClass('ui-state-hover').end();
                        $(this).find('ol').show().end().addClass('hover').children(0).addClass('ui-state-hover');
                        widget.showNextLevel();
                    })
                   .bind('click.dropslide', function(e){
                        $(widget.element).triggerHandler('dropslideclick', [e, widget], widget.options.click); 
                        $(widget.element).triggerHandler('select', [e, widget], widget.options.select); 
                    }).end()
                .find('ol')
                    .bind('mousemove.dropslide', function(e){
                       return widget._redraw();
                    })
                   .addClass('ui-widget ui-helper-clearfix ui-helper-reset')
                   .hide().end()
                .find('span').addClass('ui-state-default ui-corner-all');

            this._redraw();
        },

        // show specified level, id is the DOM position
        showLevel: function(id) {
            var ols = this.wrapper.find('ol');
            var ds  = this;
            if (id == 0) {            
                ols.eq(0).css('left', this.element.position().left);
                this.wrapper.css('top', ds.element.position().top + ds.element.height() + ds.options.top);
                this.wrapper.css('z-index', 1000);
            }
            setTimeout(function() {
                ols.removeClass('active').eq(id).addClass('active').show(ds.options.animSpeed);
            }, ds.options.showDelay);
        },

        // guess what it does
        showNextLevel: function() {
            this.wrapper.find('ol.active')
                .removeClass('active')
                .next('ol').addClass('active').show(this.options.animSpeed);
        },

        getSelection: function(level) {
            return level 
                    && this.wrapper.find('ol').eq(level).find('li span.ui-state-hover')
                    || $.makeArray(this.wrapper.find('span.ui-state-hover').map($.iterators.getText));
        },

        // essentially reposition each ol
        _redraw: function() {
            var prevLI ,prevOL, nextOL, pos = false;
            var offset = this.element.position().left + this.options.left;
            var ols    = $(this.wrapper).find('ol');

            $(this.wrapper).css({
                top: this.element.position().top + this.element.height() + this.options.top,
                left: this.element.position().left
            });
            
            // reposition each ol
            ols.each(function(i) {
                prevOL = $(this).prevAll('ol:visible:first');
                if (prevOL.get(0)) {
                    prevLI = prevOL.find('li.hover').get(0) && prevOL.find('li.hover') || prevOL.find('li:first');
                    $(this).css('margin-left', prevLI.position().left);
                }
            });
        },

        // show level 0 (shortcut)
        show: function(e) {
            this.showLevel(0);
        },

        // hide all levels
        hide: function() {
            var widget = this;
            setTimeout(function() {
                widget.wrapper.find('ol').hide();
            }, widget.options.hideDelay);
        },

        activate: function(e) {
            this.element.focus();
            this.show(this.options.animSpeed);
        },
                  
        destroy: function(e) {
            this.wrapper.remove();
        }
    }));

    $.ui.dropslide.defaults = {
        // options
        tree:      false,
        trigger:   'mouseover',
        top:       6,
        left:      0,
        showDelay: 0,
        hideDelay: 0,
        animSpeed: 0,
        // events
        select:  function() {},
        click:   function(e, ui) { ui.hide(); }
    };
})(jQuery);
/*
  jQuery ui.timepickr - 0.6.6
  http://code.google.com/p/jquery-utils/

  (c) Maxime Haineault <haineault@gmail.com> 
  http://haineault.com

  MIT License (http://www.opensource.org/licenses/mit-license.php

  Note: if you want the original experimental plugin checkout the rev 224 

  Dependencies
  ------------
  - jquery.utils.js
  - jquery.strings.js
  - jquery.ui.js
  - ui.dropslide.js
  
*/

(function($) {
    $.tpl('timepickr.menu',   '<span class="ui-helper-reset ui-dropslide ui-timepickr ui-widget" />');
    $.tpl('timepickr.row',    '<ol class="ui-timepickr" />');
    $.tpl('timepickr.button', '<li class="{className:s}"><span>{label:s}</span></li>');

    $.widget('ui.timepickr', {
        _init: function() {
            var ui = this;
            var menu = ui._buildMenu();
            var element = ui.element;
            element.data('timepickr.initialValue', element.val());
            menu.insertAfter(ui.element);
            element
                .addClass('ui-timepickr')
                .dropslide(ui.options.dropslide)
                .bind('select', ui.select);
            
            element.blur(function(e) {
                $(this).dropslide('hide');
                if (ui.options.resetOnBlur) {
                    $(this).val($(this).data('timepickr.initialValue'));
                }
            });

            if (ui.options.val) {
                element.val(this.options.val);
            }

            if (ui.options.handle) {
                $(this.options.handle).click(function() {
                    $(element).dropslide('show');
                });
            }

            if (ui.options.resetOnBlur) {
                menu.find('li > span').bind('mousedown.timepickr', function(){
                    $(element).data('timepickr.initialValue', $(element).val()); 
                });
            }
            if (ui.options.updateLive) {
                menu.find('li').bind('mouseover.timepickr', function() {
                    $(element).timepickr('update'); 
                });
            }
            var hrs = menu.find('ol:eq(1)').find('li:first').addClass('hover').find('span').addClass('ui-state-hover').end().end();
            var min = menu.find('ol:eq(2)').find('li:first').addClass('hover').find('span').addClass('ui-state-hover').end().end();
            var sec = menu.find('ol:eq(3)').find('li:first').addClass('hover').find('span').addClass('ui-state-hover').end().end();

            if (this.options.convention === 24) {
                var day        = menu.find('ol:eq(0) li:eq(0)');
                var night      = menu.find('ol:eq(0) li:eq(1)');
                var dayHours   = hrs.find('li').slice(0, 12);
                var nightHours = hrs.find('li').slice(12, 24);
                var index      = 0;
                var selectHr   = function(id) {
                    hrs.find('li').removeClass('hover');
                    hrs.find('span').removeClass('ui-state-hover');
                    hrs.find('li').eq(id).addClass('hover').find('span').addClass('ui-state-hover')
                };

                day.mouseover(function() {
                    nightHours.hide();
                    dayHours.show(0);
                    index = hrs.find('li.hover').data('id') || hrs.find('li:first').data('id');
                    selectHr(index > 11 && index - 12 || index);
                    element.dropslide('redraw');
                });

                night.mouseover(function() {
                    dayHours.hide();
                    nightHours.show(0);
                    index = hrs.find('li.hover').data('id') || hrs.find('li:first').data('id');
                    selectHr(index < 12 && index + 12 || index);
                    element.dropslide('redraw');
                });
            }
            element.dropslide('redraw');
            element.data('timepickr', this);
        },

        update: function() {
            var frmt = this.options.convention === 24 && 'format24' || 'format12';
            var val = {
                h: this.getValue('hour'),
                m: this.getValue('minute'),
                s: this.getValue('second'),
                prefix: this.getValue('prefix'),
                suffix: this.getValue('suffix')
            };
            var o = $.format(this.options[frmt], val);

            $(this.element).val(o);
        },

        select: function(e) {
            var dropslide = $(this).data('dropslide');
            $(dropslide.element).timepickr('update');
            e.stopPropagation();
        },

        getHour: function() {
            return this.getValue('hour');
        },

        getMinute: function() {
            return this.getValue('minute');
        },

        getSecond: function() {
            return this.getValue('second');
        },

        getValue: function(type) {
            return $('.ui-timepickr.'+ type +'.hover', this.element.next()).text();
        },
        
        activate: function() {
            this.element.dropslide('activate');
        },

        destroy: function() {
            this.element.dropslide('destroy');
        },
        
        /* UI private methods */
        
        _createButton: function(i, format, className) {
            var o  = format && $.format(format, i) || i;
            var cn = className && 'ui-timepickr '+ className || 'ui-timepickr';
            return $.tpl('timepickr.button', {className: cn, label: o}).data('id', i);
        },

        _createRow: function(range, format, className) {
            var row = $.tpl('timepickr.row');
            var button = this._createButton;
            // Thanks to Christoph Müller-Spengler for the bug report
            $.each(range, function(idx, val){
                row.append(button(val, format || false, className || false));
            });
            return row;
        },
        
        _getRanges12: function() {
            var o = [], opt = this.options;
            if (opt.hours)   { o.push(this._createRow($.range(1, 13), '{0:0.2d}', 'hour')); }
            if (opt.minutes) { o.push(this._createRow(opt.rangeMin,   '{0:0.2d}', 'minute')); }
            if (opt.seconds) { o.push(this._createRow(opt.rangeSec,   '{0:0.2d}', 'second')); }
            if (opt.suffix)  { o.push(this._createRow(opt.suffix,     false,      'suffix')); }
            return o;
        },

        _getRanges24: function() {
            var o = [], opt = this.options;
            o.push(this._createRow(opt.prefix, false, 'prefix')); // prefix is required in 24h mode
            if (opt.hours)   { o.push(this._createRow($.range(0, 24),   '{0:0.2d}', 'hour')); }
            if (opt.minutes) { o.push(this._createRow(opt.rangeMin, '{0:0.2d}', 'minute')); }
            if (opt.seconds) { o.push(this._createRow(opt.rangeSec, '{0:0.2d}', 'second')); }
            return o;
        },

        _buildMenu: function() {
            var menu   = $.tpl('timepickr.menu');
            var ranges = this.options.convention === 24 
                         && this._getRanges24() || this._getRanges12();

            $.each(ranges, function(idx, val){
                menu.append(val);
            });
            return menu;
        }
    });

    // These properties are shared accross every instances of timepickr 
    $.extend($.ui.timepickr, {
        version:     '0.6.6',
        eventPrefix: '',
        getter:      '',
        defaults:    {
            convention:  24, // 24, 12
            dropslide:   { trigger: 'focus' },
            format12:    '{h:02.d}:{m:02.d} {suffix:s}',
            format24:    '{h:02.d}:{m:02.d}',
            handle:      false,
            hours:       true,
            minutes:     true,
            seconds:     false,
            prefix:      ['am', 'pm'],
            suffix:      ['am', 'pm'],
            rangeMin:    $.range(0, 60, 15),
            rangeSec:    $.range(0, 60, 15),
            updateLive:  true,
            resetOnBlur: true,
            val:         false
        }
    });

})(jQuery);
