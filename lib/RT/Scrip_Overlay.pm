# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2003 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
# 
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
# 
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK
=head1 NAME

  RT::Scrip - an RT Scrip object

=head1 SYNOPSIS

  use RT::Scrip;

=head1 DESCRIPTION


=head1 METHODS

=begin testing

ok (require RT::Scrip);


my $q = RT::Queue->new($RT::SystemUser);
$q->Create(Name => 'ScripTest');
ok($q->Id, "Created a scriptest queue");

my $s1 = RT::Scrip->new($RT::SystemUser);
my ($val, $msg) =$s1->Create( Queue => $q->Id,
             ScripAction => 'User Defined',
             ScripCondition => 'User Defined',
             CustomIsApplicableCode => 'if ($self->TicketObj->Subject =~ /fire/) { return (1);} else { return(0)}',
             CustomPrepareCode => 'return 1',
             CustomCommitCode => '$self->TicketObj->SetPriority("87");',
             Template => 'Blank'
    );
ok($val,$msg);

my $ticket = RT::Ticket->new($RT::SystemUser);
my ($tv,$ttv,$tm) = $ticket->Create(Queue => $q->Id,
                                    Subject => "hair on fire",
                                    );
ok($tv, $tm);

ok ($ticket->Priority == '87', "Ticket priority is set right");


my $ticket2 = RT::Ticket->new($RT::SystemUser);
my ($t2v,$t2tv,$t2m) = $ticket2->Create(Queue => $q->Id,
                                    Subject => "hair in water",
                                    );
ok($t2v, $t2m);

ok ($ticket2->Priority != '87', "Ticket priority is set right");


=end testing

=cut

use strict;
no warnings qw(redefine);


# {{{ sub Create 

=head2 Create

Creates a new entry in the Scrips table. Takes a paramhash with:

        Queue                  => 0,
        Description            => undef,
        Template               => undef,
        ScripAction            => undef,
        ScripCondition         => undef,
        CustomPrepareCode      => undef,
        CustomCommitCode       => undef,
        CustomIsApplicableCode => undef,




Returns (retval, msg);
retval is 0 for failure or scrip id.  msg is a textual description of what happened.

=cut

sub Create {
    my $self = shift;
    my %args = (
        Queue                  => 0,
        Template               => 0, # name or id
        ScripAction            => 0, # name or id
        ScripCondition         => 0, # name or id
        Stage                  => 'TransactionCreate',
        Description            => undef,
        CustomPrepareCode      => undef,
        CustomCommitCode       => undef,
        CustomIsApplicableCode => undef,

        @_
    );


    if (! $args{'Queue'} ) {
        unless ( $self->CurrentUser->HasRight( Object => $RT::System, Right => 'ModifyScrips') ) {
            return ( 0, $self->loc('Permission Denied') );
        }
        $args{'Queue'} = 0;		# avoid undef sneaking in
    }
    else {
        my $QueueObj = new RT::Queue( $self->CurrentUser );
        $QueueObj->Load( $args{'Queue'} );
        unless ( $QueueObj->id() ) {
            return ( 0, $self->loc('Invalid queue') );
        }
        unless ( $QueueObj->CurrentUserHasRight('ModifyScrips') ) {
            return ( 0, $self->loc('Permission Denied') );
        }
        $args{'Queue'} = $QueueObj->id();
    }

    #TODO +++ validate input 

    require RT::ScripAction;
    my $action = new RT::ScripAction( $self->CurrentUser );
    $action->Load( $args{'ScripAction'} || '0' );
    return ( 0, $self->loc( "Action [_1] not found", $args{'ScripAction'} ) )
      unless $action->Id;

    require RT::Template;
    my $template = new RT::Template( $self->CurrentUser );
    $template->Load( $args{'Template'}||'0' );
    return ( 0, $self->loc('Template not found') ) unless $template->Id;

    require RT::ScripCondition;
    my $condition = new RT::ScripCondition( $self->CurrentUser );
    $condition->Load( $args{'ScripCondition'}||'0' );

    unless ( $condition->Id ) {
        return ( 0, $self->loc('Condition not found') );
    }

    my ($id,$msg) = $self->SUPER::Create(
        Queue                  => $args{'Queue'},
        Template               => $template->Id,
        ScripCondition         => $condition->id,
        Stage                  => $args{'Stage'},
        ScripAction            => $action->Id,
        Description            => $args{'Description'},
        CustomPrepareCode      => $args{'CustomPrepareCode'},
        CustomCommitCode       => $args{'CustomCommitCode'},
        CustomIsApplicableCode => $args{'CustomIsApplicableCode'},

    );
    if ($id) {
        return ( $id, $self->loc('Scrip Created') );
    }
    else {
        return($id,$msg);
    }
}

