# $Header$
# Copyright 2000 Tobias Brox <tobix@cpan.org> and  Jesse Vincent <jesse@fsck.com>
# Released under the terms of the GNU Public License

package RT::Template;
use RT::Record;

@ISA= qw(RT::Record);

#
# The new plan for RT::Template is that it's a subclass of MIME::Entity, which is
# itself a subclass of Mail::Internet. This means we'll just be able to $Template->send()
# etcetera.
#

# {{{ sub new 
sub new  {
  my $pkg=shift;
    my $self=RT::Record::new($pkg);
  
  $self->{'table'}="Templates";
  $self->_Init(@_);
  return $self;
}
# }}}

# {{{ sub _Accessible 
sub _Accessible  {
  my $self = shift;
  my %Cols = (
	      id => 'read',
	      Title => 'read',
	      Content => 'read',
	      Creator => 'read',
	      Created => 'read',
	      LastUpdatedBy => 'read',
	      LastUpdated => 'read'
	     );
  return $self->SUPER::_Accessible(@_, %Cols);
}
# }}}

# {{{ sub DisplayPermitted 
sub DisplayPermitted  {
    return 1;
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

1;
