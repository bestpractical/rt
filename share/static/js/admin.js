var path = window.location.href;

if ( path.match( /Admin\/Tools\/Queries\.html/ ) ) {
  jQuery(function () {
    jQuery(".tablesorter").tablesorter();
  });
}
