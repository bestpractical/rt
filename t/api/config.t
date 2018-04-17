use strict;
use warnings;
use RT;
use RT::Test nodb => 1, tests => undef;
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
warning_like {RT::Config->PostLoadCheck} qr{rudder},
    'Correct warning for default stylesheet';

my @canonical_encodings = RT::Config->Get('EmailInputEncodings');
is_deeply(\@encodings, \@canonical_encodings, 'Got correct encoding list');

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

done_testing;
