jQuery(function() {
  jQuery('form').submit(function() {
    jQuery(this).find('input[type="submit"]').attr('disabled','disabled');
    return true;
  })
  jQuery('input[type="submit"]').click(function() {
    var $this = jQuery(this);
    var name = $this.attr('name');
    if (!name) { return true; }
    $this.append( jQuery('<input/>', {type: "hidden", name: name, value: $this.val()} ) );
    return true;
  })
});