# Copyright 1999-2000 Jesse Vincent <jesse@fsck.com>
# Released under the terms of the GNU Public License
# $Header$

=head1 NAME

  RT::ScripAction - RT Action object

=head1 SYNOPSIS

  use RT::ScripAction;


=head1 DESCRIPTION


=head1 METHODS

=cut

package RT::ScripAction;
use RT::Record;
@ISA= qw(RT::Record);



# {{{  sub _Init 
sub _Init  {
    my $self = shift; 
    $self->{'table'} = "ScripActions";
    return ($self->SUPER::_Init(@_));
}
# }}}

# {{{ sub _Accessible 
sub _Accessible  {
    my $self = shift;
    my %Cols = ( Name  => 'read/write',
		 Description => 'read/write',
		 ExecModule  => 'read/write',
		 Argument  => 'read/write'
	       );
    return($self->SUPER::_Accessible(@_, %Cols));
}
# }}}

# {{{ sub Create 
=head2 Create
  
Takes a hash. Creates a new Action entry.
 should be better documented.
=cut
sub Create  {
  my $self = shift;
  #TODO check these args and do smart things.
  my $id = $self->SUPER::Create(@_);
  $self->LoadById($id);
  #TODO proper return values 
}
# }}}

# {{{ sub delete 
sub Delete  {
    my $self = shift;
    # this function needs to move all requests into some other queue!
    my ($query_string,$update_clause);
    
    die ("ScripAction->Delete not implemented yet");
}
# }}}



# {{{ sub Load 
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

    if (@_) {
	# Set the template Id to the passed in template    
	my $template = shift;
	
	$self->{'Template'} = $template;
    }
}
# }}}


# {{{ sub LoadAction 
sub LoadAction  {
    my $self = shift;
    my %args = ( TransactionObj => undef,
		 TicketObj => undef,
		 @_ );
    
    #TODO: Put this in an eval  
    my $type = "RT::Action::". $self->ExecModule;
    
    $RT::Logger->debug("now requiring $type\n"); 
    eval "require $type" || die "Require of $type failed.\n$@\n";
    
    $self->{'Action'}  = $type->new ( 'ScripActionObj' => $self, 
				      'TicketObj' => $args{'TicketObj'},
				      'TransactionObj' => $args{'TransactionObj'},
				      'TemplateObj' => $self->TemplateObj,
				      'Argument' => $self->Argument,
				    );
}
# }}}

# {{{ sub TemplateObj
sub TemplateObj {
    my $self = shift;
    return undef unless $self->{Template};
    if (!$self->{'TemplateObj'})  {
	require RT::Template;
	$self->{'TemplateObj'} = RT::Template->new($self->CurrentUser);
	$self->{'TemplateObj'}->LoadById($self->{'Template'});
	
    }
    
    return ($self->{'TemplateObj'});
}
# }}}

# The following methods call the action object

# {{{ sub Prepare 
sub Prepare  {
    my $self = shift;
    return ($self->{'Action'}->Prepare());
  
}
# }}}

# {{{ sub Commit 
sub Commit  {
    my $self = shift;
    return($self->{'Action'}->Commit());
    
    
}
# }}}

# {{{ sub Describe 
sub Describe  {
    my $self = shift;
    return ($self->{'Action'}->Describe());
    
}
# }}}

# {{{ sub DESTROY
sub DESTROY {
    my $self=shift;
    $self->{'Action'} = undef;
    $self->{'TemplateObj'} = undef;
}
# }}}


1;


