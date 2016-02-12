# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2016 Best Practical Solutions, LLC
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

package RT::Crypt::GnuPG;

use IO::Handle;
use GnuPG::Interface;
use RT::EmailParser ();
use RT::Util 'safe_run_child', 'mime_recommended_filename';

=head1 NAME

RT::Crypt::GnuPG - encrypt/decrypt and sign/verify email messages with the GNU Privacy Guard (GPG)

=head1 DESCRIPTION

This module provides support for encryption and signing of outgoing messages, 
as well as the decryption and verification of incoming email.

=head1 CONFIGURATION

You can control the configuration of this subsystem from RT's configuration file.
Some options are available via the web interface, but to enable this functionality, you
MUST start in the configuration file.

There are two hashes, GnuPG and GnuPGOptions in the configuration file. The 
first one controls RT specific options. It enables you to enable/disable facility 
or change the format of messages. The second one is a hash with options for the 
'gnupg' utility. You can use it to define a keyserver, enable auto-retrieval keys 
and set almost any option 'gnupg' supports on your system.

=head2 %GnuPG

=head3 Enabling GnuPG

Set to true value to enable this subsystem:

    Set( %GnuPG,
        Enable => 1,
        ... other options ...
    );

However, note that you B<must> add the 'Auth::GnuPG' email filter to enable
the handling of incoming encrypted/signed messages.

=head3 Format of outgoing messages

Format of outgoing messages can be controlled using the 'OutgoingMessagesFormat'
option in the RT config:

    Set( %GnuPG,
        ... other options ...
        OutgoingMessagesFormat => 'RFC',
        ... other options ...
    );

or

    Set( %GnuPG,
        ... other options ...
        OutgoingMessagesFormat => 'Inline',
        ... other options ...
    );

This framework implements two formats of signing and encrypting of email messages:

=over

=item RFC

This format is also known as GPG/MIME and described in RFC3156 and RFC1847.
Technique described in these RFCs is well supported by many mail user
agents (MUA), but some MUAs support only inline signatures and encryption,
so it's possible to use inline format (see below).

=item Inline

This format doesn't take advantage of MIME, but some mail clients do
not support GPG/MIME.

We sign text parts using clear signatures. For each attachments another
attachment with a signature is added with '.sig' extension.

Encryption of text parts is implemented using inline format, other parts
are replaced with attachments with the filename extension '.pgp'.

This format is discouraged because modern mail clients typically don't support
it well.

=back

=head3 Encrypting data in the database

You can allow users to encrypt data in the database using
option C<AllowEncryptDataInDB>. By default it's disabled.
Users must have rights to see and modify tickets to use
this feature.

=head2 %GnuPGOptions

Use this hash to set options of the 'gnupg' program. You can define almost any
option you want which  gnupg supports, but never try to set options which
change output format or gnupg's commands, such as --sign (command),
--list-options (option) and other.

Some GnuPG options take arguments while others take none. (Such as  --use-agent).
For options without specific value use C<undef> as hash value.
To disable these option just comment them out or delete them from the hash

    Set(%GnuPGOptions,
        'option-with-value' => 'value',
        'enabled-option-without-value' => undef,
        # 'commented-option' => 'value or undef',
    );

B<NOTE> that options may contain '-' character and such options B<MUST> be
quoted, otherwise you can see quite cryptic error 'gpg: Invalid option "--0"'.

=over

=item --homedir

The GnuPG home directory, by default it is set to F</opt/rt4/var/data/gpg>.

You can manage this data with the 'gpg' commandline utility 
using the GNUPGHOME environment variable or --homedir option. 
Other utilities may be used as well.

In a standard installation, access to this directory should be granted to
the web server user which is running RT's web interface, but if you're running
cronjobs or other utilities that access RT directly via API and may generate
encrypted/signed notifications then the users you execute these scripts under
must have access too. 

However, granting access to the dir to many users makes your setup less secure,
some features, such as auto-import of keys, may not be available if you do not.
To enable this features and suppress warnings about permissions on
the dir use --no-permission-warning.

=item --digest-algo

This option is required in advance when RFC format for outgoing messages is
used. We can not get default algorithm from gpg program so RT uses 'SHA1' by
default. You may want to override it. You can use MD5, SHA1, RIPEMD160,
SHA256 or other, however use `gpg --version` command to get information about
supported algorithms by your gpg. These algorithms are listed as hash-functions.

=item --use-agent

This option lets you use GPG Agent to cache the passphrase of RT's key. See
L<http://www.gnupg.org/documentation/manuals/gnupg/Invoking-GPG_002dAGENT.html>
for information about GPG Agent.

=item --passphrase

This option lets you set the passphrase of RT's key directly. This option is
special in that it isn't passed directly to GPG, but is put into a file that
GPG then reads (which is more secure). The downside is that anyone who has read
access to your RT_SiteConfig.pm file can see the passphrase, thus we recommend
the --use-agent option instead.

=item other

Read `man gpg` to get list of all options this program support.

=back

=head2 Per-queue options

Using the web interface it's possible to enable signing and/or encrypting by
default. As an administrative user of RT, open 'Configuration' then 'Queues',
and select a queue. On the page you can see information about the queue's keys 
at the bottom and two checkboxes to choose default actions.

As well, encryption is enabled for autoreplies and other notifications when
an encypted message enters system via mailgate interface even if queue's
option is disabled.

=head2 Handling incoming messages

To enable handling of encrypted and signed message in the RT you should add
'Auth::GnuPG' mail plugin.

    Set(@MailPlugins, 'Auth::MailFrom', 'Auth::GnuPG', ...other filter...);

See also `perldoc lib/RT/Interface/Email/Auth/GnuPG.pm`.

=head2 Errors handling

There are several global templates created in the database by default. RT
uses these templates to send error messages to users or RT's owner. These 
templates have 'Error:' or 'Error to RT owner:' prefix in the name. You can 
adjust the text of the messages using the web interface.

Note that C<$TicketObj>, C<$TransactionObj> and other variable usually available
in RT's templates are not available in these templates, but each template
used for errors reporting has set of available data structures you can use to
build better messages. See default templates and descriptions below.

As well, you can disable particular notification by deleting content of
a template. You can delete a template too, but in this case you'll see
error messages in the logs when RT can not load template you've deleted.

=head3 Problems with public keys

Template 'Error: public key' is used to inform the user that RT has problems with
his public key and won't be able to send him encrypted content. There are several 
reasons why RT can't use a key. However, the actual reason is not sent to the user, 
but sent to RT owner using 'Error to RT owner: public key'.

The possible reasons: "Not Found", "Ambiguous specification", "Wrong
key usage", "Key revoked", "Key expired", "No CRL known", "CRL too
old", "Policy mismatch", "Not a secret key", "Key not trusted" or
"No specific reason given".

Due to limitations of GnuPG, it's impossible to encrypt to an untrusted key,
unless 'always trust' mode is enabled.

In the 'Error: public key' template there are a few additional variables available:

=over 4

=item $Message - user friendly error message

=item $Reason - short reason as listed above

=item $Recipient - recipient's identification

=item $AddressObj - L<Email::Address> object containing recipient's email address

=back

A message can have several invalid recipients, to avoid sending many emails
to the RT owner the system sends one message to the owner, grouped by
recipient. In the 'Error to RT owner: public key' template a C<@BadRecipients>
array is available where each element is a hash reference that describes one
recipient using the same fields as described above. So it's something like:

    @BadRecipients = (
        { Message => '...', Reason => '...', Recipient => '...', ...},
        { Message => '...', Reason => '...', Recipient => '...', ...},
        ...
    )

=head3 Private key doesn't exist

Template 'Error: no private key' is used to inform the user that
he sent an encrypted email, but we have no private key to decrypt
it.

In this template C<$Message> object of L<MIME::Entity> class
available. It's the message RT received.

=head3 Invalid data

Template 'Error: bad GnuPG data' used to inform the user that a
message he sent has invalid data and can not be handled.

There are several reasons for this error, but most of them are data
corruption or absence of expected information.

In this template C<@Messages> array is available and contains list
of error messages.

=head1 FOR DEVELOPERS

=head2 Documentation and references

* RFC1847 - Security Multiparts for MIME: Multipart/Signed and Multipart/Encrypted.
Describes generic MIME security framework, "mulitpart/signed" and "multipart/encrypted"
MIME types.

* RFC3156 - MIME Security with Pretty Good Privacy (PGP),
updates RFC2015.

=cut

# gnupg options supported by GnuPG::Interface
# other otions should be handled via extra_args argument
my %supported_opt = map { $_ => 1 } qw(
       always_trust
       armor
       batch
       comment
       compress_algo
       default_key
       encrypt_to
       extra_args
       force_v3_sigs
       homedir
       logger_fd
       no_greeting
       no_options
       no_verbose
       openpgp
       options
       passphrase_fd
       quiet
       recipients
       rfc1991
       status_fd
       textmode
       verbose
);

our $RE_FILE_EXTENSIONS = qr/pgp|asc/i;

# DEV WARNING: always pass all STD* handles to GnuPG interface even if we don't
# need them, just pass 'IO::Handle->new()' and then close it after safe_run_child.
# we don't want to leak anything into FCGI/Apache/MP handles, this break things.
# So code should look like:
#        my $handles = GnuPG::Handles->new(
#            stdin  => ($handle{'stdin'}  = IO::Handle->new()),
#            stdout => ($handle{'stdout'} = IO::Handle->new()),
#            stderr => ($handle{'stderr'}  = IO::Handle->new()),
#            ...
#        );

=head2 SignEncrypt Entity => MIME::Entity, [ Encrypt => 1, Sign => 1, ... ]

Signs and/or encrypts an email message with GnuPG utility.

=over

=item Signing

During signing you can pass C<Signer> argument to set key we sign with this option
overrides gnupg's C<default-key> option. If C<Signer> argument is not provided
then address of a message sender is used.

As well you can pass C<Passphrase>, but if value is undefined then L</GetPassphrase>
called to get it.

=item Encrypting

During encryption you can pass a C<Recipients> array, otherwise C<To>, C<Cc> and
C<Bcc> fields of the message are used to fetch the list.

=back

Returns a hash with the following keys:

* exit_code
* error
* logger
* status
* message

=cut

