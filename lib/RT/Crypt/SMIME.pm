
use strict;
use warnings;

package RT::Crypt::SMIME;
use base 'RT::Crypt::Base';

use IPC::Run3 0.036 'run3';
use String::ShellQuote 'shell_quote';
use RT::Util 'safe_run_child';

{ my $cache = shift;
sub OpenSSLPath {
    return $cache ||= RT->Config->Get('SMIME')->{'OpenSSL'};
} }

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

    if ( $args{'Sign'} && !defined $args{'Passphrase'} ) {
        $args{'Passphrase'} = $self->GetPassphrase( Address => $args{'Signer'} );
    }

    my %res = (exit_code => 0, status => []);

    my @addresses =
        map $_->address,
        Email::Address->parse($_),
        grep defined && length,
        map $entity->head->get($_),
        qw(To Cc Bcc);

    my @keys;
    foreach my $address ( @addresses ) {
        $RT::Logger->debug( "Considering encrypting message to " . $address );
        my $user = RT::User->new( $RT::SystemUser );
        $user->LoadByEmail( $address );

        my $key;
        $key = $user->FirstCustomFieldValue('PublicKey') if $user->id;
        unless ( $key ) {
            $res{'exit_code'} = 1;
            my $reason = 'Key not found';
            push @{ $res{'status'} }, {
                Operation  => 'RecipientsCheck',
                Status     => 'ERROR',
                Message    => "Recipient '$address' is unusable, the reason is '$reason'",
                Recipient  => $address,
                Reason     => $reason,
            };
            next;
        }

        my $expire = $self->GetKeyExpiration( $user );
        unless ( $expire ) {
            # we continue here as it's most probably a problem with the key,
            # so later during encryption we'll get verbose errors
            $RT::Logger->error(
                "Trying to send an encrypted message to ". $address
                .", but we couldn't get expiration date of the key."
            );
        }
        elsif ( $expire->Diff( time ) < 0 ) {
            $res{'exit_code'} = 1;
            my $reason = 'Key expired';
            push @{ $res{'status'} }, {
                Operation  => 'RecipientsCheck',
                Status     => 'ERROR',
                Message    => "Recipient '$address' is unusable, the reason is '$reason'",
                Recipient  => $address,
                Reason     => $reason,
            };
            next;
        }
        push @keys, $key;
    }
    return %res if $res{'exit_code'};

    foreach my $key ( @keys ) {
        my $key_file = File::Temp->new;
        print $key_file $key;
        $key = $key_file;
    }

    my $opts = RT->Config->Get('SMIME');

    $entity->make_multipart('mixed', Force => 1);
    my ($buf, $err) = ('', '');
    {
        local $ENV{'SMIME_PASS'};
        
        my @command;
        if ( $args{'Sign'} ) {
            $ENV{'SMIME_PASS'} = $args{'Passphrase'};
            push @command, join ' ', shell_quote(
                $self->OpenSSLPath, qw(smime -sign -passin env:SMIME_PASS),
                -signer => $opts->{'Keyring'} .'/'. $args{'Signer'} .'.pem',
                -inkey  => $opts->{'Keyring'} .'/'. $args{'Signer'} .'.pem',
            );
        }
        if ( $args{'Encrypt'} ) {
            push @command, join ' ', shell_quote(
                $self->OpenSSLPath, qw(smime -encrypt -des3),
                map { $_->filename } @keys
            );
        }

        local $SIG{'CHLD'} = 'DEFAULT';
        safe_run_child { run3(
            join( ' | ', @command ),
            \$entity->parts(0)->stringify,
            \$buf, \$err
        ) };
    }
    $RT::Logger->debug( "openssl stderr: " . $err ) if length $err;

    my $tmpdir = File::Temp::tempdir( TMPDIR => 1, CLEANUP => 1 );
    my $parser = MIME::Parser->new();
    $parser->output_dir($tmpdir);
    my $newmime = $parser->parse_data($buf);

    $entity->parts([$newmime]);
    $entity->make_singlepart;

    return %res;
}

