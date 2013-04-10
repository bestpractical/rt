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
