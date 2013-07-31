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

package RT::Crypt::GnuPG;

use Role::Basic 'with';
with 'RT::Crypt::Role';

use IO::Handle;
use RT::Crypt::GnuPG::CRLFHandle;
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

However, note that you B<must> add the 'Auth::Crypt' email filter to enable
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

=head3 Passphrases

Passphrases for keys may be set by passing C<Passphrase>.  It may be set
to a scalar (to use for all keys), an anonymous function, or a hash (to
look up by address).  If the hash is used, the '' key is used as a
default.

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
default. As an administrative user of RT, open 'Admin' then 'Queues',
and select a queue. On the page you can see information about the queue's keys 
at the bottom and two checkboxes to choose default actions.

As well, encryption is enabled for autoreplies and other notifications when
an encypted message enters system via mailgate interface even if queue's
option is disabled.

=head2 Handling incoming messages

To enable handling of encrypted and signed message in the RT you should add
'Auth::Crypt' mail plugin.

    Set(@MailPlugins, 'Auth::MailFrom', 'Auth::Crypt', ...other filter...);

See also `perldoc lib/RT/Interface/Email/Auth/Crypt.pm`.

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

sub CallGnuPG {
    my $self = shift;
    my %args = (
        Options     => undef,
        Signer      => undef,
        Recipients  => [],
        Passphrase  => undef,

        Command     => undef,
        CommandArgs => [],

        Content     => undef,
        Handles     => {},
        Direct      => undef,
        Output      => undef,
        @_
    );

    my %handle = %{$args{Handles}};
    my ($handles, $handle_list) = _make_gpg_handles( %handle );
    $handles->options( $_ )->{'direct'} = 1
        for @{$args{Direct} || [keys %handle] };
    %handle = %$handle_list;

    my $content = $args{Content};
    my $command = $args{Command};

    my %GnuPGOptions = RT->Config->Get('GnuPGOptions');
    my %opt = (
        'digest-algo' => 'SHA1',
        %GnuPGOptions,
        %{ $args{Options} || {} },
    );
    my $gnupg = GnuPG::Interface->new;
    $gnupg->options->hash_init(
        _PrepareGnuPGOptions( %opt ),
    );
    $gnupg->options->armor( 1 );
    $gnupg->options->meta_interactive( 0 );
    $gnupg->options->default_key( $args{Signer} )
        if defined $args{Signer};

    my %seen;
    $gnupg->options->push_recipients( $_ ) for
        map { RT::Crypt->UseKeyForEncryption($_) || $_ }
        grep { !$seen{ $_ }++ }
            @{ $args{Recipients} || [] };

    $args{Passphrase} = $GnuPGOptions{passphrase}
        unless defined $args{'Passphrase'};
    $args{Passphrase} = $self->GetPassphrase( Address => $args{Signer} )
        unless defined $args{'Passphrase'};
    $gnupg->passphrase( $args{'Passphrase'} )
        if defined $args{Passphrase};

    eval {
        local $SIG{'CHLD'} = 'DEFAULT';
        my $pid = safe_run_child {
            if ($command =~ /^--/) {
                $gnupg->wrap_call(
                    handles      => $handles,
                    commands     => [$command],
                    command_args => $args{CommandArgs},
                );
            } else {
                $gnupg->$command(
                    handles      => $handles,
                    command_args => $args{CommandArgs},
                );
            }
        };
        {
            local $SIG{'PIPE'} = 'IGNORE';
            if (Scalar::Util::blessed($content) and $content->can("print")) {
                $content->print( $handle{'stdin'} );
            } elsif (ref($content) eq "SCALAR") {
                $handle{'stdin'}->print( ${ $content } );
            } elsif (defined $content) {
                $handle{'stdin'}->print( $content );
            }
            close $handle{'stdin'} or die "Can't close gnupg input handle: $!";
            $args{Callback}->(%handle) if $args{Callback};
        }
        waitpid $pid, 0;
    };
    my $err = $@;
    if ($args{Output}) {
        push @{$args{Output}}, readline $handle{stdout};
        if (not close $handle{stdout}) {
            $err ||= "Can't close gnupg output handle: $!";
        }
    }

    my %res;
    $res{'exit_code'} = $?;

    foreach ( qw(stderr logger status) ) {
        $res{$_} = do { local $/ = undef; readline $handle{$_} };
        delete $res{$_} unless $res{$_} && $res{$_} =~ /\S/s;
        if (not close $handle{$_}) {
            $err ||= "Can't close gnupg $_ handle: $!";
        }
    }
    $RT::Logger->debug( $res{'status'} ) if $res{'status'};
    $RT::Logger->warning( $res{'stderr'} ) if $res{'stderr'};
    $RT::Logger->error( $res{'logger'} ) if $res{'logger'} && $?;
    if ( $err || $res{'exit_code'} ) {
        $res{'message'} = $err? $err : "gpg exited with error code ". ($res{'exit_code'} >> 8);
    }

    return %res;
}