sub VerifyDecrypt {
    my $self = shift;
    my %args = (
        Info      => undef,
        Detach    => 1,
        SetStatus => 1,
        AddStatus => 0,
        @_
    );

    my %res;

    my $item = $args{'Info'};
    if ( $item->{'Type'} eq 'signed' ) {
        my $status_on;
        if ( $item->{'Format'} eq 'RFC3156' ) {
            $status_on = $item->{'Top'};
            %res = $self->VerifyRFC3156( %$item, SetStatus => $args{'SetStatus'} );
            if ( $args{'Detach'} ) {
                $item->{'Top'}->parts( [ $item->{'Data'} ] );
                $item->{'Top'}->make_singlepart;
            }
        }
        elsif ( $item->{'Format'} eq 'RFC3851' ) {
            $status_on = $item->{'Data'};
            %res = $self->VerifyRFC3851( %$item, SetStatus => $args{'SetStatus'} );
        }
        else {
            die "Unknow signature format. Shouldn't ever happen.";
        }
        if ( $args{'SetStatus'} || $args{'AddStatus'} ) {
            my $method = $args{'AddStatus'} ? 'add' : 'set';
            $status_on->head->$method(
                'X-RT-SMIME-Status' => $res{'status'}
            );
        }
    } elsif ( $item->{'Type'} eq 'encrypted' ) {
        %res = $self->DecryptRFC3851( %args, %$item );
        if ( $args{'SetStatus'} || $args{'AddStatus'} ) {
            my $method = $args{'AddStatus'} ? 'add' : 'set';
            $item->{'Data'}->head->$method(
                'X-RT-SMIME-Status' => $res{'status'}
            );
        }
    } else {
        die "Unknow type '". $item->{'Type'} ."' of protected item";
    }
    return %res;
}

sub VerifyRFC3851 {
    my $self = shift;
    my %args = (Data => undef, Queue => undef, @_ );

    my $msg = $args{'Data'}->as_string;

    my %res;
    my $buf;
    {
        local $SIG{CHLD} = 'DEFAULT';
        my $cmd = join( ' ', shell_quote(
            $self->OpenSSLPath, qw(smime -verify -noverify),
        ) );
        safe_run_child { run3( $cmd, \$msg, \$buf, \$res{'stderr'} ) };
        $res{'exit_code'} = $?;
    }
    if ( $res{'exit_code'} ) {
        $res{'message'} = "openssl exitted with error code ". ($? >> 8)
            ." and error: $res{stderr}";
        return %res;
    }

    my $res_entity = _extract_msg_from_buf( \$buf );
    unless ( $res_entity ) {
        $res{'exit_code'} = 1;
        $res{'message'} = "verified message, but couldn't parse result";
        return %res;
    }
    $res_entity->make_multipart( 'mixed', Force => 1 );

    $args{'Data'}->make_multipart( 'mixed', Force => 1 );
    $args{'Data'}->parts([ $res_entity->parts ]);
    $args{'Data'}->make_singlepart;

    $res{'status'} =
        "Operation: Verify\nStatus: DONE\n"
        ."Message: The signature is good\n"
    ;

    return %res;
}

