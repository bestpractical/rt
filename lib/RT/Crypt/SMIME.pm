
use strict;
use warnings;

package RT::Crypt::SMIME;
use base 'RT::Crypt::Base';

use RT::Crypt;
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


    my %res = (exit_code => 0, status => '');

    my @keys;
    if ( $args{'Encrypt'} ) {
        my @addresses =
            map $_->address,
            map Email::Address->parse($_),
            grep defined && length,
            map $entity->head->get($_),
            qw(To Cc Bcc);

        foreach my $address ( @addresses ) {
            $RT::Logger->debug( "Considering encrypting message to " . $address );

            my %key_info = $self->GetKeysInfo( Key => $address );
            unless ( %key_info ) {
                $res{'exit_code'} = 1;
                my $reason = 'Key not found';
                $res{'status'} .=
                    "Operation: RecipientsCheck\nStatus: ERROR\n"
                    ."Message: Recipient '$address' is unusable, the reason is '$reason'\n"
                    ."Recipient: $address\n"
                    ."Reason: $reason\n\n",
                ;
                next;
            }

            unless ( $key_info{'info'}[0]{'Expire'} ) {
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
                $res{'status'} .=
                    "Operation: RecipientsCheck\nStatus: ERROR\n"
                    ."Message: Recipient '$address' is unusable, the reason is '$reason'\n"
                    ."Recipient: $address\n"
                    ."Reason: $reason\n\n",
                ;
                next;
            }
            push @keys, $key_info{'info'}[0]{'Content'};
        }
    }
    return %res if $res{'exit_code'};

    my $opts = RT->Config->Get('SMIME');

    my @command;
    if ( $args{'Sign'} ) {
        # XXX: implement support for -nodetach
        $args{'Passphrase'} = $self->GetPassphrase( Address => $args{'Signer'} )
            unless defined $args{'Passphrase'};

        push @command, join ' ', shell_quote(
            $self->OpenSSLPath, qw(smime -sign -passin env:SMIME_PASS),
            -signer => $opts->{'Keyring'} .'/'. $args{'Signer'} .'.pem',
            -inkey  => $opts->{'Keyring'} .'/'. $args{'Signer'} .'.pem',
        );
    }
    if ( $args{'Encrypt'} ) {
        foreach my $key ( @keys ) {
            my $key_file = File::Temp->new;
            print $key_file $key;
            $key = $key_file;
        }
        push @command, join ' ', shell_quote(
            $self->OpenSSLPath, qw(smime -encrypt -des3),
            map { $_->filename } @keys
        );
    }

    $entity->make_multipart('mixed', Force => 1);
    my ($buf, $err) = ('', '');
    {
        local $ENV{'SMIME_PASS'} = $args{'Passphrase'};
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

sub VerifyRFC3156 {
    my $self = shift;
    my %args = ( Top => undef, Data => undef, Signature => undef, @_);
    return $self->VerifyRFC3851( %args, Data => $args{'Top'} );
}

sub VerifyRFC3851 {
    my $self = shift;
    my %args = (Data => undef, Queue => undef, @_ );

    my $msg = $args{'Data'}->as_string;
    $msg =~ s/\r*\n/\x0D\x0A/g;

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

    my %res;

    my $msg = $args{'Data'}->as_string;

    my $action = 'correspond';
    $action = 'comment' if grep defined && $_ eq 'comment', @{ $args{'Actions'}||[] };

    my $address = $action eq 'correspond'
        ? $args{'Queue'}->CorrespondAddress || RT->Config->Get('CorrespondAddress')
        : $args{'Queue'}->CommentAddress    || RT->Config->Get('CommentAddress');
    my $key_file = File::Spec->catfile( 
        RT->Config->Get('SMIME')->{'Keyring'}, $address .'.pem'
    );
    unless ( -e $key_file && -r _ ) {
        $res{'exit_code'} = 1;
        $res{'status'} = $self->FormatStatus({
            Operation => 'KeyCheck',
            Status    => 'MISSING',
            Message   => "Secret key for '$address' is not available",
            Key       => $address,
            KeyType   => 'secret',
        });
        $res{'User'} = {
            String => $address,
            SecretKeyMissing => 1,
        };
        return %res;
    }

    my $buf;
    {
        local $ENV{SMIME_PASS} = $self->GetPassphrase( Address => $address );
        local $SIG{CHLD} = 'DEFAULT';
        my $cmd = join( ' ', shell_quote(
            $self->OpenSSLPath,
            qw(smime -decrypt -passin env:SMIME_PASS),
            -recip => $key_file,
        ) );
        safe_run_child { run3( $cmd, \$msg, \$buf, \$res{'stderr'} ) };
        $res{'exit_code'} = $?;
    }
    if ( $res{'exit_code'} ) {
        $res{'message'} = "openssl exitted with error code ". ($? >> 8)
            ." and error: $res{stderr}";
        $res{'status'} = $self->FormatStatus({
            Operation => 'Decrypt', Status => 'ERROR',
            Message => 'Decryption failed',
            EncryptedTo => $address,
        });
        return %res;
    }

    my $res_entity = _extract_msg_from_buf( \$buf, 1 );
    $res_entity->make_multipart( 'mixed', Force => 1 );

    $args{'Data'}->make_multipart( 'mixed', Force => 1 );
    $args{'Data'}->parts([ $res_entity->parts ]);
    $args{'Data'}->make_singlepart;

    $res{'status'} = $self->FormatStatus({
        Operation => 'Decrypt', Status => 'DONE',
        Message => 'Decryption process succeeded',
        EncryptedTo => $address,
    });

    return %res;
}

sub FormatStatus {
    my $self = shift;
    my @status = @_;

    my $res = '';
    foreach ( @status ) {
        $res .= "\n" if $res;
        while ( my ($k, $v) = each %$_ ) {
            $res .= $k .": ". $v ."\n";
        }
    }

    return $res;
}

sub ParseStatus {
    my $self = shift;
    my $status = shift;
    return () unless $status;

    my @status = split /\n\n/, $status;
    foreach my $block ( grep length, @status ) {
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
    my $exact = shift;
    my $rtparser = RT::EmailParser->new();
    my $parser   = MIME::Parser->new();
    $rtparser->_SetupMIMEParser($parser);
    $parser->decode_bodies(0) if $exact;
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

        unless (
            $protocol eq 'application/x-pkcs7-signature'
            || $protocol eq 'application/pkcs7-signature'
        ) {
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

sub GetPassphrase {
    my $self = shift;
    my %args = (Address => undef, @_);
    $args{'Address'} = '' unless defined $args{'Address'};
    return RT->Config->Get('SMIME')->{'Passphrase'}->{ $args{'Address'} };
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
        # XXX: should we use different user??
        my $user = RT::User->new( $RT::SystemUser );
        $user->LoadByEmail( $args{'Key'} );
        unless ( $user->id ) {
            return (exit_code => 0);
        }

        $key = $user->FirstCustomFieldValue('SMIME Key');
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

    my %res;
    my $buf;
    {
        local $SIG{CHLD} = 'DEFAULT';
        my $cmd = join ' ', shell_quote(
            $self->OpenSSLPath, 'x509',
            # everything
            '-text',
            # plus fingerprint
            '-fingerprint',
            # don't print cert itself
            '-noout',
            # don't dump signature and pubkey info, header is useless too
            '-certopt', 'no_pubkey,no_sigdump,no_extensions',
            # subject and issuer are multiline, long prop names, utf8
            '-nameopt', 'sep_multiline,lname,utf8',
        );
        safe_run_child { run3( $cmd, \$args{'Certificate'}, \$buf, \$res{'stderr'} ) };
        $res{'exit_code'} = $?;
    }
    if ( $res{'exit_code'} ) {
        $res{'message'} = "openssl exitted with error code ". ($? >> 8)
            ." and error: $res{stderr}";
        return %res;
    }

    my %info = $self->CanonicalizeInfo( $self->ParseCertificateInfo( $buf ) );
    $info{'Content'} = $args{'Certificate'};
    $res{'info'} = [\%info];
    return %res;
}

my %SHORT_NAMES = (
    C => 'Country',
    ST => 'StateOrProvince',
    O  => 'Organization',
    OU => 'OrganizationUnit',
    CN => 'Name',
);
my %LONG_NAMES = (
    countryName => 'Country',
    stateOrProvinceName => 'StateOrProvince',
    organizationName => 'Organization',
    organizationalUnitName => 'OrganizationUnit',
    commonName => 'Name',
    emailAddress => 'EmailAddress',
);

sub CanonicalizeInfo {
    my $self = shift;
    my %info = @_;

    my %res = (
        # XXX: trust is not implmented for SMIME
        TrustLevel => 1,
    );
    if ( my $subject = delete $info{'Certificate'}{'Data'}{'Subject'} ) {
        $res{'User'} = [
            { $self->CanonicalizeUserInfo( %$subject ) },
        ];
    }
    if ( my $issuer = delete $info{'Certificate'}{'Data'}{'Issuer'} ) {
        $res{'Issuer'} = [
            { $self->CanonicalizeUserInfo( %$issuer ) },
        ];
    }
    if ( my $validity = delete $info{'Certificate'}{'Data'}{'Validity'} ) {
        $res{'Created'} = $self->ParseDate( $validity->{'Not Before'} );
        $res{'Expire'} = $self->ParseDate( $validity->{'Not After'} );
    }
    {
        $res{'Fingerprint'} = delete $info{'SHA1 Fingerprint'};
    }
    %res = (%{$info{'Certificate'}{'Data'}}, %res);
    return %res;
}

sub ParseCertificateInfo {
    my $self = shift;
    my $info = shift;

    my @lines = split /\n/, $info;

    my %res;
    my %prefix = ();
    my $first_line = 1;
    my $prev_prefix = '';
    my $prev_key = '';

    foreach my $line ( @lines ) {
        # some examples:
        # Validity # no trailing ':'
        # Not After : XXXXXX # space before ':'
        # countryName=RU # '=' as separator
        my ($prefix, $key, $value) = ($line =~ /^(\s*)(.*?)\s*(?:[:=]\s*(.*?)|)\s*$/);
        if ( $first_line ) {
            $prefix{$prefix} = \%res;
            $first_line = 0;
        }

        my $put_into = ($prefix{$prefix} ||= $prefix{$prev_prefix}{$prev_key});
        unless ( $put_into ) {
            die "Couldn't parse key info: $info";
        }

        if ( defined $value && length $value ) {
            $put_into->{$key} = $value;
        }
        else {
            $put_into->{$key} = {};
        }
        delete $prefix{$_} foreach
            grep length($_) > length($prefix),
            keys %prefix;

        ($prev_prefix, $prev_key) = ($prefix, $key);
    }

    return %res;
}

sub ParsePKCS7Info {
    my $self = shift;
    my $string = shift;

    return () unless defined $string && length $string && $string =~ /\S/;

    my @res = ({});
    foreach my $str ( split /\r*\n/, $string ) {
        if ( $str =~ /^\s*$/ ) {
            push @res, {} if keys %{ $res[-1] };
        } elsif ( my ($who, $values) = ($str =~ /^(subject|issuer)=(.*)$/i) ) {
            my %info;
            while ( $values =~ s{^/([a-z]+)=(.*?)(?=$|/[a-z]+=)}{}i ) {
                $info{ $1 } = $2;
            }
            die "Couldn't parse PKCS7 info: $string" if $values;

            $res[-1]{ ucfirst lc $who } = { $self->CanonicalizeUserInfo( %info ) };
        }
        else {
            $res[-1]{'Content'} ||= '';
            $res[-1]{'Content'} .= $str ."\n";
        }
    }

    # oddly, but a certificate can be duplicated
    my %seen;
    @res = grep !$seen{ $_->{'Content'} }++, grep keys %$_, @res;
    $_->{'User'} = delete $_->{'Subject'} foreach @res;
    
    return @res;
}

sub CanonicalizeUserInfo {
    my $self = shift;
    my %info = @_;

    my %res;
    while ( my ($k, $v) = each %info ) {
        $res{ $SHORT_NAMES{$k} || $LONG_NAMES{$k} || $k } = $v;
    }
    if ( $res{'EmailAddress'} ) {
        my $email = Email::Address->new( @res{'Name', 'EmailAddress'} );
        $res{'String'} = $email->format;
    }
    return %res;
}

1;
