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

package RT::Crypt::SMIME;

use Role::Basic 'with';
with 'RT::Crypt::Role';

use RT::Crypt;
use File::Which qw();
use IPC::Run3 0.036 'run3';
use RT::Util 'safe_run_child';
use Crypt::X509;
use String::ShellQuote 'shell_quote';

=head1 NAME

RT::Crypt::SMIME - encrypt/decrypt and sign/verify email messages with the SMIME

=head1 CONFIGURATION

You should start from reading L<RT::Crypt>.

=head2 %SMIME

    Set( %SMIME,
        Enable => 1,
        OpenSSL => '/usr/bin/openssl',
        Keyring => '/opt/rt4/var/data/smime',
        CAPath  => '/opt/rt4/var/data/smime/signing-ca.pem',
        Passphrase => {
            'queue.address@example.com' => 'passphrase',
            '' => 'fallback',
        },
    );

=head3 OpenSSL

Path to openssl executable.

=head3 Keyring

Path to directory with keys and certificates for queues. Key and
certificates should be stored in a PEM file named, e.g.,
F<email.address@example.com.pem>.  See L</Keyring configuration>.

=head3 CAPath

C<CAPath> should be set to either a PEM-formatted certificate of a
single signing certificate authority, or a directory of such (including
hash symlinks as created by the openssl tool C<c_rehash>).  Only SMIME
certificates signed by these certificate authorities will be treated as
valid signatures.  If left unset (and C<AcceptUntrustedCAs> is unset, as
it is by default), no signatures will be marked as valid!

=head3 AcceptUntrustedCAs

Allows arbitrary SMIME certificates, no matter their signing entities.
Such mails will be marked as untrusted, but signed; C<CAPath> will be
used to mark which mails are signed by trusted certificate authorities.
This configuration is generally insecure, as it allows the possibility
of accepting forged mail signed by an untrusted certificate authority.

Setting this option also allows encryption to users with certificates
created by untrusted CAs.

=head3 Passphrase

C<Passphrase> may be set to a scalar (to use for all keys), an anonymous
function, or a hash (to look up by address).  If the hash is used, the
'' key is used as a default.

=head2 Keyring configuration

RT looks for keys in the directory configured in the L</Keyring> option
of the L<RT_Config/%SMIME>.  While public certificates are also stored
on users, private SSL keys are only loaded from disk.  Keys and
certificates should be concatenated, in in PEM format, in files named
C<email.address@example.com.pem>, for example.

These files need be readable by the web server user which is running
RT's web interface; however, if you are running cronjobs or other
utilities that access RT directly via API, and may generate
encrypted/signed notifications, then the users you execute these scripts
under must have access too.

The keyring on disk will be checked before the user with the email
address is examined.  If the file exists, it will be used in preference
to the certificate on the user.

=cut

sub OpenSSLPath {
    state $cache = RT->Config->Get('SMIME')->{'OpenSSL'};
    $cache = $_[1] if @_ > 1;
    return $cache;
}

