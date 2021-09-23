use strict;
use warnings;

use RT::Test tests => undef;

my ( $baseurl, $m ) = RT::Test->started_ok;

RT::Test->create_ticket(
    Queue   => 'General',
    Subject => 'Shortener test',
    Content => 'test',
);

ok $m->login, 'logged in';

$m->get_ok('/Search/Results.html?Query=id<10');
$m->follow_link_ok( { text => 'Show Results' } );
my ( $sc ) = ( $m->uri =~ /\bsc=(\w+)/ );
$m->follow_link_ok( { text => 'Shortener Viewer' } );
$m->title_is('Shortener Viewer');
$m->submit_form_ok(
    {   form_name => 'LoadShortener',
        fields    => { sc => $sc },
    }
);

$m->text_contains(q{'Query' => 'id<10'});

$m->submit_form_ok(
    {   form_name => 'LoadShortener',
        fields    => { sc => 'somefake' },
    }
);

$m->content_contains(q{Could not find short URL code somefake});
$m->text_lacks(q{'Query' => 'id<10'});
$m->warning_like(qr/Could not find short URL code somefake/);

done_testing;