sub SignEncrypt {
    my %args = (@_);

    my $entity = $args{'Entity'};
    if ( $args{'Sign'} && !defined $args{'Signer'} ) {
        my @addresses = Email::Address->parse( Encode::decode("UTF-8",$entity->head->get( 'From' )));
        $args{'Signer'} = UseKeyForSigning()
            || $addresses[0]->address;
    }
    if ( $args{'Encrypt'} && !$args{'Recipients'} ) {
        my %seen;
        $args{'Recipients'} = [
            grep $_ && !$seen{ $_ }++, map $_->address,
            map Email::Address->parse( Encode::decode("UTF-8",$entity->head->get( $_ ) ) ),
            qw(To Cc Bcc)
        ];
    }
    
    my $format = lc RT->Config->Get('GnuPG')->{'OutgoingMessagesFormat'} || 'RFC';
    if ( $format eq 'inline' ) {
        return SignEncryptInline( %args );
    } else {
        return SignEncryptRFC3156( %args );
    }
}

sub SignEncryptRFC3156 {
    my %args = (
        Entity => undef,

        Sign => 1,
        Signer => undef,
        Passphrase => undef,

        Encrypt => 1,
        Recipients => undef,

        @_
    );

    my $gnupg = GnuPG::Interface->new();
    my %opt = RT->Config->Get('GnuPGOptions');

    # handling passphrase in GnuPGOptions
    $args{'Passphrase'} = delete $opt{'passphrase'}
        if !defined $args{'Passphrase'};

    $opt{'digest-algo'} ||= 'SHA1';
    $opt{'default_key'} = $args{'Signer'}
        if $args{'Sign'} && $args{'Signer'};
    $gnupg->options->hash_init(
        _PrepareGnuPGOptions( %opt ),
        armor => 1,
        meta_interactive => 0,
    );

    my $entity = $args{'Entity'};

    if ( $args{'Sign'} && !defined $args{'Passphrase'} ) {
        $args{'Passphrase'} = GetPassphrase( Address => $args{'Signer'} );
    }

    my %res;
    if ( $args{'Sign'} && !$args{'Encrypt'} ) {
        # required by RFC3156(Ch. 5) and RFC1847(Ch. 2.1)
        foreach ( grep !$_->is_multipart, $entity->parts_DFS ) {
            my $tenc = $_->head->mime_encoding;
            unless ( $tenc =~ m/^(?:7bit|quoted-printable|base64)$/i ) {
                $_->head->mime_attr( 'Content-Transfer-Encoding'
                    => $_->effective_type =~ m{^text/}? 'quoted-printable': 'base64'
                );
            }
        }

        my ($handles, $handle_list) = _make_gpg_handles(stdin =>IO::Handle::CRLF->new );
        my %handle = %$handle_list;

        $gnupg->passphrase( $args{'Passphrase'} );

        eval {
            local $SIG{'CHLD'} = 'DEFAULT';
            my $pid = safe_run_child { $gnupg->detach_sign( handles => $handles ) };
            $entity->make_multipart( 'mixed', Force => 1 );
            {
                local $SIG{'PIPE'} = 'IGNORE';
                $entity->parts(0)->print( $handle{'stdin'} );
                close $handle{'stdin'};
            }
            waitpid $pid, 0;
        };
        my $err = $@;
        my @signature = readline $handle{'stdout'};
        close $handle{'stdout'};

        $res{'exit_code'} = $?;
        foreach ( qw(stderr logger status) ) {
            $res{$_} = do { local $/; readline $handle{$_} };
            delete $res{$_} unless $res{$_} && $res{$_} =~ /\S/s;
            close $handle{$_};
        }
        $RT::Logger->debug( $res{'status'} ) if $res{'status'};
        $RT::Logger->warning( $res{'stderr'} ) if $res{'stderr'};
        $RT::Logger->error( $res{'logger'} ) if $res{'logger'} && $?;
        if ( $err || $res{'exit_code'} ) {
            $res{'message'} = $err? $err : "gpg exitted with error code ". ($res{'exit_code'} >> 8);
            return %res;
        }

        # setup RFC1847(Ch.2.1) requirements
        my $protocol = 'application/pgp-signature';
        $entity->head->mime_attr( 'Content-Type' => 'multipart/signed' );
        $entity->head->mime_attr( 'Content-Type.protocol' => $protocol );
        $entity->head->mime_attr( 'Content-Type.micalg'   => 'pgp-'. lc $opt{'digest-algo'} );
        $entity->attach(
            Type        => $protocol,
            Disposition => 'inline',
            Data        => \@signature,
            Encoding    => '7bit',
        );
    }
    if ( $args{'Encrypt'} ) {
        my %seen;
        $gnupg->options->push_recipients( $_ ) foreach 
            map UseKeyForEncryption($_) || $_,
            grep !$seen{ $_ }++, map $_->address,
            map Email::Address->parse( Encode::decode( "UTF-8", $entity->head->get( $_ ) ) ),
            qw(To Cc Bcc);

        my ($tmp_fh, $tmp_fn) = File::Temp::tempfile( UNLINK => 1 );
        binmode $tmp_fh, ':raw';

        my ($handles, $handle_list) = _make_gpg_handles(stdout => $tmp_fh);
        my %handle = %$handle_list;
        $handles->options( 'stdout'  )->{'direct'} = 1;
        $gnupg->passphrase( $args{'Passphrase'} ) if $args{'Sign'};

        eval {
            local $SIG{'CHLD'} = 'DEFAULT';
            my $pid = safe_run_child { $args{'Sign'}
                ? $gnupg->sign_and_encrypt( handles => $handles )
                : $gnupg->encrypt( handles => $handles ) };
            $entity->make_multipart( 'mixed', Force => 1 );
            {
                local $SIG{'PIPE'} = 'IGNORE';
                $entity->parts(0)->print( $handle{'stdin'} );
                close $handle{'stdin'};
            }
            waitpid $pid, 0;
        };

        $res{'exit_code'} = $?;
        foreach ( qw(stderr logger status) ) {
            $res{$_} = do { local $/; readline $handle{$_} };
            delete $res{$_} unless $res{$_} && $res{$_} =~ /\S/s;
            close $handle{$_};
        }
        $RT::Logger->debug( $res{'status'} ) if $res{'status'};
        $RT::Logger->warning( $res{'stderr'} ) if $res{'stderr'};
        $RT::Logger->error( $res{'logger'} ) if $res{'logger'} && $?;
        if ( $@ || $? ) {
            $res{'message'} = $@? $@: "gpg exited with error code ". ($? >> 8);
            return %res;
        }

        my $protocol = 'application/pgp-encrypted';
        $entity->parts([]);
        $entity->head->mime_attr( 'Content-Type' => 'multipart/encrypted' );
        $entity->head->mime_attr( 'Content-Type.protocol' => $protocol );
        $entity->attach(
            Type        => $protocol,
            Disposition => 'inline',
            Data        => ['Version: 1',''],
            Encoding    => '7bit',
        );
        $entity->attach(
            Type        => 'application/octet-stream',
            Disposition => 'inline',
            Path        => $tmp_fn,
            Filename    => '',
            Encoding    => '7bit',
        );
        $entity->parts(-1)->bodyhandle->{'_dirty_hack_to_save_a_ref_tmp_fh'} = $tmp_fh;
    }
    return %res;
}

sub SignEncryptInline {
    my %args = ( @_ );

    my $entity = $args{'Entity'};

    my %res;
    $entity->make_singlepart;
    if ( $entity->is_multipart ) {
        foreach ( $entity->parts ) {
            %res = SignEncryptInline( @_, Entity => $_ );
            return %res if $res{'exit_code'};
        }
        return %res;
    }

    return _SignEncryptTextInline( @_ )
        if $entity->effective_type =~ /^text\//i;

    return _SignEncryptAttachmentInline( @_ );
}

sub _SignEncryptTextInline {
    my %args = (
        Entity => undef,

        Sign => 1,
        Signer => undef,
        Passphrase => undef,

        Encrypt => 1,
        Recipients => undef,

        @_
    );
    return unless $args{'Sign'} || $args{'Encrypt'};

    my $gnupg = GnuPG::Interface->new();
    my %opt = RT->Config->Get('GnuPGOptions');

    # handling passphrase in GnupGOptions
    $args{'Passphrase'} = delete $opt{'passphrase'}
        if !defined($args{'Passphrase'});

    $opt{'digest-algo'} ||= 'SHA1';
    $opt{'default_key'} = $args{'Signer'}
        if $args{'Sign'} && $args{'Signer'};
    $gnupg->options->hash_init(
        _PrepareGnuPGOptions( %opt ),
        armor => 1,
        meta_interactive => 0,
    );

    if ( $args{'Sign'} && !defined $args{'Passphrase'} ) {
        $args{'Passphrase'} = GetPassphrase( Address => $args{'Signer'} );
    }

    if ( $args{'Encrypt'} ) {
        $gnupg->options->push_recipients( $_ ) foreach 
            map UseKeyForEncryption($_) || $_,
            @{ $args{'Recipients'} || [] };
    }

    my %res;

    my ($tmp_fh, $tmp_fn) = File::Temp::tempfile( UNLINK => 1 );
    binmode $tmp_fh, ':raw';

    my ($handles, $handle_list) = _make_gpg_handles(stdout => $tmp_fh);
    my %handle = %$handle_list;

    $handles->options( 'stdout'  )->{'direct'} = 1;
    $gnupg->passphrase( $args{'Passphrase'} ) if $args{'Sign'};

    my $entity = $args{'Entity'};
    eval {
        local $SIG{'CHLD'} = 'DEFAULT';
        my $method = $args{'Sign'} && $args{'Encrypt'}
            ? 'sign_and_encrypt'
            : ($args{'Sign'}? 'clearsign': 'encrypt');
        my $pid = safe_run_child { $gnupg->$method( handles => $handles ) };
        {
            local $SIG{'PIPE'} = 'IGNORE';
            $entity->bodyhandle->print( $handle{'stdin'} );
            close $handle{'stdin'};
        }
        waitpid $pid, 0;
    };
    $res{'exit_code'} = $?;
    my $err = $@;

    foreach ( qw(stderr logger status) ) {
        $res{$_} = do { local $/; readline $handle{$_} };
        delete $res{$_} unless $res{$_} && $res{$_} =~ /\S/s;
        close $handle{$_};
    }
    $RT::Logger->debug( $res{'status'} ) if $res{'status'};
    $RT::Logger->warning( $res{'stderr'} ) if $res{'stderr'};
    $RT::Logger->error( $res{'logger'} ) if $res{'logger'} && $?;
    if ( $err || $res{'exit_code'} ) {
        $res{'message'} = $err? $err : "gpg exitted with error code ". ($res{'exit_code'} >> 8);
        return %res;
    }

    $entity->bodyhandle( MIME::Body::File->new( $tmp_fn) );
    $entity->{'__store_tmp_handle_to_avoid_early_cleanup'} = $tmp_fh;

    return %res;
}

