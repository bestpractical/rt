RuleBuilder = function (sel, expressions, cb) {
    this.sel = sel;
    /* defaults for now, should use ajax query */
    if (expressions)
        this.expressions = expressions;
    else
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
    var lambda_text = jQuery(el).prev('textarea').val();
    jQuery.post('/rulebuilder/parse_lambda.json', { lambda_text: lambda_text },
               function(response, status) {
                   var rb = new RuleBuilder("#expressionbuilder",
                                            params,
                                            function () {
                                                this.load_expressions(response.body, this.top_context);
                                            });
                   rb.finalize = function() {
                       var body = this.top_context.serialize();
                       var lambda = '(lambda ('
                           +jQuery.map(params,
                                       function(val) { return val.expression }).join(" ")+') '
                           +body+')';
                       jQuery(el).prev('textarea').text(lambda);
                       this.ebuilder.html('');
                   };
               },
               'json'); // XXX: handle errors.
};

RuleBuilder.prototype.load_expressions = function (node, ctx) {
    if (node.type == 'application') {
        var func_name = node.operator.name; // XXX: ensure operator of
                                            // type: variable
        ctx.set_application(func_name, this.functions[func_name]);

        var operands = node.operands;
        if (operands instanceof Array) {
            for (var i in ctx.children) {
                var childctx = ctx.children[i];
                // XXX: make arraybuilder proper ctx subclass and provide methods for the following manipulation
                if (childctx.inner_type) {
                    jQuery('span.arraybuilder-icon', childctx.element)
                        .trigger('click');
                    this.load_expressions(node.operands[i], childctx.children[0]);
                    for (var j = parseInt(i)+1; j < node.operands.length; ++j) {
                        var newchild = childctx.mk_array_item_context(childctx.inner_type,
                                                                      jQuery('div.array-item-container', childctx.arraybuilder), childctx.children[childctx.children.length-1].element);
                        childctx.children.push(newchild);
                        this.load_expressions(node.operands[j], newchild);
                    }
                }
                else
                    this.load_expressions(node.operands[i], childctx);
            }
        }
        else {
            var names = jQuery.map(this.functions[func_name].parameters,
                                   function(param) { return param.name });
            for (var i in ctx.children) {
                this.load_expressions(node.operands[names[i]], ctx.children[i]);
            }
        }
    }
    else if (node.type == 'variable') {
        var expressions = jQuery.grep(this.expressions, function(val) { return val.expression == node.name });
        ctx.set_expression(expressions[0]);
    }
    else if (node.type == 'self_evaluating') {
        jQuery('span.enter-value', ctx.element).hide();
        ctx.expcontext = new RuleBuilder2.SelfEvalContext( { context: ctx } );
        ctx.expcontext.set_value(node.value);
    }
    else {
        alert('unknown node type');
    }
}


