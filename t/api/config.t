use strict;
use warnings;
use RT;
use RT::Test tests => undef, config => q{
Set($DefaultQueue, 1); # General

# The groupings two extensions and a site config might each add, in three of
# the shapes %CustomFieldGroupings accepts.
Set(%CustomFieldGroupings, 'RT::Ticket' => [ 'Helpdesk Information' => ['Severity'] ]);
Set(%CustomFieldGroupings, 'RT::Ticket' => { 'General' => { 'Zebra' => ['Stripes'] } });
Set(%CustomFieldGroupings,
    'RT::Ticket' => {
        'Default' => [ 'Helpdesk Information' => ['Location'] ],
        'General' => { 'Alpha' => ['First'] },
    },
);
};
use Test::Warn;

ok(
    RT::Config->AddOption(
        Name    => 'foo',
        Section => 'bar',
    ),
    'added option foo'
);

my $meta = RT::Config->Meta('foo');
is( $meta->{Section}, 'bar', 'Section is bar' );
is( $meta->{Widget}, '/Widgets/Form/String', 'default Widget is string' );
is_deeply( $meta->{WidgetArguments},
    {},, 'default WidgetArguments is empty hashref' );

ok(
    RT::Config->UpdateOption(
        Name    => 'foo',
        Section => 'baz',
        Widget => '/Widgets/Form/Boolean',
    ),
    'updated option foo to section baz'
);
is( $meta->{Section}, 'baz', 'section is updated to baz' );
is( $meta->{Widget}, '/Widgets/Form/Boolean', 'widget is updated to boolean' );

ok( RT::Config->DeleteOption( Name => 'foo' ), 'removed option foo' );
is( RT::Config->Meta('foo'), undef, 'foo is indeed deleted' );

# Test EmailInputEncodings PostLoadCheck code
RT::Config->Set('EmailInputEncodings', qw(utf-8 iso-8859-1 us-ascii foo));
my @encodings = qw(utf-8-strict iso-8859-1 ascii);

