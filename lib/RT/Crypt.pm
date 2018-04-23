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

package RT::Crypt;
use 5.010;

=head1 NAME

RT::Crypt - encrypt/decrypt and sign/verify subsystem for RT

=head1 DESCRIPTION

This module provides support for encryption and signing of outgoing
messages, as well as the decryption and verification of incoming emails
using various encryption standards. Currently, L<GnuPG|RT::Crypt::GnuPG>
and L<SMIME|RT::Crypt::SMIME> protocols are supported.

=head1 CONFIGURATION

You can control the configuration of this subsystem from RT's configuration file.
Some options are available via the web interface, but to enable this functionality,
you MUST start in the configuration file.

For each protocol there is a hash with the same name in the configuration file.
This hash controls RT-specific options regarding the protocol. It allows you to
enable/disable each facility or change the format of messages; for example, GnuPG
uses the following config:

    Set( %GnuPG,
        Enable => 1,
        ... other options ...
    );

C<Enable> is the only key that is generic for all protocols. A protocol may have
additional options to fine-tune behaviour.

=head2 %Crypt

This config option hash chooses which protocols are decrypted and
verified in incoming messages, which protocol is used for outgoing
emails, and RT's behaviour on errors during decrypting and verification.

RT will provide sane defaults for all of these options.  By default, all
enabled encryption protocols are decrypted on incoming mail; if you wish
to limit this to a subset, you may, via:

    Set( %Crypt,
        ...
        Incoming => ['SMIME'],
        ...
    );

RT can currently only use one protocol to encrypt and sign outgoing
email; this defaults to the first enabled protocol.  You many specify it
explicitly via:

    Set( %Crypt,
        ...
        Outgoing => 'GnuPG',
        ...
    );

You can allow users to encrypt data in the database by setting the
C<AllowEncryptDataInDB> key to a true value; by default, this is
disabled.  Be aware that users must have rights to see and modify
tickets to use this feature.

=head2 Per-queue options

Using the web interface, it is possible to enable signing and/or
encrypting by default. As an administrative user of RT, navigate to the
'Admin' and 'Queues' menus, and select a queue.  If at least one
encryption protocol is enabled, information concerning available keys
will be displayed, as well as options to enable signing and encryption.

=head2 Error handling

There are several global templates created in the database by
default. RT uses these templates to send error messages to users or RT's
owner. These templates have an 'Error:' or 'Error to RT owner:' prefix
in the name. You can adjust the text of the messages using the web
interface.

Note that while C<$TicketObj>, C<$TransactionObj> and other variables
usually available in RT's templates are not available in these
templates, but each is passed alternate data structures can be used to
build better messages; see the default templates and descriptions below.

You can disable any particular notification by simply deleting the
content of a template.  Deleting the templates entirely is not
suggested, as RT will log error messages when attempting to send mail
usign them.

=head3 Problems with public keys

The 'Error: public key' template is used to inform the user that RT had
problems with their public key, and thus will not be able to send
encrypted content. There are several reasons why RT might fail to use a
key; by default, the actual reason is not sent to the user, but sent to
the RT owner using the 'Error to RT owner: public key' template.

Possible reasons include "Not Found", "Ambiguous specification", "Wrong
key usage", "Key revoked", "Key expired", "No CRL known", "CRL too old",
"Policy mismatch", "Not a secret key", "Key not trusted" or "No specific
reason given".

In the 'Error: public key' template there are a few additional variables
available:

=over 4

=item $Message - user friendly error message

=item $Reason - short reason as listed above

=item $Recipient - recipient's identification

=item $AddressObj - L<Email::Address> object containing recipient's email address

=back

As a message may have several invalid recipients, to avoid sending many
emails to the RT owner, the system sends one message to the owner,
grouped by recipient. In the 'Error to RT owner: public key' template a
C<@BadRecipients> array is available where each element is a hash
reference that describes one recipient using the same fields as
described above:

    @BadRecipients = (
        { Message => '...', Reason => '...', Recipient => '...', ...},
        { Message => '...', Reason => '...', Recipient => '...', ...},
        ...
    )

=head3 Private key doesn't exist

The 'Error: no private key' template is used to inform the user that
they sent an encrypted email to RT, but RT does not have the private key
to decrypt it.

In this template L<MIME::Entity> object C<$Message> is available, which
is the originally received message.

=head3 Invalid data