RuleBuilder.prototype.init = function () {
    var sel = this.sel;
    var ebuilder = jQuery(sel);
    var that = this;

    this.ebuilder = ebuilder;

	ebuilder.append('<div class="panel">');
	this.panel = jQuery('.panel');

    jQuery._div_({'class': 'context top-context'})
        .appendTo(this.panel);

    this.top_context = new RuleBuilder2.Context(
        { expected_type: 'Bool',
          element: jQuery(".top-context").get(0),
          parent: null,
          rb: this }
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
        .text("Show serialized expression")
        .click(function(e){
            that.top_context.traverse(function(ctx) {
                jQuery(ctx.element).append(ctx.state());
            });
            alert(that.top_context.serialize())})
        .prependTo(this.panel);

    jQuery._input_({'class': 'done', 'type': 'submit', 'value': 'Done' })
        .text("Done")
        .click(function(e){
            if (that.finalize)
                that.finalize.apply(that);
        })
        .prependTo(this.panel);

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

Module("RuleBuilder2", function(m) {
    Class("SelfEvalContext", {
        has: { context: { is: "rw" },
             },
        after: {
            initialize: function() {
                var that = this;
                jQuery._input_({ 'type': 'text', class: 'enter-value'})
                    .change(function() {
                        that.context.update_return_type(that.return_type(this.value))
                    } )
                    .appendTo(this.context.element)
                    .trigger('focus');
            },
        },
        methods: {
            set_value: function(val) {
                jQuery('input.enter-value', this.context.element)
                    .val(val)
                    .trigger('change');
            },
            return_type: function(val) {
                // XXX
                return 'Str';
            },
            serialize: function() {
                var val = jQuery('input.enter-value', this.context.element).val();
                if (this.context.expected_type == 'Str') {
                    return '"'+val+'"';
                }
                else {
                    return val;
                }
            }
        }
    });

    Class("Context", {
        has: {
            expected_type: { is: "rw" },
            element: { is: "rw" },
            parent: { is: "rw" },
            rb: { is: "rw" }
        },
        after: { initialize: function() {
            var expected_type = this.expected_type;
            var rb = this.rb;

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
                        that.expcontext = new m.SelfEvalContext( { context: that } );
                        return true;
                    })
                    .appendTo(this.element);
            }

            var matched = /^ArrayRef\[(.*)\]$/.exec(expected_type);
            if (matched) {
                this.inner_type = matched[1];
                this.children = [];
                var builder = jQuery._div({'class': 'arraybuilder'})
                    ._div_({'class': 'array-item-container'})
                    .div_()
                    .appendTo(this.element)
                    .hide();
                jQuery._span_({'class': 'arraybuilder-icon'})
                    .text("Array builder")
                    .appendTo(this.element)
                    .click(function(e) {
                        that.arraybuilder = builder;
                        var child = that.mk_array_item_context(that.inner_type,
                                                               jQuery('div.array-item-container', builder), 0);
                        that.children.push(child);
                        builder.show();
                        jQuery(this).hide();
                        that.rb.focus(child);
                        return false;
                    });
            }
        }
               },
        methods: {
            array_item_idx: function() {
                for (var i in this.parent.children) {
                    if (this.parent.children[i] == this)
                        return parseInt(i);
                }
                return -1;
            },

            mk_array_item_context: function(type, container, insert_after) {
                var li = jQuery._div_({'class': 'array-item'});
                if (insert_after)
                    li.insertAfter(jQuery(insert_after).parent(".array-item"));
                else
                    li.appendTo(container);
                var x = jQuery._div_({'class': 'context'})
                    .appendTo(li);
                var child = new RuleBuilder2.Context({ expected_type: type,
                                                       element: x.get(0),
                                                       parent: this,
                                                       rb: this.rb });
                jQuery._span_({'class': 'add-icon'})
                    .text("+")
                    .appendTo(li)
                    .click(function(e) {
                        var that = child.parent;
                        var idx = child.array_item_idx()+1;
                        var newchild = that.mk_array_item_context(that.inner_type,
                                                                  jQuery('div.array-item-container', that.arraybuilder), child.element);
                        that.children.splice(idx, 0, newchild);
                    });
                jQuery._span_({'class': 'delete-icon'})
                    .text("-")
                    .appendTo(li)
                    .click(function(e) {
                        var that = child.parent;
                        var idx = child.array_item_idx();
                        jQuery(child.element).parent('.array-item').remove();
                        that.children.splice(idx, 1);
                    });

                return child;
            },

            transform: function(func_name) {
                var rb = this.rb;
                var func = rb.functions[func_name];
                var new_element = jQuery._div_({'class': 'context'});
                var parent = new RuleBuilder2.Context({ expected_type: this.expected_type,
                                                        element: new_element.get(0),
                                                        parent: this.parent,
                                                        rb: rb });

                if (this.parent) {
                    new_element.insertAfter(this.element);
                    jQuery(this.element).remove();

                    this.parent.children[this.array_item_idx()] = parent;
                }
                else {
                    jQuery(rb.top_context.element).removeClass('top-context').remove();
                    new_element.addClass('top-context').appendTo(rb.panel);

                    rb.top_context = parent;
                }

                this.parent = parent;

                parent.set_application(func_name, func);

                jQuery(this.element).unbind('click');
                var first_param = parent.children[0];
                var second_param = parent.children.length > 1 ? parent.children[1] : null;

                if (first_param.inner_type) {
                    //   Bool "or"                 (......)  <- parent
                    //        |--- ArrayRef[Bool]  (parent)  <- first_param
                    //              |- first_param           <- 
                    //              |- second_param          <- 
                    parent = first_param;
                    var builder = jQuery('div.arraybuilder', parent.element).show();
                    jQuery("span.arraybuilder-icon", parent.element).hide();
                    parent.arraybuilder = builder;
                    var container = jQuery('div.array-item-container', builder);
                    first_param = parent.mk_array_item_context(parent.inner_type,
                                                               container, null);
                    second_param = parent.mk_array_item_context(parent.inner_type,
                                                                container, first_param.element);
                    parent.children = [ first_param, second_param ];
                }

                parent.children[0] = this;
                this.parent = parent;
                this.expected_type = first_param.expected_type;

                jQuery('span.return-type:first', this.element)
                    .text(first_param.expected_type);
                jQuery(first_param.element).replaceWith(this.element);
                first_param.element = this.element;
                var that = this;
                jQuery(this.element).click(function(e) { rb.focus(that); return false });
                this.update_return_type(this.return_type);
                if (second_param)
                    this.rb.focus(second_param);
            },

            transformMenu: function(el) {
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

            },

            state: function() {
                if( this.expcontext instanceof m.SelfEvalContext ) {
                }
                else if ( this.expression ) {
                }
                else if ( this.func_name ) {
                    var type_complete = false;
                    for (var i in this.children) {
                        var child = this.children[i];
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
            },

            update_return_type: function(type) {
                // XXX: this should query the server for 'is-a-type-of'
                this.return_type = type;
                var el = jQuery("span.return-type", this.element);
                if (this.expected_type == type) {
                    el.removeClass("unmatched").addClass("matched");
                }
                else {
                    el.removeClass("matched").addClass("unmatched");
                }
                this.transformMenu(el);
            },

            clear: function() {
                jQuery('div.application', this.element).remove();
                jQuery('span.expression', this.element).remove();
                jQuery('span.transform', this.element).hide();
                jQuery('span.enter-value', this.element).hide();

                this.expcontext = null;
                this.expression = null;
                this.func_name = null;
            },

            traverse: function(fn) {
                fn(this);
                if ( this.func_name ) {
                    jQuery.each(this.children, function(idx, val) { fn(this) } );
                }
            },

            serialize: function() {
                if( this.expcontext instanceof m.SelfEvalContext ) {
                    return this.expcontext.serialize();
                }
                else if ( this.expression ) {
                    return this.expression;
                }
                else if ( this.func_name ) {
                    var args = jQuery.map(this.children, function(val) { return val.serialize() });
                    args.unshift(this.func_name);
                    return '('+args.join(' ')+')';
                }
                else if ( this.arraybuilder ) {
                    var args = jQuery.map(this.children, function(val) { return val.serialize() });
                    return args.join(' ');
                }
            },

            set_expression: function(expression) {
                this.clear();
                this.expression = expression.expression;
                this.update_return_type(expression.type);
                jQuery('span.transform', this.element).show();

                jQuery._span_({ 'class': 'expression'})
                    .text(this.expression)
                    .appendTo(this.element);
            },

            set_application: function(func_name, func) {
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

                                var child = new RuleBuilder2.Context({ expected_type: val.type,
                                                                       element: x.get(0),
                                                                       parent: that,
                                                                       rb: that.rb });

                                that.children.push(child);
                            });
                if (this.children.length) {
                    this.rb.focus(this.children[0]);
                }
            }
        }
    })
});


jQuery.fn.sort = function() {
    return this.pushStack( [].sort.apply( this, arguments ), []);
};

function sortAlpha(a,b){
     return a.innerHTML > b.innerHTML ? 1 : -1;
};

