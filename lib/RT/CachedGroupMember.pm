# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2012 Best Practical Solutions, LLC
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

package RT::CachedGroupMember;

use strict;
use warnings;


use base 'RT::Record';

sub Table {'CachedGroupMembers'}

=head1 NAME

  RT::CachedGroupMember

=head1 SYNOPSIS

  use RT::CachedGroupMember;

=head1 DESCRIPTION

=head1 METHODS

=cut

# {{ Create

=head2 Create PARAMHASH

Create takes a hash of values and creates a row in the database:

  'Group' is the "top level" group we're building the cache for. This 
  is an RT::Principal object

  'Member' is the RT::Principal  of the user or group we're adding to 
  the cache.

  'ImmediateParent' is the RT::Principal of the group that this 
  principal belongs to to get here

  int(11) 'Via' is an internal reference to CachedGroupMembers->Id of
  the "parent" record of this cached group member. It should be empty if 
  this member is a "direct" member of this group. (In that case, it will 
  be set to this cached group member's id after creation)

  This routine should _only_ be called by GroupMember->Create

=cut

sub Create {
    my $self = shift;
    my %args = (
        Group           => undef,
        Member          => undef,
        @_
    );

    unless (    $args{'Member'}
             && UNIVERSAL::isa( $args{'Member'}, 'RT::Principal' )
             && $args{'Member'}->Id ) {
        $RT::Logger->debug("$self->Create: bogus Member argument");
    }

    unless (    $args{'Group'}
             && UNIVERSAL::isa( $args{'Group'}, 'RT::Principal' )
             && $args{'Group'}->Id ) {
        $RT::Logger->debug("$self->Create: bogus Group argument");
    }

    $args{'Disabled'} = $args{'Group'}->Disabled? 1 : 0;

    $self->LoadByCols(
        GroupId           => $args{'Group'}->Id,
        MemberId          => $args{'Member'}->Id,
    );

    my $id;
    if ( $id = $self->id ) {
        if ( $self->Disabled != $args{'Disabled'} && $args{'Disabled'} == 0 ) {
            my ($status) = $self->SetDisabled( 0 );
            return undef unless $status;
        }
        return $id;
    }

    ($id) = $self->SUPER::Create(
        GroupId           => $args{'Group'}->Id,
        MemberId          => $args{'Member'}->Id,
        Disabled          => $args{'Disabled'},
    );
    unless ($id) {
        $RT::Logger->warning(
            "Couldn't create ". $args{'Member'} ." as a cached member of "
            . $args{'Group'} ." via ". $args{'Via'}
        );
        return (undef);
    }
    return $id if $args{'Member'}->id == $args{'Group'}->id;

    my $table = $self->Table;
    if ( !$args{'Disabled'} && $args{'Member'}->IsGroup ) {
        # update existing records, in case we activated some paths
        my $query = "
            SELECT CGM3.id FROM
                $table CGM1 CROSS JOIN $table CGM2
                JOIN $table CGM3
                    ON CGM3.GroupId = CGM1.GroupId AND CGM3.MemberId = CGM2.MemberId
            WHERE
                CGM1.MemberId = ? AND (CGM1.GroupId != CGM1.MemberId OR CGM1.MemberId = ?)
                AND CGM2.GroupId = ? AND (CGM2.GroupId != CGM2.MemberId OR CGM2.GroupId = ?)
                AND CGM1.Disabled = 0 AND CGM2.Disabled = 0 AND CGM3.Disabled > 0
        ";
        $RT::Handle->SimpleUpdateFromSelect(
            $table, { Disabled => 0 }, $query,
            $args{'Group'}->id, $args{'Group'}->id,
            $args{'Member'}->id, $args{'Member'}->id
        ) or return undef;
    }

    my @binds;

    my $disabled_clause;
    if ( $args{'Disabled'} ) {
        $disabled_clause = '?';
        push @binds, $args{'Disabled'};
    } else {
        $disabled_clause = 'CASE WHEN CGM1.Disabled + CGM2.Disabled > 0 THEN 1 ELSE 0 END';
    }

    my $query = "SELECT CGM1.GroupId, CGM2.MemberId, $disabled_clause FROM
        $table CGM1 CROSS JOIN $table CGM2
        LEFT JOIN $table CGM3
            ON CGM3.GroupId = CGM1.GroupId AND CGM3.MemberId = CGM2.MemberId
        WHERE
            CGM1.MemberId = ? AND (CGM1.GroupId != CGM1.MemberId OR CGM1.MemberId = ?)
            AND CGM3.id IS NULL
    ";
    push @binds, $args{'Group'}->id, $args{'Group'}->id;

    if ( $args{'Member'}->IsGroup ) {
        $query .= "
            AND CGM2.GroupId = ?
            AND (CGM2.GroupId != CGM2.MemberId OR CGM2.GroupId = ?)
        ";
        push @binds, $args{'Member'}->id, $args{'Member'}->id;
    }
    else {
        $query .= " AND CGM2.id = ?";
        push @binds, $id;
    }
    $RT::Handle->InsertFromSelect(
        $table, ['GroupId', 'MemberId', 'Disabled'], $query, @binds,
    );

    return $id;
}

=head2 Delete

Deletes the current CachedGroupMember from the group it's in and cascades 
the delete to all submembers. This routine could be completely excised if
mysql supported foreign keys with cascading deletes.

=cut 

sub Delete {
    my $self = shift;

    
    my $member = $self->MemberObj();
    if ( $member->IsGroup ) {
        my $deletable = RT::CachedGroupMembers->new( $self->CurrentUser );

        $deletable->Limit( FIELD    => 'id',
                           OPERATOR => '!=',
                           VALUE    => $self->id );
        $deletable->Limit( FIELD    => 'Via',
                           OPERATOR => '=',
                           VALUE    => $self->id );

        while ( my $kid = $deletable->Next ) {
            my $kid_err = $kid->Delete();
            unless ($kid_err) {
                $RT::Logger->error(
                              "Couldn't delete CachedGroupMember " . $kid->Id );
                return (undef);
            }
        }
    }
    my $ret = $self->SUPER::Delete();
    unless ($ret) {
        $RT::Logger->error( "Couldn't delete CachedGroupMember " . $self->Id );
        return (undef);
    }
    return $ret;
}



=head2 SetDisabled

SetDisableds the current CachedGroupMember from the group it's in and cascades 
the SetDisabled to all submembers. This routine could be completely excised if
mysql supported foreign keys with cascading SetDisableds.

=cut 

sub SetDisabled {
    my $self = shift;
    my $val = shift;
 
    # if it's already disabled, we're good.
    return (1) if ( $self->__Value('Disabled') == $val);
    my $err = $self->_Set(Field => 'Disabled', Value => $val);
    my ($retval, $msg) = $err->as_array();
    unless ($retval) {
        $RT::Logger->error( "Couldn't SetDisabled CachedGroupMember " . $self->Id .": $msg");
        return ($err);
    }
    
    my $member = $self->MemberObj();
    if ( $member->IsGroup ) {
        my $deletable = RT::CachedGroupMembers->new( $self->CurrentUser );

        $deletable->Limit( FIELD    => 'Via', OPERATOR => '=', VALUE    => $self->id );
        $deletable->Limit( FIELD    => 'id', OPERATOR => '!=', VALUE    => $self->id );

        while ( my $kid = $deletable->Next ) {
            my $kid_err = $kid->SetDisabled($val );
            unless ($kid_err) {
                $RT::Logger->error( "Couldn't SetDisabled CachedGroupMember " . $kid->Id );
                return ($kid_err);
            }
        }
    }
    return ($err);
}



=head2 GroupObj  

Returns the RT::Principal object for this group Group

=cut

sub GroupObj {
    my $self      = shift;
    my $principal = RT::Principal->new( $self->CurrentUser );
    $principal->Load( $self->GroupId );
    return ($principal);
}



=head2 ImmediateParentObj  

Returns the RT::Principal object for this group ImmediateParent

=cut

sub ImmediateParentObj {
    my $self      = shift;
    my $principal = RT::Principal->new( $self->CurrentUser );
    $principal->Load( $self->ImmediateParentId );
    return ($principal);
}



=head2 MemberObj  

Returns the RT::Principal object for this group member

=cut

sub MemberObj {
    my $self      = shift;
    my $principal = RT::Principal->new( $self->CurrentUser );
    $principal->Load( $self->MemberId );
    return ($principal);
}

# }}}






=head2 id

Returns the current value of id.
(In the database, id is stored as int(11).)


=cut


=head2 GroupId

Returns the current value of GroupId.
(In the database, GroupId is stored as int(11).)



=head2 SetGroupId VALUE


Set GroupId to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, GroupId will be stored as a int(11).)