The 'Error: bad encrypted data' template is used to inform the user that
a message they sent had invalid data, and could not be handled.  There
are several possible reasons for this error, but most of them are data
corruption or absence of expected information.

In this template, the C<@Messages> array is available, and will contain
a list of error messages.

=head1 METHODS

=head2 Protocols

Returns the complete set of encryption protocols that RT implements; not
all may be supported by this installation.

=cut

our @PROTOCOLS = ('GnuPG', 'SMIME');
our %PROTOCOLS = map { lc $_ => $_ } @PROTOCOLS;

sub Protocols {
    return @PROTOCOLS;
}

=head2 EnabledProtocols

Returns the set of enabled and available encryption protocols.

=cut

sub EnabledProtocols {
    my $self = shift;
    return grep RT->Config->Get($_)->{'Enable'}, $self->Protocols;
}

=head2 UseForOutgoing

Returns the configured outgoing encryption protocol; see
L<RT_Config/Crypt>.

=cut

sub UseForOutgoing {
    return RT->Config->Get('Crypt')->{'Outgoing'};
}

=head2 EnabledOnIncoming

Returns the list of encryption protocols that should be used for
decryption and verification of incoming email; see L<RT_Config/Crypt>.

=cut

sub EnabledOnIncoming {
    return @{ scalar RT->Config->Get('Crypt')->{'Incoming'} };
}

=head2 LoadImplementation CLASS

Given the name of an encryption implementation (e.g. "GnuPG"), loads the
L<RT::Crypt> class associated with it; return the classname on success,
and undef on failure.

=cut

sub LoadImplementation {
    state %cache;
    my $proto = $PROTOCOLS{ lc $_[1] } or die "Unknown protocol '$_[1]'";
    my $class = 'RT::Crypt::'. $proto;
    return $cache{ $class } if exists $cache{ $class };

    if ($class->require) {
        return $cache{ $class } = $class;
    } else {
        RT->Logger->warn( "Could not load $class: $@" );
        return $cache{ $class } = undef;
    }
}

=head2 SimpleImplementationCall Protocol => NAME, [...]

Examines the caller of this method, and dispatches to the method of the
same name on the correct L<RT::Crypt::Role> class based on the provided
C<Protocol>.

=cut

sub SimpleImplementationCall {
    my $self = shift;
    my %args = (@_);
    my $protocol = delete $args{'Protocol'} || $self->UseForOutgoing;

    my $method = (caller(1))[3];
    $method =~ s/.*:://;

    my %res = $self->LoadImplementation( $protocol )->$method( %args );
    $res{'Protocol'} = $protocol if keys %res;
    return %res;
}

=head2 FindProtectedParts Entity => MIME::Entity

Looks for encrypted or signed parts of the given C<Entity>, using all
L</EnabledOnIncoming> encryption protocols.  For each node in the MIME
hierarchy, L<RT::Crypt::Role/CheckIfProtected> for that L<MIME::Entity>
is called on each L</EnabledOnIncoming> protocol.  Any multipart nodes
not claimed by those protocols are recursed into.

Finally, L<RT::Crypt::Role/FindScatteredParts> is called on the top-most
entity for each L</EnabledOnIncoming> protocol.

Returns a list of hash references; each hash reference is guaranteed to
contain a C<Protocol> key describing the protocol of the found part, and
a C<Type> which is either C<encrypted> or C<signed>.  The remaining keys
are protocol-dependent; the hashref will be provided to
L</VerifyDecrypt>.

=cut

