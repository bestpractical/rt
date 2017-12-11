use strict;
use warnings;
use RT::Interface::REST;

use RT::Test tests => undef;

my ( $baseurl, $m ) = RT::Test->started_ok;

my $cf = RT::Test->load_or_create_custom_field(
    Name       => 'foo',
    Type       => 'Freeform',
    LookupType => 'RT::User',
);
$cf->AddToObject(RT::User->new(RT->SystemUser));

my $root = RT::User->new( RT->SystemUser );
$root->Load('root');
$root->AddCustomFieldValue( Field => 'foo', Value => 'blabla' );
is( $root->FirstCustomFieldValue('foo'), 'blabla', 'cf is set' );

ok( $m->login, 'logged in' );
$m->post( "$baseurl/REST/1.0/show", [ id => 'user/14', ] );
like( $m->content, qr/CF-foo: blabla/, 'found the cf' );

done_testing;