sub _SignEncryptAttachmentInline {
    my %args = (
        Entity => undef,

        Sign => 1,
        Signer => undef,
        Passphrase => undef,

        Encrypt => 1,
        Recipients => undef,

        @_
    );
    return unless $args{'Sign'} || $args{'Encrypt'};

    my $gnupg = GnuPG::Interface->new();
    my %opt = RT->Config->Get('GnuPGOptions');

    # handling passphrase in GnupGOptions
    $args{'Passphrase'} = delete $opt{'passphrase'}
        if !defined($args{'Passphrase'});

    $opt{'digest-algo'} ||= 'SHA1';
    $opt{'default_key'} = $args{'Signer'}
        if $args{'Sign'} && $args{'Signer'};
    $gnupg->options->hash_init(
        _PrepareGnuPGOptions( %opt ),
        armor => 1,
        meta_interactive => 0,
    );

    if ( $args{'Sign'} && !defined $args{'Passphrase'} ) {
        $args{'Passphrase'} = GetPassphrase( Address => $args{'Signer'} );
    }

    my $entity = $args{'Entity'};
    if ( $args{'Encrypt'} ) {
        $gnupg->options->push_recipients( $_ ) foreach
            map UseKeyForEncryption($_) || $_,
            @{ $args{'Recipients'} || [] };
    }

    my %res;

    my ($tmp_fh, $tmp_fn) = File::Temp::tempfile( UNLINK => 1 );
    binmode $tmp_fh, ':raw';

    my ($handles, $handle_list) = _make_gpg_handles(stdout => $tmp_fh);
    my %handle = %$handle_list;
    $handles->options( 'stdout'  )->{'direct'} = 1;
    $gnupg->passphrase( $args{'Passphrase'} ) if $args{'Sign'};

    eval {
        local $SIG{'CHLD'} = 'DEFAULT';
        my $method = $args{'Sign'} && $args{'Encrypt'}
            ? 'sign_and_encrypt'
            : ($args{'Sign'}? 'detach_sign': 'encrypt');
        my $pid = safe_run_child { $gnupg->$method( handles => $handles ) };
        {
            local $SIG{'PIPE'} = 'IGNORE';
            $entity->bodyhandle->print( $handle{'stdin'} );
            close $handle{'stdin'};
        }
        waitpid $pid, 0;
    };
    $res{'exit_code'} = $?;
    my $err = $@;

    foreach ( qw(stderr logger status) ) {
        $res{$_} = do { local $/; readline $handle{$_} };
        delete $res{$_} unless $res{$_} && $res{$_} =~ /\S/s;
        close $handle{$_};
    }
    $RT::Logger->debug( $res{'status'} ) if $res{'status'};
    $RT::Logger->warning( $res{'stderr'} ) if $res{'stderr'};
    $RT::Logger->error( $res{'logger'} ) if $res{'logger'} && $?;
    if ( $err || $res{'exit_code'} ) {
        $res{'message'} = $err? $err : "gpg exitted with error code ". ($res{'exit_code'} >> 8);
        return %res;
    }

    my $filename = mime_recommended_filename( $entity ) || 'no_name';
    if ( $args{'Sign'} && !$args{'Encrypt'} ) {
        $entity->make_multipart;
        $entity->attach(
            Type     => 'application/octet-stream',
            Path     => $tmp_fn,
            Filename => "$filename.sig",
            Disposition => 'attachment',
        );
    } else {
        $entity->bodyhandle(MIME::Body::File->new( $tmp_fn) );
        $entity->effective_type('application/octet-stream');
        $entity->head->mime_attr( $_ => "$filename.pgp" )
            foreach (qw(Content-Type.name Content-Disposition.filename));

    }
    $entity->{'__store_tmp_handle_to_avoid_early_cleanup'} = $tmp_fh;

    return %res;
}

sub SignEncryptContent {
    my %args = (
        Content => undef,

        Sign => 1,
        Signer => undef,
        Passphrase => undef,

        Encrypt => 1,
        Recipients => undef,

        @_
    );
    return unless $args{'Sign'} || $args{'Encrypt'};

    my $gnupg = GnuPG::Interface->new();
    my %opt = RT->Config->Get('GnuPGOptions');

    # handling passphrase in GnupGOptions
    $args{'Passphrase'} = delete $opt{'passphrase'}
        if !defined($args{'Passphrase'});

    $opt{'digest-algo'} ||= 'SHA1';
    $opt{'default_key'} = $args{'Signer'}
        if $args{'Sign'} && $args{'Signer'};
    $gnupg->options->hash_init(
        _PrepareGnuPGOptions( %opt ),
        armor => 1,
        meta_interactive => 0,
    );

    if ( $args{'Sign'} && !defined $args{'Passphrase'} ) {
        $args{'Passphrase'} = GetPassphrase( Address => $args{'Signer'} );
    }

    if ( $args{'Encrypt'} ) {
        $gnupg->options->push_recipients( $_ ) foreach 
            map UseKeyForEncryption($_) || $_,
            @{ $args{'Recipients'} || [] };
    }

    my %res;

    my ($tmp_fh, $tmp_fn) = File::Temp::tempfile( UNLINK => 1 );
    binmode $tmp_fh, ':raw';

    my ($handles, $handle_list) = _make_gpg_handles(stdout => $tmp_fh);
    my %handle = %$handle_list;
    $handles->options( 'stdout'  )->{'direct'} = 1;
    $gnupg->passphrase( $args{'Passphrase'} ) if $args{'Sign'};

    eval {
        local $SIG{'CHLD'} = 'DEFAULT';
        my $method = $args{'Sign'} && $args{'Encrypt'}
            ? 'sign_and_encrypt'
            : ($args{'Sign'}? 'clearsign': 'encrypt');
        my $pid = safe_run_child { $gnupg->$method( handles => $handles ) };
        {
            local $SIG{'PIPE'} = 'IGNORE';
            $handle{'stdin'}->print( ${ $args{'Content'} } );
            close $handle{'stdin'};
        }
        waitpid $pid, 0;
    };
    $res{'exit_code'} = $?;
    my $err = $@;

    foreach ( qw(stderr logger status) ) {
        $res{$_} = do { local $/; readline $handle{$_} };
        delete $res{$_} unless $res{$_} && $res{$_} =~ /\S/s;
        close $handle{$_};
    }
    $RT::Logger->debug( $res{'status'} ) if $res{'status'};
    $RT::Logger->warning( $res{'stderr'} ) if $res{'stderr'};
    $RT::Logger->error( $res{'logger'} ) if $res{'logger'} && $?;
    if ( $err || $res{'exit_code'} ) {
        $res{'message'} = $err? $err : "gpg exitted with error code ". ($res{'exit_code'} >> 8);
        return %res;
    }

    ${ $args{'Content'} } = '';
    seek $tmp_fh, 0, 0;
    while (1) {
        my $status = read $tmp_fh, my $buf, 4*1024;
        unless ( defined $status ) {
            $RT::Logger->crit( "couldn't read message: $!" );
        } elsif ( !$status ) {
            last;
        }
        ${ $args{'Content'} } .= $buf;
    }

    return %res;
}

sub FindProtectedParts {
    my %args = ( Entity => undef, CheckBody => 1, @_ );
    my $entity = $args{'Entity'};

    # inline PGP block, only in singlepart
    unless ( $entity->is_multipart ) {
        my $file = ($entity->head->recommended_filename||'') =~ /\.${RE_FILE_EXTENSIONS}$/;

        my $io = $entity->open('r');
        unless ( $io ) {
            $RT::Logger->warning( "Entity of type ". $entity->effective_type ." has no body" );
            return ();
        }

        # Deal with "partitioned" PGP mail, which (contrary to common
        # sense) unnecessarily applies a base64 transfer encoding to PGP
        # mail (whose content is already base64-encoded).
        if ( $entity->bodyhandle->is_encoded and $entity->head->mime_encoding ) {
            my $decoder = MIME::Decoder->new( $entity->head->mime_encoding );
            if ($decoder) {
                local $@;
                eval {
                    my $buf = '';
                    open my $fh, '>', \$buf
                        or die "Couldn't open scalar for writing: $!";
                    binmode $fh, ":raw";
                    $decoder->decode($io, $fh);
                    close $fh or die "Couldn't close scalar: $!";

                    open $fh, '<', \$buf
                        or die "Couldn't re-open scalar for reading: $!";
                    binmode $fh, ":raw";
                    $io = $fh;
                    1;
                } or do {
                    $RT::Logger->error("Couldn't decode body: $@");
                }
            }
        }

        while ( defined($_ = $io->getline) ) {
            next unless /^-----BEGIN PGP (SIGNED )?MESSAGE-----/;
            my $type = $1? 'signed': 'encrypted';
            $RT::Logger->debug("Found $type inline part");
            return {
                Type    => $type,
                Format  => !$file || $type eq 'signed'? 'Inline' : 'Attachment',
                Data    => $entity,
            };
        }
        $io->close;
        return ();
    }

    # RFC3156, multipart/{signed,encrypted}
    if ( ( my $type = $entity->effective_type ) =~ /^multipart\/(?:encrypted|signed)$/ ) {
        unless ( $entity->parts == 2 ) {
            $RT::Logger->error( "Encrypted or signed entity must has two subparts. Skipped" );
            return ();
        }

        my $protocol = $entity->head->mime_attr( 'Content-Type.protocol' );
        unless ( $protocol ) {
            $RT::Logger->error( "Entity is '$type', but has no protocol defined. Skipped" );
            return ();
        }

        if ( $type eq 'multipart/encrypted' ) {
            unless ( $protocol eq 'application/pgp-encrypted' ) {
                $RT::Logger->info( "Skipping protocol '$protocol', only 'application/pgp-encrypted' is supported" );
                return ();
            }
            $RT::Logger->debug("Found encrypted according to RFC3156 part");
            return {
                Type    => 'encrypted',
                Format  => 'RFC3156',
                Top   => $entity,
                Data  => $entity->parts(1),
                Info    => $entity->parts(0),
            };
        } else {
            unless ( $protocol eq 'application/pgp-signature' ) {
                $RT::Logger->info( "Skipping protocol '$protocol', only 'application/pgp-signature' is supported" );
                return ();
            }
            $RT::Logger->debug("Found signed according to RFC3156 part");
            return {
                Type      => 'signed',
                Format    => 'RFC3156',
                Top     => $entity,
                Data    => $entity->parts(0),
                Signature => $entity->parts(1),
            };
        }
    }

    # attachments signed with signature in another part
    my @file_indices;
    foreach my $i ( 0 .. $entity->parts - 1 ) {
        my $part = $entity->parts($i);

        # we can not associate a signature within an attachment
        # without file names
        my $fname = $part->head->recommended_filename;
        next unless $fname;

        if ( $part->effective_type eq 'application/pgp-signature' ) {
            push @file_indices, $i;
        }
        elsif ( $fname =~ /\.sig$/i && $part->effective_type eq 'application/octet-stream' ) {
            push @file_indices, $i;
        }
    }

    my (@res, %skip);
    foreach my $i ( @file_indices ) {
        my $sig_part = $entity->parts($i);
        $skip{"$sig_part"}++;
        my $sig_name = $sig_part->head->recommended_filename;
        my ($file_name) = $sig_name =~ /^(.*?)(?:\.sig)?$/;

        my ($data_part_idx) =
            grep $file_name eq ($entity->parts($_)->head->recommended_filename||''),
            grep $sig_part  ne  $entity->parts($_),
                0 .. $entity->parts - 1;
        unless ( defined $data_part_idx ) {
            $RT::Logger->error("Found $sig_name attachment, but didn't find $file_name");
            next;
        }
        my $data_part_in = $entity->parts($data_part_idx);

        $skip{"$data_part_in"}++;
        $RT::Logger->debug("Found signature (in '$sig_name') of attachment '$file_name'");
        push @res, {
            Type      => 'signed',
            Format    => 'Attachment',
            Top       => $entity,
            Data      => $data_part_in,
            Signature => $sig_part,
        };
    }

    # attachments with inline encryption
    my @encrypted_indices =
        grep {($entity->parts($_)->head->recommended_filename || '') =~ /\.${RE_FILE_EXTENSIONS}$/}
            0 .. $entity->parts - 1;

    foreach my $i ( @encrypted_indices ) {
        my $part = $entity->parts($i);
        $skip{"$part"}++;
        $RT::Logger->debug("Found encrypted attachment '". $part->head->recommended_filename ."'");
        push @res, {
            Type      => 'encrypted',
            Format    => 'Attachment',
            Top     => $entity,
            Data    => $part,
        };
    }

    push @res, FindProtectedParts( Entity => $_ )
        foreach grep !$skip{"$_"}, $entity->parts;

    return @res;
}