sub FindProtectedParts {
    my $self = shift;
    my %args = (
        Entity => undef,
        Skip => {},
        Scattered => 1,
        @_
    );

    my $entity = $args{'Entity'};
    return () if $args{'Skip'}{ $entity };

    $args{'TopEntity'} ||= $entity;

    my @protocols = $self->EnabledOnIncoming;

    foreach my $protocol ( @protocols ) {
        my $class = $self->LoadImplementation( $protocol );
        my %info = $class->CheckIfProtected(
            TopEntity => $args{'TopEntity'},
            Entity    => $entity,
        );
        next unless keys %info;

        $args{'Skip'}{ $entity } = 1;
        $info{'Protocol'} = $protocol;
        return \%info;
    }

    if ( $entity->effective_type =~ /^multipart\/(?:signed|encrypted)/ ) {
        # if no module claimed that it supports these types then
        # we don't dive in and check sub-parts
        $args{'Skip'}{ $entity } = 1;
        return ();
    }

    my @res;

    # not protected itself, look inside
    push @res, $self->FindProtectedParts(
        %args, Entity => $_, Scattered => 0,
    ) foreach grep !$args{'Skip'}{$_}, $entity->parts;

    if ( $args{'Scattered'} ) {
        my %parent;
        my $filter; $filter = sub {
            $parent{$_[0]} = $_[1];
            unless ( $_[0]->is_multipart ) {
                return () if $args{'Skip'}{$_[0]};
                return $_[0];
            }
            return map $filter->($_, $_[0]), grep !$args{'Skip'}{$_}, $_[0]->parts;
        };
        my @parts = $filter->($entity);
        return @res unless @parts;

        foreach my $protocol ( @protocols ) {
            my $class = $self->LoadImplementation( $protocol );
            my @list = $class->FindScatteredParts(
                Entity  => $args{'TopEntity'},
                Parts   => \@parts,
                Parents => \%parent,
                Skip    => $args{'Skip'}
            );
            next unless @list;

            $_->{'Protocol'} = $protocol foreach @list;
            push @res, @list;
            @parts = grep !$args{'Skip'}{$_}, @parts;
        }
    }

    return @res;
}

=head2 SignEncrypt Entity => ENTITY, [Sign => 1], [Encrypt => 1],
[Recipients => ARRAYREF], [Signer => NAME], [Protocol => NAME],
[Passphrase => VALUE]

Takes a L<MIME::Entity> object, and signs and/or encrypts it using the
given C<Protocol>.  If not set, C<Recipients> for encryption will be set
by examining the C<To>, C<Cc>, and C<Bcc> headers of the MIME entity.
If not set, C<Signer> defaults to the C<From> of the MIME entity.

C<Passphrase>, if not provided, will be retrieved using
L<RT::Crypt::Role/GetPassphrase>.

Returns a hash with at least the following keys:

=over

=item exit_code

True if there was an error encrypting or signing.

=item message

An un-localized error message desribing the problem.

=back

=cut

sub SignEncrypt {
    my $self = shift;
    my %args = (
        Sign => 1,
        Encrypt => 1,
        @_,
    );

    my $entity = $args{'Entity'};
    if ( $args{'Sign'} && !defined $args{'Signer'} ) {
        $args{'Signer'} =
            $self->UseKeyForSigning
            || do {
                my ($addr) = map {Email::Address->parse( Encode::decode( "UTF-8", $_ ) )}
                    $entity->head->get( 'From' );
                $addr ? $addr->address : undef
            };
    }
    if ( $args{'Encrypt'} && !$args{'Recipients'} ) {
        my %seen;
        $args{'Recipients'} = [
            grep $_ && !$seen{ $_ }++, map $_->address,
            map Email::Address->parse( Encode::decode("UTF-8", $_ ) ),
            map $entity->head->get( $_ ),
            qw(To Cc Bcc)
        ];
    }
    return $self->SimpleImplementationCall( %args );
}

=head2 SignEncryptContent Content => STRINGREF, [Sign => 1], [Encrypt => 1],
[Recipients => ARRAYREF], [Signer => NAME], [Protocol => NAME],
[Passphrase => VALUE]

Signs and/or encrypts a string, which is passed by reference.
C<Recipients> defaults to C</UseKeyForSigning>, and C<Recipients>
defaults to the global L<RT::Config/CorrespondAddress>.  All other
arguments and return values are identical to L</SignEncrypt>.

=cut

sub SignEncryptContent {
    my $self = shift;
    my %args = (@_);

    if ( $args{'Sign'} && !defined $args{'Signer'} ) {
        $args{'Signer'} = $self->UseKeyForSigning;
    }
    if ( $args{'Encrypt'} && !$args{'Recipients'} ) {
        $args{'Recipients'} = [ RT->Config->Get('CorrespondAddress') ];
    }

    return $self->SimpleImplementationCall( %args );
}

=head2 DrySign Signer => KEY

Signs a small message with the key, to make sure the key exists and we
have a useable passphrase. The Signer argument MUST be a key identifier
of the signer: either email address, key id or finger print.

Returns a true value if all went well.

=cut

sub DrySign {
    my $self = shift;

    my $mime = MIME::Entity->build(
        Type    => "text/plain",
        From    => 'nobody@localhost',
        To      => 'nobody@localhost',
        Subject => "dry sign",
        Data    => ['t'],
    );

    my %res = $self->SignEncrypt(
        @_,
        Sign    => 1,
        Encrypt => 0,
        Entity  => $mime,
    );

    return $res{exit_code} == 0;
}