sub SignEncrypt {
    my $self = shift;

    my $format = lc RT->Config->Get('GnuPG')->{'OutgoingMessagesFormat'} || 'RFC';
    if ( $format eq 'inline' ) {
        return $self->SignEncryptInline( @_ );
    } else {
        return $self->SignEncryptRFC3156( @_ );
    }
}

sub SignEncryptRFC3156 {
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
        $entity->make_multipart( 'mixed', Force => 1 );

        my @signature;
        # We use RT::Crypt::GnuPG::CRLFHandle to canonicalize the
        # MIME::Entity output to use \r\n instead of \n for its newlines
        %res = $self->CallGnuPG(
            Signer     => $args{'Signer'},
            Command    => "detach_sign",
            Handles    => { stdin => RT::Crypt::GnuPG::CRLFHandle->new },
            Direct     => [],
            Passphrase => $args{'Passphrase'},
            Content    => $entity->parts(0),
            Output     => \@signature,
        );
        return %res if $res{message};

        # setup RFC1847(Ch.2.1) requirements
        my $protocol = 'application/pgp-signature';
        my $algo = RT->Config->Get('GnuPGOptions')->{'digest-algo'} || 'SHA1';
        $entity->head->mime_attr( 'Content-Type' => 'multipart/signed' );
        $entity->head->mime_attr( 'Content-Type.protocol' => $protocol );
        $entity->head->mime_attr( 'Content-Type.micalg'   => 'pgp-'. lc $algo );
        $entity->attach(
            Type        => $protocol,
            Disposition => 'inline',
            Data        => \@signature,
            Encoding    => '7bit',
        );
    }
    if ( $args{'Encrypt'} ) {
        my @recipients = map $_->address,
            map Email::Address->parse( $entity->head->get( $_ ) ),
            qw(To Cc Bcc);

        my ($tmp_fh, $tmp_fn) = File::Temp::tempfile( UNLINK => 1 );
        binmode $tmp_fh, ':raw';

        $entity->make_multipart( 'mixed', Force => 1 );
        %res = $self->CallGnuPG(
            Signer     => $args{'Signer'},
            Recipients => \@recipients,
            Command    => ( $args{'Sign'} ? "sign_and_encrypt" : "encrypt" ),
            Handles    => { stdout => $tmp_fh },
            Passphrase => $args{'Passphrase'},
            Content    => $entity->parts(0),
        );
        return %res if $res{message};

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
    my $self = shift;
    my %args = ( @_ );

    my $entity = $args{'Entity'};

    my %res;
    $entity->make_singlepart;
    if ( $entity->is_multipart ) {
        foreach ( $entity->parts ) {
            %res = $self->SignEncryptInline( @_, Entity => $_ );
            return %res if $res{'exit_code'};
        }
        return %res;
    }

    return $self->_SignEncryptTextInline( @_ )
        if $entity->effective_type =~ /^text\//i;

    return $self->_SignEncryptAttachmentInline( @_ );
}

