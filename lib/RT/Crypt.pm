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

package RT::Crypt;
use 5.010;

require RT::Crypt::GnuPG;

=head1 NAME

RT::Crypt - encrypt/decrypt and sign/verify subsystem for RT

=head1 DESCRIPTION

This module provides support for encryption and signing of outgoing
messages, as well as the decryption and verification of incoming email.

=head1 METHODS

=head2 Protocols

Returns the complete set of encryption protocols that RT implements; not
all may be supported by this installation.

=cut

our @PROTOCOLS = ('GnuPG');
our %PROTOCOLS = map { lc $_ => $_ } @PROTOCOLS;

sub Protocols {
    return @PROTOCOLS;
}

=head2 EnabledOnIncoming

Returns the list of encryption protocols that should be used for
decryption and verification of incoming email.  This list is irrelevant
unless L<RT::Interface::Email::Auth::Crypt> is enabled in
L<RT_Config/@MailPlugins>.

=cut

sub EnabledOnIncoming {
    return 'GnuPG';
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

    if (eval "require $class; 1") {
        return $cache{ $class } = $class;
    } else {
        RT->Logger->warn( "Could not load $class: $@" );
        return $cache{ $class } = undef;
    }
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

    my @protocols = $self->EnabledOnIncoming;

    foreach my $protocol ( @protocols ) {
        my $class = $self->LoadImplementation( $protocol );
        my %info = $class->CheckIfProtected( Entity => $entity );
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
            my @list = $class->FindScatteredParts( Parts => \@parts, Parents => \%parent, Skip => $args{'Skip'} );
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
    my %args = (@_);

    my $entity = $args{'Entity'};
    if ( $args{'Sign'} && !defined $args{'Signer'} ) {
        $args{'Signer'} =
            $self->UseKeyForSigning
            || do {
                my $addr = (Email::Address->parse( $entity->head->get( 'From' ) ))[0];
                $addr? $addr->address : undef
            };
    }
    if ( $args{'Encrypt'} && !$args{'Recipients'} ) {
        my %seen;
        $args{'Recipients'} = [
            grep $_ && !$seen{ $_ }++, map $_->address,
            map Email::Address->parse( $entity->head->get( $_ ) ),
            qw(To Cc Bcc)
        ];
    }

    my $protocol = delete $args{'Protocol'} || 'GnuPG';
    my $class = $self->LoadImplementation( $protocol );

    my %res = $class->SignEncrypt( %args );
    $res{'Protocol'} = $protocol;
    return %res;
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
        SetStatus => 1,
        AddStatus => 0,
        @_
    );

    my @res;

    my @protected = $self->FindProtectedParts( Entity => $args{'Entity'} );
    foreach my $protected ( @protected ) {
        my $protocol = $protected->{'Protocol'};
        my $class = $self->LoadImplementation( $protocol );
        my %res = $class->VerifyDecrypt( %args, Info => $protected );
        $res{'Protocol'} = $protocol;
        push @res, \%res;
    }
    return @res;
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

1;
