RuleBuilder = function (sel, cb) {
    this.sel = sel;
    /* defaults for now, should use ajax query */
    this.expressions = RuleBuilder.expressions;

    var that = this;
    jQuery.get('/rulebuilder/allfunctions.json', {},
               function(response, status) {
                   that.functions = response;
                   that.init();
                   if (cb)
                       cb.apply(that);
               },
               'json'); // XXX: handle errors.
};

RuleBuilder.expressions = [
    { expression: 'ticket',
      type: 'RT::Model::Ticket'
    },
    { expression: 'transaction',
      type: 'RT::Model::Transaction'
    }
];

RuleBuilder.load_and_edit_lambda = function (params, return_type, el) {
    var lambda_text = jQuery(el).prev('textarea').text();
    jQuery.post('/rulebuilder/parse_lambda.json', { lambda_text: lambda_text },
               function(response, status) {
                   new RuleBuilder("#expressionbuilder",
                                   function () {
                                       this.load_expressions(response, this.top_context);
                                   });
               },
               'json'); // XXX: handle errors.
};

RuleBuilder.prototype.load_expressions = function (node, ctx) {
    if (node.type == 'application') {
        var func_name = node.operator.name; // XXX: ensure operator of
                                            // type: variable
        ctx.set_application(func_name, this.functions[func_name]);
        for (var i in ctx.children) {
            this.load_expressions(node.operands[i], ctx.children[i]);
        }
    }
    else if (node.type == 'variable') {
        var expressions = jQuery.grep(this.expressions, function(val) { return val.expression == node.name });
        ctx.set_expression(expressions[0]);
    }
    else if (node.type == 'self_evaluating') {
        jQuery._input_({ 'type': 'text', 'class': 'enter-value', 'value': node.value})
            .change(function() { ctx.update_return_type(ctx.return_type_from_val(this.value)) } )
            .appendTo(ctx.element).trigger('focus');
        ctx.self_eval = true;

    }
    else {
        console.log('unknown node type');
    }
}

RuleBuilder.prototype.init = function () {
    var sel = this.sel;
    var ebuilder = jQuery(sel);
    var that = this;

    this.ebuilder = ebuilder;

    jQuery._div_({'class': 'context top-context'})
        .appendTo(ebuilder);

    this.top_context = new RuleBuilder.Context(
        'Bool',
        jQuery(".top-context").get(0),
        null,
        this
    );

    ebuilder.append('<div class="library">');

    jQuery('.library').append('<div class="expressions">');
    jQuery('.library').append('<div class="functions">');
    this.update_expressions();

    functions_div = jQuery('.functions');
    functions_div.append('<h3>Functions</h3>');
    jQuery.each(this.functions,
                function(key, val) {
                    functions_div.append('<div class="function ret_'+val.return_type+'"> <span class="return-type">'+val.return_type+'</span> <span class="function-name">'+key+'</span>'+render_signature(val.parameters).html() +'</div>');
                });

    jQuery(this.sel+' div.function').click(
        function(e) {
            var func_name = jQuery('span.function-name', this).text();
            that.push_application(func_name);
        });

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

    this.focus(this.top_context);

    jQuery._div_({'class': 'ohai'})
        .text("OH HAI")
        .click(function(e){
            that.top_context.traverse(function(ctx) {
                jQuery(ctx.element).append(ctx.state());
            });
            alert(that.top_context.serialize())})
        .prependTo(ebuilder);

};

RuleBuilder.prototype.push_application = function(func_name) {
    this.current_ctx.set_application(func_name, this.functions[func_name]);
};


RuleBuilder.prototype.push_expression = function(expression) {
    this.current_ctx.set_expression(expression);
};

RuleBuilder.prototype.focus = function(ctx) {
    if( this.current_ctx )
        jQuery(this.current_ctx.element).removeClass('current');

    this.current_ctx = ctx;
    jQuery(this.current_ctx.element).addClass('current');
    var type = this.current_ctx.expected_type;
    jQuery('.functions .function', this.ebuilder).removeClass('matched')
                                                     .addClass('unmatched');

    jQuery('.expressions .expression', this.ebuilder).removeClass('matched')
                                                   .addClass('unmatched');

    jQuery('.functions .function .return-type:contains('+type+')', this.ebuilder)
    .parent().removeClass('unmatched').addClass('matched');

    jQuery('.expressions .expression .return-type:contains('+type+')', this.ebuilder)
    .parent().removeClass('unmatched').addClass('matched');
};