warning_like {RT::Config->PostLoadCheck} qr{Unknown encoding \'foo\' in \@EmailInputEncodings option},
  'Correct warning for encoding foo';

RT::Config->Set( WebDefaultStylesheet => 'non-existent-skin-name' );
warning_like {RT::Config->PostLoadCheck} qr{elevator},
    'Correct warning for default stylesheet';

my @canonical_encodings = RT::Config->Get('EmailInputEncodings');
is_deeply(\@encodings, \@canonical_encodings, 'Got correct encoding list');

# Test the created message from RT::Configuration
{
    my $test_queue = RT::Test->load_or_create_queue( Name => 'Test' );
    my $config     = RT::Configuration->new( RT->SystemUser );
    my ( $ret, $msg ) = $config->Create( Name => 'DefaultQueue', Content => $test_queue->Id );
    ok( $ret, 'Created DefaultQueue config' );
    is( $msg, q{DefaultQueue changed from "General" to "Test"}, 'Created message' );
}

RT->Config->Set(
    ExternalSettings => {
        'My_LDAP' => {
            'user'          => 'rt_ldap_username',
            'pass'          => 'rt_ldap_password',
            'net_ldap_args' => [
                raw => qr/^givenName/,
            ],
            subroutine => sub { },
        },
    }
);

my $external_settings = RT::Config->GetObfuscated( 'ExternalSettings', RT->SystemUser );
is( $external_settings->{My_LDAP}{user}, 'rt_ldap_username',     'plain value' );
is( $external_settings->{My_LDAP}{pass}, 'Password not printed', 'obfuscated password' );
is( $external_settings->{My_LDAP}{net_ldap_args}[ 1 ], qr/^givenName/, 'regex correct' );
is( ref $external_settings->{My_LDAP}{subroutine},     'CODE',         'subroutine type correct' );

diag "CustomFieldGroupings of every config file are merged as RT loads them";
is_deeply(
    scalar RT->Config->Get('CustomFieldGroupings'),
    {   'RT::Ticket' => {
            'Default' => [ 'Helpdesk Information' => ['Severity'] ],
            'General' => [ 'Alpha' => ['First'], 'Zebra' => ['Stripes'] ],
        },
    },
    'groupings set by each config file are merged, and unordered ones sorted'
);

# Run some additional config permutations through the same config processing
# RT runs during startup. Those steps are different from calling the Set
# method, so we need this helper.

my $merge = sub {
    RT::Config->Set( CustomFieldGroupings => () );
    for my $config (@_) {
        RT::Config->SetFromConfig(
            Option => \'CustomFieldGroupings',
            Value  => [%$config],
            File   => __FILE__,
            Line   => __LINE__,
        );
    }
    RT::Config->Meta('CustomFieldGroupings')->{PostLoadCheck}->('RT::Config');
    return scalar RT::Config->Get('CustomFieldGroupings');
};

diag "CustomFieldGroupings merges the accepted class-level shapes";
{
    # The shapes two extensions and a site config might each use for the same
    # class: a flat list of groupings, a hash keyed by queue name, and a hash
    # keyed by queue name with the groupings as a hash.
    my %helpdesk = ( 'RT::Ticket' => [ 'Helpdesk Information' => [ 'Severity', 'Service Impacted' ] ] );
    my %rtir     = (
        'RT::Ticket' => {
            'Incidents'        => [ 'Networking' => [ 'IP', 'Domain' ] ],
            'Incident Reports' => [ 'Networking' => [ 'IP', 'Domain' ] ],
        },
    );
    my %site = (
        'RT::Ticket' => {
            'Default'   => { 'Helpdesk Information' => ['Location'] },
            'Incidents' => [ 'Networking'           => ['ASN'] ],
        },
        'RT::User' => [ 'Extra' => ['Nickname'] ],
    );

    # Groupings only one config provides are all kept. Where two configs name
    # the same grouping, the one loaded first wins its list of custom fields,
    # and a site config is loaded before any extension config.
    is_deeply(
        $merge->( \%site, \%helpdesk, \%rtir ),
        {   'RT::Ticket' => {
                'Default'          => [ 'Helpdesk Information' => ['Location'] ],
                'Incidents'        => [ 'Networking'           => ['ASN'] ],
                'Incident Reports' => [ 'Networking'           => [ 'IP', 'Domain' ] ],
            },
            'RT::User' => { 'Default' => [ 'Extra' => ['Nickname'] ] },
        },
        'groupings of all three configs are merged, site config winning shared groupings'
    );

    my %expected = (
        'RT::Ticket' => {
            'Default'          => [ 'Helpdesk Information' => [ 'Severity', 'Service Impacted' ] ],
            'Incidents'        => [ 'Networking'           => [ 'IP', 'Domain' ] ],
            'Incident Reports' => [ 'Networking'           => [ 'IP', 'Domain' ] ],
        },
        'RT::User' => { 'Default' => [ 'Extra' => ['Nickname'] ] },
    );

    is_deeply( $merge->( \%helpdesk, \%rtir, \%site ), \%expected,
        'the extensions win the shared groupings when they are loaded first' );

    # PostLoadCheck runs on config the merger has already normalized, and on
    # config that never went through it, so it has to be idempotent.
    RT::Config->Meta('CustomFieldGroupings')->{PostLoadCheck}->('RT::Config');
    is_deeply( scalar RT::Config->Get('CustomFieldGroupings'), \%expected,
        'PostLoadCheck leaves merged groupings unchanged' );

    RT::Config->Set( CustomFieldGroupings => () );
}

diag "CustomFieldGroupings orders groupings by how each config wrote them";
{
    # Groupings given as a hash are displayed alphabetically, and that ordering
    # covers the groupings of every config file, not those of each file on its
    # own.
    my %zebra = ( 'RT::Ticket' => { 'Zebra' => ['Stripes'] } );
    my %alpha = (
        'RT::Ticket' => {
            'Alpha'    => ['First'],
            'Mongoose' => ['Snakes'],
        },
    );

    my %expected = (
        'RT::Ticket' => {
            'Default' => [
                'Alpha'    => ['First'],
                'Mongoose' => ['Snakes'],
                'Zebra'    => ['Stripes'],
            ],
        },
    );

    is_deeply( $merge->( \%zebra, \%alpha ), \%expected,
        'hash-form groupings of two configs are sorted together' );

    is_deeply( $merge->( \%alpha, \%zebra ), \%expected,
        'same sorted groupings when the configs load in a different order' );

    # Groupings given as an array are displayed in the order they are written,
    # so the first config's order is kept and later groupings are appended.
    is_deeply(
        $merge->( { 'RT::Ticket' => [ 'Zebra' => ['Stripes'] ] }, \%alpha ),
        {   'RT::Ticket' => {
                'Default' => [
                    'Zebra'    => ['Stripes'],
                    'Alpha'    => ['First'],
                    'Mongoose' => ['Snakes'],
                ],
            },
        },
        'explicitly ordered groupings keep their order and take later ones after them'
    );

    RT::Config->Set( CustomFieldGroupings => () );
}

done_testing;