sub _SignEncryptTextInline {
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
    return unless $args{'Sign'} || $args{'Encrypt'};

    my ($tmp_fh, $tmp_fn) = File::Temp::tempfile( UNLINK => 1 );
    binmode $tmp_fh, ':raw';

    my $entity = $args{'Entity'};
    my %res = $self->CallGnuPG(
        Signer     => $args{'Signer'},
        Recipients => $args{'Recipients'},
        Command    => ( $args{'Sign'} && $args{'Encrypt'}
                      ? 'sign_and_encrypt'
                      : ( $args{'Sign'}
                        ? 'clearsign'
                        : 'encrypt' ) ),
        Handles    => { stdout => $tmp_fh },
        Passphrase => $args{'Passphrase'},
        Content    => $entity->bodyhandle,
    );
    return %res if $res{message};

    $entity->bodyhandle( MIME::Body::File->new( $tmp_fn) );
    $entity->{'__store_tmp_handle_to_avoid_early_cleanup'} = $tmp_fh;

    return %res;
}

sub _SignEncryptAttachmentInline {
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
    return unless $args{'Sign'} || $args{'Encrypt'};


    my $entity = $args{'Entity'};

    my ($tmp_fh, $tmp_fn) = File::Temp::tempfile( UNLINK => 1 );
    binmode $tmp_fh, ':raw';

    my %res = $self->CallGnuPG(
        Signer     => $args{'Signer'},
        Recipients => $args{'Recipients'},
        Command    => ( $args{'Sign'} && $args{'Encrypt'}
                      ? 'sign_and_encrypt'
                      : ( $args{'Sign'}
                        ? 'detach_sign'
                        : 'encrypt' ) ),
        Handles    => { stdout => $tmp_fh },
        Passphrase => $args{'Passphrase'},
        Content    => $entity->bodyhandle,
    );
    return %res if $res{message};

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
    my $self = shift;
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

    my ($tmp_fh, $tmp_fn) = File::Temp::tempfile( UNLINK => 1 );
    binmode $tmp_fh, ':raw';

    my %res = $self->CallGnuPG(
        Signer     => $args{'Signer'},
        Recipients => $args{'Recipients'},
        Command    => ( $args{'Sign'} && $args{'Encrypt'}
                      ? 'sign_and_encrypt'
                      : ( $args{'Sign'}
                        ? 'clearsign'
                        : 'encrypt' ) ),
        Handles    => { stdout => $tmp_fh },
        Passphrase => $args{'Passphrase'},
        Content    => $args{'Content'},
    );
    return %res if $res{message};

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

sub CheckIfProtected {
    my $self = shift;
    my %args = ( Entity => undef, @_ );

    my $entity = $args{'Entity'};

    # we check inline PGP block later in another sub
    return () unless $entity->is_multipart;

    # RFC3156, multipart/{signed,encrypted}
    my $type = $entity->effective_type;
    return () unless $type =~ /^multipart\/(?:encrypted|signed)$/;

    unless ( $entity->parts == 2 ) {
        $RT::Logger->error( "Encrypted or signed entity must has two subparts. Skipped" );
        return ();
    }

    my $protocol = $entity->head->mime_attr( 'Content-Type.protocol' );
    unless ( $protocol ) {
        # if protocol is not set then we can check second part for PGP message
        $RT::Logger->error( "Entity is '$type', but has no protocol defined. Checking for PGP part" );
        my $protected = $self->_CheckIfProtectedInline( $entity->parts(1), 1 );
        return () unless $protected;

        if ( $protected eq 'signature' ) {
            $RT::Logger->debug("Found part signed according to RFC3156");
            return (
                Type      => 'signed',
                Format    => 'RFC3156',
                Top       => $entity,
                Data      => $entity->parts(0),
                Signature => $entity->parts(1),
            );
        } else {
            $RT::Logger->debug("Found part encrypted according to RFC3156");
            return (
                Type   => 'encrypted',
                Format => 'RFC3156',
                Top    => $entity,
                Data   => $entity->parts(1),
                Info   => $entity->parts(0),
            );
        }
    }
    elsif ( $type eq 'multipart/encrypted' ) {
        unless ( $protocol eq 'application/pgp-encrypted' ) {
            $RT::Logger->info( "Skipping protocol '$protocol', only 'application/pgp-encrypted' is supported" );
            return ();
        }
        $RT::Logger->debug("Found part encrypted according to RFC3156");
        return (
            Type   => 'encrypted',
            Format => 'RFC3156',
            Top    => $entity,
            Data   => $entity->parts(1),
            Info   => $entity->parts(0),
        );
    } else {
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


sub FindScatteredParts {
    my $self = shift;
    my %args = ( Parts => [], Skip => {}, @_ );

    my @res;

    my @parts = @{ $args{'Parts'} };

    # attachments signed with signature in another part
    {
        my @file_indices;
        for (my $i = 0; $i < @parts; $i++ ) {
            my $part = $parts[ $i ];

            # we can not associate a signature within an attachment
            # without file names
            my $fname = $part->head->recommended_filename;
            next unless $fname;

            my $type = $part->effective_type;

            if ( $type eq 'application/pgp-signature' ) {
                push @file_indices, $i;
            }
            elsif ( $type eq 'application/octet-stream' && $fname =~ /\.sig$/i ) {
                push @file_indices, $i;
            }
        }

        foreach my $i ( @file_indices ) {
            my $sig_part = $parts[ $i ];
            my $sig_name = $sig_part->head->recommended_filename;
            my ($file_name) = $sig_name =~ /^(.*?)(?:\.sig)?$/;

            my ($data_part_idx) =
                grep $file_name eq ($parts[$_]->head->recommended_filename||''),
                grep $sig_part  ne  $parts[$_],
                    0 .. @parts - 1;
            unless ( defined $data_part_idx ) {
                $RT::Logger->error("Found $sig_name attachment, but didn't find $file_name");
                next;
            }

            my $data_part_in = $parts[ $data_part_idx ];

            $RT::Logger->debug("Found signature (in '$sig_name') of attachment '$file_name'");

            $args{'Skip'}{$data_part_in} = 1;
            $args{'Skip'}{$sig_part} = 1;
            push @res, {
                Type      => 'signed',
                Format    => 'Attachment',
                Top       => $args{'Parents'}{$sig_part},
                Data      => $data_part_in,
                Signature => $sig_part,
            };
        }
    }

    # attachments with inline encryption
    foreach my $part ( @parts ) {
        next if $args{'Skip'}{$part};

        my $fname = $part->head->recommended_filename || '';
        next unless $fname =~ /\.${RE_FILE_EXTENSIONS}$/;

        $RT::Logger->debug("Found encrypted attachment '$fname'");

        $args{'Skip'}{$part} = 1;
        push @res, {
            Type    => 'encrypted',
            Format  => 'Attachment',
            Data    => $part,
        };
    }

    # inline PGP block
    foreach my $part ( @parts ) {
        next if $args{'Skip'}{$part};

        my $type = $self->_CheckIfProtectedInline( $part );
        next unless $type;

        my $file = ($part->head->recommended_filename||'') =~ /\.${RE_FILE_EXTENSIONS}$/;

        $args{'Skip'}{$part} = 1;
        push @res, {
            Type      => $type,
            Format    => !$file || $type eq 'signed'? 'Inline' : 'Attachment',
            Data      => $part,
        };
    }

    return @res;
}

sub _CheckIfProtectedInline {
    my $self = shift;
    my $entity = shift;
    my $check_for_signature = shift || 0;

    my $io = $entity->open('r');
    unless ( $io ) {
        $RT::Logger->warning( "Entity of type ". $entity->effective_type ." has no body" );
        return '';
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
        if ( /^-----BEGIN PGP (SIGNED )?MESSAGE-----/ ) {
            return $1? 'signed': 'encrypted';
        }
        elsif ( $check_for_signature && !/^-----BEGIN PGP SIGNATURE-----/ ) {
            return 'signature';
        }
    }
    $io->close;
    return '';
}

sub VerifyDecrypt {
    my $self = shift;
    my %args = (
        Info      => undef,
        @_
    );

    my %res;

    my $item = $args{'Info'};
    my $status_on;
    if ( $item->{'Type'} eq 'signed' ) {
        if ( $item->{'Format'} eq 'RFC3156' ) {
            %res = $self->VerifyRFC3156( %$item );
            $status_on = $item->{'Top'};
        } elsif ( $item->{'Format'} eq 'Inline' ) {
            %res = $self->VerifyInline( %$item );
            $status_on = $item->{'Data'};
        } elsif ( $item->{'Format'} eq 'Attachment' ) {
            %res = $self->VerifyAttachment( %$item );
            $status_on = $item->{'Data'};
        } else {
            die "Unknown format '".$item->{'Format'} . "' of GnuPG signed part";
        }
    } elsif ( $item->{'Type'} eq 'encrypted' ) {
        if ( $item->{'Format'} eq 'RFC3156' ) {
            %res = $self->DecryptRFC3156( %$item );
            $status_on = $item->{'Top'};
        } elsif ( $item->{'Format'} eq 'Inline' ) {
            %res = $self->DecryptInline( %$item );
            $status_on = $item->{'Data'};
        } elsif ( $item->{'Format'} eq 'Attachment' ) {
            %res = $self->DecryptAttachment( %$item );
            $status_on = $item->{'Data'};
        } else {
            die "Unknown format '".$item->{'Format'} . "' of GnuPG encrypted part";
        }
    } else {
        die "Unknown type '".$item->{'Type'} . "' of protected item";
    }

    return (%res, status_on => $status_on);
}

sub VerifyInline { return (shift)->DecryptInline( @_ ) }

sub VerifyAttachment {
    my $self = shift;
    my %args = ( Data => undef, Signature => undef, @_ );

    foreach ( $args{'Data'}, $args{'Signature'} ) {
        next unless $_->bodyhandle->is_encoded;

        require RT::EmailParser;
        RT::EmailParser->_DecodeBody($_);
    }

    my ($tmp_fh, $tmp_fn) = File::Temp::tempfile( UNLINK => 1 );
    binmode $tmp_fh, ':raw';
    $args{'Data'}->bodyhandle->print( $tmp_fh );
    $tmp_fh->flush;

    my %res = $self->CallGnuPG(
        Command     => "verify",
        CommandArgs => [ '-', $tmp_fn ],
        Passphrase  => $args{'Passphrase'},
        Content     => $args{'Signature'}->bodyhandle,
    );

    $args{'Top'}->parts( [
        grep "$_" ne $args{'Signature'}, $args{'Top'}->parts
    ] );
    $args{'Top'}->make_singlepart;

    return %res;
}

sub VerifyRFC3156 {
    my $self = shift;
    my %args = ( Data => undef, Signature => undef, @_ );

    my ($tmp_fh, $tmp_fn) = File::Temp::tempfile( UNLINK => 1 );
    binmode $tmp_fh, ':raw:eol(CRLF?)';
    $args{'Data'}->print( $tmp_fh );
    $tmp_fh->flush;

    my %res = $self->CallGnuPG(
        Command     => "verify",
        CommandArgs => [ '-', $tmp_fn ],
        Passphrase  => $args{'Passphrase'},
        Content     => $args{'Signature'}->bodyhandle,
    );

    $args{'Top'}->parts( [ $args{'Data'} ] );
    $args{'Top'}->make_singlepart;

    return %res;
}

sub DecryptRFC3156 {
    my $self = shift;
    my %args = (
        Data => undef,
        Info => undef,
        Top => undef,
        Passphrase => undef,
        @_
    );

    if ( $args{'Data'}->bodyhandle->is_encoded ) {
        require RT::EmailParser;
        RT::EmailParser->_DecodeBody($args{'Data'});
    }

    my ($tmp_fh, $tmp_fn) = File::Temp::tempfile( UNLINK => 1 );
    binmode $tmp_fh, ':raw';

    my %res = $self->CallGnuPG(
        Command     => "decrypt",
        Handles     => { stdout => $tmp_fh },
        Passphrase  => $args{'Passphrase'},
        Content     => $args{'Data'}->bodyhandle,
    );

    # if the decryption is fine but the signature is bad, then without this
    # status check we lose the decrypted text
    # XXX: add argument to the function to control this check
    delete $res{'message'} if $res{'status'} =~ /DECRYPTION_OKAY/;

    return %res if $res{message};

    seek $tmp_fh, 0, 0;
    my $parser = RT::EmailParser->new();
    my $decrypted = $parser->ParseMIMEEntityFromFileHandle( $tmp_fh, 0 );
    $decrypted->{'__store_link_to_object_to_avoid_early_cleanup'} = $parser;

    $args{'Top'}->parts( [$decrypted] );
    $args{'Top'}->make_singlepart;

    return %res;
}

sub DecryptInline {
    my $self = shift;
    my %args = (
        Data => undef,
        Passphrase => undef,
        @_
    );

    if ( $args{'Data'}->bodyhandle->is_encoded ) {
        require RT::EmailParser;
        RT::EmailParser->_DecodeBody($args{'Data'});
    }

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
            ($res_fh, $res_fn, %res) = $self->_DecryptInlineBlock(
                %args,
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
        ($res_fh, $res_fn, %res) = $self->_DecryptInlineBlock(
            %args,
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
    my $self = shift;
    my %args = (
        BlockHandle => undef,
        Passphrase => undef,
        @_
    );

    my ($tmp_fh, $tmp_fn) = File::Temp::tempfile( UNLINK => 1 );
    binmode $tmp_fh, ':raw';

    my %res = $self->CallGnuPG(
        Command     => "decrypt",
        Handles     => { stdout => $tmp_fh, stdin => $args{'BlockHandle'} },
        Passphrase  => $args{'Passphrase'},
    );

    # if the decryption is fine but the signature is bad, then without this
    # status check we lose the decrypted text
    # XXX: add argument to the function to control this check
    delete $res{'message'} if $res{'status'} =~ /DECRYPTION_OKAY/;

    return (undef, undef, %res) if $res{message};

    seek $tmp_fh, 0, 0;
    return ($tmp_fh, $tmp_fn, %res);
}

sub DecryptAttachment {
    my $self = shift;
    my %args = (
        Data => undef,
        Passphrase => undef,
        @_
    );

    if ( $args{'Data'}->bodyhandle->is_encoded ) {
        require RT::EmailParser;
        RT::EmailParser->_DecodeBody($args{'Data'});
    }

    my ($tmp_fh, $tmp_fn) = File::Temp::tempfile( UNLINK => 1 );
    binmode $tmp_fh, ':raw';
    $args{'Data'}->bodyhandle->print( $tmp_fh );
    seek $tmp_fh, 0, 0;

    my ($res_fh, $res_fn, %res) = $self->_DecryptInlineBlock(
        %args,
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
    my $self = shift;
    my %args = (
        Content => undef,
        Passphrase => undef,
        @_
    );

    my ($tmp_fh, $tmp_fn) = File::Temp::tempfile( UNLINK => 1 );
    binmode $tmp_fh, ':raw';

    my %res = $self->CallGnuPG(
        Command     => "decrypt",
        Handles     => { stdout => $tmp_fh },
        Passphrase  => $args{'Passphrase'},
        Content     => $args{'Content'},
    );

    # if the decryption is fine but the signature is bad, then without this
    # status check we lose the decrypted text
    # XXX: add argument to the function to control this check
    delete $res{'message'} if $res{'status'} =~ /DECRYPTION_OKAY/;

    return %res if $res{'message'};

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
    my $self = shift;
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

sub GetKeysForEncryption {
    my $self = shift;
    my %args = (Recipient => undef, @_);
    my %res = $self->GetKeysInfo( Key => delete $args{'Recipient'}, %args, Type => 'public' );
    return %res if $res{'exit_code'};
    return %res unless $res{'info'};

    foreach my $key ( splice @{ $res{'info'} } ) {
        # skip disabled keys
        next if $key->{'Capabilities'} =~ /D/;
        # skip keys not suitable for encryption
        next unless $key->{'Capabilities'} =~ /e/i;
        # skip disabled, expired, revoked and keys with no trust,
        # but leave keys with unknown trust level
        next if $key->{'TrustLevel'} < 0;

        push @{ $res{'info'} }, $key;
    }
    delete $res{'info'} unless @{ $res{'info'} };
    return %res;
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
    my $type = $args{'Type'};
    unless ( $email ) {
        return (exit_code => 0) unless $args{'Force'};
    }

    my @info;
    my $method = $type eq 'private'? 'list_secret_keys': 'list_public_keys';
    my %res = $self->CallGnuPG(
        Options     => {
            'with-colons'     => undef, # parseable format
            'fingerprint'     => undef, # show fingerprint
            'fixed-list-mode' => undef, # don't merge uid with keys
        },
        Command     => $method,
        ( $email ? (CommandArgs => ['--', $email]) : () ),
        Output      => \@info,
    );
    return %res if $res{'message'};

    @info = $self->ParseKeysInfo( @info );
    $res{'info'} = \@info;
    return %res;
}

sub ParseKeysInfo {
    my $self = shift;
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
            $info{ $_ } = $self->ParseDate( $info{ $_ } )
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
            $info{ $_ } = $self->ParseDate( $info{ $_ } )
                foreach qw(Created Expire);
            push @res, \%info;
        }
        elsif ( $tag eq 'uid' ) {
            my %info;
            @info{ qw(Trust Created Expire String) }
                = (split /:/, $line)[0,4,5,8];
            $info{ $_ } = $self->ParseDate( $info{ $_ } )
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

sub DeleteKey {
    my $self = shift;
    my $key = shift;

    return $self->CallGnuPG(
        Command     => "--delete-secret-and-public-key",
        CommandArgs => ["--", $key],
        Callback    => sub {
            my %handle = @_;
            while ( my $str = readline $handle{'status'} ) {
                if ( $str =~ /^\[GNUPG:\]\s*GET_BOOL delete_key\..*/ ) {
                    print { $handle{'command'} } "y\n";
                }
            }
        },
    );
}

sub ImportKey {
    my $self = shift;
    my $key = shift;

    return $self->CallGnuPG(
        Command     => "import_keys",
        Content     => $key,
    );
}

sub Probe {
    my $self = shift;
    my $gnupg = GnuPG::Interface->new;
    $gnupg->options->hash_init(
        _PrepareGnuPGOptions( RT->Config->Get('GnuPGOptions') )
    );
    $gnupg->options->meta_interactive( 0 );

    my ($handles, $handle_list) = _make_gpg_handles();
    my %handle = %$handle_list;

    local $@ = undef;
    eval {
        local $SIG{'CHLD'} = 'DEFAULT';
        my $pid = safe_run_child {
            $gnupg->wrap_call(
                commands => ['--version' ],
                handles  => $handles
            )
        };
        close $handle{'stdin'} or die "Can't close gnupg input handle: $!";
        waitpid $pid, 0;
    };
    if ( $@ ) {
        $RT::Logger->warning(
            "RT's GnuPG libraries couldn't successfully execute gpg.".
                " GnuPG support has been disabled");
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
            ." Process exited with code ". ($? >> 8)
            . ($? & 127 ? (" as recieved signal ". ($? & 127)) : '')
            . ".";
        foreach ( qw(stderr logger status) ) {
            my $tmp = do { local $/ = undef; readline $handle{$_} };
            next unless $tmp && $tmp =~ /\S/s;
            close $handle{$_} or $tmp .= "\nFailed to close: $!";
            $msg .= "\n$_:\n$tmp\n";
        }
        $RT::Logger->warning(
            "RT's GnuPG libraries couldn't successfully execute gpg.".
                " GnuPG support has been disabled");
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

1;