RuleBuilder.prototype.update_expressions = function() {
    var sel = this.sel;
    var ebuilder = jQuery(sel);
    var that = this;

    var expressions_div = jQuery('div.expressions', ebuilder);
	expressions_div.html('<h3>Current Expressions</h3>');


    jQuery.each(this.expressions,
                function(idx, val) {
                    jQuery._div({'class': 'expression ret_'+val.type})
                            ._span_({ 'class': 'return-type' }).text(val.type)
                            ._span_({ 'class': 'expression-text' }).text(val.expression)
                          .div_().click(function(e) {
                              that.push_expression(val);
                          })
                    .appendTo(expressions_div);
                });

    this.model_accessors = {};
    this.build_accessor_menu('RT::Model::Queue');
    this.build_accessor_menu('RT::Model::Ticket');
    this.build_accessor_menu('RT::Model::Transaction');
}

RuleBuilder.prototype.build_accessor_menu = function(model) {
    var that = this;

    var options = {
        onClick: function(e,item) {
            that.push_expression({ expression: "("+item.data.func+" "+item.data.expression+")",
                                   type: item.data.type });
            jQuery.Menu.closeAll();
            return false;
        },
        minWidth: 120,
        arrowSrc: '/images/arrow_right.gif',
        hoverOpenDelay: 500,
        hideDelay: 500 };

    var re = new RegExp('^'+model+'\.');
    jQuery.get('/rulebuilder/getfunctions.json',
               { parameters: [model] },
               function(response, status) {
                   var entries = [];
                   for (var name in response) {
                       if (name.match(re))
                           entries.push(name);
                   }
                   that.model_accessors[model] = entries;
                   jQuery('.ret_'+e_sel(model), that.ebuilder)
                   .each(function() {
                       var expression = jQuery('span.expression-text',this).text();
                       jQuery._span_({ 'class': 'launch-menu'} ).text('...')
                       .appendTo(this)
                       .menu(options,
                             jQuery.map(entries,
                                        function(val) {
                                            return that.map_accessor_menu_entry(model, val, expression, true);
                                        }
                                       ))
                   });
               },
               'json');
};

RuleBuilder.prototype.map_accessor_menu_entry = function (model, func_name, expression, want_submenu) {
    var re = new RegExp('^'+model+'\.');
    var attribute = func_name.replace(re, '');
    var type = this.functions[func_name].return_type;
    var submenu = null;
    attribute += ' <span class="return-type">'+type+'</span>';

    var that = this;
    if (want_submenu && that.model_accessors[type]) {
        submenu = jQuery.map(that.model_accessors[type],
                             function(val) {
                                 return that.map_accessor_menu_entry(type, val,
                                                                     "("+func_name+" "+expression+")" );
                             });
    }

    return {src: attribute,
            subMenu: submenu,
            data: { type: type, expression: expression, func: func_name } };
};