sub Probe {
    my $self = shift;
    my $bin = $self->OpenSSLPath();
    unless ($bin) {
        $RT::Logger->warning(
            "No openssl path set; SMIME support has been disabled.  ".
            "Check the 'OpenSSL' configuration in %OpenSSL");
        return 0;
    }

    if ($bin =~ m{^/}) {
        unless (-f $bin and -x _) {
            $RT::Logger->warning(
                "Invalid openssl path $bin; SMIME support has been disabled.  ".
                "Check the 'OpenSSL' configuration in %OpenSSL");
            return 0;
        }
    } else {
        local $ENV{PATH} = '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
            unless defined $ENV{PATH};
        my $path = File::Which::which( $bin );
        unless ($path) {
            $RT::Logger->warning(
                "Can't find openssl binary '$bin' in PATH ($ENV{PATH}); SMIME support has been disabled.  ".
                "You may need to specify a full path to opensssl via the 'OpenSSL' configuration in %OpenSSL");
            return 0;
        }
        $self->OpenSSLPath( $bin = $path );
    }

    {
        my ($buf, $err) = ('', '');

        local $SIG{'CHLD'} = 'DEFAULT';
        safe_run_child { run3( [$bin, "list-standard-commands"],
            \undef,
            \$buf, \$err
        ) };

        if ($err && $err =~ /Invalid command/) {
            ($buf, $err) = ('', '');
            safe_run_child { run3( [$bin, "list", "-commands"],
                \undef,
                \$buf, \$err
            ) };
        }

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

    my $entity = $args{'Entity'};

    if ( $args{'Encrypt'} ) {
        my %seen;
        $args{'Recipients'} = [
            grep !$seen{$_}++, map $_->address, map Email::Address->parse(Encode::decode("UTF-8",$_)),
            grep defined && length, map $entity->head->get($_), qw(To Cc Bcc)
        ];
    }

    $entity->make_multipart('mixed', Force => 1);
    my ($buf, %res) = $self->_SignEncrypt(
        %args,
        Content => \$entity->parts(0)->stringify,
    );
    unless ( $buf ) {
        $entity->make_singlepart;
        return %res;
    }

    my $tmpdir = File::Temp::tempdir( TMPDIR => 1, CLEANUP => 1 );
    my $parser = MIME::Parser->new();
    $parser->output_dir($tmpdir);
    my $newmime = $parser->parse_data($$buf);

    # Work around https://rt.cpan.org/Public/Bug/Display.html?id=87835
    for my $part (grep {$_->is_multipart and $_->preamble and @{$_->preamble}} $newmime->parts_DFS) {
        $part->preamble->[-1] .= "\n"
            if $part->preamble->[-1] =~ /\r$/;
    }

    $entity->parts([$newmime]);
    $entity->make_singlepart;

    return %res;
}

sub SignEncryptContent {
    my $self = shift;
    my %args = (
        Content => undef,
        @_
    );

    my ($buf, %res) = $self->_SignEncrypt(%args);
    ${ $args{'Content'} } = $$buf if $buf;
    return %res;
}

sub _SignEncrypt {
    my $self = shift;
    my %args = (
        Content => undef,

        Sign => 1,
        Signer => undef,
        Passphrase => undef,

        Encrypt => 1,
        Recipients => [],

        @_
    );

    my %res = (exit_code => 0, status => '');

    my @keys;
    if ( $args{'Encrypt'} ) {
        my @addresses = @{ $args{'Recipients'} };

        foreach my $address ( @addresses ) {
            $RT::Logger->debug( "Considering encrypting message to " . $address );

            my %key_info = $self->GetKeysInfo( Key => $address );
            unless ( defined $key_info{'info'} ) {
                $res{'exit_code'} = 1;
                my $reason = 'Key not found';
                $res{'status'} .= $self->FormatStatus({
                    Operation => "RecipientsCheck", Status => "ERROR",
                    Message => "Recipient '$address' is unusable, the reason is '$reason'",
                    Recipient => $address,
                    Reason => $reason,
                });
                next;
            }

            if ( not $key_info{'info'}[0]{'Expire'} ) {
                # we continue here as it's most probably a problem with the key,
                # so later during encryption we'll get verbose errors
                $RT::Logger->error(
                    "Trying to send an encrypted message to ". $address
                    .", but we couldn't get expiration date of the key."
                );
            }
            elsif ( $key_info{'info'}[0]{'Expire'}->Diff( time ) < 0 ) {
                $res{'exit_code'} = 1;
                my $reason = 'Key expired';
                $res{'status'} .= $self->FormatStatus({
                    Operation => "RecipientsCheck", Status => "ERROR",
                    Message => "Recipient '$address' is unusable, the reason is '$reason'",
                    Recipient => $address,
                    Reason => $reason,
                });
                next;
            }
            push @keys, $key_info{'info'}[0]{'Content'};
        }
    }
    return (undef, %res) if $res{'exit_code'};

    my $opts = RT->Config->Get('SMIME');

    my @commands;
    if ( $args{'Sign'} ) {
        my $file = $self->CheckKeyring( Key => $args{'Signer'} );
        unless ($file) {
            $res{'status'} .= $self->FormatStatus({
                Operation => "KeyCheck", Status => "MISSING",
                Message   => "Secret key for $args{Signer} is not available",
                Key       => $args{Signer},
                KeyType   => "secret",
            });
            $res{exit_code} = 1;
            return (undef, %res);
        }
        $args{'Passphrase'} = $self->GetPassphrase( Address => $args{'Signer'} )
            unless defined $args{'Passphrase'};

        push @commands, [
            $self->OpenSSLPath, qw(smime -sign),
            -signer => $file,
            -inkey  => $file,
            (defined $args{'Passphrase'} && length $args{'Passphrase'})
                ? (qw(-passin env:SMIME_PASS))
                : (),
        ];
    }
    if ( $args{'Encrypt'} ) {
        foreach my $key ( @keys ) {
            my $key_file = File::Temp->new;
            print $key_file $key;
            close $key_file;
            $key = $key_file;
        }
        push @commands, [
            $self->OpenSSLPath, qw(smime -encrypt -des3),
            map { $_->filename } @keys
        ];
    }

    my $buf = ${ $args{'Content'} };
    for my $command (@commands) {
        my ($out, $err) = ('', '');
        {
            local $ENV{'SMIME_PASS'} = $args{'Passphrase'};
            local $SIG{'CHLD'} = 'DEFAULT';
            safe_run_child { run3(
                $command,
                \$buf,
                \$out, \$err
            ) };
        }

        $RT::Logger->debug( "openssl stderr: " . $err ) if length $err;

        # copy output from the first command to the second command
        # similar to the pipe we used to use to pipe signing -> encryption
        # Using the pipe forced us to invoke the shell, this avoids any use of shell.
        $buf = $out;
    }

    if ($buf) {
        $res{'status'} .= $self->FormatStatus({
            Operation => "Sign", Status => "DONE",
            Message => "Signed message",
        }) if $args{'Sign'};
        $res{'status'} .= $self->FormatStatus({
            Operation => "Encrypt", Status => "DONE",
            Message => "Data has been encrypted",
        }) if $args{'Encrypt'};
    }

    return (\$buf, %res);
}

sub VerifyDecrypt {
    my $self = shift;
    my %args = ( Info => undef, @_ );

    my %res;
    my $item = $args{'Info'};
    if ( $item->{'Type'} eq 'signed' ) {
        %res = $self->Verify( %$item );
    } elsif ( $item->{'Type'} eq 'encrypted' ) {
        %res = $self->Decrypt( %args, %$item );
    } else {
        die "Unknown type '". $item->{'Type'} ."' of protected item";
    }

    return (%res, status_on => $item->{'Data'});
}

sub Verify {
    my $self = shift;
    my %args = (Data => undef, @_ );

    my $msg = $args{'Data'}->as_string;

    my %res;
    my $buf;
    my $keyfh = File::Temp->new;
    {
        local $SIG{CHLD} = 'DEFAULT';
        my $cmd = [
            $self->OpenSSLPath, qw(smime -verify -noverify),
            '-signer', $keyfh->filename,
        ];
        safe_run_child { run3( $cmd, \$msg, \$buf, \$res{'stderr'} ) };
        $res{'exit_code'} = $?;
    }
    if ( $res{'exit_code'} ) {
        if ($res{stderr} =~ /(signature|digest) failure/) {
            $res{'message'} = "Validation failed";
            $res{'status'} = $self->FormatStatus({
                Operation => "Verify", Status => "BAD",
                Message => "The signature did not verify",
            });
        } else {
            $res{'message'} = "openssl exited with error code ". ($? >> 8)
                ." and error: $res{stderr}";
            $res{'status'} = $self->FormatStatus({
                Operation => "Verify", Status => "ERROR",
                Message => "There was an error verifying: $res{stderr}",
            });
            $RT::Logger->error($res{'message'});
        }
        return %res;
    }

    my $signer;
    if ( my $key = do { $keyfh->seek(0, 0); local $/; readline $keyfh } ) {{
        my %info = $self->GetCertificateInfo( Certificate => $key );

        $signer = $info{info}[0];
        last unless $signer and $signer->{User}[0]{String};

        unless ( $info{info}[0]{TrustLevel} > 0 or RT->Config->Get('SMIME')->{AcceptUntrustedCAs}) {
            # We don't trust it; give it the finger
            $res{exit_code} = 1;
            $res{'message'} = "Validation failed";
            $res{'status'} = $self->FormatStatus({
                Operation => "Verify", Status => "BAD",
                Message => "The signing CA was not trusted",
                UserString => $signer->{User}[0]{String},
                Trust => "NONE",
            });
            return %res;
        }

        my ($address) = Email::Address->parse($signer->{User}[0]{String});
        my $user = RT::User->new( $RT::SystemUser );
        $user->LoadOrCreateByEmail(
            EmailAddress => $address->address,
            RealName     => $address->phrase,
            Comments     => 'Autocreated during SMIME parsing',
        );
        my $current_key = $user->SMIMECertificate;
        last if $current_key && $current_key eq $key;

        # Never over-write existing keys with untrusted ones.
        last if $current_key and not $info{info}[0]{TrustLevel} > 0;

        my ($status, $msg) = $user->SetSMIMECertificate( $key );
        $RT::Logger->error("Couldn't set SMIME certificate for user #". $user->id .": $msg")
            unless $status;
    }}

    my $res_entity = _extract_msg_from_buf( \$buf );
    unless ( $res_entity ) {
        $res{'exit_code'} = 1;
        $res{'message'} = "verified message, but couldn't parse result";
        $res{'status'} = $self->FormatStatus({
            Operation => "Verify", Status => "DONE",
            Message => "The signature is good, unknown signer",
            Trust => "UNKNOWN",
        });
        return %res;
    }

    $res_entity->make_multipart( 'mixed', Force => 1 );

    $args{'Data'}->make_multipart( 'mixed', Force => 1 );
    $args{'Data'}->parts([ $res_entity->parts ]);
    $args{'Data'}->make_singlepart;

    $res{'status'} = $self->FormatStatus({
        Operation => "Verify", Status => "DONE",
        Message => "The signature is good, signed by ".$signer->{User}[0]{String}.", trust is ".$signer->{TrustTerse},
        UserString => $signer->{User}[0]{String},
        Trust => uc($signer->{TrustTerse}),
    });

    return %res;
}

sub Decrypt {
    my $self = shift;
    my %args = (Data => undef, Queue => undef, @_ );

    my $msg = $args{'Data'}->as_string;

    push @{ $args{'Recipients'} ||= [] },
        $args{'Queue'}->CorrespondAddress, RT->Config->Get('CorrespondAddress'),
        $args{'Queue'}->CommentAddress, RT->Config->Get('CommentAddress')
    ;

    my ($buf, %res) = $self->_Decrypt( %args, Content => \$args{'Data'}->as_string );
    return %res unless $buf;

    my $res_entity = _extract_msg_from_buf( $buf );
    $res_entity->make_multipart( 'mixed', Force => 1 );

    # Work around https://rt.cpan.org/Public/Bug/Display.html?id=87835
    for my $part (grep {$_->is_multipart and $_->preamble and @{$_->preamble}} $res_entity->parts_DFS) {
        $part->preamble->[-1] .= "\n"
            if $part->preamble->[-1] =~ /\r$/;
    }

    $args{'Data'}->make_multipart( 'mixed', Force => 1 );
    $args{'Data'}->parts([ $res_entity->parts ]);
    $args{'Data'}->make_singlepart;

    return %res;
}

sub DecryptContent {
    my $self = shift;
    my %args = (
        Content => undef,
        @_
    );

    my ($buf, %res) = $self->_Decrypt( %args );
    ${ $args{'Content'} } = $$buf if $buf;
    return %res;
}

sub _Decrypt {
    my $self = shift;
    my %args = (Content => undef, @_ );

    my %seen;
    my @addresses =
        grep !$seen{lc $_}++, map $_->address, map Email::Address->parse($_),
        grep length && defined, @{$args{'Recipients'}};

    my ($buf, $encrypted_to, %res);

    foreach my $address ( @addresses ) {
        my $file = $self->CheckKeyring( Key => $address );
        unless ( $file ) {
            my $keyring = RT->Config->Get('SMIME')->{'Keyring'};
            $RT::Logger->debug("No key found for $address in $keyring directory");
            next;
        }

        local $ENV{SMIME_PASS} = $self->GetPassphrase( Address => $address );
        local $SIG{CHLD} = 'DEFAULT';
        my $cmd = [
            $self->OpenSSLPath,
            qw(smime -decrypt),
            -recip => $file,
            (defined $ENV{'SMIME_PASS'} && length $ENV{'SMIME_PASS'})
                ? (qw(-passin env:SMIME_PASS))
                : (),
        ];
        safe_run_child { run3( $cmd, $args{'Content'}, \$buf, \$res{'stderr'} ) };
        unless ( $? ) {
            $encrypted_to = $address;
            $RT::Logger->debug("Message encrypted for $encrypted_to");
            last;
        }

        if ( index($res{'stderr'}, 'no recipient matches key') >= 0 ) {
            $RT::Logger->debug("Although we have a key for $address, it is not the one that encrypted this message");
            next;
        }

        $res{'exit_code'} = $?;
        $res{'message'} = "openssl exited with error code ". ($? >> 8)
            ." and error: $res{stderr}";
        $RT::Logger->error( $res{'message'} );
        $res{'status'} = $self->FormatStatus({
            Operation => 'Decrypt', Status => 'ERROR',
            Message => 'Decryption failed',
            EncryptedTo => $address,
        });
        return (undef, %res);
    }
    unless ( $encrypted_to ) {
        $RT::Logger->error("Couldn't find SMIME key for addresses: ". join ', ', @addresses);
        $res{'exit_code'} = 1;
        $res{'status'} = $self->FormatStatus({
            Operation => 'KeyCheck',
            Status    => 'MISSING',
            Message   => "Secret key is not available",
            KeyType   => 'secret',
        });
        return (undef, %res);
    }

    $res{'status'} = $self->FormatStatus({
        Operation => 'Decrypt', Status => 'DONE',
        Message => 'Decryption process succeeded',
        EncryptedTo => $encrypted_to,
    });

    return (\$buf, %res);
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

sub _extract_msg_from_buf {
    my $buf = shift;
    my $rtparser = RT::EmailParser->new();
    my $parser   = MIME::Parser->new();
    $rtparser->_SetupMIMEParser($parser);
    $parser->decode_bodies(0);
    $parser->output_to_core(1);
    unless ( $rtparser->{'entity'} = $parser->parse_data($$buf) ) {
        $RT::Logger->crit("Couldn't parse MIME stream and extract the submessages");

        # Try again, this time without extracting nested messages
        $parser->extract_nested_messages(0);
        unless ( $rtparser->{'entity'} = $parser->parse_data($$buf) ) {
            $RT::Logger->crit("couldn't parse MIME stream");
            return (undef);
        }
    }
    return $rtparser->Entity;
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

        my %res = (
            Type   => $security_type,
            Format => 'RFC3851',
            Data   => $entity,
        );

        if ( $security_type eq 'encrypted' ) {
            my $top = $args{'TopEntity'}->head;
            $res{'Recipients'} = [map {Encode::decode("UTF-8", $_)}
                                      grep defined && length, map $top->get($_), 'To', 'Cc'];
        }

        return %res;
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

    my $email = $args{'Key'};
    unless ( $email ) {
        return (exit_code => 0); # unless $args{'Force'};
    }

    my $key = $self->GetKeyContent( %args );
    return (exit_code => 0) unless $key;

    return $self->GetCertificateInfo( Certificate => $key );
}

sub GetKeyContent {
    my $self = shift;
    my %args = ( Key => undef, @_ );

    my $key;
    if ( my $file = $self->CheckKeyring( %args ) ) {
        open my $fh, '<:raw', $file
            or die "Couldn't open file '$file': $!";
        $key = do { local $/; readline $fh };
        close $fh;
    }
    else {
        my $user = RT::User->new( RT->SystemUser );
        $user->LoadByEmail( $args{'Key'} );
        $key = $user->SMIMECertificate if $user->id;
    }
    return $key;
}

sub CheckKeyring {
    my $self = shift;
    my %args = (
        Key => undef,
        @_,
    );
    my $keyring = RT->Config->Get('SMIME')->{'Keyring'};
    return undef unless $keyring;

    my $file = File::Spec->catfile( $keyring, $args{'Key'} .'.pem' );
    return undef unless -f $file;

    return $file;
}

sub GetCertificateInfo {
    my $self = shift;
    my %args = (
        Certificate => undef,
        @_,
    );

    if ($args{Certificate} =~ /^-----BEGIN \s+ CERTIFICATE----- \s* $
                                (.*?)
                               ^-----END \s+ CERTIFICATE----- \s* $/smx) {
        $args{Certificate} = MIME::Base64::decode_base64($1);
    }

    my $cert = Crypt::X509->new( cert => $args{Certificate} );
    return ( exit_code => 1, stderr => $cert->error ) if $cert->error;

    my %USER_MAP = (
        Country          => 'country',
        StateOrProvince  => 'state',
        Organization     => 'org',
        OrganizationUnit => 'ou',
        Name             => 'cn',
        EmailAddress     => 'email',
    );
    my $canonicalize = sub {
        my $type = shift;
        my %data;
        for (keys %USER_MAP) {
            my $method = $type . "_" . $USER_MAP{$_};
            $data{$_} = $cert->$method if $cert->can($method);
        }
        $data{String} = Email::Address->new( @data{'Name', 'EmailAddress'} )->format
            if $data{EmailAddress};
        return \%data;
    };

    my $PEM = "-----BEGIN CERTIFICATE-----\n"
        . MIME::Base64::encode_base64( $args{Certificate} )
        . "-----END CERTIFICATE-----\n";

    my %res = (
        exit_code => 0,
        info => [ {
            Content         => $PEM,
            Fingerprint     => Digest::SHA::sha1_hex($args{Certificate}),
            'Serial Number' => $cert->serial,
            Created         => $self->ParseDate( $cert->not_before ),
            Expire          => $self->ParseDate( $cert->not_after ),
            Version         => sprintf("%d (0x%x)",hex($cert->version || 0)+1, hex($cert->version || 0)),
            Issuer          => [ $canonicalize->( 'issuer' ) ],
            User            => [ $canonicalize->( 'subject' ) ],
        } ],
        stderr => ''
    );

    # Check the validity
    my $ca = RT->Config->Get('SMIME')->{'CAPath'};
    if ($ca) {
        my @ca_verify;
        if (-d $ca) {
            @ca_verify = ('-CApath', $ca);
        } elsif (-f $ca) {
            @ca_verify = ('-CAfile', $ca);
        }

        local $SIG{CHLD} = 'DEFAULT';
        my $cmd = [
            $self->OpenSSLPath,
            'verify', @ca_verify,
        ];
        my $buf = '';
        safe_run_child { run3( $cmd, \$PEM, \$buf, \$res{stderr} ) };

        if ($buf =~ /^stdin: OK$/) {
            $res{info}[0]{Trust} = "Signed by trusted CA $res{info}[0]{Issuer}[0]{String}";
            $res{info}[0]{TrustTerse} = "full";
            $res{info}[0]{TrustLevel} = 2;
        } elsif ($? == 0 or ($? >> 8) == 2) {
            $res{info}[0]{Trust} = "UNTRUSTED signing CA $res{info}[0]{Issuer}[0]{String}";
            $res{info}[0]{TrustTerse} = "none";
            $res{info}[0]{TrustLevel} = -1;
        } else {
            $res{exit_code} = $?;
            $res{message} = "openssl exited with error code ". ($? >> 8)
                ." and stout: $buf";
            $res{info}[0]{Trust} = "unknown (openssl failed)";
            $res{info}[0]{TrustTerse} = "unknown";
            $res{info}[0]{TrustLevel} = 0;
        }
    } else {
        $res{info}[0]{Trust} = "unknown (no CAPath set)";
        $res{info}[0]{TrustTerse} = "unknown";
        $res{info}[0]{TrustLevel} = 0;
    }

    $res{info}[0]{Formatted} = $res{info}[0]{User}[0]{String}
        . " (issued by $res{info}[0]{Issuer}[0]{String})";

    return %res;
}

1;
