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
use strict;
no warnings qw(redefine);

# {{{ sub LimitToCustomField

=head2 LimitToCustomField FIELD

Limits the returned set to values for the custom field with Id FIELD

=cut
  
sub LimitToCustomField {
    my $self = shift;
    my $cf = shift;
    return ($self->Limit( FIELD => 'CustomField',
			  VALUE => $cf,
			  OPERATOR => '='));

}

# }}}

# {{{ sub LimitToTicket

=head2 LimitToTicket TICKETID

Limits the returned set to values for the ticket with Id TICKETID

=cut
  
sub LimitToTicket {
    my $self = shift;
    my $ticket = shift;
    $self->Limit( FIELD => 'ObjectType',
		  VALUE => 'RT::Ticket',
		  OPERATOR => '=');
    return ($self->Limit( FIELD => 'ObjectId',
			  VALUE => $ticket,
			  OPERATOR => '='));

}

# }}}


sub LimitToObject {
    my $self = shift;
    my $object = shift;
    $self->Limit( FIELD => 'ObjectType',
		  VALUE => ref($object),
		  OPERATOR => '=');
    return ($self->Limit( FIELD => 'ObjectId',
			  VALUE => $object->Id,
			  OPERATOR => '='));

}

=sub HasEntry VALUE

Returns true if this CustomFieldValues collection has an entry with content that eq VALUE

=cut


sub HasEntry {
    my $self = shift;
    my $value = shift;

    #TODO: this could cache and optimize a fair bit.
    foreach my $item (@{$self->ItemsArrayRef}) {
        return(1) if ($item->Content eq $value);  
    }
    return undef;

}

sub _DoSearch {
    my $self = shift;
    
    #unless we really want to find disabled rows, make sure we\'re only finding enabled ones.
    unless($self->{'find_expired_rows'}) {
        $self->LimitToCurrent();
    }
    
    return($self->SUPER::_DoSearch(@_));
    
}

sub _DoCount {
    my $self = shift;
    
    #unless we really want to find disabled rows, make sure we\'re only finding enabled ones.
    unless($self->{'find_expired_rows'}) {
        $self->LimitToCurrent();
    }
    
    return($self->SUPER::_DoCount(@_));
    
}

sub LimitToCurrent {
    my $self = shift;
    
    $self->Limit( FIELD => 'Current',
		  VALUE => '1',
		  OPERATOR => '=' );
}

1;

