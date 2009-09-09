RuleBuilder = function (sel) {
    this.sel = sel;
    /* defaults for now, should use ajax query */
    this.expressions = RuleBuilder.expressions;

    this.current_application = null;

    var that = this;
    jQuery.get('/rulebuilder/allfunctions.json', {},
               function(response, status) {
                   that.functions = response;
                   that.init();
               },
               'json'); // handle errors.
};

RuleBuilder.expressions = [
    { expression: 'ticket',
      type: 'RT::Model::Ticket'
    },
    { expression: 'transaction',
      type: 'RT::Model::Transaction'
    }
];

RuleBuilder.prototype.init = function () {
    var sel = this.sel;
    var ebuilder = jQuery(sel);
    var that = this;

    jQuery._div({'class': 'application'})
            ._h3_().text("New Expression")
            ._div_({'class': 'application-function function'})
           ._div_({'class': 'application-params signature'})
          .div_()
        .appendTo(ebuilder);

    jQuery("#add-expression")
		.appendTo(jQuery(".application"));


    this.update_expressions();

    ebuilder.append('<div class="functions">');

    functions_div = jQuery('.functions');
    functions_div.append('<h3>Functions</h3>');
    jQuery.each(this.functions,
                function(key, val) {
                    functions_div.append('<div class="function ret_'+val.return_type+'"> <span class="return-type">'+val.return_type+'</span> <span class="function-name">'+key+'</span>'+render_signature(val.parameters).html() +'</div>');
                });

    jQuery(this.sel+' div.function').click(
        function(e) {
            var func_name = jQuery('span.function-name', this).text();
            that.current_application = func_name;
            that.update_application();
        });
//    jQuery(this.sel+' div.application').hide();
	function render_signature(sig) {
			var content = jQuery._span_({'class': 'outer node we should not need but createdomnodes is broken'});
			if (!sig) 
					return content.append()._div_({ 'class': 'signature empty'});

			var innercontent = content.append()._div_({ 'class': 'signature'});

			jQuery.map(sig,
					function (item) {
					name = item.name;
					type = item.type;
						innercontent.append(content._div({class: 'parameter'})._span_({ 'class': 'name'}).text(name)
						._span_({ 'class': 'type'}).text(type).div_());
						
					});
			return content;
	}
};

RuleBuilder.prototype.update_expressions = function() {
    var sel = this.sel;
    var ebuilder = jQuery(sel);
    var that = this;

    jQuery('div.expressions', ebuilder).remove();

    jQuery._div({'class': 'expressions'})
            ._h3_().text("Current Expressions")
          .div_()
        .prependTo(ebuilder);

    var expressions_div = jQuery('div.expressions', ebuilder);

    jQuery.each(this.expressions,
                function(idx, val) {
                    jQuery._div({'class': 'expression ret_'+val.type})
                            ._span_({ 'class': 'type' }).text(val.type)
                            ._span_({ 'class': 'expression-text' }).text(val.expression)
                          .div_().click(function(e) {
                        if (that.current_application_param != null) {
                            if (val.type != 
                                that.functions[that.current_application].parameters[that.current_application_param].type) {
                                alert("type mismatch: "+val.type+" vs "+that.functions[that.current_application].parameters[that.current_application_param].type);
                                return;
                            }
                            jQuery(that.sel+ ' .param:eq('+parseInt(idx)+')').removeClass('param-placeholder').text(val.expression);
                        }
                        else {
                            alert("must select param first");
                        }
                          })
                    .appendTo(expressions_div);
                });

    var options = {
        onClick: function(e,item) { x=e;y=item },
        minWidth: 120,
        arrowSrc: '/images/arrow_right.gif',
        hoverOpenDelay: 500,
        hideDelay: 500 };

    var items = [   {src: 'test' },
        {src: ''}, /* separator */
        {src: 'test2', subMenu: [   {src: 'sub 1'},
                                    {src: 'sub 2' },
                                    {src: 'sub 3'}]}];
    jQuery('.ret_'+e_sel('RT::Model::Ticket')).menu(options, items);
};


RuleBuilder.prototype.update_application = function () {
    /* might be an expression too */
    jQuery(this.sel+' div.application-function').html(this.current_application);
    jQuery(this.sel+' div.application').show();
    jQuery(this.sel+' div.application-params').html('');
    var params = jQuery(this.sel+' div.application-params');
    var that = this;
    jQuery.each(this.functions[this.current_application].parameters,
                function(idx, val) {
                    params.append('<span class="param param-placeholder">'+val.type+'</span> ').children(':last-child')
         .click(function(e) {
             jQuery(that.sel+ ' .param-placeholder').removeClass('current');
             jQuery(this).addClass('current');
             that.filter_expression_type(jQuery(this).text());
             that.current_application_param = idx; });
                });
};

RuleBuilder.prototype.add_expression = function () {
    var params = jQuery.map(
        jQuery(".application-params span.param"),
        function(elt) { return elt.textContent });
  
    params.unshift(this.current_application);
    var expression = {
        expression: '('+params.join(' ')+')',
        type: this.functions[this.current_application].return_type
    };

    this.expressions.push(expression);
    this.update_expressions();
}

var e_sel = function(sel) {
    return sel.replace(/:/g, '\\\\\\:');
};

var e_jquery = function(sel) {
    return jQuery(e_sel(sel));
};

RuleBuilder.prototype.unfilter_return_type = function () {
    jQuery(this.sel+' .function').show();
};

RuleBuilder.prototype.filter_return_type = function (type) {
    jQuery(this.sel+' .function').show();
    jQuery(this.sel+' .function').not(e_sel('.ret_'+type)).hide();
};

RuleBuilder.prototype.filter_expression_type = function (type) {
    jQuery(this.sel+' .expression').show();
    jQuery(this.sel+' .expression:not(.ret_'+e_sel(type)+')').hide();
};

