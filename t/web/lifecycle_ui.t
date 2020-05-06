use strict;
use warnings;

use JSON qw/decode_json encode_json/;
use RT::Lifecycle;

use RT::Test tests => undef;
my ($baseurl, $m) = RT::Test->started_ok;

ok $m->login;

my $queue = RT::Queue->new( RT->SystemUser );
ok $queue->Load( 'General' );

my ($t) = RT::Test->create_tickets(
    { Queue => $queue->Id, Status => 'open' },
    { },
);

$m->get( "$baseurl/Admin/Lifecycles/Advanced.html?Type=ticket;Name=".$queue->Lifecycle );
# Go to the advanced page of Lifecycle UI
my $advanced_form = $m->form_name( 'ModifyLifecycleAdvanced' );
my $config = $advanced_form->find_input( 'Config' );

my $new_config = decode_json($config->value);

$new_config->{'active'} = ['stalled'];
push @{$new_config->{'inactive'}}, 'open';
my $json = encode_json( $new_config );

$m->submit_form(
    form_name => 'ModifyLifecycleAdvanced',
    fields    => { Config => $json },
    button    => 'Update',
);
ok( $m->content_contains('Lifecycle updated'), "Lifecycle updated from advanced page" );

$m->get($baseurl);
ok( !$m->find_link( text => '(No subject)' ), "Open ticket does not show up in active ticket search after lifecycle update" );

done_testing();
