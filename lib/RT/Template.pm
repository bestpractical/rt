# Copyright 2000 Tobias Brox <tobix@cpan.org>
# Part of Request Tracker by Jesse Vincent <jesse@fsck.com>
# Released under the terms of the GNU Public License
# $Id$

package RT::Template;
use RT::Record;
@ISA= qw(RT::Record);

sub new {
    $pkg=shift;
    my $self=SUPER::new $pkg;
    $self->{'table'}="Templates";
    $self->_Init(@_);
    return $self;
}

sub _Accessible {
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

sub DisplayPermitted {
    return 1;
}

sub ParseHeaders {
    return Parse(@_, 'Headers');
}

sub Parse {
    my $self=shift;
    my $object=shift;
    my $what=shift;

    # Might be subject to change
    require Text::Template;

    # Ouch ... this sucks a bit.  Maybe Text::Template is based upon
    # some old perl4 code?  It can't take my'ed variables, and it
    # won't accept objects as hashes, nor hashes containing objects.

    $T::self=$self;
    $T::object=$object;
    $T::rtname=$RT::rtname;
    
    $template=Text::Template->new(TYPE=>STRING, 
				  SOURCE=>($what&&($what eq 'Headers')
				      ? $self->Headers 
                                      : $self->Content));
    return $template->fill_in(PACKAGE=>T);
}

1;
