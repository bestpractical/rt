# $Header$
# Copyright 2000 Tobias Brox <tobix@cpan.org> and  Jesse Vincent <jesse@fsck.com>
# Released under the terms of the GNU Public License

package RT::Template;
use RT::Record;
use MIME::Entity;
@ISA= qw(RT::Record MIME::Entity);

#
# The new plan for RT::Template is that it's a subclass of MIME::Entity, which is
# itself a subclass of Mail::Internet. This means we'll just be able to $Template->send()
# etcetera.
#

# {{{ sub new 
sub new  {
    $pkg=shift;
    my $self=SUPER::new $pkg;
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
	      Headers => 'read',
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


# {{{ sub Parse 

# This routine performs Text::Template parsing on thte template and then imports the 
# results into the MIME::Entity's namespace, where we can do real work with them.

sub Parse {
  my $self = shift;
  $self->_ParseHeaders();
  $self->_ParseContent();
  $self->_ImportHeaders();
  $self->_ImportContent();

}

# }}}

# {{{ sub _ImportHeaders
# This sticks $self->Headers into the templates MIME::Entity Headers
sub _ImportHeaders {
  my $self = shift;
  

  for (split /\n/, $self->Headers) {
    /: /;
    $self->{Header}->add($`, $');
  }
}

# }}}

# {{{ sub ImportContent {

# This sticks $self->Content into the Template's MIME::Entity Body 
sub _ImportBody {
  my $self = shift;
  
}
# }}}


# {{{ sub ParseHeaders 
# This routine performs template substitutions on $self->Headers

sub _ParseHeaders  {
  my $self=shift;
  my $object=shift;
  
  # Might be subject to change
  require Text::Template;
  
  # Ouch ... this sucks a bit.  Maybe Text::Template is based upon
  # some old perl4 code?  It can't take my'ed variables, and it
  # won't accept objects as hashes, nor hashes containing objects.
  
  $T::self=$self;
  $T::object=$object;
  $T::rtname=$RT::rtname;
  
  $template=Text::Template->new(TYPE=>STRING, 
				SOURCE=>$self->Headers));
return ($template->fill_in(PACKAGE=>T));

}
# }}}

# {{{ sub ParseBody 

# ParseBody will perform Template substitutions on the Body

sub _ParseBody  {
  my $self=shift;
  my $object=shift;

  
  # Might be subject to change
  require Text::Template;
  
  # Ouch ... this sucks a bit.  Maybe Text::Template is based upon
  # some old perl4 code?  It can't take my'ed variables, and it
  # won't accept objects as hashes, nor hashes containing objects.
  
  $T::self=$self;
  $T::object=$object;
  $T::rtname=$RT::rtname;

  $template=Text::Template->new(TYPE=>STRING, 
				SOURCE=>$self->Content);
  
  return ($template->fill_in(PACKAGE=>T));
}
# }}}





1;
