# Copyright 2000 Jesse Vincent <jesse@fsck.com>
# Released under the terms of the GNU Public License
# $Id$ 
#
#
package RT::Attachment;
use RT::Record;
@ISA= qw(RT::Record);

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  
  $self->{'table'} = "Attachments";
  $self->_Init(@_);
  return ($self);
}

sub _Accessible {
  my $self = shift;
  my %Cols = (
	      Transaction => 'read',
	      MessageId => 'read',
	      ContentType => 'read',
	      Summary => 'read/write',
	      Content => 'read',
	      Creator => 'read',
	      Created => 'read'
	     );
}
#take simple args and call RT::Record to do the real work.

sub Create {
  my $self = shift;
  
  my %args = ( id => undef,
               TransactionId => 0,
	       Content => undef,
	       Summary => undef,
	       ContentType => 'text/plain',
	       MessageId => undef,
	       @_
	     );
  #if we didn't specify a ticket, we need to bail
  if ( $args{'TransactionId'} == 0) {
    die "RT::Attachment->Create couldn't, as you didn't specify a transaction\n";
  }
  
  #lets create our parent object
  my $id = $self->SUPER::Create(TransactionId => $args{'TransactionId'},
				ContentType  => $args{'ContentType'},
				MessageId => $args{'MessageId'},
				Content => $args{'Content'},
				Summary => $args{'Summary'},
				Created => undef,
				Creator => $self->CurrentUser->UserId()
			       );
  return ($id);
}


#ACCESS CONTROL
# 
sub DisplayPermitted {
  my $self = shift;

  my $actor = shift;
  if (!$actor) {
    my $actor = $self->CurrentUser->Id();
  }
  if (1) {
#  if ($self->Queue->DisplayPermitted($actor)) {
    return(1);
  }
  else {
    #if it's not permitted,
    return(0);
  }
}

sub ModifyPermitted {
  my $self = shift;
  my $actor = shift;
  if (!$actor) {
    my $actor = $self->CurrentUser->Id();
  }
  if ($self->Queue->ModifyPermitted($actor)) {
    
    return(1);
  }
  else {
    #if it's not permitted,
    return(0);
  }
}

sub AdminPermitted {
  my $self = shift;
  my $actor = shift;
  if (!$actor) {
    my $actor = $self->CurrentUser->Id();
  }


  if ($self->Queue->AdminPermitted($actor)) {
    
    return(1);
  }
  else {
    #if it's not permitted,
    return(0);
  }
}
1;