=head2 VerifyDecrypt Entity => undef, [ Detach => 1, Passphrase => undef, SetStatus => 1 ]

=cut

sub VerifyDecrypt {
    my %args = (
        Entity    => undef,
        Detach    => 1,
        SetStatus => 1,
        AddStatus => 0,
        @_
    );
    my @protected = FindProtectedParts( Entity => $args{'Entity'} );
    my @res;
    # XXX: detaching may brake nested signatures
    foreach my $item( grep $_->{'Type'} eq 'signed', @protected ) {
        my $status_on;
        if ( $item->{'Format'} eq 'RFC3156' ) {
            push @res, { VerifyRFC3156( %$item, SetStatus => $args{'SetStatus'} ) };
            if ( $args{'Detach'} ) {
                $item->{'Top'}->parts( [ $item->{'Data'} ] );
                $item->{'Top'}->make_singlepart;
            }
            $status_on = $item->{'Top'};
        } elsif ( $item->{'Format'} eq 'Inline' ) {
            push @res, { VerifyInline( %$item ) };
            $status_on = $item->{'Data'};
        } elsif ( $item->{'Format'} eq 'Attachment' ) {
            push @res, { VerifyAttachment( %$item ) };
            if ( $args{'Detach'} ) {
                $item->{'Top'}->parts( [
                    grep "$_" ne $item->{'Signature'}, $item->{'Top'}->parts
                ] );
                $item->{'Top'}->make_singlepart;
            }
            $status_on = $item->{'Data'};
        }
        if ( $args{'SetStatus'} || $args{'AddStatus'} ) {
            my $method = $args{'AddStatus'} ? 'add' : 'set';
            # Let the header be modified so continuations are handled
            my $modify = $status_on->head->modify;
            $status_on->head->modify(1);
            $status_on->head->$method(
                'X-RT-GnuPG-Status' => $res[-1]->{'status'}
            );
            $status_on->head->modify($modify);
        }
    }
    foreach my $item( grep $_->{'Type'} eq 'encrypted', @protected ) {
        my $status_on;
        if ( $item->{'Format'} eq 'RFC3156' ) {
            push @res, { DecryptRFC3156( %$item ) };
            $status_on = $item->{'Top'};
        } elsif ( $item->{'Format'} eq 'Inline' ) {
            push @res, { DecryptInline( %$item ) };
            $status_on = $item->{'Data'};
        } elsif ( $item->{'Format'} eq 'Attachment' ) {
            push @res, { DecryptAttachment( %$item ) };
            $status_on = $item->{'Data'};
        }
        if ( $args{'SetStatus'} || $args{'AddStatus'} ) {
            my $method = $args{'AddStatus'} ? 'add' : 'set';
            # Let the header be modified so continuations are handled
            my $modify = $status_on->head->modify;
            $status_on->head->modify(1);
            $status_on->head->$method(
                'X-RT-GnuPG-Status' => $res[-1]->{'status'}
            );
            $status_on->head->modify($modify);
        }
    }
    return @res;
}

sub VerifyInline { return DecryptInline( @_ ) }

sub VerifyAttachment {
    my %args = ( Data => undef, Signature => undef, Top => undef, @_ );

    my $gnupg = GnuPG::Interface->new();
    my %opt = RT->Config->Get('GnuPGOptions');
    $opt{'digest-algo'} ||= 'SHA1';
    $gnupg->options->hash_init(
        _PrepareGnuPGOptions( %opt ),
        meta_interactive => 0,
    );

    foreach ( $args{'Data'}, $args{'Signature'} ) {
        next unless $_->bodyhandle->is_encoded;

        require RT::EmailParser;
        RT::EmailParser->_DecodeBody($_);
    }

    my ($tmp_fh, $tmp_fn) = File::Temp::tempfile( UNLINK => 1 );
    binmode $tmp_fh, ':raw';
    $args{'Data'}->bodyhandle->print( $tmp_fh );
    $tmp_fh->flush;

    my ($handles, $handle_list) = _make_gpg_handles();
    my %handle = %$handle_list;

    my %res;
    eval {
        local $SIG{'CHLD'} = 'DEFAULT';
        my $pid = safe_run_child { $gnupg->verify(
            handles => $handles, command_args => [ '-', $tmp_fn ]
        ) };
        {
            local $SIG{'PIPE'} = 'IGNORE';
            $args{'Signature'}->bodyhandle->print( $handle{'stdin'} );
            close $handle{'stdin'};
        }
        waitpid $pid, 0;
    };
    $res{'exit_code'} = $?;
    foreach ( qw(stderr logger status) ) {
        $res{$_} = do { local $/; readline $handle{$_} };
        delete $res{$_} unless $res{$_} && $res{$_} =~ /\S/s;
        close $handle{$_};
    }
    $RT::Logger->debug( $res{'status'} ) if $res{'status'};
    $RT::Logger->warning( $res{'stderr'} ) if $res{'stderr'};
    $RT::Logger->error( $res{'logger'} ) if $res{'logger'} && $?;
    if ( $@ || $? ) {
        $res{'message'} = $@? $@: "gpg exitted with error code ". ($? >> 8);
    }
    return %res;
}

sub VerifyRFC3156 {
    my %args = ( Data => undef, Signature => undef, Top => undef, @_ );

    my $gnupg = GnuPG::Interface->new();
    my %opt = RT->Config->Get('GnuPGOptions');
    $opt{'digest-algo'} ||= 'SHA1';
    $gnupg->options->hash_init(
        _PrepareGnuPGOptions( %opt ),
        meta_interactive => 0,
    );

    my ($tmp_fh, $tmp_fn) = File::Temp::tempfile( UNLINK => 1 );
    binmode $tmp_fh, ':raw:eol(CRLF?)';
    $args{'Data'}->print( $tmp_fh );
    $tmp_fh->flush;

    my ($handles, $handle_list) = _make_gpg_handles();
    my %handle = %$handle_list;

    my %res;
    eval {
        local $SIG{'CHLD'} = 'DEFAULT';
        my $pid = safe_run_child { $gnupg->verify(
            handles => $handles, command_args => [ '-', $tmp_fn ]
        ) };
        {
            local $SIG{'PIPE'} = 'IGNORE';
            $args{'Signature'}->bodyhandle->print( $handle{'stdin'} );
            close $handle{'stdin'};
        }
        waitpid $pid, 0;
    };
    $res{'exit_code'} = $?;
    foreach ( qw(stderr logger status) ) {
        $res{$_} = do { local $/; readline $handle{$_} };
        delete $res{$_} unless $res{$_} && $res{$_} =~ /\S/s;
        close $handle{$_};
    }
    $RT::Logger->debug( $res{'status'} ) if $res{'status'};
    $RT::Logger->warning( $res{'stderr'} ) if $res{'stderr'};
    $RT::Logger->error( $res{'logger'} ) if $res{'logger'} && $?;
    if ( $@ || $? ) {
        $res{'message'} = $@? $@: "gpg exitted with error code ". ($? >> 8);
    }
    return %res;
}

