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
          Alias => 'read/write',
	      Title => 'read/write',
	      Content => 'read/write',
          Queue => 'read/write'
	     );
  return $self->SUPER::_Accessible(@_, %Cols);
}
# }}}

# {{{ sub _Set

sub _Set {
  my $self = shift;

  unless ($self->CurrentUserHasQueueRight('ModifyTemplates')) {
    return (0, "Permission Denied");
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

 unless ($self->CurrentUserHasQueueRight('ShowTemplates')) {
    return (0, "Permission Denied");
  }

  return($self->SUPER::_Value($field));

}

# }}}



# {{{ sub Create

=head2 Create

Takes a paramhash of Content, Queue, Title and Alias.
Alias should be a unique string identifying this Template.
Title and Content should be the template's title and content.
Queue should be 0 for a global template and the queue # for a queue-specific 
template.

Returns the Template's id # if the create was successful. Returns undef for
unknown database failure.


=cut

sub Create {
    my $self = shift;
    my %args = ( Content => undef,
                 Queue => undef,
                 Title => '[no title]',
                 Alias => undef,
                 @_
                );

    my $QueueObj = new RT::Queue($self->CurrentUser);
    $QueueObj->Load($args{'Queue'}) || return (0,'Invalid queue');

    unless ($QueueObj->CurrentUserHasRight('CreateTemplate')) {
     return (0, "Permission Denied");
    }
   
    #TODO+++ check the queue for validity. check the alias for uniqueness.

    my $result = $self->SUPER::Create( Content => "$args{'Content'}",
                                       Queue   => "$args{'Queue'}",
                                       Title   => "$args{'Title'}",
                                       Alias   => "$args{'Alias'}"
                                      );

    return ($result);

}


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
    #We call SUPER::_Value so that we can avoid the ACL decision and some deep recursion
    my ($result) = $self->{'queue'}->Load($self->SUPER::_Value('Queue'));

  }
  return ($self->{'queue'});
}


# }}}

=head2 CurrentUserHasQueueRight

Helper function to call the template's queue's CurrentUserHasQueueRight with the passed in args.

=cut
sub CurrentUserHasQueueRight {
    my $self = shift;
    return($self->QueueObj->CurrentUserHasRight(@_));
}

1;