RuleBuilder.prototype.add_expression = function () {
    var params = jQuery.map(
        jQuery(".application-params span.param"),
        function(elt) { return elt.textContent });

    // XXX: later

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


RuleBuilder.Context = function(expected_type, element, parent, rb) {
    this.expected_type = expected_type;
    this.element = element;
    this.parent = parent;
    this.rb = rb;

    var that = this;
    jQuery(this.element).click(function(e) { rb.focus(that); return false });
    jQuery._span_({ 'class': 'return-type'})
          .text(expected_type)
          .appendTo(this.element);

    if (expected_type == 'Str' || expected_type == 'Num') { // self-evaluating
        jQuery._span_({ 'class': 'enter-value' })
          .text("Enter a value")
          .click(function(e) {
              jQuery(this).html('').unbind('click');
              jQuery._input_({ 'type': 'text', class: 'enter-value'})
                  .change(function() { that.update_return_type(that.return_type_from_val(this.value)) } )
                  .appendTo(this).trigger('focus');
              that.self_eval = true;
              return true;
          })
          .appendTo(this.element);
    }
};

RuleBuilder.Context.prototype.return_type_from_val = function(val) {
    // XXX
    return 'Str';
}

RuleBuilder.Context.prototype.transform = function(func_name) {
    if (this.parent) {
        alert('not yet');
    }
    else {
        var rb = this.rb;
        var func = rb.functions[func_name];
        jQuery(rb.top_context.element).removeClass('top-context').remove();
        var tc = jQuery._div_({'class': 'context top-context'})
            .prependTo(this.rb.ebuilder);

        var parent = new RuleBuilder.Context(this.expected_type,
                                             tc.get(0), null, rb);
        parent.set_application(func_name, func);
        this.parent = rb.top_context = parent;

        jQuery(this.element).unbind('click');
        var first_param = parent.children[0];
        var second_param = parent.children.length > 1 ? parent.children[1] : null;
        parent.children[0] = this;
        this.expected_type = first_param.expected_type;
        jQuery('span.return-type:first', this.element)
            .text(first_param.expected_type);
        jQuery(first_param.element).replaceWith(this.element);
        var that = this;
        jQuery(this.element).click(function(e) { rb.focus(that); return false });
        this.update_return_type(this.return_type);
        if (second_param)
            this.rb.focus(second_param);
    }
}

RuleBuilder.Context.prototype.transformMenu = function(el) {
    // this.return_type -> this.expected_type
    var that = this;
    var options = {
        onClick: function(e,item) {
            jQuery.Menu.closeAll();
            that.transform(item.src);
            return false;
        },
        minWidth: 120,
        arrowSrc: '/images/arrow_right.gif',
        hoverOpenDelay: 500,
        hideDelay: 500 };

    jQuery.get('/rulebuilder/getfunctions.json',
               { parameters: [ this.return_type ],
                 return_type: this.expected_type },
               function(response, status) {
                   var entries = [];
                   for (var name in response) {
                       entries.push(name);
                   }

                   jQuery(el)
                   .menu(options,
                         jQuery.map(entries,
                                    function(val) {
                                        return {src: val, data: {  } }}
                                       ));
               },
               'json');

}

RuleBuilder.Context.prototype.state = function() {
    if( this.self_eval ) {
    }
    else if ( this.expression ) {
    }
    else if ( this.func_name ) {
        var type_complete = false;
        console.log(this.children);
        for (var i in this.children) {
            var child = this.children[i];
            console.log(i);
            console.log(this.children[i]);
            var state = child.state();
            if (state == 'pending')
                return 'pending';
            if (state == 'type-complete')
                type_complete = true;
        }
        if (!type_complete)
            return "complete";
    }
    else {
        return 'pending';
    }

    var el = jQuery("span.return-type", this.element);
    return el.hasClass('matched') ? 'type-complete' : 'complete';
}

RuleBuilder.Context.prototype.update_return_type = function(type) {
    // XXX: this should query the server for 'is-a-type-of'
    this.return_type = type;
    var el = jQuery("span.return-type", this.element);
    if (this.expected_type == type) {
        el.removeClass("unmatched").addClass("matched");
    }
    else {
        el.removeClass("matched").addClass("unmatched");
        this.transformMenu(el);
    }
}

RuleBuilder.Context.prototype.clear = function() {
    jQuery('div.application', this.element).remove();
    jQuery('span.expression', this.element).remove();
    jQuery('span.transform', this.element).hide();
    jQuery('span.enter-value', this.element).hide();
    this.self_eval = false;
    this.expression = null;
    this.func_name = null;
}

RuleBuilder.Context.prototype.traverse = function(fn) {
    fn(this);
    if ( this.func_name ) {
        jQuery.each(this.children, function(idx, val) { fn(this) } );
    }
}

RuleBuilder.Context.prototype.serialize = function() {
    if( this.self_eval ) {
        var val = jQuery('input.enter-value', this.element).val();
        if (this.expected_type == 'Str') {
            return '"'+val+'"';
        }
        else {
            return val;
        }
    }
    else if ( this.expression ) {
        return this.expression;
    }
    else if ( this.func_name ) {
        var args = jQuery.map(this.children, function(val) { return val.serialize() });
        args.unshift(this.func_name);
        return '('+args.join(' ')+')';
    }
}

RuleBuilder.Context.prototype.set_expression = function(expression) {
    this.clear();
    this.expression = expression.expression;
    this.update_return_type(expression.type);
    jQuery('span.transform', this.element).show();

    jQuery._span_({ 'class': 'expression'})
          .text(this.expression)
          .appendTo(this.element);
}



RuleBuilder.Context.prototype.set_application = function(func_name, func) {
    this.clear();
    this.func_name = func_name;
    this.children = [];
    this.update_return_type(func.return_type);
    jQuery('span.transform', this.element).show();
    jQuery._div({'class': 'application'})
            ._div_({'class': 'application-function function'})
           ._div_({'class': 'application-params signature'})
          .div_()
        .appendTo(this.element);

    jQuery('div.application-function',this.element).html(func_name);
    jQuery('div.application', this.element).show();
    jQuery('div.application-params', this.element).html('');
    var params = jQuery('div.application-params', this.element);
    var that = this;
    jQuery.each(func.parameters,
                function(idx, val) {
                    var x = jQuery._div_({'class': 'context'})
                    .appendTo(params);

                    var child = new RuleBuilder.Context(val.type, x.get(0), that, that.rb);
                    that.children.push(child);
                });
    if (this.children.length) {
        this.rb.focus(this.children[0]);
    }
};

jQuery.fn.sort = function() {
    return this.pushStack( [].sort.apply( this, arguments ), []);
};

function sortAlpha(a,b){
     return a.innerHTML > b.innerHTML ? 1 : -1;
};

