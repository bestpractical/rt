# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2003 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
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
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK
=head1 NAME

  RT::CustomFields - a collection of RT CustomField objects

=head1 SYNOPSIS

  use RT::CustomFields;

=head1 DESCRIPTION

=head1 METHODS


=begin testing

ok (require RT::CustomFields);

=end testing

=cut

use strict;
no warnings qw(redefine);


sub _OCFAlias {
    my $self = shift;
    $self->{_sql_ocfalias} ||= $self->NewAlias('ObjectCustomFields');
}


# {{{ sub LimitToGlobalOrQueue 

=item LimitToGlobalOrQueue QUEUEID

Limits the set of custom fields found to global custom fields or those tied to the queue with ID QUEUEID 

=cut

sub LimitToGlobalOrQueue {
    my $self = shift;
    my $queue = shift;
    $self->LimitToQueue($queue);
    $self->LimitToGlobal();
}

# }}}

# {{{ sub LimitToQueue 

=head2 LimitToQueue QUEUEID

Takes a queue id (numerical) as its only argument. Makes sure that 
Scopes it pulls out apply to this queue (or another that you've selected with
another call to this method

=cut

sub LimitToQueue  {
   my $self = shift;
  my $queue = shift;
 
  $self->Limit (ALIAS => $self->_OCFAlias,
                ENTRYAGGREGATOR => 'OR',
		FIELD => 'ObjectId',
		VALUE => "$queue")
      if defined $queue;
  $self->LimitToObjectType( 'RT::Queue' );
}
# }}}

# {{{ sub LimitToGlobal

=head2 LimitToGlobal

Makes sure that 
Scopes it pulls out apply to all queues (or another that you've selected with
another call to this method or LimitToQueue

=cut


sub LimitToGlobal  {
   my $self = shift;
 
  $self->Limit (ALIAS => $self->_OCFAlias,
                ENTRYAGGREGATOR => 'OR',
		FIELD => 'ObjectId',
		VALUE => 0);
  $self->LimitToObjectType( 'RT::Queue' );
}
# }}}

sub LimitToObjectType {
    my $self = shift;
    my $type = shift;

    return if $self->{_sql_limit_objectype}{$type}++;
    $self->Limit (ALIAS => $self->_OCFAlias,
		    ENTRYAGGREGATOR => 'OR',
		    FIELD => 'ObjectType',
		    VALUE => $type);
}

# {{{ sub _DoSearch 

=head2 _DoSearch

  A subclass of DBIx::SearchBuilder::_DoSearch that makes sure that _Disabled ro
ws never get seen unless
we're explicitly trying to see them.

=cut

sub _DoSearch {
    my $self = shift;
    
    #unless we really want to find disabled rows, make sure we\'re only finding enabled ones.
    unless($self->{'find_disabled_rows'}) {
        $self->LimitToEnabled();
    }
    
    return($self->SUPER::_DoSearch(@_));
    
}

# }}}

# {{{ sub Next 

=head2 Next

Returns the next custom field that this user can see.

=cut
  
sub Next {
    my $self = shift;
    
    
    my $CF = $self->SUPER::Next();
    if ((defined($CF)) and (ref($CF))) {

	if ($CF->CurrentUserHasRight('SeeCustomField')) {
	    return($CF);
	}
	
	#If the user doesn't have the right to show this queue
	else {	
	    return($self->Next());
	}
    }
    #if there never was any queue
    else {
	return(undef);
    }	
    
}
# }}}

sub LimitToParentId  {
    my $self = shift;
    my $id = shift || 0;
 
    $self->Limit( FIELD => 'ParentId', VALUE => "$id" );
}

sub LimitToObjectType  {
    my $self = shift;
    my $o_type = shift;
 
    $self->Limit( FIELD => 'ObjectType', VALUE => "$o_type" );
}

sub LimitToComposite  {
    my $self = shift;
    my $composite = shift;
    my ($o_type, $i_type, $p_type) = split(/-/, $composite, 3);
 
    $self->Limit( FIELD => 'ObjectType', VALUE => "$o_type" );
    $self->Limit( FIELD => 'IntermediateType', VALUE => "$i_type" );
    $self->Limit( FIELD => 'ParentType', VALUE => "$p_type" );
}

sub LimitToGlobalOrParentId {
    my $self = shift;
    my $id = shift || 0;

    my $object_cfs = $self->NewAlias('ObjectCustomFields');
    $self->Join( ALIAS1 => 'main',
                FIELD1 => 'id',
                ALIAS2 => $object_cfs,
                FIELD2 => 'CustomField' );
    $self->Limit( ALIAS           => $object_cfs,
                 FIELD           => 'ParentId',
                 OPERATOR        => '=',
                 VALUE           => $id,
                 ENTRYAGGREGATOR => 'OR' );
    $self->Limit( ALIAS           => $object_cfs,
                 FIELD           => 'ParentId',
                 OPERATOR        => '=',
                 VALUE           => 0,
                 ENTRYAGGREGATOR => 'OR' ) if $id;
    
    # This doesn't work on postgres. 
    #$self->OrderBy( ALIAS => $class_cfs , FIELD => "SortOrder", ORDER => 'ASC');

}
  
1;

