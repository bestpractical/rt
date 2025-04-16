use strict;
use warnings;

use RT::Test tests => undef;

my ( $url, $m ) = RT::Test->started_ok;
ok( $m->login(), 'logged in' );

$m->follow_link_ok( { text => 'System Configuration' } );
$m->text_contains( q{UsernameFormat'role'}, 'Default UsernameFormat is role' );

$m->follow_link_ok( { text => 'Preferences' } );
$m->submit_form_ok(
    {
        form_name => 'ModifyPreferences',
        fields    => {
            UsernameFormat => 'verbose',
        },
        button => 'Update',
    },
    'Change UsernameFormat pref to verbose'
);
$m->text_contains('Preferences saved.');

$m->follow_link_ok( { text => 'System Configuration' } );
$m->text_contains( q{UsernameFormat'role'}, 'UsernameFormat is still role' );

done_testing;
