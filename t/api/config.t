use strict;
use warnings;
use RT;
use RT::Test tests => undef, config => q{
Set($DefaultQueue, 1); # General
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

my $disable_mfa = RT::Config->Get('DisableMFA');
RT::Config->Set( DisableMFA => 1 );

RT::Config->Set( SecretKey => '' );
RT::Config->Set( DatabasePassword => 'rt_pass' );
warning_like { RT::Config->PostLoadCheck } qr{SecretKey is empty or the default database password},
    'Warning for SecretKey falling back to the default database password';

RT::Config->Set( SecretKey => '' );
RT::Config->Set( DatabasePassword => '' );
warning_like { RT::Config->PostLoadCheck } qr{SecretKey is empty or the default database password},
    'Warning for empty SecretKey';

RT::Config->Set( SecretKey => '' );
RT::Config->Set( DatabasePassword => 'a-db-password' );
warnings_are { RT::Config->PostLoadCheck } [],
    'No warning for SecretKey falling back to the database password with MFA disabled';

RT::Config->Set( SecretKey => 'a-long-random-secret' );
warnings_are { RT::Config->PostLoadCheck } [], 'No warning for a dedicated SecretKey';

SKIP: {
    skip 'RT::MFA::TOTP is not available', 3 unless eval { require RT::MFA::TOTP };

    RT::Config->Set( DisableMFA => 0 );

    RT::Config->Set( SecretKey => '' );
    RT::Config->Set( DatabasePassword => 'a-db-password' );
    warning_like { RT::Config->PostLoadCheck } qr{SecretKey is not set or matches \$DatabasePassword},
        'Warning for SecretKey falling back to the database password with MFA enabled';

    RT::Config->Set( SecretKey => '' );
    RT::Config->Set( DatabasePassword => 'rt_pass' );
    warnings_like { RT::Config->PostLoadCheck }
        [
            qr{SecretKey is empty or the default database password},
            qr{SecretKey is not set or matches \$DatabasePassword},
        ],
        'Both warnings for SecretKey falling back to the default database password with MFA enabled';

    RT::Config->Set( SecretKey => 'a-long-random-secret' );
    warnings_are { RT::Config->PostLoadCheck } [], 'No warning for a dedicated SecretKey with MFA enabled';
}

RT::Config->Set( DisableMFA => $disable_mfa );

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
my $password_policy = RT->Config->Get('PasswordPolicy');

RT->Config->Set( PasswordPolicy => { Bogus => { MinLength => 8 }, Default => { MinLength => 8 } } );
warning_like { RT::Config->PostLoadCheck } qr{Invalid \$PasswordPolicy key 'Bogus'}, 'Warning for invalid PasswordPolicy role';
is_deeply( RT->Config->Get('PasswordPolicy'), { Default => { MinLength => 8 } }, 'Invalid role dropped' );

RT->Config->Set( PasswordPolicy => { Default => 'strict' } );
warning_like { RT::Config->PostLoadCheck } qr{Invalid \$PasswordPolicy->\{Default\} value \(must be a HASH ref\)},
    'Warning for non-hash PasswordPolicy value';
is_deeply( RT->Config->Get('PasswordPolicy'), {}, 'Non-hash value dropped' );

RT->Config->Set( PasswordPolicy => { Default => { MinLength => 'long' } } );
warning_like { RT::Config->PostLoadCheck } qr{Invalid \$PasswordPolicy->\{Default\}\{MinLength\} value 'long'},
    'Warning for non-integer MinLength';
is_deeply( RT->Config->Get('PasswordPolicy'), { Default => { MinLength => 0 } }, 'Bad MinLength falls back to 0' );

RT->Config->Set( PasswordPolicy => { Default => { MinLength => 8, RequireUpper => 'yes', Bogus => 1 } } );
warning_like { RT::Config->PostLoadCheck } qr{Unknown \$PasswordPolicy->\{Default\}\{Bogus\} key},
    'Warning for unknown PasswordPolicy field';
is_deeply(
    RT->Config->Get('PasswordPolicy'),
    { Default => { MinLength => 8, RequireUpper => 1 } },
    'Unknown field dropped and flag normalized to 1'
);

RT->Config->Set( PasswordPolicy => $password_policy );

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
