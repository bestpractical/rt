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
})(jQuery);
