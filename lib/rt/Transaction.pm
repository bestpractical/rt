# Copyright 1999 Jesse Vincent <jesse@fsck.com>
# Released under the terms of the GNU Public License
# $Id$ 
#
# This code is not used yet.
#
package rt::Transaction;
@ISA= qw(RT::Record);

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);

  $self->{'table'} = "transactions";
  $self->{'user'} = shift;
  return $self;
}


#take simple args and call MKIA::Database::Record to do the real work.
sub create {
  my $self = shift;

  my %args = ( id => '',
	       effective_sn => '',
	       serial_num => '',
               actor => '',
               type => '',
	       trans_data => '',
	       trans_date => '',
	       content => '',
	       @_
	     );
  return (0) if (! $args{'article'});
  my $id = $self->SUPER::create(article => $args{'article'},
				url => $args{'url'},
				title => $args{'title'},
				comment => $args{'comment'});
  return ($id);
}



#Table specific data accessors/ modifiers
sub title {
  my $self = shift;
  return($self->_set_and_return('title',@_));
}

sub url {
  my $self = shift;
  return($self->_set_and_return('url',@_));
}
sub comment {
  my $self = shift;
  return($self->_set_and_return('comment',@_));
}

sub content {
  my $self=shift;
  return($self->_set_and_return('content',@_));
}
1;
