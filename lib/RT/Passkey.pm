# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2025 Best Practical Solutions, LLC
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

package RT::Passkey;

use strict;
use warnings;

use base 'RT::Record';

sub Table {'Passkeys'}

use RT::User;
use RT::Passkeys;

=head1 NAME

RT::Passkey - one stored WebAuthn credential

=head1 DESCRIPTION

A single passkey registered to a user. Multiple credentials per user are
allowed up to C<$PasskeyMaxCredentials>.

=head1 METHODS

=head2 Create

Takes a paramhash with C<UserId>, C<CredentialId>, C<PublicKey>,
C<SignCount>, C<Name>, and C<RecordTransaction>. Inserts a new
credential row. Returns C<($id, $msg)>.

When C<RecordTransaction> is true (the default), records a
C<CreatePasskey> transaction on the owning user. Bulk callers that
manage the audit trail themselves can opt out by passing
C<RecordTransaction =E<gt> 0>.

=cut

sub Create {
    my $self = shift;
    my %args = (
        UserId            => 0,
        CredentialId      => '',
        PublicKey         => '',
        SignCount         => 0,
        Name              => '',
        RecordTransaction => 1,
        @_,
    );

    my $record_tx = delete $args{RecordTransaction};

    return ( 0, $self->loc('UserId is required') )       unless $args{UserId};
    return ( 0, $self->loc('CredentialId is required') ) unless length $args{CredentialId};
    return ( 0, $self->loc('PublicKey is required') )    unless length $args{PublicKey};

    $args{Name} = $self->CanonicalizeName( $args{Name} );
    return ( 0, $self->loc('Name is required') ) unless defined $args{Name} && length $args{Name};
    return ( 0, $self->loc('Name too long') ) if length $args{Name} > 255;

    my $cu = $self->CurrentUser;
    return ( 0, $self->loc('Permission Denied') ) unless $cu && $cu->Id;

    # Gate enrollment on the owner's Password-modify right: passkeys are
    # an authentication credential, so the same self-service gate that
    # governs SetPassword should govern adding a passkey. CurrentUserCanModify
    # short-circuits to true for AdminUsers and otherwise requires ModifySelf
    # when the current user is editing themselves -- matching how
    # CurrentUserCanModify/Delete below evaluate the existing record.
    my $owner = RT::User->new($cu);
    $owner->Load( $args{UserId} );
    unless ( $owner->id && $owner->CurrentUserCanModify('Password') ) {
        return ( 0, $self->loc('Permission Denied') );
    }

    my $existing = RT::Passkey->new( RT->SystemUser );
    $existing->LoadByCredentialId( $args{CredentialId} );
    return ( 0, $self->loc('Credential already registered') ) if $existing->id;

    # Per-user name uniqueness -- ValidateName can't see UserId during the
    # framework auto-validate loop in SUPER::Create because $self isn't
    # loaded yet, so the check lives here against the explicit args.
    my $name_lc  = lc $args{Name};
    my $siblings = RT::Passkeys->new( RT->SystemUser );
    $siblings->LimitToUser( $args{UserId} );
    while ( my $p = $siblings->Next ) {
        return ( 0, $self->loc('You already have a passkey with this name') )
            if lc( $p->__Value('Name') // '' ) eq $name_lc;
    }

    my ( $id, $msg ) = $self->SUPER::Create(%args);
    return ( $id, $msg ) unless $id;

    if ($record_tx) {
        my ( $tx_ret, $tx_msg ) = $owner->_NewTransaction(
            Type     => 'CreatePasskey',
            NewValue => $args{Name},
        );
        RT->Logger->error("Could not record CreatePasskey transaction: $tx_msg") unless $tx_ret;
    }

    return ( $id, $msg );
}

=head2 LoadByCredentialId CREDENTIAL_ID

Loads this record by its base64url credential ID. Returns C<($id, $msg)>
from L<DBIx::SearchBuilder::Record/LoadByCols>; check C<< $self->id >> for
success.

=cut

sub LoadByCredentialId {
    my ( $self, $b64 ) = @_;
    return $self->LoadByCols( CredentialId => $b64 );
}

=head2 CurrentUserCanSee

True if the current user owns this passkey or has the C<AdminUsers> right.

=cut

sub CurrentUserCanSee {
    my $self = shift;
    return 0 unless $self->id;
    return 1 if $self->__Value('UserId') == $self->CurrentUser->Id;
    return 1 if $self->CurrentUser->HasRight( Right => 'AdminUsers', Object => RT->System );
    return 0;
}

=head2 CurrentUserCanModify

True when the current user can rename this passkey. Gated on the owning
user's C<Password>-modify right (i.e. C<AdminUsers> or, for the owner
themselves, C<ModifySelf>) because passkeys are credentials and should
follow the same self-service rules as passwords.

