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

=head1 NAME

  RT::ACL - collection of RT ACE objects

=head1 SYNOPSIS

  use RT::ACL;
my $ACL = RT::ACL->new($CurrentUser);

=head1 DESCRIPTION


=head1 METHODS


=cut


package RT::ACL;
use RT::ACE;

use base 'RT::SearchBuilder';

sub Table { 'ACL'}

use strict;
use warnings;



=head2 Next

Hand out the next ACE that was found

=cut



=head2 LimitToObject $object

Limit the ACL to rights for the object $object. It needs to be an RT::Record class.

=cut

sub LimitToObject {
    my $self = shift;
    my $obj  = shift;

    my $obj_type = ref($obj)||$obj;
    my $obj_id = eval { $obj->id};

    my $object_clause = 'possible_objects';
    $self->_OpenParen($object_clause);
    $self->Limit(
        SUBCLAUSE       => $object_clause,
        FIELD           => 'ObjectType',
        OPERATOR        => '=',
        VALUE           => (ref($obj)||$obj),
        ENTRYAGGREGATOR => 'OR' # That "OR" applies to the separate objects we're searching on, not "Type Or ID"
    );
    if ($obj_id) {
    $self->Limit(
        SUBCLAUSE       => $object_clause,
        FIELD           => 'ObjectId',
        OPERATOR        => '=',
        VALUE           => $obj_id,
        ENTRYAGGREGATOR => 'AND',
        QUOTEVALUE      => 0
    );
    }
    $self->_CloseParen($object_clause);

}



=head2 LimitNotObject $object

Limit the ACL to rights NOT on the object $object.  $object needs to be
an RT::Record class.

=cut

sub LimitNotObject {
    my $self = shift;
    my $obj  = shift;
    unless ( defined($obj)
        && ref($obj)
        && UNIVERSAL::can( $obj, 'id' )
        && $obj->id )
    {
        return undef;
    }
    $self->Limit( FIELD => 'ObjectType',
		  OPERATOR => '!=',
		  VALUE => ref($obj),
		  ENTRYAGGREGATOR => 'OR',
		  SUBCLAUSE => $obj->id
		);
    $self->Limit( FIELD => 'ObjectId',
		  OPERATOR => '!=',
		  VALUE => $obj->id,
		  ENTRYAGGREGATOR => 'OR',
		  QUOTEVALUE => 0,
		  SUBCLAUSE => $obj->id
		);
}



=head2 LimitToPrincipal { Type => undef, Id => undef, IncludeGroupMembership => undef }

Limit the ACL to the principal with PrincipalId Id and PrincipalType Type

Id is not optional.
Type is.

if IncludeGroupMembership => 1 is specified, ACEs which apply to the principal due to group membership will be included in the resultset.


=cut

sub LimitToPrincipal {
    my $self = shift;
    my %args = ( Type                   => undef,
                 Id                     => undef,
                 IncludeGroupMembership => undef,
                 @_
               );
    if ( $args{'IncludeGroupMembership'} ) {
        my $cgm = $self->NewAlias('CachedGroupMembers');
        $self->Join( ALIAS1 => 'main',
                     FIELD1 => 'PrincipalId',
                     ALIAS2 => $cgm,
                     FIELD2 => 'GroupId'
                   );
        $self->Limit( ALIAS => $cgm,
                      FIELD => 'Disabled',
                      VALUE => 0 );
        $self->Limit( ALIAS           => $cgm,
                      FIELD           => 'MemberId',
                      OPERATOR        => '=',
                      VALUE           => $args{'Id'},
                      ENTRYAGGREGATOR => 'OR'
                    );
    } else {
        if ( defined $args{'Type'} ) {
            $self->Limit( FIELD           => 'PrincipalType',
                          OPERATOR        => '=',
                          VALUE           => $args{'Type'},
                          ENTRYAGGREGATOR => 'OR'
                        );
        }

        # if the principal id points to a user, we really want to point
        # to their ACL equivalence group. The machinations we're going through
        # lead me to start to suspect that we really want users and groups
        # to just be the same table. or _maybe_ that we want an object db.
        my $princ = RT::Principal->new( RT->SystemUser );
        $princ->Load( $args{'Id'} );
        if ( $princ->PrincipalType eq 'User' ) {
            my $group = RT::Group->new( RT->SystemUser );
            $group->LoadACLEquivalenceGroup($princ);
            $args{'Id'} = $group->PrincipalId;
        }
        $self->Limit( FIELD           => 'PrincipalId',
                      OPERATOR        => '=',
                      VALUE           => $args{'Id'},
                      ENTRYAGGREGATOR => 'OR'
                    );
    }
}




sub AddRecord {
    my $self = shift;
    my ($record) = @_;

    # Short-circuit having to load up the ->Object
    return $self->SUPER::AddRecord( $record )
        if $record->CurrentUser->PrincipalObj->Id == RT->SystemUser->Id;

    my $obj = $record->Object;
    return unless $self->CurrentUser->HasRight( Right  => 'ShowACL',
                                                Object => $obj )
               or $self->CurrentUser->HasRight( Right  => 'ModifyACL',
                                                Object => $obj );

    return $self->SUPER::AddRecord( $record );
}




#wrap around _DoSearch  so that we can build the hash of returned
#values 
sub _DoSearch {
    my $self = shift;
   # $RT::Logger->debug("Now in ".$self."->_DoSearch");
    my $return = $self->SUPER::_DoSearch(@_);
  #  $RT::Logger->debug("In $self ->_DoSearch. return from SUPER::_DoSearch was $return");
    if ( $self->{'must_redo_search'} ) {
        $RT::Logger->crit(
"_DoSearch is not so successful as it still needs redo search, won't call _BuildHash"
        );
    }
    else {
        $self->_BuildHash();
    }
    return ($return);
}


#Build a hash of this ACL's entries.
sub _BuildHash {
    my $self = shift;

    while (my $entry = $self->Next) {
        my $hashkey = join '-', map $entry->__Value( $_ ),
            qw(ObjectType ObjectId RightName PrincipalId PrincipalType);

        $self->{'as_hash'}->{"$hashkey"} =1;

    }
}



=head2 HasEntry

=cut

sub HasEntry {

    my $self = shift;
    my %args = ( RightScope => undef,
                 RightAppliesTo => undef,
                 RightName => undef,
                 PrincipalId => undef,
                 PrincipalType => undef,
                 @_ );

    #if we haven't done the search yet, do it now.
    $self->_DoSearch();

    if ($self->{'as_hash'}->{ $args{'RightScope'} . "-" .
			      $args{'RightAppliesTo'} . "-" . 
			      $args{'RightName'} . "-" .
			      $args{'PrincipalId'} . "-" .
			      $args{'PrincipalType'}
                            } == 1) {
	return(1);
    }
    else {
	return(undef);
    }
}

# }}}


=head2 NewItem

Returns an empty new RT::ACE item

=cut

sub NewItem {
    my $self = shift;
    return(RT::ACE->new($self->CurrentUser));
}
RT::Base->_ImportOverlays();

1;
