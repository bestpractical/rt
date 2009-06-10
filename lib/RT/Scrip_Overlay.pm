# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2009 Best Practical Solutions, LLC 
#                                          <jesse@bestpractical.com>
# 
# (Except where explicitly superseded by other copyright notices)
# 
# 
# LICENSE:
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
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
# 
# 
# CONTRIBUTION SUBMISSION POLICY:
# 
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
# 
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
# 
# END BPS TAGGED BLOCK }}}
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


package RT::Scrip;

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
        Template               => 0,                     # name or id
        ScripAction            => 0,                     # name or id
        ScripCondition         => 0,                     # name or id
        Stage                  => 'TransactionCreate',
        Description            => undef,
        CustomPrepareCode      => undef,
        CustomCommitCode       => undef,
        CustomIsApplicableCode => undef,
        @_
    );

    unless ( $args{'Queue'} ) {
        unless ( $self->CurrentUser->HasRight( Object => $RT::System,
                                               Right  => 'ModifyScrips' )
          ) {
            return ( 0, $self->loc('Permission Denied') );
        }
        $args{'Queue'} = 0;    # avoid undef sneaking in
    }
    else {
        my $QueueObj = RT::Queue->new( $self->CurrentUser );
        $QueueObj->Load( $args{'Queue'} );
        unless ( $QueueObj->id ) {
            return ( 0, $self->loc('Invalid queue') );
        }
        unless ( $QueueObj->CurrentUserHasRight('ModifyScrips') ) {
            return ( 0, $self->loc('Permission Denied') );
        }
        $args{'Queue'} = $QueueObj->id();
    }

    #TODO +++ validate input

    require RT::ScripAction;
    return ( 0, $self->loc("Action is mandatory argument") )
        unless $args{'ScripAction'};
    my $action = RT::ScripAction->new( $self->CurrentUser );
    $action->Load( $args{'ScripAction'} );
    return ( 0, $self->loc( "Action [_1] not found", $args{'ScripAction'} ) )
        unless $action->Id;

    require RT::Template;
    return ( 0, $self->loc("Template is mandatory argument") )
        unless $args{'Template'};
    my $template = RT::Template->new( $self->CurrentUser );
    $template->Load( $args{'Template'} );
    return ( 0, $self->loc('Template not found') )
        unless $template->Id;

    require RT::ScripCondition;
    return ( 0, $self->loc("Condition is mandatory argument") )
        unless $args{'ScripCondition'};
    my $condition = RT::ScripCondition->new( $self->CurrentUser );
    $condition->Load( $args{'ScripCondition'} );
    return ( 0, $self->loc('Condition not found') )
        unless $condition->Id;

    my ( $id, $msg ) = $self->SUPER::Create(
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
    if ( $id ) {
        return ( $id, $self->loc('Scrip Created') );
    }
    else {
        return ( $id, $msg );
    }
}

# }}}

# {{{ sub Delete

=head2 Delete

Delete this object

=cut

sub Delete {
    my $self = shift;

    unless ( $self->CurrentUserHasRight('ModifyScrips') ) {
        return ( 0, $self->loc('Permission Denied') );
    }

    return ( $self->SUPER::Delete(@_) );
}

# }}}

# {{{ sub QueueObj

=head2 QueueObj

Retuns an RT::Queue object with this Scrip\'s queue

=cut

sub QueueObj {
    my $self = shift;

    if ( !$self->{'QueueObj'} ) {
        require RT::Queue;
        $self->{'QueueObj'} = RT::Queue->new( $self->CurrentUser );
        $self->{'QueueObj'}->Load( $self->__Value('Queue') );
    }
    return ( $self->{'QueueObj'} );
}

# }}}

# {{{ sub ActionObj

=head2 ActionObj

Retuns an RT::Action object with this Scrip\'s Action

=cut

sub ActionObj {
    my $self = shift;

    unless ( defined $self->{'ScripActionObj'} ) {
        require RT::ScripAction;

        $self->{'ScripActionObj'} = RT::ScripAction->new( $self->CurrentUser );

        #TODO: why are we loading Actions with templates like this.
        # two separate methods might make more sense
        $self->{'ScripActionObj'}->Load( $self->ScripAction, $self->Template );
    }
    return ( $self->{'ScripActionObj'} );
}