=cut

sub CurrentUserCanModify {
    my $self = shift;
    return 0 unless $self->id;
    # Resolve the owning user and ask whether their Password is modifiable
    # by the current user. We check 'Password' rather than inventing a
    # new field so passkey and password self-service stay locked together:
    # one ModifySelf revocation freezes both.
    my $owner = RT::User->new( $self->CurrentUser );
    $owner->Load( $self->__Value('UserId') );
    return 0 unless $owner->id;
    return $owner->CurrentUserCanModify('Password') ? 1 : 0;
}

=head2 CurrentUserCanDelete

True when the current user can revoke this passkey. Aliased to
L</CurrentUserCanModify> -- revoking a credential is a modification of
the user's authentication state and uses the same gate.

=cut

sub CurrentUserCanDelete { $_[0]->CurrentUserCanModify }

=head2 Delete { RecordTransaction => 1|0 }

Checks L</CurrentUserCanDelete>. When C<RecordTransaction> is true
(the default), records a C<DeletePasskey> transaction on the owning
user. Bulk callers wiping a user record (e.g. L<RT::User/AnonymizeUser>)
can opt out by passing C<RecordTransaction =E<gt> 0>.

=cut

sub Delete {
    my $self = shift;
    my %args = ( RecordTransaction => 1, @_ );
    return ( 0, $self->loc('Permission Denied') ) unless $self->CurrentUserCanDelete;

    # Snapshot the audit-relevant fields before the row goes away.
    my $name    = $self->__Value('Name') // '';
    my $user_id = $self->__Value('UserId');

    my ( $ret, $msg ) = $self->SUPER::Delete;
    return ( $ret, $msg ) unless $ret;

    if ( $args{RecordTransaction} && $user_id ) {
        my $user = RT::User->new( $self->CurrentUser );
        $user->Load($user_id);
        if ( $user->id ) {
            my ( $tx_ret, $tx_msg ) = $user->_NewTransaction(
                Type     => 'DeletePasskey',
                OldValue => $name,
            );
            RT->Logger->error("Could not record DeletePasskey transaction: $tx_msg") unless $tx_ret;
        }
    }

    return ( $ret, $msg );
}

=head2 SetLastUsedToNow

Updates LastUsed to the current time. Returns C<($ret, $msg)>.

=cut

sub SetLastUsedToNow {
    my $self = shift;
    my $now  = RT::Date->new( $self->CurrentUser );
    $now->SetToNow;
    return $self->_Set( Field => 'LastUsed', Value => $now->ISO );
}

=head2 SetName NAME

Renames this passkey, stripping leading and trailing whitespace from
NAME via L</CanonicalizeName>. Validation (empty, length, uniqueness)
is performed by the framework's auto-call to L</ValidateName>. Records
a C<RenamePasskey> transaction on the owning user on success.

=cut