sub DecryptRFC3156 {
    my %args = (
        Data => undef,
        Info => undef,
        Top => undef,
        Passphrase => undef,
        @_
    );

    my $gnupg = GnuPG::Interface->new();
    my %opt = RT->Config->Get('GnuPGOptions');

    # handling passphrase in GnupGOptions
    $args{'Passphrase'} = delete $opt{'passphrase'}
        if !defined($args{'Passphrase'});

    $opt{'digest-algo'} ||= 'SHA1';
    $gnupg->options->hash_init(
        _PrepareGnuPGOptions( %opt ),
        meta_interactive => 0,
    );

    if ( $args{'Data'}->bodyhandle->is_encoded ) {
        require RT::EmailParser;
        RT::EmailParser->_DecodeBody($args{'Data'});
    }

    $args{'Passphrase'} = GetPassphrase()
        unless defined $args{'Passphrase'};

    my ($tmp_fh, $tmp_fn) = File::Temp::tempfile( UNLINK => 1 );
    binmode $tmp_fh, ':raw';

    my ($handles, $handle_list) = _make_gpg_handles(stdout => $tmp_fh);
    my %handle = %$handle_list;
    $handles->options( 'stdout' )->{'direct'} = 1;

    my %res;
    eval {
        local $SIG{'CHLD'} = 'DEFAULT';
        $gnupg->passphrase( $args{'Passphrase'} );
        my $pid = safe_run_child { $gnupg->decrypt( handles => $handles ) };
        {
            local $SIG{'PIPE'} = 'IGNORE';
            $args{'Data'}->bodyhandle->print( $handle{'stdin'} );
            close $handle{'stdin'}
        }

        waitpid $pid, 0;
    };
    $res{'exit_code'} = $?;
    foreach ( qw(stderr logger status) ) {
        $res{$_} = do { local $/; readline $handle{$_} };
        delete $res{$_} unless $res{$_} && $res{$_} =~ /\S/s;
        close $handle{$_};
    }
    $RT::Logger->debug( $res{'status'} ) if $res{'status'};
    $RT::Logger->warning( $res{'stderr'} ) if $res{'stderr'};
    $RT::Logger->error( $res{'logger'} ) if $res{'logger'} && $?;

    # if the decryption is fine but the signature is bad, then without this
    # status check we lose the decrypted text
    # XXX: add argument to the function to control this check
    if ( $res{'status'} !~ /DECRYPTION_OKAY/ ) {
        if ( $@ || $? ) {
            $res{'message'} = $@? $@: "gpg exitted with error code ". ($? >> 8);
            return %res;
        }
    }

    seek $tmp_fh, 0, 0;
    my $parser = RT::EmailParser->new();
    my $decrypted = $parser->ParseMIMEEntityFromFileHandle( $tmp_fh, 0 );
    $decrypted->{'__store_link_to_object_to_avoid_early_cleanup'} = $parser;
    $args{'Top'}->parts( [] );
    $args{'Top'}->add_part( $decrypted );
    $args{'Top'}->make_singlepart;
    return %res;
}

sub DecryptInline {
    my %args = (
        Data => undef,
        Passphrase => undef,
        @_
    );

    my $gnupg = GnuPG::Interface->new();
    my %opt = RT->Config->Get('GnuPGOptions');

    # handling passphrase in GnuPGOptions
    $args{'Passphrase'} = delete $opt{'passphrase'}
        if !defined($args{'Passphrase'});

    $opt{'digest-algo'} ||= 'SHA1';
    $gnupg->options->hash_init(
        _PrepareGnuPGOptions( %opt ),
        meta_interactive => 0,
    );

    if ( $args{'Data'}->bodyhandle->is_encoded ) {
        require RT::EmailParser;
        RT::EmailParser->_DecodeBody($args{'Data'});
    }

    $args{'Passphrase'} = GetPassphrase()
        unless defined $args{'Passphrase'};

    my ($tmp_fh, $tmp_fn) = File::Temp::tempfile( UNLINK => 1 );
    binmode $tmp_fh, ':raw';

    my $io = $args{'Data'}->open('r');
    unless ( $io ) {
        die "Entity has no body, never should happen";
    }

    my %res;

    my ($had_literal, $in_block) = ('', 0);
    my ($block_fh, $block_fn) = File::Temp::tempfile( UNLINK => 1 );
    binmode $block_fh, ':raw';

    while ( defined(my $str = $io->getline) ) {
        if ( $in_block && $str =~ /^-----END PGP (?:MESSAGE|SIGNATURE)-----/ ) {
            print $block_fh $str;
            $in_block--;
            next if $in_block > 0;

            seek $block_fh, 0, 0;

            my ($res_fh, $res_fn);
            ($res_fh, $res_fn, %res) = _DecryptInlineBlock(
                %args,
                GnuPG => $gnupg,
                BlockHandle => $block_fh,
            );
            return %res unless $res_fh;

            print $tmp_fh "-----BEGIN OF PGP PROTECTED PART-----\n" if $had_literal;
            while (my $buf = <$res_fh> ) {
                print $tmp_fh $buf;
            }
            print $tmp_fh "-----END OF PART-----\n" if $had_literal;

            ($block_fh, $block_fn) = File::Temp::tempfile( UNLINK => 1 );
            binmode $block_fh, ':raw';
            $in_block = 0;
        }
        elsif ( $str =~ /^-----BEGIN PGP (SIGNED )?MESSAGE-----/ ) {
            $in_block++;
            print $block_fh $str;
        }
        elsif ( $in_block ) {
            print $block_fh $str;
        }
        else {
            print $tmp_fh $str;
            $had_literal = 1 if /\S/s;
        }
    }
    $io->close;

    if ( $in_block ) {
        # we're still in a block, this not bad not good. let's try to
        # decrypt what we have, it can be just missing -----END PGP...
        seek $block_fh, 0, 0;

        my ($res_fh, $res_fn);
        ($res_fh, $res_fn, %res) = _DecryptInlineBlock(
            %args,
            GnuPG => $gnupg,
            BlockHandle => $block_fh,
        );
        return %res unless $res_fh;

        print $tmp_fh "-----BEGIN OF PGP PROTECTED PART-----\n" if $had_literal;
        while (my $buf = <$res_fh> ) {
            print $tmp_fh $buf;
        }
        print $tmp_fh "-----END OF PART-----\n" if $had_literal;
    }

    seek $tmp_fh, 0, 0;
    $args{'Data'}->bodyhandle(MIME::Body::File->new( $tmp_fn ));
    $args{'Data'}->{'__store_tmp_handle_to_avoid_early_cleanup'} = $tmp_fh;
    return %res;
}

sub _DecryptInlineBlock {
    my %args = (
        GnuPG => undef,
        BlockHandle => undef,
        Passphrase => undef,
        @_
    );
    my $gnupg = $args{'GnuPG'};

    my ($tmp_fh, $tmp_fn) = File::Temp::tempfile( UNLINK => 1 );
    binmode $tmp_fh, ':raw';

    my ($handles, $handle_list) = _make_gpg_handles(
            stdin => $args{'BlockHandle'}, 
            stdout => $tmp_fh);
    my %handle = %$handle_list;
    $handles->options( 'stdout' )->{'direct'} = 1;
    $handles->options( 'stdin' )->{'direct'} = 1;

    my %res;
    eval {
        local $SIG{'CHLD'} = 'DEFAULT';
        $gnupg->passphrase( $args{'Passphrase'} );
        my $pid = safe_run_child { $gnupg->decrypt( handles => $handles ) };
        waitpid $pid, 0;
    };
    $res{'exit_code'} = $?;
    foreach ( qw(stderr logger status) ) {
        $res{$_} = do { local $/; readline $handle{$_} };
        delete $res{$_} unless $res{$_} && $res{$_} =~ /\S/s;
        close $handle{$_};
    }
    $RT::Logger->debug( $res{'status'} ) if $res{'status'};
    $RT::Logger->warning( $res{'stderr'} ) if $res{'stderr'};
    $RT::Logger->error( $res{'logger'} ) if $res{'logger'} && $?;

    # if the decryption is fine but the signature is bad, then without this
    # status check we lose the decrypted text
    # XXX: add argument to the function to control this check
    if ( $res{'status'} !~ /DECRYPTION_OKAY/ ) {
        if ( $@ || $? ) {
            $res{'message'} = $@? $@: "gpg exitted with error code ". ($? >> 8);
            return (undef, undef, %res);
        }
    }

    seek $tmp_fh, 0, 0;
    return ($tmp_fh, $tmp_fn, %res);
}

sub DecryptAttachment {
    my %args = (
        Top  => undef,
        Data => undef,
        Passphrase => undef,
        @_
    );

    my $gnupg = GnuPG::Interface->new();
    my %opt = RT->Config->Get('GnuPGOptions');

    # handling passphrase in GnuPGOptions
    $args{'Passphrase'} = delete $opt{'passphrase'}
        if !defined($args{'Passphrase'});

    $opt{'digest-algo'} ||= 'SHA1';
    $gnupg->options->hash_init(
        _PrepareGnuPGOptions( %opt ),
        meta_interactive => 0,
    );

    if ( $args{'Data'}->bodyhandle->is_encoded ) {
        require RT::EmailParser;
        RT::EmailParser->_DecodeBody($args{'Data'});
    }

    $args{'Passphrase'} = GetPassphrase()
        unless defined $args{'Passphrase'};

    my ($tmp_fh, $tmp_fn) = File::Temp::tempfile( UNLINK => 1 );
    binmode $tmp_fh, ':raw';
    $args{'Data'}->bodyhandle->print( $tmp_fh );
    seek $tmp_fh, 0, 0;

    my ($res_fh, $res_fn, %res) = _DecryptInlineBlock(
        %args,
        GnuPG => $gnupg,
        BlockHandle => $tmp_fh,
    );
    return %res unless $res_fh;

    $args{'Data'}->bodyhandle(MIME::Body::File->new($res_fn) );
    $args{'Data'}->{'__store_tmp_handle_to_avoid_early_cleanup'} = $res_fh;

    my $head = $args{'Data'}->head;

    # we can not trust original content type
    # TODO: and don't have way to detect, so we just use octet-stream
    # some clients may send .asc files (encryped) as text/plain
    $head->mime_attr( "Content-Type" => 'application/octet-stream' );

    my $filename = $head->recommended_filename;
    $filename =~ s/\.${RE_FILE_EXTENSIONS}$//i;
    $head->mime_attr( $_ => $filename )
        foreach (qw(Content-Type.name Content-Disposition.filename));

    return %res;
}

