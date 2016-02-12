%# BEGIN BPS TAGGED BLOCK {{{
%#
%# COPYRIGHT:
%#
%# This software is Copyright (c) 1996-2016 Best Practical Solutions, LLC
%#                                          <sales@bestpractical.com>
%#
%# (Except where explicitly superseded by other copyright notices)
%#
%#
%# LICENSE:
%#
%# This work is made available to you under the terms of Version 2 of
%# the GNU General Public License. A copy of that license should have
%# been provided with this software, but in any event can be snarfed
%# from www.gnu.org.
%#
%# This work is distributed in the hope that it will be useful, but
%# WITHOUT ANY WARRANTY; without even the implied warranty of
%# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
%# General Public License for more details.
%#
%# You should have received a copy of the GNU General Public License
%# along with this program; if not, write to the Free Software
%# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
%# 02110-1301 or visit their web page on the internet at
%# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
%#
%#
%# CONTRIBUTION SUBMISSION POLICY:
%#
%# (The following paragraph is not intended to limit the rights granted
%# to you to modify and distribute this software under the terms of
%# the GNU General Public License and is only of importance to you if
%# you choose to contribute your changes and enhancements to the
%# community by submitting them to Best Practical Solutions, LLC.)
%#
%# By intentionally submitting any modifications, corrections or
%# derivatives to this work, or any other work intended for use with
%# Request Tracker, to Best Practical Solutions, LLC, you confirm that
%# you are the copyright holder for those contributions and you grant
%# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
%# royalty-free, perpetual, license to use, copy, create derivative
%# works based on those contributions, and sublicense and distribute
%# those contributions and any derivatives thereof.
%#
%# END BPS TAGGED BLOCK }}}
(function($){
    $.datepicker._newInst_orig = $.datepicker._newInst;
    $.datepicker._newInst = function(target, inline) {
        var data = this._newInst_orig(target, inline);

        // Escape single quotes to avoid incorrect quoting in onclick handlers
        // when other datepicker code interpolates inst.id.  They'll already be
        // escaped by the original _newInst for handing to jQuery's CSS
        // selector parser.
        data.id = data.id.replace(/'/g, "\\'");

        return data;
    };

    $.datepicker._checkOffset_orig = $.datepicker._checkOffset;
    $.datepicker._checkOffset = function(inst, offset, isFixed) {
        // copied from the original
        var dpHeight    = inst.dpDiv.outerHeight();
        var inputHeight = inst.input ? inst.input.outerHeight() : 0;
        var viewHeight  = document.documentElement.clientHeight + $(document).scrollTop();

        // save the original offset rather than the new offset because the
        // original function modifies the passed arg as a side-effect
        var old_offset = { top: offset.top, left: offset.left };
        offset = $.datepicker._checkOffset_orig(inst, offset, isFixed);

        // Negate any up or down positioning by adding instead of subtracting
        offset.top += Math.min(old_offset.top, (old_offset.top + dpHeight > viewHeight && viewHeight > dpHeight) ?
            Math.abs(dpHeight + inputHeight) : 0);

        return offset;
    };


    $.timepicker._newInst_orig = $.timepicker._newInst;
    $.timepicker._newInst = function($input, o) {
        var tp_inst = $.timepicker._newInst_orig($input, o);
        tp_inst._defaults.onClose = function(dateText, dp_inst) {
	    if ($.isFunction(o.onClose))
		o.onClose.call($input[0], dateText, dp_inst, tp_inst);
        };
        return tp_inst;
    };

})(jQuery);
