use strict;
use warnings;

use RT::Test tests => undef;

eval { require RT::Authen::ExternalAuth; 1; } or do {
    plan skip_all => 'Unable to test without Net::LDAP';
};

RT->Config->Set(
    ExternalSettings => {
        'My_LDAP' => {
            type => 'ldap',
            user => 'ldap_bind',
            pass => 'sekrit',
        },
        'My_DBI' => {
            type => 'db',
            user => 'external_db_user',
            pass => 'nottelling',
        },
    }
);

my ($base, $m) = RT::Test->started_ok();
ok( $m->login, 'logged in' );

$m->get_ok('/Admin/Tools/Configuration.html', 'config page');
$m->content_lacks('sekrit', 'external source 1 pass obfuscated');
$m->content_lacks('nottelling', 'external source 2 pass obfuscated');
$m->content_contains('ldap_bind', 'sanity check: we do have external config dumped');
$m->content_contains('external_db_user', 'sanity check: we do have external config dumped');


done_testing;
