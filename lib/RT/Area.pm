# Copyright 1999 Jesse Vincent <jesse@fsck.com>
# Released under the terms of the GNU Public License
# $Id$ 
#
# This code is not used yet.
#
package RT::Area;
use RT::Record;
@ISA= qw(RT::Record);


sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);

  $self->{'table'} = "queue_areas";
  $self->{'user'} = shift;
  $self->_init(@_);
  return ($self);
}


#take simple args and call DBIx::Record to do the real work.
sub create {
  my $self = shift;

  my %args = ( id => undef,
	       queue => '',
	       area => '',
               description => '',
	       @_
	     );
  # Return 0 if missing any critical values
  return (0) if ((!$args{'area'}) || (! $args{'queue'}));
  
  my $id = $self->SUPER::Create(queue => $args{'queue'},
				area => $args{'area'},
				description => $args{'description'},
				comment => $args{'comment'});
  return ($id);
}



#Table specific data accessors/ modifiers
sub Queue {
  my $self = shift;
  return($self->_set_and_return('queue',@_));
}

sub Area {
  my $self = shift;
  return($self->_set_and_return('area',@_));
}
sub Description {
  my $self = shift;
  return($self->_set_and_return('description',@_));
}

1;