# }}}

# {{{ sub ConditionObj

=head2 ConditionObj

Retuns an RT::ScripCondition object with this Scrip's IsApplicable

=cut

sub ConditionObj {
    my $self = shift;

    unless ( defined $self->{'ScripConditionObj'} ) {
        require RT::ScripCondition;
        $self->{'ScripConditionObj'} =
          RT::ScripCondition->new( $self->CurrentUser );
        if ( $self->ScripCondition ) {
            $self->{'ScripConditionObj'}->Load( $self->ScripCondition );
        }
    }
    return ( $self->{'ScripConditionObj'} );
}

# }}}

# {{{ sub TemplateObj

=head2 TemplateObj

Retuns an RT::Template object with this Scrip\'s Template

=cut

sub TemplateObj {
    my $self = shift;

    unless ( defined $self->{'TemplateObj'} ) {
        require RT::Template;
        $self->{'TemplateObj'} = RT::Template->new( $self->CurrentUser );
        $self->{'TemplateObj'}->Load( $self->Template );
    }
    return ( $self->{'TemplateObj'} );
}

# }}}

# {{{ Dealing with this instance of a scrip

# {{{ sub Apply

=head2 Apply { TicketObj => undef, TransactionObj => undef}

This method instantiates the ScripCondition and ScripAction objects for a
single execution of this scrip. it then calls the IsApplicable method of the 
ScripCondition.
If that succeeds, it calls the Prepare method of the
ScripAction. If that succeeds, it calls the Commit method of the ScripAction.

Usually, the ticket and transaction objects passed to this method
should be loaded by the SuperUser role

=cut


# XXX TODO : This code appears to be obsoleted in favor of similar code in Scrips->Apply.
# Why is this here? Is it still called?

sub Apply {
    my $self = shift;
    my %args = ( TicketObj      => undef,
                 TransactionObj => undef,
                 @_ );

    $RT::Logger->debug("Now applying scrip ".$self->Id . " for transaction ".$args{'TransactionObj'}->id);

    my $ApplicableTransactionObj = $self->IsApplicable( TicketObj      => $args{'TicketObj'},
                                                        TransactionObj => $args{'TransactionObj'} );
    unless ( $ApplicableTransactionObj ) {
        return undef;
    }

    if ( $ApplicableTransactionObj->id != $args{'TransactionObj'}->id ) {
        $RT::Logger->debug("Found an applicable transaction ".$ApplicableTransactionObj->Id . " in the same batch with transaction ".$args{'TransactionObj'}->id);
    }

    #If it's applicable, prepare and commit it
    $RT::Logger->debug("Now preparing scrip ".$self->Id . " for transaction ".$ApplicableTransactionObj->id);
    unless ( $self->Prepare( TicketObj      => $args{'TicketObj'},
                             TransactionObj => $ApplicableTransactionObj )
      ) {
        return undef;
    }

    $RT::Logger->debug("Now commiting scrip ".$self->Id . " for transaction ".$ApplicableTransactionObj->id);
    unless ( $self->Commit( TicketObj => $args{'TicketObj'},
                            TransactionObj => $ApplicableTransactionObj)
      ) {
        return undef;
    }

    $RT::Logger->debug("We actually finished scrip ".$self->Id . " for transaction ".$ApplicableTransactionObj->id);
    return (1);

}

# }}}

# {{{ sub IsApplicable

=head2 IsApplicable

Calls the  Condition object\'s IsApplicable method

Upon success, returns the applicable Transaction object.
Otherwise, undef is returned.

If the Scrip is in the TransactionCreate Stage (the usual case), only test
the associated Transaction object to see if it is applicable.

For Scrips in the TransactionBatch Stage, test all Transaction objects
created during the Ticket object's lifetime, and returns the first one
that is applicable.

=cut

