use strict;
use warnings;

use RT::Test::Assets tests => undef;

my $catalog = create_catalog( Name => 'Test Catalog');
ok $catalog && $catalog->id, "Created catalog";

for my $name (qw/SingleTestCustomRole MultipleTestCustomRole/) {
    my $role = RT::CustomRole->new( RT->SystemUser );
    my ( $ok, $msg ) = $role->Create(
        Name      => $name,
        MaxValues => $name =~ /Single/ ? 1 : 0,
        LookupType => RT::Asset->CustomFieldLookupType,
    );
    ok( $ok, "Created custom role: $msg" );

    ( $ok, $msg ) = $role->AddToObject( $catalog->Id );
    ok( $ok, "Added role to catalog: $msg" );
}

# Create a test asset
my $asset = RT::Asset->new( RT->SystemUser );
my ($id, $msg) = $asset->Create(
    Name        => 'Thinkpad T420s',
    Description => 'Laptop',
    Catalog     => $catalog->Name,
);
ok $id, "Created: $msg";

my ( $baseurl, $m ) = RT::Test->started_ok;
ok $m->login, 'logged in as root';

# Test that custom role is visible by default
$m->get_ok( "/Asset/Create.html?Catalog=" . $catalog->Id );
$m->content_contains( $_, "Custom roles are visible on Create page by default" )
    for qw/SingleTestCustomRole MultipleTestCustomRole/;

$m->get_ok( "/Asset/Display.html?id=" . $asset->Id );
$m->content_contains( $_, "Custom roles are visible on display page by default" )
    for qw/SingleTestCustomRole MultipleTestCustomRole/;

diag( 'Test hiding custom roles with page layout configuration' );

# Configure page layout to hide custom role in People widget
my %layout = (
    'RT::Asset' => {
        'Create' => {
            'Default' => [
                {   'Elements' => [
                        [   {   Name        => 'People',
                                HiddenRoles => ['MultipleTestCustomRole'],
                            },
                            'Submit'
                        ],
                        [ 'Basics', ]
                    ]
                }
            ]
        },
        'Display' => {
            'Default' => [
                {   'Layout'   => 'col-12',
                    'Elements' => [
                        [
                            {   Name        => 'People',
                                HiddenRoles => [ 'SingleTestCustomRole', 'MultipleTestCustomRole' ]
                            },
                        ]
                    ]
                }
            ]
        },
    }
);

my $config = RT::Configuration->new( RT->SystemUser );
( my $ret, $msg ) = $config->Create( Name => 'PageLayouts', Content => \%layout );
ok( $ret, 'Updated config' );


$m->get_ok( '/Asset/Create.html?Catalog=' . $catalog->Id );
$m->text_contains( 'SingleTestCustomRole', 'SingleTestCustomRole still appears on page in People widget' );
$m->text_lacks( 'MultipleTestCustomRole', 'MultipleTestCustomRole is now hidden' );

$m->get_ok( '/Asset/Display.html?id=' . $asset->Id );
$m->text_lacks( 'TestCustomRole', 'TestCustomRoles are hidden' );

done_testing();