=cut


=head2 MemberId

Returns the current value of MemberId.
(In the database, MemberId is stored as int(11).)



=head2 SetMemberId VALUE


Set MemberId to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, MemberId will be stored as a int(11).)


=cut


=head2 Via

Returns the current value of Via.
(In the database, Via is stored as int(11).)



=head2 SetVia VALUE


Set Via to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Via will be stored as a int(11).)


=cut


=head2 ImmediateParentId

Returns the current value of ImmediateParentId.
(In the database, ImmediateParentId is stored as int(11).)



=head2 SetImmediateParentId VALUE


Set ImmediateParentId to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, ImmediateParentId will be stored as a int(11).)


=cut


=head2 Disabled

Returns the current value of Disabled.
(In the database, Disabled is stored as smallint(6).)



=head2 SetDisabled VALUE


Set Disabled to VALUE.
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Disabled will be stored as a smallint(6).)


=cut



sub _CoreAccessible {
    {

        id =>
		{read => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        GroupId =>
		{read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        MemberId =>
		{read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        Via =>
		{read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        ImmediateParentId =>
		{read => 1, write => 1, sql_type => 4, length => 11,  is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => ''},
        Disabled =>
		{read => 1, write => 1, sql_type => 5, length => 6,  is_blob => 0,  is_numeric => 1,  type => 'smallint(6)', default => '0'},

 }
};

RT::Base->_ImportOverlays();

1;
