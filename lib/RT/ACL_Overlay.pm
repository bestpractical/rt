# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2011 Best Practical Solutions, LLC
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
my $ACL = new RT::ACL($CurrentUser);

=head1 DESCRIPTION


=head1 METHODS


=cut


package RT::ACL;

use strict;
no warnings qw(redefine);


=head2 Next

Hand out the next ACE that was found

=cut


# {{{ LimitToObject 

=head2 LimitToObject $object

Limit the ACL to rights for the object $object. It needs to be an RT::Record class.

=cut

sub LimitToObject {
    my $self = shift;
    my $obj  = shift;
    unless ( defined($obj)
        && ref($obj)
        && UNIVERSAL::can( $obj, 'id' )
        && $obj->id )
    {
        return undef;
    }
    $self->Limit(
        FIELD           => 'ObjectType',
        OPERATOR        => '=',
        VALUE           => ref($obj),
        ENTRYAGGREGATOR => 'OR'
    );
    $self->Limit(
        FIELD           => 'ObjectId',
        OPERATOR        => '=',
        VALUE           => $obj->id,
        ENTRYAGGREGATOR => 'OR',
        QUOTEVALUE      => 0
    );

}

# }}}

# {{{ LimitNotObject

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

# }}}

# {{{ LimitToPrincipal 

=head2 LimitToPrincipal { Type => undef, Id => undef, IncludeGroupMembership => undef }

Limit the ACL to the principal with PrincipalId Id and PrincipalType Type

Id is not optional.
Type is.

if IncludeGroupMembership => 1 is specified, ACEs which apply to the principal due to group membership will be included in the resultset.


=cut

sub LimitToPrincipal {
    my $self = shift;
    my %args = ( Type                               => undef,
                 Id                                 => undef,
                 IncludeGroupMembership => undef,
                 @_ );
    if ( $args{'IncludeGroupMembership'} ) {
        my $cgm = $self->NewAlias('CachedGroupMembers');
        $self->Join( ALIAS1 => 'main',
                     FIELD1 => 'PrincipalId',
                     ALIAS2 => $cgm,
                     FIELD2 => 'GroupId' );
        $self->Limit( ALIAS => $cgm,
                      FIELD => 'Disabled',
                      VALUE => 0 );
        $self->Limit( ALIAS           => $cgm,
                      FIELD           => 'MemberId',
                      OPERATOR        => '=',
                      VALUE           => $args{'Id'},
                      ENTRYAGGREGATOR => 'OR' );
    }
    else {
        if ( defined $args{'Type'} ) {
            $self->Limit( FIELD           => 'PrincipalType',
                          OPERATOR        => '=',
                          VALUE           => $args{'Type'},
                          ENTRYAGGREGATOR => 'OR' );
        }
    # if the principal id points to a user, we really want to point
    # to their ACL equivalence group. The machinations we're going through
    # lead me to start to suspect that we really want users and groups
    # to just be the same table. or _maybe_ that we want an object db.
    my $princ = RT::Principal->new($RT::SystemUser);
    $princ->Load($args{'Id'});
    if ($princ->PrincipalType eq 'User') {
    my $group = RT::Group->new($RT::SystemUser);
        $group->LoadACLEquivalenceGroup($princ);
        $args{'Id'} = $group->PrincipalId;
    }
        $self->Limit( FIELD           => 'PrincipalId',
                      OPERATOR        => '=',
                      VALUE           => $args{'Id'},
                      ENTRYAGGREGATOR => 'OR' );
    }
}

# }}}



# {{{ ExcludeDelegatedRights

=head2 ExcludeDelegatedRights 

Don't list rights which have been delegated.

=cut

sub ExcludeDelegatedRights {
    my $self = shift;
    $self->DelegatedBy(Id => 0);
    $self->DelegatedFrom(Id => 0);
}
# }}}

# {{{ DelegatedBy 

=head2 DelegatedBy { Id => undef }

Limit the ACL to rights delegated by the principal whose Principal Id is
B<Id>

Id is not optional.

=cut

sub DelegatedBy {
    my $self = shift;
    my %args = (
        Id => undef,
        @_
    );
    $self->Limit(
        FIELD           => 'DelegatedBy',
        OPERATOR        => '=',
        VALUE           => $args{'Id'},
        ENTRYAGGREGATOR => 'OR'
    );

}

# }}}

# {{{ DelegatedFrom 

=head2 DelegatedFrom { Id => undef }

Limit the ACL to rights delegate from the ACE which has the Id specified 
by the Id parameter.

Id is not optional.

=cut

sub DelegatedFrom {
    my $self = shift;
    my %args = (
                 Id => undef,
                 @_);
    $self->Limit(FIELD => 'DelegatedFrom', OPERATOR=> '=', VALUE => $args{'Id'}, ENTRYAGGREGATOR => 'OR');

}

# }}}


# {{{ sub Next 
sub Next {
    my $self = shift;

    my $ACE = $self->SUPER::Next();
    if ( ( defined($ACE) ) and ( ref($ACE) ) ) {

        if ( $self->CurrentUser->HasRight( Right  => 'ShowACL',
                                           Object => $ACE->Object )
             or $self->CurrentUser->HasRight( Right  => 'ModifyACL',
                                              Object => $ACE->Object )
          ) {
            return ($ACE);
        }

        #If the user doesn't have the right to show this ACE
        else {
            return ( $self->Next() );
        }
    }

    #if there never was any ACE
    else {
        return (undef);
    }

}

# }}}



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


# {{{ HasEntry

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
1;