sub IsApplicable {
    my $self = shift;
    my %args = ( TicketObj      => undef,
                 TransactionObj => undef,
                 @_ );

    my $return;
    eval {

	my @Transactions;

        if ( $self->Stage eq 'TransactionCreate') {
	    # Only look at our current Transaction
	    @Transactions = ( $args{'TransactionObj'} );
        }
        elsif ( $self->Stage eq 'TransactionBatch') {
	    # Look at all Transactions in this Batch
            @Transactions = @{ $args{'TicketObj'}->TransactionBatch || [] };
        }
	else {
	    $RT::Logger->error( "Unknown Scrip stage:" . $self->Stage );
	    return (undef);
	}
	my $ConditionObj = $self->ConditionObj;
	foreach my $TransactionObj ( @Transactions ) {
	    # in TxnBatch stage we can select scrips that are not applicable to all txns
	    my $txn_type = $TransactionObj->Type;
	    next unless( $ConditionObj->ApplicableTransTypes =~ /(?:^|,)(?:Any|\Q$txn_type\E)(?:,|$)/i );
	    # Load the scrip's Condition object
	    $ConditionObj->LoadCondition(
		ScripObj       => $self,
		TicketObj      => $args{'TicketObj'},
		TransactionObj => $TransactionObj,
	    );

            if ( $ConditionObj->IsApplicable() ) {
	        # We found an application Transaction -- return it
                $return = $TransactionObj;
                last;
            }
	}
    };
    if ($@) {
        $RT::Logger->error( "Scrip IsApplicable " . $self->Id . " died. - " . $@ );
        return (undef);
    }

            return ($return);

}

# }}}

# {{{ SUb Prepare

=head2 Prepare

Calls the action object's prepare method

=cut

sub Prepare {
    my $self = shift;
    my %args = ( TicketObj      => undef,
                 TransactionObj => undef,
                 @_ );

    my $return;
    eval {
        $self->ActionObj->LoadAction( ScripObj       => $self,
                                      TicketObj      => $args{'TicketObj'},
                                      TransactionObj => $args{'TransactionObj'},
        );

        $return = $self->ActionObj->Prepare();
    };
    if ($@) {
        $RT::Logger->error( "Scrip Prepare " . $self->Id . " died. - " . $@ );
        return (undef);
    }
        unless ($return) {
        }
        return ($return);
}

# }}}

# {{{ sub Commit

=head2 Commit

Calls the action object's commit method

=cut

sub Commit {
    my $self = shift;
    my %args = ( TicketObj      => undef,
                 TransactionObj => undef,
                 @_ );

    my $return;
    eval {
        $return = $self->ActionObj->Commit();
    };

#Searchbuilder caching isn't perfectly coherent. got to reload the ticket object, since it
# may have changed
    $args{'TicketObj'}->Load( $args{'TicketObj'}->Id );

    if ($@) {
        $RT::Logger->error( "Scrip Commit " . $self->Id . " died. - " . $@ );
        return (undef);
    }

    # Not destroying or weakening hte Action and Condition here could cause a
    # leak

    return ($return);
}

# }}}

# }}}

# {{{ ACL related methods

# {{{ sub _Set

# does an acl check and then passes off the call
sub _Set {
    my $self = shift;

    unless ( $self->CurrentUserHasRight('ModifyScrips') ) {
        $RT::Logger->debug(
                 "CurrentUser can't modify Scrips for " . $self->Queue . "\n" );
        return ( 0, $self->loc('Permission Denied') );
    }
    return $self->__Set(@_);
}

# }}}

# {{{ sub _Value
# does an acl check and then passes off the call
sub _Value {
    my $self = shift;

    unless ( $self->CurrentUserHasRight('ShowScrips') ) {
        $RT::Logger->debug( "CurrentUser can't modify Scrips for "
                            . $self->__Value('Queue')
                            . "\n" );
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
    my $self  = shift;
    my $right = shift;
    return ( $self->HasRight( Principal => $self->CurrentUser->UserObj,
                              Right     => $right ) );

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
    my %args = ( Right     => undef,
                 Principal => undef,
                 @_ );

    if ( $self->SUPER::_Value('Queue') ) {
        return $args{'Principal'}->HasRight(
            Right  => $args{'Right'},
            Object => $self->QueueObj
        );
    }
    else {
        return $args{'Principal'}->HasRight(
            Object => $RT::System,
            Right  => $args{'Right'},
        );
    }
}

# }}}

# }}}

1;

