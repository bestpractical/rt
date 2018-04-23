# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2018 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
#
# (Except where explicitly superseded by other copyright notices)
#
#
# LICENSE:
#
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
#
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
#
#
# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# END BPS TAGGED BLOCK }}}

use strict;
use warnings;
use 5.010;

package RT::Test::SMIME;

use Test::More;
use base qw(RT::Test);
use File::Temp qw(tempdir);

sub import {
    my $class = shift;
    my %args  = @_;
    my $t     = $class->builder;

    RT::Test::plan( skip_all => 'openssl executable is required.' )
        unless RT::Test->find_executable('openssl');

    require RT::Crypt;
    $class->SUPER::import(%args);

    $class->set_rights(
        Principal => 'Everyone',
        Right => ['CreateTicket', 'ShowTicket', 'SeeQueue', 'ReplyToTicket', 'ModifyTicket'],
    );

    $class->export_to_level(1);
}

sub bootstrap_more_config {
    my $self = shift;
    my $handle = shift;
    my $args = shift;

    $self->SUPER::bootstrap_more_config($handle, $args, @_);

    my $openssl = $self->find_executable('openssl');

    my $keyring = $self->keyring_path;
    mkdir($keyring);

    my $ca = $self->key_path("demoCA", "cacert.pem");

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
            CAPath  => q{$ca},
        );
    };

}

sub keyring_path {
    return File::Spec->catfile( RT::Test->temp_directory, "smime" );
}

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

sub import_key {
    my $self = shift;
    my $key  = shift;
    my $user = shift;

    my $path = RT::Test::find_relocatable_path( 'data', 'smime', 'keys' );
    die "can't find the dir where smime keys are stored"
        unless $path;

    my $keyring = RT->Config->Get('SMIME')->{'Keyring'};
    die "SMIME keyring '$keyring' doesn't exist"
        unless $keyring && -e $keyring;

    $key .= ".pem" unless $key =~ /\.(pem|crt|key)$/;

    my $content = RT::Test->file_content( [ $path, $key ] );

    if ( $user ) {
        my ($status, $msg) = $user->SetSMIMECertificate( $content );
        die "Couldn't set CF: $msg" unless $status;
    } else {
        my $keyring = RT->Config->Get('SMIME')->{'Keyring'};
        die "SMIME keyring '$keyring' doesn't exist"
            unless $keyring && -e $keyring;

        open my $fh, '>:raw', File::Spec->catfile($keyring, $key)
            or die "can't open file: $!";
        print $fh $content;
        close $fh;
    }

    return;
}

1;
