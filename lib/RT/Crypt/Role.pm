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

package RT::Crypt::Role;
use Role::Basic;

=head1 NAME

RT::Crypt::Role - Common requirements for encryption implementations

=head1 METHODS

=head2 Probe

This routine is called only if the protocol is enabled, and should
return true if all binaries required by the protocol are installed.  It
should produce any warnings necessary to describe any issues it
encounters.

=cut

requires 'Probe';

=head2 GetPassphrase Address => ADDRESS

Returns the passphrase for the given address.  It looks at the relevant
configuration option for the encryption protocol
(e.g. L<RT_Config/GnuPG> for GnuPG), and examines the Passphrase key.
It it does not exist, returns the empty string.  If it is a scalar, it
returns that value.  If it is an anonymous subroutine, it calls it.  If
it is a hash, it looks up the address (using '' as a fallback key).

=cut

sub GetPassphrase {
    my $self = shift;
    my %args = ( Address => undef, @_ );

    my $class = ref($self) || $self;
    $class =~ s/^RT::Crypt:://;

    my $config = RT->Config->Get($class)->{Passphrase};

    return '' unless defined $config;

    if (not ref $config) {
        return $config;
    } elsif (ref $config eq "HASH") {
        return $config->{$args{Address}}
            || $config->{''};
    } elsif (ref $config eq "CODE") {
        return $config->( @_ );
    } else {
        warn "Unknown Passphrase type for $class: ".ref($config);
    }
}

=head2 SignEncrypt Entity => MIME::Entity, [ Encrypt => 1, Sign => 1, ... ]

Signs and/or encrypts a MIME entity.  All arguments and return values
are identical to L<RT::Crypt/SignEncrypt>, with the omission of
C<Protocol>.

=cut

requires 'SignEncrypt';

=head2 SignEncryptContent Content => STRINGREF, [ Encrypt => 1, Sign => 1, ... ]

Signs and/or encrypts a string, which is passed by reference.  All
arguments and return values are identical to
L<RT::Crypt/SignEncryptContent>, with the omission of C<Protocol>.

=cut

requires 'SignEncryptContent';

=head2 VerifyDecrypt Info => HASHREF, [ Passphrase => undef ]

The C<Info> key is a hashref as returned from L</FindScatteredParts> or
L</CheckIfProtected>.  This method should alter the mime objects
in-place as necessary during signing and decryption.

Returns a hash with at least the following keys:

=over

=item exit_code

True if there was an error encrypting or signing.

=item message

An un-localized error message desribing the problem.

=back

=cut

requires 'VerifyDecrypt';

=head2 DecryptContent Content => STRINGREF, [ Passphrase => undef ]

Decrypts the content in the string reference in-place.  All arguments
and return values are identical to L<RT::Crypt/DecryptContent>, with the
omission of C<Protocol>.

=cut

requires 'DecryptContent';

=head2 ParseStatus STRING

Takes a string describing the status of verification/decryption, usually
as stored in a MIME header.  Parses and returns it as described in
L<RT::Crypt/ParseStatus>.

=cut

requires 'ParseStatus';

=head2 FindScatteredParts Parts => ARRAYREF, Parents => HASHREF, Skip => HASHREF

Passed the list of unclaimed L<MIME::Entity> objects in C<Parts>, this
method should examine them as a whole to determine if there are any that
could not be claimed by the single-entity-at-a-time L</CheckIfProtected>
method.  This is generally only necessary in the case of signatures
manually attached in parallel, and the like.

If found, the relevant entities should be inserted into C<Skip> with a
true value, to signify to other encryption protols that they have been
claimed.  The method should return a list of hash references, each
containing a C<Type> key which is either C<signed> or C<encrypted>.  The
remaining keys are protocol-dependent; the hashref will be provided to
L</VerifyDecrypt>.

=cut

requires 'FindScatteredParts';

=head2 CheckIfProtected Entity => MIME::Entity

Examines the provided L<MIME::Entity>, and returns an empty list if it
is not signed or encrypted using the protocol.  If it is, returns a hash
reference containing a C<Type> which is either C<encrypted> or
C<signed>.  The remaining keys are protocol-dependent; the hashref will
be provided to L</VerifyDecrypt>.

=cut

requires 'CheckIfProtected';

=head2 GetKeysInfo Type => ('public'|'private'), Key => EMAIL

Returns a list of keys matching the email C<Key>, as described in
L<RT::Crypt/GetKeysInfo>.

=cut

requires 'GetKeysInfo';

=head2 GetKeysForEncryption Recipient => EMAIL

Returns a list of keys suitable for encryption, as described in
L<RT::Crypt/GetKeysForEncryption>.

=cut

requires 'GetKeysForEncryption';

=head2 GetKeysForSigning Signer => EMAIL

Returns a list of keys suitable for encryption, as described in
L<RT::Crypt/GetKeysForSigning>.

=cut

requires 'GetKeysForSigning';

=head2 ParseDate STRING

Takes a string, and parses and returns a L<RT::Date>; if the string is
purely numeric, assumes is a epoch timestamp.

=cut

sub ParseDate {
    my $self = shift;
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


1;
