# $Header$
# Copyright 2000 Tobias Brox <tobix@cpan.org> and  Jesse Vincent <jesse@fsck.com>
# Released under the terms of the GNU Public License

=head1 NAME

  RT::Template - RT's template object

=head1 SYNOPSIS

  use RT::Template;


=head1 DESCRIPTION


=head1 METHODS

=cut

package RT::Template;
use RT::Record;

@ISA= qw(RT::Record);


# {{{ sub _Init

sub _Init {
  my $self = shift;
  $self->{'table'} = "Templates";
  return($self->SUPER::_Init(@_));
}

# }}}

# {{{ sub _Accessible 

sub _Accessible  {
  my $self = shift;
  my %Cols = (
	      id => 'read',
	      Name => 'read/write',
	      Description => 'read/write',
	      Type => 'read/write', #Type is one of Action or Message
	      Content => 'read/write',
	      Queue => 'read/write',
	      Creator => 'read/auto',
	      Created => 'read/auto',
	      LastUpdatedBy => 'read/auto',
	      LastUpdated => 'read/auto'
	     );
  return $self->SUPER::_Accessible(@_, %Cols);
}

# }}}

# {{{ sub _Set

sub _Set {
  my $self = shift;
  # use super::value or we get acl blocked
  if ((defined $self->SUPER::_Value('Queue')) && ($self->SUPER::_Value('Queue') == 0 )) {
      unless ($self->CurrentUser->HasSystemRight('ModifyTemplate')) {
	  return (undef);
      }	
  }
  else {
      
      unless ($self->CurrentUserHasQueueRight('ModifyTemplate')) {
	  return (undef);
      }
  }
  return($self->SUPER::_Set(@_));
     
}

# }}}

# {{{ sub _Value 

=head2 _Value

Takes the name of a table column.
Returns its value as a string, if the user passes an ACL check

=cut

sub _Value  {

  my $self = shift;
  my $field = shift;

  #If the current user doesn't have ACLs, don't let em at it.  
  #use super::value or we get acl blocked
  if ((!defined $self->SUPER::_Value('Queue')) || ($self->SUPER::_Value('Queue') == 0 )) {
      unless ($self->CurrentUser->HasSystemRight('ShowTemplates')) {
	  return (undef);
      }	
  }
  else {
      unless ($self->CurrentUserHasQueueRight('ShowTemplate')) {
	  return (undef);
      }
  }
  return($self->__Value($field));
  
}

# }}}

# {{{ sub Load

=head2 Load <identifer>

Load a template, either by number or by name

=cut

sub Load  {
    my $self = shift;
    my $identifier = shift;
    
    
    
    
    if (!$identifier) {
	return (undef);
    }	    
    
    if ($identifier !~ /\D/) {
	$self->SUPER::LoadById($identifier);
    }
    else {
	$self->LoadByCol('Name', $identifier);
	
    }
}
# }}}

# {{{ sub Create

=head2 Create

Takes a paramhash of Content, Queue, Name and Description.
Name should be a unique string identifying this Template.
Description and Content should be the template's title and content.
Queue should be 0 for a global template and the queue # for a queue-specific 
template.

Returns the Template's id # if the create was successful. Returns undef for
unknown database failure.


=cut

sub Create {
    my $self = shift;
    my %args = ( Content => undef,
                 Queue => 0,
                 Description => '[no description]',
                 Type => 'Action', #By default, template are 'Action' templates
                 Name => undef,
                 @_
                );
    
    
    if ($args{'Queue'} == 0 ) { 
	unless ($self->CurrentUser->HasSystemRight('CreateTemplate')) {
	    return (undef);
 	}	
    }
    else {
	my $QueueObj = new RT::Queue($self->CurrentUser);
	$QueueObj->Load($args{'Queue'}) || return (0,'Invalid queue');
	
	unless ($QueueObj->CurrentUserHasRight('CreateTemplate')) {
	    return (undef);
	}	
    }
    #TODO+++ check the Name for uniqueness
    
    
    #$RT::Logger->debug ("Creating a new template: Content is ".$args{'Content'});
    my $result = $self->SUPER::Create( Content => $args{'Content'},
                                       Queue   => $args{'Queue'},,
                                       Description   => $args{'Description'},
				       Name   => $args{'Name'}
                                     );

    return ($result);

}

# }}}

# {{{ sub MIMEObj
sub MIMEObj {
  my $self = shift;
  return ($self->{'MIMEObj'});
}
# }}}

# {{{ sub Parse 

# This routine performs Text::Template parsing on thte template and then imports the 
# results into the MIME::Entity's namespace, where we can do real work with them.

sub Parse {
  my $self = shift;

  #We're passing in whatever we were passed. it's destined for _ParseContent
  my $content = $self->_ParseContent(@_);
  
  #Lets build our mime Entity
  use MIME::Entity;
  $self->{'MIMEObj'}= MIME::Entity->new();

  $self->{'MIMEObj'}->build(Type => 'multipart/mixed');

  (my $headers, my $body) = split(/\n\n/,$content,2);

  $self->{'MIMEObj'}->attach(Data => $body);

  foreach $header (split(/\n/,$headers)) {
    (my $key, my $value) = (split(/: /,$header,2));
    $self->{'MIMEObj'}->head->add($key, $value);
  }
  
}

# }}}

# {{{ sub _ParseContent

# Perform Template substitutions on the Body

sub _ParseContent  {
  my $self=shift;
  my %args = ( Argument => undef,
	       TicketObj => undef,
	       TransactionObj => undef,
	       @_);

  # Might be subject to change
  require Text::Template;
  
  $T::Ticket = $args{'TicketObj'};
  $T::Transaction = $args{'TransactionObj'};
  $T::Argument = $args{'Argument'};
  $T::rtname=$RT::rtname;
  $T::WebRT=$RT::WebRT;
  
  $template=Text::Template->new(TYPE=>STRING, 
				SOURCE=>$self->Content);
  
  return ($template->fill_in(PACKAGE=>T));
}
# }}}

# {{{ sub QueueObj

=head2 QueueObj

Takes nothing. returns this ticket's queue object

=cut

sub QueueObj {
    my $self = shift;
    if (!defined $self->{'queue'})  {
	require RT::Queue;
	$self->{'queue'} = RT::Queue->new($self->CurrentUser)
	  or die "RT::Queue->new(". $self->CurrentUser. ") returned false";
	#We call __Value so that we can avoid the ACL decision and some deep recursion
	my ($result) = $self->{'queue'}->Load($self->SUPER::_Value('Queue'));
	
    }
    return ($self->{'queue'});
}

# }}}

# {{{ sub CurrentUserHasQueueRight

=head2 CurrentUserHasQueueRight

Helper function to call the template's queue's CurrentUserHasQueueRight with the passed in args.

=cut
sub CurrentUserHasQueueRight {
    my $self = shift;
    return($self->QueueObj->CurrentUserHasRight(@_));
}

# }}}
1;
