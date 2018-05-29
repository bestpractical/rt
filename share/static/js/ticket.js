var path = window.location.href;

if ( path.match( /Ticket\/Update\.html/ ) ) {
  jQuery(function() {
    jQuery('a.ToggleSuggestions').click(function(e) {
      e.preventDefault();
      var toggleSuggestions = jQuery(this);
      var oneTimeCcs = toggleSuggestions.closest('td').find('.OneTimeCcs');
      oneTimeCcs.toggleClass('hidden');
      var hideOrShow = oneTimeCcs.hasClass('hidden') ? toggleSuggestions.data('showLabel') : toggleSuggestions.data('hideLabel');
      toggleSuggestions.find('i').html('(' + hideOrShow + ')');
    });
  });
}

if ( path.match( /SelfService\/Display\.html/ | /Asset\/Display\.html/ | /Ticket\/Display\.html/ | /Approvals\/Display\.html/ ) ) {
  jQuery("#assets-accordion ul.toplevel").addClass('sf-menu sf-js-enabled sf-shadow').supersubs().superfish({ dropShadows: false, speed: 'fast', delay: 0 }).supposition()
    .find('a').click(function(ev){
      ev.stopPropagation();
        return true;
  });
}
