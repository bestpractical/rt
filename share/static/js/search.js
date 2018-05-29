var path = window.location.href;

if ( path.match( /Search\/Build\.html/ ) ) {
  jQuery(function() {

    // move the actual value to a hidden value, and shadow the others
    var hidden = jQuery('<input>').attr('type','hidden').attr('name','ValueOfQueue');

    // change the selector's name, but preserve the values, we'll set value via js
    var selector = jQuery("[name='ValueOfQueue']");

    // rename the selector so we don't get an extra term in the query
    selector[0].name = "";
    selector.bind('change',function() {
      hidden[0].value = selector[0].value;
    });

    // create a text input box and hide it for use with matches / doesn't match
    // NB: if you give text a name it will add an additional term to the query!
    var text = jQuery('<input>').attr('type','text');
    text.hide();
    text.bind('change',function() {
      hidden[0].value = text[0].value;
    });

    // hook the op field so that we can swap between the two input types
    var op = jQuery("[name='QueueOp']");
    op.bind('change',function() {
      if (op[0].value == "=" || op[0].value == "!=" ) {
        text.hide();
        selector.show();
        hidden[0].value = selector[0].value;
      } else {
        text.show();
        selector.hide();
        hidden[0].value = text[0].value;
      }
    });

    // add the fields to the DOM
    selector.before(hidden);
    selector.after(text);
  });
}

if ( path.match( /Search\/Chart\.html/ ) ) {
  var updateChartStyle = function() {
    var val = jQuery(".chart-picture [name=ChartType]").val();
    if ( val != 'table' && jQuery(".chart-picture [name=ChartStyleIncludeTable]").is(':checked') ) {
      val += '+table';
    }
    if ( jQuery(".chart-picture [name=ChartStyleIncludeSQL]").is(':checked') ) {
      val += '+sql';
    }
    jQuery(".chart-picture [name=ChartStyle]").val(val);
  };
  jQuery(".chart-picture [name=ChartType]").change(function(){
    var t = jQuery(this);
    t.closest("form").find("[name=Height]").closest(".height").toggle( t.val() == 'bar' );
    t.closest("form").find("[name=Width]").closest(".width").toggle( t.val() !== 'table' );
    t.closest("form .chart-picture").find("div.include-table").toggle( t.val() !== 'table' );
    updateChartStyle();
  }).change();

  jQuery(".chart-picture [name=ChartStyleIncludeTable]").change( updateChartStyle );
  jQuery(".chart-picture [name=ChartStyleIncludeSQL]").change( updateChartStyle );
}