sub DecryptContent {
    my %args = (
        Content => undef,
        Passphrase => undef,
        @_
    );

    my $gnupg = GnuPG::Interface->new();
    my %opt = RT->Config->Get('GnuPGOptions');

    # handling passphrase in GnupGOptions
    $args{'Passphrase'} = delete $opt{'passphrase'}
        if !defined($args{'Passphrase'});

    $opt{'digest-algo'} ||= 'SHA1';
    $gnupg->options->hash_init(
        _PrepareGnuPGOptions( %opt ),
        meta_interactive => 0,
    );

    $args{'Passphrase'} = GetPassphrase()
        unless defined $args{'Passphrase'};

    my ($tmp_fh, $tmp_fn) = File::Temp::tempfile( UNLINK => 1 );
    binmode $tmp_fh, ':raw';

    my ($handles, $handle_list) = _make_gpg_handles(
            stdout => $tmp_fh);
    my %handle = %$handle_list;
    $handles->options( 'stdout' )->{'direct'} = 1;

    my %res;
    eval {
        local $SIG{'CHLD'} = 'DEFAULT';
        $gnupg->passphrase( $args{'Passphrase'} );
        my $pid = safe_run_child { $gnupg->decrypt( handles => $handles ) };
        {
            local $SIG{'PIPE'} = 'IGNORE';
            print { $handle{'stdin'} } ${ $args{'Content'} };
            close $handle{'stdin'};
        }

        waitpid $pid, 0;
    };
    $res{'exit_code'} = $?;
    foreach ( qw(stderr logger status) ) {
        $res{$_} = do { local $/; readline $handle{$_} };
        delete $res{$_} unless $res{$_} && $res{$_} =~ /\S/s;
        close $handle{$_};
    }
    $RT::Logger->debug( $res{'status'} ) if $res{'status'};
    $RT::Logger->warning( $res{'stderr'} ) if $res{'stderr'};
    $RT::Logger->error( $res{'logger'} ) if $res{'logger'} && $?;

    # if the decryption is fine but the signature is bad, then without this
    # status check we lose the decrypted text
    # XXX: add argument to the function to control this check
    if ( $res{'status'} !~ /DECRYPTION_OKAY/ ) {
        if ( $@ || $? ) {
            $res{'message'} = $@? $@: "gpg exitted with error code ". ($? >> 8);
            return %res;
        }
    }

    ${ $args{'Content'} } = '';
    seek $tmp_fh, 0, 0;
    while (1) {
        my $status = read $tmp_fh, my $buf, 4*1024;
        unless ( defined $status ) {
            $RT::Logger->crit( "couldn't read message: $!" );
        } elsif ( !$status ) {
            last;
        }
        ${ $args{'Content'} } .= $buf;
    }

    return %res;
}

=head2 GetPassphrase [ Address => undef ]

Returns passphrase, called whenever it's required with Address as a named argument.

=cut

sub GetPassphrase {
    my %args = ( Address => undef, @_ );
    return 'test';
}

=head2 ParseStatus

Takes a string containing output of gnupg status stream. Parses it and returns
array of hashes. Each element of array is a hash ref and represents line or
group of lines in the status message.

All hashes have Operation, Status and Message elements.

=over

=item Operation

Classification of operations gnupg performs. Now we have support
for Sign, Encrypt, Decrypt, Verify, PassphraseCheck, RecipientsCheck and Data
values.

=item Status

Informs about success. Value is 'DONE' on success, other values means that
an operation failed, for example 'ERROR', 'BAD', 'MISSING' and may be other.

=item Message

User friendly message.

=back

This parser is based on information from GnuPG distribution.

=cut

my %REASON_CODE_TO_TEXT = (
    NODATA => {
        1 => "No armored data",
        2 => "Expected a packet, but did not found one",
        3 => "Invalid packet found",
        4 => "Signature expected, but not found",
    },
    INV_RECP => {
        0 => "No specific reason given",
        1 => "Not Found",
        2 => "Ambigious specification",
        3 => "Wrong key usage",
        4 => "Key revoked",
        5 => "Key expired",
        6 => "No CRL known",
        7 => "CRL too old",
        8 => "Policy mismatch",
        9 => "Not a secret key",
        10 => "Key not trusted",
    },
    ERRSIG => {
        0 => 'not specified',
        4 => 'unknown algorithm',
        9 => 'missing public key',
    },
);

sub ReasonCodeToText {
    my $keyword = shift;
    my $code = shift;
    return $REASON_CODE_TO_TEXT{ $keyword }{ $code }
        if exists $REASON_CODE_TO_TEXT{ $keyword }{ $code };
    return 'unknown';
}

my %simple_keyword = (
    NO_RECP => {
        Operation => 'RecipientsCheck',
        Status    => 'ERROR',
        Message   => 'No recipients',
    },
    UNEXPECTED => {
        Operation => 'Data',
        Status    => 'ERROR',
        Message   => 'Unexpected data has been encountered',
    },
    BADARMOR => {
        Operation => 'Data',
        Status    => 'ERROR',
        Message   => 'The ASCII armor is corrupted',
    },
);

# keywords we parse
my %parse_keyword = map { $_ => 1 } qw(
    USERID_HINT
    SIG_CREATED GOODSIG BADSIG ERRSIG
    END_ENCRYPTION
    DECRYPTION_FAILED DECRYPTION_OKAY
    BAD_PASSPHRASE GOOD_PASSPHRASE
    NO_SECKEY NO_PUBKEY
    NO_RECP INV_RECP NODATA UNEXPECTED
);

# keywords we ignore without any messages as we parse them using other
# keywords as starting point or just ignore as they are useless for us
my %ignore_keyword = map { $_ => 1 } qw(
    NEED_PASSPHRASE MISSING_PASSPHRASE BEGIN_SIGNING PLAINTEXT PLAINTEXT_LENGTH
    BEGIN_ENCRYPTION SIG_ID VALIDSIG
    ENC_TO BEGIN_DECRYPTION END_DECRYPTION GOODMDC
    TRUST_UNDEFINED TRUST_NEVER TRUST_MARGINAL TRUST_FULLY TRUST_ULTIMATE
    DECRYPTION_INFO
);

