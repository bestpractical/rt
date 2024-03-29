/*
 * Supposition v0.3a - an optional enhancer for Superfish jQuery menu widget
 *
 * Copyright (c) 2013 Joel Birch - based on work by Jesse Klaasse - credit goes largely to him.
 * Special thanks to Karl Swedberg for valuable input.
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 * 	http://www.gnu.org/licenses/gpl.html
 */

;(function($){

	$.fn.supposition = function(){
		var $w = $(window),/*do this once instead of every onBeforeShow call*/
			$topNav, 
			_offset = function(dir) {
				return window[dir === 'y' ? 'pageYOffset' : 'pageXOffset'] || 
					document.documentElement && document.documentElement[dir==='y' ? 'scrollTop' : 'scrollLeft'] || 
					document.body[dir==='y' ? 'scrollTop' : 'scrollLeft'];
			},
			onInit = function(){
				/* I haven't touched this bit - needs work as there are still z-index issues */
				$topNav = $('li',this);
				var cZ=parseInt($topNav.css('z-index')) + $topNav.length;
				$topNav.each(function() {
					$(this).css({zIndex:--cZ});
				});
			},
			onHide = function(){
				this.css({marginTop:'',marginLeft:''});
			},
			onBeforeShow = function(){
				this.each(function(){
					var $u = $(this);
					var old_display = $u.css('display');
					$u.css('display','block');
					var tolerance = 0.1; // make following conditions more tolerant to get rid of the precision issue.

					var menuWidth = $u.width(),
						parentWidth = $u.parents('ul').width(),
						totalRight = $w.width() + _offset('x'),
						menuRight = $u.offset().left + menuWidth;

					if (menuRight > totalRight + tolerance) {
						$u.css('margin-left', ($u.parents('ul').length === 1 ? totalRight - menuRight : -(menuWidth + parentWidth)) + 'px');
					}

					var windowHeight = $w.height(),
						offsetTop = $u.offset().top,
						menuHeight = $u.height(),
						baseline = windowHeight + _offset('y');
					var expandUp = (offsetTop + menuHeight > baseline + tolerance);
					if (expandUp) {
						$u.css('margin-top',baseline - (menuHeight + offsetTop));
					}
					$u.css('display', old_display);
				});
			};
		
		return this.each(function() {
			var $this = $(this),
				o = $this.data('sf-options'); /* get this menu's options */
			
			/* if callbacks already set, store them */
			var _onInit = o.onInit,
				_onBeforeShow = o.onBeforeShow,
				_onHide = o.onHide;
				
			$.extend($this.data('sf-options'),{
				onInit: function() {
					onInit.call(this); /* fire our Supposition callback */
					_onInit.call(this); /* fire stored callbacks */
				},
				onBeforeShow: function() {
					onBeforeShow.call(this); /* fire our Supposition callback */
					_onBeforeShow.call(this); /* fire stored callbacks */
				},
				onHide: function() {
					onHide.call(this); /* fire our Supposition callback */
					_onHide.call(this); /* fire stored callbacks */
				}
			});
		});
	};

})(jQuery);