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
	      title => 'read',
	      content => 'read',
	      Creator => 'read',
	      Created => 'read',
	      LastUpdatedBy => 'read',
	      LastUpdated => 'read'
	     );
  return $self->SUPER::_Accessible(@_, %Cols);
}

sub Parse {
    my $self=shift;
    my $object=shift;

    # Might be subject to change
    require Text::Template;

    $template=Text::Template->new(TYPE=>STRING, SOURCE=>$self->content);
    return $template->fill_in(HASH=>$object);
}

1;
