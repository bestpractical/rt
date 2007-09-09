# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC 
#                                          <jesse@bestpractical.com>
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
# http://www.gnu.org/copyleft/gpl.html.
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

  RT::Model::ACECollection - collection of RT ACE objects

=head1 SYNOPSIS

  use RT::Model::ACECollection;
my $ACL = new RT::Model::ACECollection($CurrentUser);

=head1 DESCRIPTION


=head1 METHODS


=cut


package RT::Model::ACECollection;

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
    $self->limit(
        column           => 'ObjectType',
        operator        => '=',
        value           => ref($obj),
        entry_aggregator => 'OR'
    );
    $self->limit(
        column           => 'ObjectId',
        operator        => '=',
        value           => $obj->id,
        entry_aggregator => 'OR',
        quote_value      => 0
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
    $self->limit( column => 'ObjectType',
		  operator => '!=',
		  value => ref($obj),
		  entry_aggregator => 'OR',
		  subclause => $obj->id
		);
    $self->limit( column => 'ObjectId',
		  operator => '!=',
		  value => $obj->id,
		  entry_aggregator => 'OR',
		  quote_value => 0,
		  subclause => $obj->id
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
        my $cgm = $self->new_alias('CachedGroupMembers');
        $self->join( alias1 => 'main',
                     column1 => 'PrincipalId',
                     alias2 => $cgm,
                     column2 => 'GroupId' );
        $self->limit( alias           => $cgm,
                      column           => 'MemberId',
                      operator        => '=',
                      value           => $args{'Id'},
                      entry_aggregator => 'OR' );
    }
    else {
        if ( defined $args{'Type'} ) {
            $self->limit( column           => 'PrincipalType',
                          operator        => '=',
                          value           => $args{'Type'},
                          entry_aggregator => 'OR' );
        }
    # if the principal id points to a user, we really want to point
    # to their ACL equivalence group. The machinations we're going through
    # lead me to start to suspect that we really want users and groups
    # to just be the same table. or _maybe_ that we want an object db.
    my $princ = RT::Model::Principal->new($RT::SystemUser);
    $princ->load($args{'Id'});
    if ($princ->PrincipalType eq 'User') {
    my $group = RT::Model::Group->new($RT::SystemUser);
        $group->load_acl_equivalence_group($princ);
        $args{'Id'} = $group->PrincipalId;
    }
        $self->limit( column           => 'PrincipalId',
                      operator        => '=',
                      value           => $args{'Id'},
                      entry_aggregator => 'OR' );
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
    $self->limit(
        column           => 'DelegatedBy',
        operator        => '=',
        value           => $args{'Id'},
        entry_aggregator => 'OR'
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
    $self->limit(column => 'DelegatedFrom', operator=> '=', value => $args{'Id'}, entry_aggregator => 'OR');

}

# }}}


# {{{ sub Next 
sub Next {
    my $self = shift;

    my $ACE = $self->SUPER::Next();
    if ( ( defined($ACE) ) and ( ref($ACE) ) ) {

        if ( $self->CurrentUser->has_right( Right  => 'ShowACL',
                                           Object => $ACE->Object )
             or $self->CurrentUser->has_right( Right  => 'ModifyACL',
                                              Object => $ACE->Object )
          ) {
            return ($ACE);
        }

        #If the user doesn't have the right to show this ACE
        else {
            return ( $self->next() );
        }
    }

    #if there never was any ACE
    else {
        return (undef);
    }

}

# }}}



#wrap around _do_search  so that we can build the hash of returned
#values 
sub _do_search {
    my $self = shift;
   # $RT::Logger->debug("Now in ".$self."->_do_search");
    my $return = $self->SUPER::_do_search(@_);
  #  $RT::Logger->debug("In $self ->_do_search. return from SUPER::_do_search was $return\n");
    $self->{'must_redo_search'}=0;
    $self->_is_limited(1);
    $self->_build_hash();
    return ($return);
}


#Build a hash of this ACL's entries.
sub _build_hash {
    my $self = shift;

    while (my $entry = $self->next) {
       my $hashkey = $entry->__value('ObjectType'). "-" .  $entry->__value('ObjectId'). "-" .  $entry->__value('RightName'). "-" .  $entry->__value('PrincipalId'). "-" .  $entry->__value('PrincipalType');

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
    $self->_do_search();

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