=head2 VerifyDecrypt Entity => ENTITY [, Passphrase => undef ]

Locates all protected parts of the L<MIME::Entity> object C<ENTITY>, as
found by L</FindProtectedParts>, and calls
L<RT::Crypt::Role/VerifyDecrypt> from the appropriate L<RT::Crypt::Role>
class on each.

C<Passphrase>, if not provided, will be retrieved using
L<RT::Crypt::Role/GetPassphrase>.

Returns a list of the hash references returned from
L<RT::Crypt::Role/VerifyDecrypt>.

=cut

sub VerifyDecrypt {
    my $self = shift;
    my %args = (
        Entity    => undef,
        Recursive => 1,
        @_
    );

    my @res;

    my @protected = $self->FindProtectedParts( Entity => $args{'Entity'} );
    foreach my $protected ( @protected ) {
        my %res = $self->SimpleImplementationCall(
            %args, Protocol => $protected->{'Protocol'}, Info => $protected
        );

        # Let the header be modified so continuations are handled
        my $modify = $res{status_on}->head->modify;
        $res{status_on}->head->modify(1);
        $res{status_on}->head->add(
            "X-RT-" . $protected->{'Protocol'} . "-Status" => Encode::encode( "UTF-8", $res{'status'} )
        );
        $res{status_on}->head->modify($modify);

        push @res, \%res;
    }

    push @res, $self->VerifyDecrypt( %args )
        if $args{Recursive} and @res and not grep {$_->{'exit_code'}} @res;

    return @res;
}

=head2 DecryptContent Protocol => NAME, Content => STRINGREF, [Passphrase => undef]

Decrypts the content in the string reference in-place.  All other
arguments and return values are identical to L</VerifyDecrypt>.

=cut

sub DecryptContent {
    return shift->SimpleImplementationCall( @_ );
}

=head2 ParseStatus Protocol => NAME, Status => STRING

Takes a C<String> describing the status of verification/decryption,
usually as stored in a MIME header.  Parses it and returns array of hash
references, one for each operation.  Each hashref contains at least
three keys:

=over

=item Operation

The classification of the process whose status is being reported upon.
Valid values include C<Sign>, C<Encrypt>, C<Decrypt>, C<Verify>,
C<PassphraseCheck>, C<RecipientsCheck> and C<Data>.

=item Status

Whether the operation was successful; contains C<DONE> on success.
Other possible values include C<ERROR>, C<BAD>, or C<MISSING>.

=item Message

An un-localized user friendly message.

=back

=cut

sub ParseStatus {
    my $self = shift;
    my %args = (
        Protocol => undef,
        Status   => '',
        @_
    );
    return $self->LoadImplementation( $args{'Protocol'} )->ParseStatus( $args{'Status'} );
}

=head2 UseKeyForSigning [KEY]

Returns or sets the identifier of the key that should be used for
signing.  Returns the current value when called without arguments; sets
the new value when called with one argument and unsets if it's undef.

This cache is cleared at the end of every request.

=cut

sub UseKeyForSigning {
    my $self = shift;
    state $key;
    if ( @_ ) {
        $key = $_[0];
    }
    return $key;
}

=head2 UseKeyForEncryption [KEY [, VALUE]]

Gets or sets keys to use for encryption.  When passed no arguments,
clears the cache.  When passed just a key, returns the encryption key
previously stored for that key.  When passed two (or more) keys, stores
them associatively.

This cache is reset at the end of every request.

=cut

sub UseKeyForEncryption {
    my $self = shift;
    state %key;
    unless ( @_ ) {
        %key = ();
    } elsif ( @_ > 1 ) {
        %key = (%key, @_);
        $key{ lc($_) } = delete $key{ $_ } foreach grep lc ne $_, keys %key;
    } else {
        return $key{ $_[0] };
    }
    return ();
}

=head2 GetKeysForEncryption Recipient => EMAIL, Protocol => NAME

Returns the list of keys which are suitable for encrypting mail to the
given C<Recipient>.  Generally this is equivalent to L</GetKeysInfo>
with a C<Type> of <private>, but encryption protocols may further limit
which keys can be used for encryption, as opposed to signing.

=cut