sub ParseStatus {
    my $status = shift;
    return () unless $status;

    my @status;
    while ( $status =~ /\[GNUPG:\]\s*(.*?)(?=\[GNUPG:\]|\z)/igms ) {
        push @status, $1; $status[-1] =~ s/\s+/ /g; $status[-1] =~ s/\s+$//;
    }
    $status = join "\n", @status;
    study $status;

    my @res;
    my (%user_hint, $latest_user_main_key);
    for ( my $i = 0; $i < @status; $i++ ) {
        my $line = $status[$i];
        my ($keyword, $args) = ($line =~ /^(\S+)\s*(.*)$/s);
        if ( $simple_keyword{ $keyword } ) {
            push @res, $simple_keyword{ $keyword };
            $res[-1]->{'Keyword'} = $keyword;
            next;
        }
        unless ( $parse_keyword{ $keyword } ) {
            $RT::Logger->warning("Skipped $keyword") unless $ignore_keyword{ $keyword };
            next;
        }

        if ( $keyword eq 'USERID_HINT' ) {
            my %tmp = _ParseUserHint($status, $line);
            $latest_user_main_key = $tmp{'MainKey'};
            if ( $user_hint{ $tmp{'MainKey'} } ) {
                while ( my ($k, $v) = each %tmp ) {
                    $user_hint{ $tmp{'MainKey'} }->{$k} = $v;
                }
            } else {
                $user_hint{ $tmp{'MainKey'} } = \%tmp;
            }
            next;
        }
        elsif ( $keyword eq 'BAD_PASSPHRASE' || $keyword eq 'GOOD_PASSPHRASE' ) {
            my $key_id = $args;
            my %res = (
                Operation => 'PassphraseCheck',
                Status    => $keyword eq 'BAD_PASSPHRASE'? 'BAD' : 'DONE',
                Key       => $key_id,
            );
            $res{'Status'} = 'MISSING' if $status[ $i - 1 ] =~ /^MISSING_PASSPHRASE/;
            foreach my $line ( reverse @status[ 0 .. $i-1 ] ) {
                next unless $line =~ /^NEED_PASSPHRASE\s+(\S+)\s+(\S+)\s+(\S+)/;
                next if $key_id && $2 ne $key_id;
                @res{'MainKey', 'Key', 'KeyType'} = ($1, $2, $3);
                last;
            }
            $res{'Message'} = ucfirst( lc( $res{'Status'} eq 'DONE'? 'GOOD': $res{'Status'} ) ) .' passphrase';
            $res{'User'} = ( $user_hint{ $res{'MainKey'} } ||= {} ) if $res{'MainKey'};
            if ( exists $res{'User'}->{'EmailAddress'} ) {
                $res{'Message'} .= ' for '. $res{'User'}->{'EmailAddress'};
            } else {
                $res{'Message'} .= " for '0x$key_id'";
            }
            push @res, \%res;
        }
        elsif ( $keyword eq 'END_ENCRYPTION' ) {
            my %res = (
                Operation => 'Encrypt',
                Status    => 'DONE',
                Message   => 'Data has been encrypted',
            );
            foreach my $line ( reverse @status[ 0 .. $i-1 ] ) {
                next unless $line =~ /^BEGIN_ENCRYPTION\s+(\S+)\s+(\S+)/;
                @res{'MdcMethod', 'SymAlgo'} = ($1, $2);
                last;
            }
            push @res, \%res;
        }
        elsif ( $keyword eq 'DECRYPTION_FAILED' || $keyword eq 'DECRYPTION_OKAY' ) {
            my %res = ( Operation => 'Decrypt' );
            @res{'Status', 'Message'} = 
                $keyword eq 'DECRYPTION_FAILED'
                ? ('ERROR', 'Decryption failed')
                : ('DONE',  'Decryption process succeeded');

            foreach my $line ( reverse @status[ 0 .. $i-1 ] ) {
                next unless $line =~ /^ENC_TO\s+(\S+)\s+(\S+)\s+(\S+)/;
                my ($key, $alg, $key_length) = ($1, $2, $3);

                my %encrypted_to = (
                    Message   => "The message is encrypted to '0x$key'",
                    User      => ( $user_hint{ $key } ||= {} ),
                    Key       => $key,
                    KeyLength => $key_length,
                    Algorithm => $alg,
                );

                push @{ $res{'EncryptedTo'} ||= [] }, \%encrypted_to;
            }

            push @res, \%res;
        }
        elsif ( $keyword eq 'NO_SECKEY' || $keyword eq 'NO_PUBKEY' ) {
            my ($key) = split /\s+/, $args;
            my $type = $keyword eq 'NO_SECKEY'? 'secret': 'public';
            my %res = (
                Operation => 'KeyCheck',
                Status    => 'MISSING',
                Message   => ucfirst( $type ) ." key '0x$key' is not available",
                Key       => $key,
                KeyType   => $type,
            );
            $res{'User'} = ( $user_hint{ $key } ||= {} );
            $res{'User'}{ ucfirst( $type ). 'KeyMissing' } = 1;
            push @res, \%res;
        }
        # GOODSIG, BADSIG, VALIDSIG, TRUST_*
        elsif ( $keyword eq 'GOODSIG' ) {
            my %res = (
                Operation  => 'Verify',
                Status     => 'DONE',
                Message    => 'The signature is good',
            );
            @res{qw(Key UserString)} = split /\s+/, $args, 2;
            $res{'Message'} .= ', signed by '. $res{'UserString'};

            foreach my $line ( @status[ $i .. $#status ] ) {
                next unless $line =~ /^TRUST_(\S+)/;
                $res{'Trust'} = $1;
                last;
            }
            $res{'Message'} .= ', trust level is '. lc( $res{'Trust'} || 'unknown');

            foreach my $line ( @status[ $i .. $#status ] ) {
                next unless $line =~ /^VALIDSIG\s+(.*)/;
                @res{ qw(
                    Fingerprint
                    CreationDate
                    Timestamp
                    ExpireTimestamp
                    Version
                    Reserved
                    PubkeyAlgo
                    HashAlgo
                    Class
                    PKFingerprint
                    Other
                ) } = split /\s+/, $1, 10;
                last;
            }
            push @res, \%res;
        }
        elsif ( $keyword eq 'BADSIG' ) {
            my %res = (
                Operation  => 'Verify',
                Status     => 'BAD',
                Message    => 'The signature has not been verified okay',
            );
            @res{qw(Key UserString)} = split /\s+/, $args, 2;
            push @res, \%res;
        }
        elsif ( $keyword eq 'ERRSIG' ) {
            my %res = (
                Operation => 'Verify',
                Status    => 'ERROR',
                Message   => 'Not possible to check the signature',
            );
            @res{qw(Key PubkeyAlgo HashAlgo Class Timestamp ReasonCode Other)}
                = split /\s+/, $args, 7;

            $res{'Reason'} = ReasonCodeToText( $keyword, $res{'ReasonCode'} );
            $res{'Message'} .= ", the reason is ". $res{'Reason'};

            push @res, \%res;
        }
        elsif ( $keyword eq 'SIG_CREATED' ) {
            # SIG_CREATED <type> <pubkey algo> <hash algo> <class> <timestamp> <key fpr>
            my @props = split /\s+/, $args;
            push @res, {
                Operation      => 'Sign',
                Status         => 'DONE',
                Message        => "Signed message",
                Type           => $props[0],
                PubKeyAlgo     => $props[1],
                HashKeyAlgo    => $props[2],
                Class          => $props[3],
                Timestamp      => $props[4],
                KeyFingerprint => $props[5],
                User           => $user_hint{ $latest_user_main_key },
            };
            $res[-1]->{Message} .= ' by '. $user_hint{ $latest_user_main_key }->{'EmailAddress'}
                if $user_hint{ $latest_user_main_key };
        }
        elsif ( $keyword eq 'INV_RECP' ) {
            my ($rcode, $recipient) = split /\s+/, $args, 2;
            my $reason = ReasonCodeToText( $keyword, $rcode );
            push @res, {
                Operation  => 'RecipientsCheck',
                Status     => 'ERROR',
                Message    => "Recipient '$recipient' is unusable, the reason is '$reason'",
                Recipient  => $recipient,
                ReasonCode => $rcode,
                Reason     => $reason,
            };
        }
        elsif ( $keyword eq 'NODATA' ) {
            my $rcode = (split /\s+/, $args)[0];
            my $reason = ReasonCodeToText( $keyword, $rcode );
            push @res, {
                Operation  => 'Data',
                Status     => 'ERROR',
                Message    => "No data has been found. The reason is '$reason'",
                ReasonCode => $rcode,
                Reason     => $reason,
            };
        }
        else {
            $RT::Logger->warning("Keyword $keyword is unknown");
            next;
        }
        $res[-1]{'Keyword'} = $keyword if @res && !$res[-1]{'Keyword'};
    }
    return @res;
}

sub _ParseUserHint {
    my ($status, $hint) = (@_);
    my ($main_key_id, $user_str) = ($hint =~ /^USERID_HINT\s+(\S+)\s+(.*)$/);
    return () unless $main_key_id;
    return (
        MainKey      => $main_key_id,
        String       => $user_str,
        EmailAddress => (map $_->address, Email::Address->parse( $user_str ))[0],
    );
}

sub _PrepareGnuPGOptions {
    my %opt = @_;
    my %res = map { lc $_ => $opt{ $_ } } grep $supported_opt{ lc $_ }, keys %opt;
    $res{'extra_args'} ||= [];
    foreach my $o ( grep !$supported_opt{ lc $_ }, keys %opt ) {
        push @{ $res{'extra_args'} }, '--'. lc $o;
        push @{ $res{'extra_args'} }, $opt{ $o }
            if defined $opt{ $o };
    }
    return %res;
}

{ my %key;
# no args -> clear
# one arg -> return preferred key
# many -> set
sub UseKeyForEncryption {
    unless ( @_ ) {
        %key = ();
    } elsif ( @_ > 1 ) {
        %key = (%key, @_);
        $key{ lc($_) } = delete $key{ $_ } foreach grep lc ne $_, keys %key;
    } else {
        return $key{ $_[0] };
    }
    return ();
} }

=head2 UseKeyForSigning

Returns or sets identifier of the key that should be used for signing.

Returns the current value when called without arguments.

Sets new value when called with one argument and unsets if it's undef.

=cut

{ my $key;
sub UseKeyForSigning {
    if ( @_ ) {
        $key = $_[0];
    }
    return $key;
} }

=head2 GetKeysForEncryption

Takes identifier and returns keys suitable for encryption.

B<Note> that keys for which trust level is not set are
also listed.

=cut

sub GetKeysForEncryption {
    my $key_id = shift;
    my %res = GetKeysInfo( $key_id, 'public', @_ );
    return %res if $res{'exit_code'};
    return %res unless $res{'info'};

    foreach my $key ( splice @{ $res{'info'} } ) {
        # skip disabled keys
        next if $key->{'Capabilities'} =~ /D/;
        # skip keys not suitable for encryption
        next unless $key->{'Capabilities'} =~ /e/i;
        # skip disabled, expired, revoke and keys with no trust,
        # but leave keys with unknown trust level
        next if $key->{'TrustLevel'} < 0;

        push @{ $res{'info'} }, $key;
    }
    delete $res{'info'} unless @{ $res{'info'} };
    return %res;
}

sub GetKeysForSigning {
    my $key_id = shift;
    return GetKeysInfo( $key_id, 'private', @_ );
}

sub CheckRecipients {
    my @recipients = (@_);

    my ($status, @issues) = (1, ());

    my %seen;
    foreach my $address ( grep !$seen{ lc $_ }++, map $_->address, @recipients ) {
        my %res = GetKeysForEncryption( $address );
        if ( $res{'info'} && @{ $res{'info'} } == 1 && $res{'info'}[0]{'TrustLevel'} > 0 ) {
            # good, one suitable and trusted key 
            next;
        }
        my $user = RT::User->new( RT->SystemUser );
        $user->LoadByEmail( $address );
        # it's possible that we have no User record with the email
        $user = undef unless $user->id;

        if ( my $fpr = UseKeyForEncryption( $address ) ) {
            if ( $res{'info'} && @{ $res{'info'} } ) {
                next if
                    grep lc $_->{'Fingerprint'} eq lc $fpr,
                    grep $_->{'TrustLevel'} > 0,
                    @{ $res{'info'} };
            }

            $status = 0;
            my %issue = (
                EmailAddress => $address,
                $user? (User => $user) : (),
                Keys => undef,
            );
            $issue{'Message'} = "Selected key either is not trusted or doesn't exist anymore."; #loc
            push @issues, \%issue;
            next;
        }

        my $prefered_key;
        $prefered_key = $user->PreferredKey if $user;
        #XXX: prefered key is not yet implemented...

        # classify errors
        $status = 0;
        my %issue = (
            EmailAddress => $address,
            $user? (User => $user) : (),
            Keys => undef,
        );

        unless ( $res{'info'} && @{ $res{'info'} } ) {
            # no key
            $issue{'Message'} = "There is no key suitable for encryption."; #loc
        }
        elsif ( @{ $res{'info'} } == 1 && !$res{'info'}[0]{'TrustLevel'} ) {
            # trust is not set
            $issue{'Message'} = "There is one suitable key, but trust level is not set."; #loc
        }
        else {
            # multiple keys
            $issue{'Message'} = "There are several keys suitable for encryption."; #loc
        }
        push @issues, \%issue;
    }
    return ($status, @issues);
}

sub GetPublicKeyInfo {
    return GetKeyInfo( shift, 'public', @_ );
}

sub GetPrivateKeyInfo {
    return GetKeyInfo( shift, 'private', @_ );
}

sub GetKeyInfo {
    my %res = GetKeysInfo(@_);
    $res{'info'} = $res{'info'}->[0];
    return %res;
}

sub GetKeysInfo {
    my $email = shift;
    my $type = shift || 'public';
    my $force = shift;

    unless ( $email ) {
        return (exit_code => 0) unless $force;
    }

    my $gnupg = GnuPG::Interface->new();
    my %opt = RT->Config->Get('GnuPGOptions');
    $opt{'digest-algo'} ||= 'SHA1';
    $opt{'with-colons'} = undef; # parseable format
    $opt{'fingerprint'} = undef; # show fingerprint
    $opt{'fixed-list-mode'} = undef; # don't merge uid with keys
    $gnupg->options->hash_init(
        _PrepareGnuPGOptions( %opt ),
        armor => 1,
        meta_interactive => 0,
    );

    my %res;

    my ($handles, $handle_list) = _make_gpg_handles();
    my %handle = %$handle_list;

    eval {
        local $SIG{'CHLD'} = 'DEFAULT';
        my $method = $type eq 'private'? 'list_secret_keys': 'list_public_keys';
        my $pid = safe_run_child { $gnupg->$method( handles => $handles, $email
                                                        ? (command_args => [ "--", $email])
                                                        : () ) };
        close $handle{'stdin'};
        waitpid $pid, 0;
    };

    my @info = readline $handle{'stdout'};
    close $handle{'stdout'};

    $res{'exit_code'} = $?;
    foreach ( qw(stderr logger status) ) {
        $res{$_} = do { local $/; readline $handle{$_} };
        delete $res{$_} unless $res{$_} && $res{$_} =~ /\S/s;
        close $handle{$_};
    }
    $RT::Logger->debug( $res{'status'} ) if $res{'status'};
    $RT::Logger->warning( $res{'stderr'} ) if $res{'stderr'};
    if ( $res{'logger'} && $? ) {
        $RT::Logger->error( $res{'logger'} );
        $RT::Logger->error( 'The above error may result from an unconfigured RT/GPG installation. See perldoc etc/RT_Config.pm for information about configuring or disabling GPG support for RT' );
    }
    if ( $@ || $? ) {
        $res{'message'} = $@? $@: "gpg exitted with error code ". ($? >> 8);
        return %res;
    }

    @info = ParseKeysInfo( @info );
    $res{'info'} = \@info;
    return %res;
}

sub ParseKeysInfo {
    my @lines = @_;

    my %gpg_opt = RT->Config->Get('GnuPGOptions');

    my @res = ();
    foreach my $line( @lines ) {
        chomp $line;
        my $tag;
        ($tag, $line) = split /:/, $line, 2;
        if ( $tag eq 'pub' ) {
            my %info;
            @info{ qw(
                TrustChar KeyLength Algorithm Key
                Created Expire Empty OwnerTrustChar
                Empty Empty Capabilities Other
            ) } = split /:/, $line, 12;

            # workaround gnupg's wierd behaviour, --list-keys command report calculated trust levels
            # for any model except 'always', so you can change models and see changes, but not for 'always'
            # we try to handle it in a simple way - we set ultimate trust for any key with trust
            # level >= 0 if trust model is 'always'
            my $always_trust;
            $always_trust = 1 if exists $gpg_opt{'always-trust'};
            $always_trust = 1 if exists $gpg_opt{'trust-model'} && $gpg_opt{'trust-model'} eq 'always';
            @info{qw(Trust TrustTerse TrustLevel)} = 
                _ConvertTrustChar( $info{'TrustChar'} );
            if ( $always_trust && $info{'TrustLevel'} >= 0 ) {
                @info{qw(Trust TrustTerse TrustLevel)} = 
                    _ConvertTrustChar( 'u' );
            }

            @info{qw(OwnerTrust OwnerTrustTerse OwnerTrustLevel)} = 
                _ConvertTrustChar( $info{'OwnerTrustChar'} );
            $info{ $_ } = _ParseDate( $info{ $_ } )
                foreach qw(Created Expire);
            push @res, \%info;
        }
        elsif ( $tag eq 'sec' ) {
            my %info;
            @info{ qw(
                Empty KeyLength Algorithm Key
                Created Expire Empty OwnerTrustChar
                Empty Empty Capabilities Other
            ) } = split /:/, $line, 12;
            @info{qw(OwnerTrust OwnerTrustTerse OwnerTrustLevel)} = 
                _ConvertTrustChar( $info{'OwnerTrustChar'} );
            $info{ $_ } = _ParseDate( $info{ $_ } )
                foreach qw(Created Expire);
            push @res, \%info;
        }
        elsif ( $tag eq 'uid' ) {
            my %info;
            @info{ qw(Trust Created Expire String) }
                = (split /:/, $line)[0,4,5,8];
            $info{ $_ } = _ParseDate( $info{ $_ } )
                foreach qw(Created Expire);
            push @{ $res[-1]{'User'} ||= [] }, \%info;
        }
        elsif ( $tag eq 'fpr' ) {
            $res[-1]{'Fingerprint'} = (split /:/, $line, 10)[8];
        }
    }
    return @res;
}

{
    my %verbose = (
        # deprecated
        d   => [
            "The key has been disabled", #loc
            "key disabled", #loc
            "-2"
        ],

        r   => [
            "The key has been revoked", #loc
            "key revoked", #loc
            -3,
        ],

        e   => [ "The key has expired", #loc
            "key expired", #loc
            '-4',
        ],

        n   => [ "Don't trust this key at all", #loc
            'none', #loc
            -1,
        ],

        #gpupg docs says that '-' and 'q' may safely be treated as the same value
        '-' => [
            'Unknown (no trust value assigned)', #loc
            'not set',
            0,
        ],
        q   => [
            'Unknown (no trust value assigned)', #loc
            'not set',
            0,
        ],
        o   => [
            'Unknown (this value is new to the system)', #loc
            'unknown',
            0,
        ],

        m   => [
            "There is marginal trust in this key", #loc
            'marginal', #loc
            1,
        ],
        f   => [
            "The key is fully trusted", #loc
            'full', #loc
            2,
        ],
        u   => [
            "The key is ultimately trusted", #loc
            'ultimate', #loc
            3,
        ],
    );

    sub _ConvertTrustChar {
        my $value = shift;
        return @{ $verbose{'-'} } unless $value;
        $value = substr $value, 0, 1;
        return @{ $verbose{ $value } || $verbose{'o'} };
    }
}

sub _ParseDate {
    my $value = shift;
    # never
    return $value unless $value;

    require RT::Date;
    my $obj = RT::Date->new( RT->SystemUser );
    # unix time
    if ( $value =~ /^\d+$/ ) {
        $obj->Set( Value => $value );
    } else {
        $obj->Set( Format => 'unknown', Value => $value, Timezone => 'utc' );
    }
    return $obj;
}

sub DeleteKey {
    my $key = shift;

    my $gnupg = GnuPG::Interface->new();
    my %opt = RT->Config->Get('GnuPGOptions');
    $gnupg->options->hash_init(
        _PrepareGnuPGOptions( %opt ),
        meta_interactive => 0,
    );

    my ($handles, $handle_list) = _make_gpg_handles();
    my %handle = %$handle_list;

    eval {
        local $SIG{'CHLD'} = 'DEFAULT';
        my $pid = safe_run_child { $gnupg->wrap_call(
            handles => $handles,
            commands => ['--delete-secret-and-public-key'],
            command_args => ["--", $key],
        ) };
        close $handle{'stdin'};
        while ( my $str = readline $handle{'status'} ) {
            if ( $str =~ /^\[GNUPG:\]\s*GET_BOOL delete_key\..*/ ) {
                print { $handle{'command'} } "y\n";
            }
        }
        waitpid $pid, 0;
    };
    my $err = $@;
    close $handle{'stdout'};

    my %res;
    $res{'exit_code'} = $?;
    foreach ( qw(stderr logger status) ) {
        $res{$_} = do { local $/; readline $handle{$_} };
        delete $res{$_} unless $res{$_} && $res{$_} =~ /\S/s;
        close $handle{$_};
    }
    $RT::Logger->debug( $res{'status'} ) if $res{'status'};
    $RT::Logger->warning( $res{'stderr'} ) if $res{'stderr'};
    $RT::Logger->error( $res{'logger'} ) if $res{'logger'} && $?;
    if ( $err || $res{'exit_code'} ) {
        $res{'message'} = $err? $err : "gpg exitted with error code ". ($res{'exit_code'} >> 8);
    }
    return %res;
}

sub ImportKey {
    my $key = shift;

    my $gnupg = GnuPG::Interface->new();
    my %opt = RT->Config->Get('GnuPGOptions');
    $gnupg->options->hash_init(
        _PrepareGnuPGOptions( %opt ),
        meta_interactive => 0,
    );

    my ($handles, $handle_list) = _make_gpg_handles();
    my %handle = %$handle_list;

    eval {
        local $SIG{'CHLD'} = 'DEFAULT';
        my $pid = safe_run_child { $gnupg->wrap_call(
            handles => $handles,
            commands => ['--import'],
        ) };
        print { $handle{'stdin'} } $key;
        close $handle{'stdin'};
        waitpid $pid, 0;
    };
    my $err = $@;
    close $handle{'stdout'};

    my %res;
    $res{'exit_code'} = $?;
    foreach ( qw(stderr logger status) ) {
        $res{$_} = do { local $/; readline $handle{$_} };
        delete $res{$_} unless $res{$_} && $res{$_} =~ /\S/s;
        close $handle{$_};
    }
    $RT::Logger->debug( $res{'status'} ) if $res{'status'};
    $RT::Logger->warning( $res{'stderr'} ) if $res{'stderr'};
    $RT::Logger->error( $res{'logger'} ) if $res{'logger'} && $?;
    if ( $err || $res{'exit_code'} ) {
        $res{'message'} = $err? $err : "gpg exitted with error code ". ($res{'exit_code'} >> 8);
    }
    return %res;
}

=head2 KEY

Signs a small message with the key, to make sure the key exists and 
we have a useable passphrase. The first argument MUST be a key identifier
of the signer: either email address, key id or finger print.

Returns a true value if all went well.

=cut

sub DrySign {
    my $from = shift;

    my $mime = MIME::Entity->build(
        Type    => "text/plain",
        From    => 'nobody@localhost',
        To      => 'nobody@localhost',
        Subject => "dry sign",
        Data    => ['t'],
    );

    my %res = SignEncrypt(
        Sign    => 1,
        Encrypt => 0,
        Entity  => $mime,
        Signer  => $from,
    );

    return $res{exit_code} == 0;
}

1;

=head2 Probe

This routine returns true if RT's GnuPG support is configured and working 
properly (and false otherwise).


=cut


sub Probe {
    my $gnupg = GnuPG::Interface->new();
    my %opt = RT->Config->Get('GnuPGOptions');
    $gnupg->options->hash_init(
        _PrepareGnuPGOptions( %opt ),
        armor => 1,
        meta_interactive => 0,
    );

    my ($handles, $handle_list) = _make_gpg_handles();
    my %handle = %$handle_list;

    local $@;
    eval {
        local $SIG{'CHLD'} = 'DEFAULT';
        my $pid = safe_run_child { $gnupg->wrap_call( commands => ['--version' ], handles => $handles ) };
        close $handle{'stdin'};
        waitpid $pid, 0;
    };
    if ( $@ ) {
        $RT::Logger->debug(
            "Probe for GPG failed."
            ." Couldn't run `gpg --version`: ". $@
        );
        return 0;
    }

# on some systems gpg exits with code 2, but still 100% functional,
# it's general error system error or incorrect command, command is correct,
# but there is no way to get actuall error
    if ( $? && ($? >> 8) != 2 ) {
        my $msg = "Probe for GPG failed."
            ." Process exitted with code ". ($? >> 8)
            . ($? & 127 ? (" as recieved signal ". ($? & 127)) : '')
            . ".";
        foreach ( qw(stderr logger status) ) {
            my $tmp = do { local $/; readline $handle{$_} };
            next unless $tmp && $tmp =~ /\S/s;
            close $handle{$_};
            $msg .= "\n$_:\n$tmp\n";
        }
        $RT::Logger->debug( $msg );
        return 0;
    }
    return 1;
}


sub _make_gpg_handles {
    my %handle_map = (@_);
    $handle_map{$_} = IO::Handle->new
        foreach grep !defined $handle_map{$_}, 
        qw(stdin stdout stderr logger status command);

    my $handles = GnuPG::Handles->new(%handle_map);
    return ($handles, \%handle_map);
}

RT::Base->_ImportOverlays();

# helper package to avoid using temp file
package IO::Handle::CRLF;

use base qw(IO::Handle);

sub print {
    my ($self, @args) = (@_);
    s/\r*\n/\x0D\x0A/g foreach @args;
    return $self->SUPER::print( @args );
}

1;