sub DecryptRFC3851 {
    my $self = shift;
    my %args = (Data => undef, Queue => undef, @_ );

    my $msg = $args{'Data'}->as_string;

    my $action = 'correspond';
    $action = 'comment' if grep defined && $_ eq 'comment', @{ $args{'Actions'}||[] };

    my $address = $action eq 'correspond'
        ? $args{'Queue'}->CorrespondAddress || RT->Config->Get('CorrespondAddress')
        : $args{'Queue'}->CommentAddress    || RT->Config->Get('CommentAddress');

    my %res;
    my $buf;
    {
        local $ENV{SMIME_PASS} = $self->GetPassphrase( Address => $address );
        local $SIG{CHLD} = 'DEFAULT';
        my $cmd = join( ' ', shell_quote(
            $self->OpenSSLPath,
            qw(smime -decrypt -passin env:SMIME_PASS),
            -recip => RT->Config->Get('SMIME')->{'Keyring'} .'/'. $address .'.pem',
        ) );
        safe_run_child { run3( $cmd, \$msg, \$buf, \$res{'stderr'} ) };
        $res{'exit_code'} = $?;
    }
    if ( $res{'exit_code'} ) {
        $res{'message'} = "openssl exitted with error code ". ($? >> 8)
            ." and error: $res{stderr}";
        return %res;
    }

    my $res_entity = _extract_msg_from_buf( \$buf );
    $res_entity->make_multipart( 'mixed', Force => 1 );

    $args{'Data'}->make_multipart( 'mixed', Force => 1 );
    $args{'Data'}->parts([ $res_entity->parts ]);
    $args{'Data'}->make_singlepart;

    $res{'status'} =
        "Operation: Decrypt\nStatus: DONE\n"
        ."Message: Decryption process succeeded\n"
        ."EncryptedTo: $address\n";

    return %res;
}

sub ParseStatus {
    my $self = shift;
    my $status = shift;
    return () unless $status;

    my @status = split /\n\n/, $status;
    foreach my $block ( @status ) {
        chomp $block;
        $block = { map { s/^\s+//; s/\s+$//; $_ } map split(/:/, $_, 2), split /\n+/, $block };
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
    $rtparser->_PostProcessNewEntity;
    return $rtparser->Entity;
}


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
        return () if !$security_type && $type eq 'application/octet-stream';

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

        unless ( $protocol eq 'application/pgp-signature' ) {
            $RT::Logger->info( "Skipping protocol '$protocol', only 'application/pgp-signature' is supported" );
            return ();
        }
        $RT::Logger->debug("Found part signed according to RFC3156");
        return (
            Type      => 'signed',
            Format    => 'RFC3156',
            Top       => $entity,
            Data      => $entity->parts(0),
            Signature => $entity->parts(1),
        );
    }
    return ();
}

sub KeyExpirationDate {
    my $self = shift;
    my %args = (@_);

    my $user = $args{'User'};

    my $key_obj = $user->CustomFieldValues('PublicKey')->First;
    unless ( $key_obj ) {
        $RT::Logger->warn('User #'. $user->id .' has no SMIME key');
        return;
    }

    my $attr = $user->FirstAttribute('SMIMEKeyNotAfter');
    if ( $attr and my $date_str = $attr->Content
         and $key_obj->LastUpdatedObj->Unix < $attr->LastUpdatedObj->Unix )
    {
        my $date = RT::Date->new( $RT::SystemUser );
        $date->Set( Format => 'unknown', Value => $attr->Content );
        return $date;
    }
    $RT::Logger->debug('Expiration date of SMIME key is not up to date');

    my $key = $key_obj->Content;

    my ($buf, $err) = ('', '');
    {
        local $ENV{SMIME_PASS} = '123456';
        safe_run3(
            join( ' ', shell_quote( $self->OpenSSLPath, qw(x509 -noout -dates) ) ),
            \$key, \$buf, \$err
        );
    }
    $RT::Logger->debug( "openssl stderr: " . $err ) if length $err;

    my ($date_str) = ($buf =~ /^notAfter=(.*)$/m);
    return unless $date_str;

    $RT::Logger->debug( "smime key expiration date is $date_str" );
    $user->SetAttribute(
        Name => 'SMIMEKeyNotAfter',
        Description => 'SMIME key expiration date',
        Content => $date_str,
    );
    my $date = RT::Date->new( $RT::SystemUser );
    $date->Set( Format => 'unknown', Value => $date_str );
    return $date;
}

sub GetPassphrase {
    my $self = shift;
    my %args = (Address => undef, @_);
    $args{'Address'} = '' unless defined $args{'Address'};
    return RT->Config->Get('SMIME')->{'Passphrase'}->{ $args{'Address'} };
}

1;
