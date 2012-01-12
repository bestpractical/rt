use strict;
use warnings;

package RT::Test::SMIME;

use Test::More;
use base qw(RT::Test);
use File::Temp qw(tempdir);

sub import {
    my $class = shift;
    my %args  = @_;
    my $t     = $class->builder;

    $t->plan( skip_all => 'openssl executable is required.' )
        unless RT::Test->find_executable('openssl');

    require RT::Crypt;
    $class->SUPER::import(%args);

    RT::Test::diag "GnuPG --homedir " . RT->Config->Get('GnuPGOptions')->{'homedir'};

    $class->set_rights(
        Principal => 'Everyone',
        Right => ['CreateTicket', 'ShowTicket', 'SeeQueue', 'ReplyToTicket', 'ModifyTicket'],
    );

    $class->bootstrap_key_cf;

    $class->export_to_level(1);
}

sub bootstrap_more_config {
    my $self = shift;
    my $handle = shift;
    my $args = shift;

    $self->SUPER::bootstrap_more_config($handle, $args, @_);

    my $openssl = $self->find_executable('openssl');
    my $keyring = $self->keyring_path;

    print $handle qq{
        Set(\%GnuPG, Enable => 0);
        Set(\%SMIME =>
            Enable => 1,
            Passphrase => {
                'root\@example.com' => '123456',
                'sender\@example.com' => '123456',
            },
            OpenSSL => q{$openssl},
            Keyring => q{$keyring},
        );
        Set(\@MailPlugins => qw(Auth::MailFrom Auth::Crypt));
    };

}

sub bootstrap_key_cf {
    my $self = shift;

    my $cf = RT::CustomField->new( RT->SystemUser );
    my ($ret, $msg) = $cf->Create(
        Name       => 'SMIME Key',
        LookupType => RT::User->new( RT->SystemUser )->CustomFieldLookupType,
        Type       => 'TextSingle',
    );
    ok($ret, "Custom Field created");

    my $OCF = RT::ObjectCustomField->new( $RT::SystemUser );
    $OCF->Create(
        CustomField => $cf->id,
        ObjectId    => 0,
    );
}

{ my $cache;
sub keyring_path {
    return $cache ||= shift->new_temp_dir(
        crypt => smime => 'smime_keyring'
    );
} }

sub key_path {
    my $self = shift;
    my $keys = RT::Test::get_abs_relocatable_dir(
        (File::Spec->updir()) x 2,
        qw(data smime keys),
    );
    return File::Spec->catfile( $keys => @_ ),
}

sub mail_set_path {
    my $self = shift;
    return RT::Test::get_abs_relocatable_dir(
        (File::Spec->updir()) x 2,
        qw(data smime mails),
    );
}

1;