sub CheckRecipients {
    my $self = shift;
    my @recipients = (@_);

    my ($status, @issues) = (1, ());

    my $trust = sub { 1 };
    if ( $self->UseForOutgoing eq 'SMIME' ) {
        $trust = sub { $_[0]->{'TrustLevel'} > 0 or RT->Config->Get('SMIME')->{AcceptUntrustedCAs} };
    } elsif ( $self->UseForOutgoing eq 'GnuPG' ) {
        $trust = sub { $_[0]->{'TrustLevel'} > 0 };
    }

    my %seen;
    foreach my $address ( grep !$seen{ lc $_ }++, map $_->address, @recipients ) {
        my %res = $self->GetKeysForEncryption( Recipient => $address );
        if ( $res{'info'} && @{ $res{'info'} } == 1 and $trust->($res{'info'}[0]) ) {
            # One key, which is trusted, or we can sign with an
            # untrusted key (aka SMIME with AcceptUntrustedCAs)
            next;
        }
        my $user = RT::User->new( RT->SystemUser );
        $user->LoadByEmail( $address );
        # it's possible that we have no User record with the email
        $user = undef unless $user->id;

        if ( my $fpr = RT::Crypt->UseKeyForEncryption( $address ) ) {
            if ( $res{'info'} && @{ $res{'info'} } ) {
                next if
                    grep lc $_->{'Fingerprint'} eq lc $fpr,
                    grep $trust->($_),
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

sub GetKeysForEncryption {
    my $self = shift;
    my %args = @_%2? (Recipient => @_) : (Protocol => undef, Recipient => undef, @_ );
    return $self->SimpleImplementationCall( %args );
}

=head2 GetKeysForSigning Signer => EMAIL, Protocol => NAME

Returns the list of keys which are suitable for signing mail from the
given C<Signer>.  Generally this is equivalent to L</GetKeysInfo>
with a C<Type> of <private>, but encryption protocols may further limit
which keys can be used for signing, as opposed to encryption.

=cut

sub GetKeysForSigning {
    my $self = shift;
    my %args = @_%2? (Signer => @_) : (Protocol => undef, Signer => undef, @_);
    return $self->SimpleImplementationCall( %args );
}

=head2 GetPublicKeyInfo Protocol => NAME, KEY => EMAIL

As per L</GetKeyInfo>, but the C<Type> is forced to C<public>.

=cut

sub GetPublicKeyInfo {
    return (shift)->GetKeyInfo( @_, Type => 'public' );
}

=head2 GetPrivateKeyInfo Protocol => NAME, KEY => EMAIL

As per L</GetKeyInfo>, but the C<Type> is forced to C<private>.

=cut

sub GetPrivateKeyInfo {
    return (shift)->GetKeyInfo( @_, Type => 'private' );
}

=head2 GetKeyInfo Protocol => NAME, Type => ('public'|'private'), KEY => EMAIL

As per L</GetKeysInfo>, but only the first matching key is returned in
the C<info> value of the result.

=cut

sub GetKeyInfo {
    my $self = shift;
    my %res = $self->GetKeysInfo( @_ );
    $res{'info'} = $res{'info'}->[0];
    return %res;
}

=head2 GetKeysInfo Protocol => NAME, Type => ('public'|'private'), Key => EMAIL

Looks up information about the public or private keys (as determined by
C<Type>) for the email address C<Key>.  As each protocol has its own key
store, C<Protocol> is also required.  If no C<Key> is provided and a
true value for C<Force> is given, returns all keys.

The return value is a hash containing C<exit_code> and C<message> in the
case of failure, or C<info>, which is an array reference of key
information.  Each key is represented as a hash reference; the keys are
protocol-dependent, but will at least contain:

=over

=item Protocol

The name of the protocol of this key

=item Created

An L<RT::Date> of the date the key was created; undef if unset.

=item Expire

An L<RT::Date> of the date the key expires; undef if the key does not expire.

=item Fingerprint

A fingerprint unique to this key

=item Formatted

A formatted string representation of the key

=item User

An array reference of associated user data, each of which is a hashref
containing at least a C<String> value, which is a C<< Alice Example
<alice@example.com> >> style email address.  Each may also contain
C<Created> and C<Expire> keys, which are L<RT::Date> objects.

=back

=cut

sub GetKeysInfo {
    my $self = shift;
    my %args = @_%2 ? (Key => @_) : ( Protocol => undef, Key => undef, @_ );
    return $self->SimpleImplementationCall( %args );
}

1;