sub SetName {
    my ( $self, $value ) = @_;
    my $new = $self->CanonicalizeName($value);
    my $old = $self->__Value('Name') // '';
    my ( $ret, $msg ) = $self->_Set( Field => 'Name', Value => $new );
    return ( $ret, $msg ) unless $ret;

    if ( ( $old // '' ) ne ( $new // '' ) ) {
        my $user = RT::User->new( $self->CurrentUser );
        $user->Load( $self->__Value('UserId') );
        if ( $user->id ) {
            my ( $tx_ret, $tx_msg ) = $user->_NewTransaction(
                Type     => 'RenamePasskey',
                OldValue => $old,
                NewValue => $new,
            );
            RT->Logger->error("Could not record RenamePasskey transaction: $tx_msg") unless $tx_ret;
        }
    }
    return ( $ret, $msg );
}

=head2 CanonicalizeName NAME

Returns NAME with leading and trailing whitespace stripped. C<undef>
in, C<undef> out.

=cut

sub CanonicalizeName {
    my ( $self, $value ) = @_;
    return $value unless defined $value;
    $value =~ s/\A\s+//;
    $value =~ s/\s+\z//;
    return $value;
}

=head2 ValidateName NAME

Returns true if NAME is acceptable as this passkey's name, false
otherwise. Auto-called by L<RT::Record/Create> and
L<DBIx::SearchBuilder::Record/_Set>; the boolean shape matches the RT
convention.

For uniqueness, this consults C<< $self->__Value('UserId') >>. The
framework's auto-call during C<Create> runs before C<$self> is loaded,
so the per-user duplicate check is skipped on that path; L</Create>
performs the equivalent check explicitly against its arguments. On a
loaded record (e.g. rename via C<_Set>), C<< $self->id >> is excluded
from the duplicate check so a row never collides with itself.

=cut

sub ValidateName {
    my ( $self, $value ) = @_;
    return 0 unless defined $value && length $value;
    return 0 if length $value > 255;

    my $user_id = $self->__Value('UserId');
    return 1 unless $user_id;

    my $lc       = lc $value;
    my $passkeys = RT::Passkeys->new( RT->SystemUser );
    $passkeys->LimitToUser($user_id);
    while ( my $p = $passkeys->Next ) {
        next     if $self->id && $p->id == $self->id;
        return 0 if lc( $p->__Value('Name') // '' ) eq $lc;
    }
    return 1;
}

=head1 PRIVATE METHODS

=head2 _Set

Checks L</CurrentUserCanModify> before calling C<SUPER::_Set>.

=cut

sub _Set {
    my $self = shift;
    return ( 0, $self->loc('Permission Denied') ) unless $self->CurrentUserCanModify;
    return $self->SUPER::_Set(@_);
}

=head2 _Value

Checks L</CurrentUserCanSee> before calling C<SUPER::_Value>.

=cut

sub _Value {
    my $self = shift;
    return unless $self->CurrentUserCanSee;
    return $self->SUPER::_Value(@_);
}

=head2 _CoreAccessible

Standard SearchBuilder accessor manifest.

=cut

sub _CoreAccessible {
    {   id            => { read => 1, type  => 'int(11)',       default => '' },
        UserId        => { read => 1, type  => 'int(11)',       default => 0 },
        CredentialId  => { read => 1, type  => 'varchar(2048)', default => '' },
        PublicKey     => { read => 1, type  => 'varchar(2048)', default => '' },
        SignCount     => { read => 1, write => 1,               type    => 'int(11)',      default => 0 },
        Name          => { read => 1, write => 1,               type    => 'varchar(255)', default => '' },
        Created       => { read => 1, auto  => 1,               type    => 'datetime',     default => '' },
        LastUsed      => { read => 1, write => 1,               type    => 'datetime',     default => '' },
        Creator       => { read => 1, auto  => 1,               type    => 'int(11)',      default => 0 },
        LastUpdated   => { read => 1, auto  => 1,               type    => 'datetime',     default => '' },
        LastUpdatedBy => { read => 1, auto  => 1,               type    => 'int(11)',      default => 0 },
    };
}

RT::Base->_ImportOverlays();

1;
