#$Header$
=head1 NAME

  RT::Scrip - an RT Scrip object

=head1 SYNOPSIS

  use RT::Scrip;

=head1 DESCRIPTION


=head1 METHODS

=cut

package RT::Scrip;
use RT::Record;
@ISA= qw(RT::Record);

# {{{ sub _Init
sub _Init  {
    my $self = shift;
    $self->{'table'} = "Scrips";
    return ($self->SUPER::_Init(@_));
}
# }}}

# {{{ sub _Accessible 
sub _Accessible  {
    my $self = shift;
    my %Cols = ( ScripAction  => 'read/write',
		 ScripCondition => 'read/write',
		 Stage => 'read/write',
		 Queue => 'read/write', 
		 Template => 'read/write',
	       );
    return($self->SUPER::_Accessible(@_, %Cols));
}
# }}}

# {{{ sub Create 

=head2 Create

Creates a new entry in the Scrips table. Takes a paramhash with three
fields, Queue, Template and Action.

=cut

sub Create  {
    my $self = shift;
    my %args = ( Queue => undef,
		 Template => undef,
		 ScripAction => undef,
		 ScripCondition => undef,
		 Stage => 'TransactionCreate',
		 @_
	       );
    
    

    unless ($self->CurrentUserHasRight('ModifyScrips')) {
	return (0, 'Permission Denied');
    }
    
    #TODO +++ validate input 
    #TODO: Allow loading Template, ScripAction and ScripCondition by name

    require RT::ScripAction;
    my $action = new RT::ScripAction($self->CurrentUser);
    $action->Load($args{'ScripAction'});
    return (0, "Action ".$args{'ScripAction'}." not found") unless $action->Id;

    require RT::Template;
    my $template = new RT::Template($self->CurrentUser);
    $template->Load($args{'Template'});
    return (0, 'Template not found') unless $template->Id;

    require RT::ScripCondition;
    my $condition = new RT::ScripCondition($self->CurrentUser);
    $condition->Load($args{'ScripCondition'});

    unless ($condition->Id) {
	return (0, 'Condition not found');
    }	
    
    my $id = $self->SUPER::Create(Queue => $args{'Queue'},
				  Template => $template->Id,
				  ScripCondition => $condition->id,
				  Stage => $args{'Stage'},
				  ScripAction => $action->Id
				 );
    return ($id, 'Scrip Created'); 
}

# }}}

# {{{ sub QueueObj

=head2 QueueObj

Retuns an RT::Queue object with this Scrip\'s queue

=cut

sub QueueObj {
    my $self = shift;
    
    if (!$self->{'QueueObj'})  {
	require RT::Queue;
	$self->{'QueueObj'} = RT::Queue->new($self->CurrentUser);
	$self->{'QueueObj'}->Load($self->Queue);
    }
    return ($self->{'QueueObj'});
}

# }}}

# {{{ sub ActionObj


=head2 ActionObj

Retuns an RT::Action object with this Scrip\'s Action

=cut

sub ActionObj {
    my $self = shift;
    
    unless (defined $self->{'ScripActionObj'})  {
	require RT::ScripAction;
	
	$self->{'ScripActionObj'} = RT::ScripAction->new($self->CurrentUser);
	#TODO: why are we loading Actions with templates like this. 
	# two seperate methods might make more sense
	$self->{'ScripActionObj'}->Load($self->ScripAction, $self->Template);
    }
    return ($self->{'ScripActionObj'});
}

# }}}


# {{{ sub TemplateObj
=head2 TemplateObj

Retuns an RT::Template object with this Scrip\'s Template

=cut

sub TemplateObj {
    my $self = shift;
    
    unless (defined $self->{'TemplateObj'})  {
	require RT::Template;
	$self->{'TemplateObj'} = RT::Template->new($self->CurrentUser);
	$self->{'TemplateObj'}->Load($self->Template);
    }
    return ($self->{'TemplateObj'});
}

# }}}

# {{{ sub Prepare
=head2 Prepare

Calls the action object's prepare method

=cut

sub Prepare {
    my $self = shift;
    $self->ActionObj->Prepare(@_);
}

# }}}

# {{{ sub Commit
=head2 Commit

Calls the action object's commit method

=cut

sub Commit {
    my $self = shift;
    $self->ActionObj->Commit(@_);
}

# }}}

# {{{ sub ConditionObj

=head2 ConditionObj

Retuns an RT::ScripCondition object with this Scrip's IsApplicable

=cut

sub ConditionObj {
    my $self = shift;
    
    unless (defined $self->{'ScripConditionObj'})  {
	require RT::ScripCondition;
	$self->{'ScripConditionObj'} = RT::ScripCondition->new($self->CurrentUser);
	$self->{'ScripConditionObj'}->Load($self->ScripCondition);
    }
    return ($self->{'ScripConditionObj'});
}

# }}}

# {{{ sub IsApplicable

=head2 IsApplicable

Calls the  Condition object\'s IsApplicable method

=cut

sub IsApplicable {
    my $self = shift;
    return ($self->ConditionObj->IsApplicable(@_));
}

# }}}

# {{{ sub DESTROY
sub DESTROY {
    my $self = shift;
    $self->{'ActionObj'} = undef;
}
# }}}

# {{{ ACL related methods

# {{{ sub _Set

# does an acl check and then passes off the call
sub _Set {
    my $self = shift;
    
    unless ($self->CurrentUserHasRight('ModifyScrips')) {
        $RT::Logger->debug("CurrentUser can't modify Scrips for ".$self->Queue."\n");
	return (0, 'Permission denied');
    }
    return $self->__Set(@_);
}

# }}}

# {{{ sub _Value
# does an acl check and then passes off the call
sub _Value {
    my $self = shift;
    
    unless ($self->CurrentUserHasRight('ShowScrips')) {
        $RT::Logger->debug("CurrentUser can't modify Scrips for ".$self->Queue."\n");
	return (undef);
    }
    
    return $self->__Value(@_);
}
# }}}

# {{{ sub CurrentUserHasRight

=head2 CurrentUserHasRight

Helper menthod for HasRight. Presets Principal to CurrentUser then 
calls HasRight.

=cut

sub CurrentUserHasRight {
    my $self = shift;
    my $right = shift;
    return ($self->HasRight( Principal => $self->CurrentUser->UserObj,
                             Right => $right ));
    
}

# }}}

# {{{ sub HasRight

=head2 HasRight

Takes a param-hash consisting of "Right" and "Principal"  Principal is 
an RT::User object or an RT::CurrentUser object. "Right" is a textual
Right string that applies to Scrips.

=cut

sub HasRight {
    my $self = shift;
    my %args = ( Right => undef,
                 Principal => undef,
                 @_ );
    
    if ((defined $self->SUPER::_Value('Queue')) and ($self->SUPER::_Value('Queue') != 0)) {
        return ( $args{'Principal'}->HasQueueRight(
						   Right => $args{'Right'},
						   Queue => $self->SUPER::_Value('Queue'),
						   Principal => $args{'Principal'}
						  ) 
	       );
	
    }
    else {
        return( $args{'Principal'}->HasSystemRight( $args{'Right'}) );
    }
}
# }}}

# }}}

1;