# }}}

# {{{ sub Delete

=head2 Delete

Delete this object

=cut

sub Delete {
    my $self = shift;
    
    unless ($self->CurrentUserHasRight('ModifyScrips')) {
	return (0, $self->loc('Permission Denied'));
    }
    
    return ($self->SUPER::Delete(@_));
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
	$self->{'QueueObj'}->Load($self->__Value('Queue'));
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


# {{{ Dealing with this instance of a scrip

=head2 Apply { TicketObj => undef, TransactionObj => undef}

This method instantiates the ScripCondition and ScripAction objects for a
single execution of this scrip. it then calls the IsApplicable method of the 
ScripCondition.
If that succeeds, it calls the Prepare method of the
ScripAction. If that succeeds, it calls the Commit method of the ScripAction.

Usually, the ticket and transaction objects passed to this method
should be loaded by the SuperUser role

=cut


# {{{ sub Apply

sub Apply {
    my $self = shift;
    my %args = ( TicketObj      => undef,
                 TransactionObj => undef,
                 @_ );

    # We want to make sure that if a scrip dies, we don't get
    # hurt
    eval {

        #Load the scrip's Condition object
        $self->ConditionObj->LoadCondition(
                                      ScripObj       => $self,
                                      TicketObj      => $args{'TicketObj'},
                                      TransactionObj => $args{'TransactionObj'},
        );

        unless ( $self->IsApplicable() ) {
            $self->ConditionObj->DESTROY;
            return (undef);
        }

        #If it's applicable, prepare and commit it
        $self->ActionObj->LoadAction( ScripObj       => $self,
                                      TicketObj      => $args{'TicketObj'},
                                      TransactionObj => $args{'TransactionObj'},
        );

        unless ( $self->Prepare() ) {
            $RT::Logger->info(
                          "$self: Couldn't prepare " . $self->ActionObj->Name );
            $self->ActionObj->DESTROY();
            $self->ConditionObj->DESTROY();
            return (undef);
        }
        unless ( $self->Commit() ) {
            $RT::Logger->info(
                           "$self: Couldn't commit " . $self->ActionObj->Name );
            $self->ActionObj->DESTROY();
            $self->ConditionObj->DESTROY();
            return (undef);
        }

        #Searchbuilder caching isn't perfectly coherent. got to reload the ticket object, since it
        # may have changed
        $args{'TicketObj'}->Load($args{'TicketObj'}->Id);

        #We're done with it. lets clean up.
        #TODO: something else isn't letting these get garbage collected. check em out.
        $self->ActionObj->DESTROY();
        $self->ConditionObj->DESTROY();
        return (1);
    };
    if ($@) {
        $RT::Logger->error( "Scrip " . $self->Id . " died. - " . $@ );
    }

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
	return (0, $self->loc('Permission Denied'));
    }
    return $self->__Set(@_);
}

# }}}

# {{{ sub _Value
# does an acl check and then passes off the call
sub _Value {
    my $self = shift;
    
    unless ($self->CurrentUserHasRight('ShowScrips')) {
        $RT::Logger->debug("CurrentUser can't modify Scrips for ".$self->__Value('Queue')."\n");
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
        return ( $args{'Principal'}->HasRight(
						   Right => $args{'Right'},
						   Object => $self->QueueObj
						  ) 
	       );
	
    }
    else {
        return( $args{'Principal'}->HasRight( Object => $RT::System, Right =>  $args{'Right'}) );
    }
}
# }}}

# }}}

1;


