# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2013 Best Practical Solutions, LLC
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

package RT::Crypt::SMIME;

use Role::Basic 'with';
with 'RT::Crypt::Role';

use RT::Crypt;
use IPC::Run3 0.036 'run3';
use RT::Util 'safe_run_child';

=head1 NAME

RT::Crypt::SMIME - encrypt/decrypt and sign/verify email messages with the SMIME

=head1 CONFIGURATION

You should start from reading L<RT::Crypt>.

=head2 %SMIME

    Set( %SMIME,
        Enable => 1,
        OpenSSL => '/usr/bin/openssl',
    );

=head3 OpenSSL

Path to openssl executable.

=cut

sub OpenSSLPath {
    state $cache = RT->Config->Get('SMIME')->{'OpenSSL'};
    return $cache;
}

sub Probe {
    my $self = shift;
    my $bin = $self->OpenSSLPath();
    return 0 unless $bin;

    if ($bin =~ m{^/}) {
        return 0 unless -f $bin;
        return 0 unless -x _;
    }

    {
        my ($buf, $err) = ('', '');

        local $SIG{'CHLD'} = 'DEFAULT';
        safe_run_child { run3( [$bin, "list-standard-commands"],
            \undef,
            \$buf, \$err
        ) };

        if ($? or $err) {
            $RT::Logger->warning(
                "RT's SMIME libraries couldn't successfully execute openssl.".
                    " SMIME support has been disabled") ;
            return;
        } elsif ($buf !~ /\bsmime\b/) {
            $RT::Logger->warning(
                "openssl does not include smime support.".
                    " SMIME support has been disabled");
            return;
        } else {
            return 1;
        }
    }
}

sub SignEncrypt {
    my $self = shift;
    my %args = (
        Entity => undef,

        Sign => 1,
        Signer => undef,
        Passphrase => undef,

        Encrypt => 1,
        Recipients => undef,

        @_
    );

    return ( exit_code => 1 );
}

sub SignEncryptContent {
    my $self = shift;
    return ( exit_code => 1 );
}

sub VerifyDecrypt {
    my $self = shift;
    my %args = ( Info => undef, @_ );

    return ( exit_code => 1 );
}

sub DecryptContent {
    my $self = shift;
    return ( exit_code => 1 );
}

sub FormatStatus {
    my $self = shift;
    my @status = @_;

    my $res = '';
    foreach ( @status ) {
        while ( my ($k, $v) = each %$_ ) {
            $res .= "[SMIME:]". $k .": ". $v ."\n";
        }
        $res .= "[SMIME:]\n";
    }

    return $res;
}

sub ParseStatus {
    my $self = shift;
    my $status = shift;
    return () unless $status;

    my @status = split /\s*(?:\[SMIME:\]\s*){2}/, $status;
    foreach my $block ( grep length, @status ) {
        chomp $block;
        $block = { map { s/^\s+//; s/\s+$//; $_ } map split(/:/, $_, 2), split /\s*\[SMIME:\]/, $block };
    }
    foreach my $block ( grep $_->{'EncryptedTo'}, @status ) {
        $block->{'EncryptedTo'} = [{
            EmailAddress => $block->{'EncryptedTo'},  
        }];
    }

    return @status;
}

sub FindScatteredParts { return () }

sub CheckIfProtected {
    my $self = shift;
    my %args = ( Entity => undef, @_ );

    my $entity = $args{'Entity'};

    my $type = $entity->effective_type;
    if ( $type =~ m{^application/(?:x-)?pkcs7-mime$} || $type eq 'application/octet-stream' ) {
        # RFC3851 ch.3.9 variant 1 and 3

        my $security_type;

        my $smime_type = $entity->head->mime_attr('Content-Type.smime-type');
        if ( $smime_type ) { # it's optional according to RFC3851
            if ( $smime_type eq 'enveloped-data' ) {
                $security_type = 'encrypted';
            }
            elsif ( $smime_type eq 'signed-data' ) {
                $security_type = 'signed';
            }
            elsif ( $smime_type eq 'certs-only' ) {
                $security_type = 'certificate management';
            }
            elsif ( $smime_type eq 'compressed-data' ) {
                $security_type = 'compressed';
            }
            else {
                $security_type = $smime_type;
            }
        }

        unless ( $security_type ) {
            my $fname = $entity->head->recommended_filename || '';
            if ( $fname =~ /\.p7([czsm])$/ ) {
                my $type_char = $1;
                if ( $type_char eq 'm' ) {
                    # RFC3851, ch3.4.2
                    # it can be both encrypted and signed
                    $security_type = 'encrypted';
                }
                elsif ( $type_char eq 's' ) {
                    # RFC3851, ch3.4.3, multipart/signed, XXX we should never be here
                    # unless message is changed by some gateway
                    $security_type = 'signed';
                }
                elsif ( $type_char eq 'c' ) {
                    # RFC3851, ch3.7
                    $security_type = 'certificate management';
                }
                elsif ( $type_char eq 'z' ) {
                    # RFC3851, ch3.5
                    $security_type = 'compressed';
                }
            }
        }
        return () unless $security_type;

        return (
            Type   => $security_type,
            Format => 'RFC3851',
            Data   => $entity,
        );
    }
    elsif ( $type eq 'multipart/signed' ) {
        # RFC3156, multipart/signed
        # RFC3851, ch.3.9 variant 2

        unless ( $entity->parts == 2 ) {
            $RT::Logger->error( "Encrypted or signed entity must has two subparts. Skipped" );
            return ();
        }

        my $protocol = $entity->head->mime_attr( 'Content-Type.protocol' );
        unless ( $protocol ) {
            $RT::Logger->error( "Entity is '$type', but has no protocol defined. Skipped" );
            return ();
        }

        unless ( $protocol =~ m{^application/(x-)?pkcs7-signature$} ) {
            $RT::Logger->info( "Skipping protocol '$protocol', only 'application/x-pkcs7-signature' is supported" );
            return ();
        }
        $RT::Logger->debug("Found part signed according to RFC3156");
        return (
            Type      => 'signed',
            Format    => 'RFC3156',
            Data      => $entity,
        );
    }
    return ();
}

sub GetKeysForEncryption {
    my $self = shift;
    my %args = (Recipient => undef, @_);
    return $self->GetKeysInfo( Key => delete $args{'Recipient'}, %args, Type => 'public' );
}

sub GetKeysForSigning {
    my $self = shift;
    my %args = (Signer => undef, @_);
    return $self->GetKeysInfo( Key => delete $args{'Signer'}, %args, Type => 'private' );
}

sub GetKeysInfo {
    my $self = shift;
    my %args = (
        Key   => undef,
        Type  => 'public',
        Force => 0,
        @_
    );

    return (exit_code => 1);
}

1;
