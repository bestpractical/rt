# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC 
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
# http://www.gnu.org/copyleft/gpl.html.
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
=head1 name

  RT::Model::Scrip - an RT Scrip object

=head1 SYNOPSIS

  use RT::Model::Scrip;

=head1 DESCRIPTION


=head1 METHODS


=cut


package RT::Model::Scrip;

use strict;
no warnings qw(redefine);


use base qw'RT::Record';
sub table {'Scrips'}
use Jifty::DBI::Schema;
use Jifty::DBI::Record schema {

        column Queue      => type is 'int';
        column Template => type is 'int';
        column ScripAction => type is 'int';
       column  ScripCondition         => type is 'int';
       column  Stage                  => type is 'varchar(32)', default is 'TransactionCreate';
     column   Description            => type is 'text';
    column     CustomPrepareCode      => type is 'text';
   column     CustomCommitCode       => type is 'text';
   column     CustomIsApplicableCode =>  type is 'text';
    };



# {{{ sub create

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

sub create {
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
        unless ( $self->current_user->has_right( Object => RT->system,
                                               Right  => 'ModifyScrips' ) )
        {
            return ( 0, _('Permission Denied') );
        }
        $args{'Queue'} = 0;    # avoid undef sneaking in
    }
    else {
        my $QueueObj = RT::Model::Queue->new;
        $QueueObj->load( $args{'Queue'} );
        unless ( $QueueObj->id ) {
            return ( 0, _('Invalid queue') );
        }
        unless ( $QueueObj->current_user_has_right('ModifyScrips') ) {
            return ( 0, _('Permission Denied') );
        }
        $args{'Queue'} = $QueueObj->id;
    }

    #TODO +++ validate input

    require RT::Model::ScripAction;
    return ( 0, _("Action is mandatory argument") )
        unless $args{'ScripAction'};
    my $action = RT::Model::ScripAction->new;
    $action->load( $args{'ScripAction'} );
    return ( 0, _( "Action '%1' not found", $args{'ScripAction'} ) ) 
        unless $action->id;

    require RT::Model::Template;
    return ( 0, _("Template is mandatory argument") )
        unless $args{'Template'};
    my $template = RT::Model::Template->new;
    $template->load( $args{'Template'} );
    return ( 0, _( "Template '%1' not found", $args{'Template'} ) )
        unless $template->id;

    require RT::Model::ScripCondition;
    return ( 0, _("Condition is mandatory argument") )
        unless $args{'ScripCondition'};
    my $condition = RT::Model::ScripCondition->new;
    $condition->load( $args{'ScripCondition'} );
    return ( 0, _( "Condition '%1' not found", $args{'ScripCondition'} ) )
        unless $condition->id;

    my ( $id, $msg ) = $self->SUPER::create(
        Queue                  => $args{'Queue'},
        Template               => $template->id,
        ScripCondition         => $condition->id,
        Stage                  => $args{'Stage'},
        ScripAction            => $action->id,
        Description            => $args{'Description'},
        CustomPrepareCode      => $args{'CustomPrepareCode'},
        CustomCommitCode       => $args{'CustomCommitCode'},
        CustomIsApplicableCode => $args{'CustomIsApplicableCode'},
    );
    if ( $id ) {
        return ( $id, _('Scrip Created') );
    }
    else {
        return ( $id, $msg );
    }
}

# }}}

# {{{ sub delete

=head2 Delete

Delete this object

=cut

sub delete {
    my $self = shift;

    unless ( $self->current_user_has_right('ModifyScrips') ) {
        return ( 0, _('Permission Denied') );
    }

    return ( $self->SUPER::delete(@_) );
}

# }}}

# {{{ sub QueueObj

=head2 QueueObj

Retuns an RT::Model::Queue object with this Scrip\'s queue

=cut

sub QueueObj {
    my $self = shift;

    if ( !$self->{'QueueObj'} ) {
        require RT::Model::Queue;
        $self->{'QueueObj'} = RT::Model::Queue->new;
        $self->{'QueueObj'}->load( $self->__value('Queue') );
    }
    return ( $self->{'QueueObj'} );
}

# }}}

# {{{ sub ActionObj

=head2 ActionObj

Retuns an RT::ScripAction object with this Scrip\'s Action

=cut

sub ActionObj {
    my $self = shift;

    unless ( defined $self->{'ScripActionObj'} ) {
        require RT::Model::ScripAction;

        $self->{'ScripActionObj'} = RT::Model::ScripAction->new;

        #TODO: why are we loading Actions with templates like this.
        # two separate methods might make more sense
        $self->{'ScripActionObj'}->load( $self->ScripAction, $self->Template );
    }
    return ( $self->{'ScripActionObj'} );
}

# }}}

# {{{ sub ConditionObj

=head2 ConditionObj

Retuns an L<RT::Model::ScripCondition> object with this Scrip's IsApplicable

=cut

sub ConditionObj {
    my $self = shift;

    my $res = RT::Model::ScripCondition->new;
    $res->load( $self->ScripCondition );
    return $res;
}

# }}}

# {{{ sub TemplateObj

=head2 TemplateObj

Retuns an RT::Model::Template object with this Scrip\'s Template

=cut

sub TemplateObj {
    my $self = shift;

    unless ( defined $self->{'TemplateObj'} ) {
        require RT::Model::Template;
        $self->{'TemplateObj'} = RT::Model::Template->new;
        $self->{'TemplateObj'}->load( $self->Template );
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
If that succeeds, it calls the prepare method of the
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

    Jifty->log->debug("Now applying scrip ".$self->id . " for transaction ".$args{'TransactionObj'}->id);

    my $ApplicableTransactionObj = $self->IsApplicable( TicketObj      => $args{'TicketObj'},
                                                        TransactionObj => $args{'TransactionObj'} );
    unless ( $ApplicableTransactionObj ) {
        return undef;
    }

    if ( $ApplicableTransactionObj->id != $args{'TransactionObj'}->id ) {
        Jifty->log->debug("Found an applicable transaction ".$ApplicableTransactionObj->id . " in the same batch with transaction ".$args{'TransactionObj'}->id);
    }

    #If it's applicable, prepare and commit it
    Jifty->log->debug("Now preparing scrip ".$self->id . " for transaction ".$ApplicableTransactionObj->id);
    unless ( $self->prepare( TicketObj      => $args{'TicketObj'},
                             TransactionObj => $ApplicableTransactionObj )
      ) {
        return undef;
    }

    Jifty->log->debug("Now commiting scrip ".$self->id . " for transaction ".$ApplicableTransactionObj->id);
    unless ( $self->commit( TicketObj => $args{'TicketObj'},
                            TransactionObj => $ApplicableTransactionObj)
      ) {
        return undef;
    }

    Jifty->log->debug("We actually finished scrip ".$self->id . " for transaction ".$ApplicableTransactionObj->id);
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
Created during the Ticket object's lifetime, and returns the first one
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
	    Jifty->log->error( "Unknown Scrip stage:" . $self->Stage );
	    return (undef);
	}
	my $ConditionObj = $self->ConditionObj;
	foreach my $TransactionObj ( @Transactions ) {
	    # in TxnBatch stage we can select scrips that are not applicable to all txns
	    my $txn_type = $TransactionObj->Type;
	    next unless( $ConditionObj->ApplicableTransTypes =~ /(?:^|,)(?:Any|\Q$txn_type\E)(?:,|$)/i );
	    # Load the scrip's Condition object
	    $ConditionObj->loadCondition(
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
        die( "Scrip IsApplicable " . $self->id . " died. - " . $@ );
        Jifty->log->error( "Scrip IsApplicable " . $self->id . " died. - " . $@ );
        return (undef);
    }

            return ($return);

}

# }}}


=head2 prepare

Calls the action object's prepare method

=cut

sub prepare {
    my $self = shift;
    my %args = ( TicketObj      => undef,
                 TransactionObj => undef,
                 @_ );

    my $return;
    eval {
        $self->ActionObj->loadAction( ScripObj       => $self,
                                      TicketObj      => $args{'TicketObj'},
                                      TransactionObj => $args{'TransactionObj'},
        );
        $return = $self->ActionObj->prepare();
    };
    if (my $err = $@) {
        Jifty->log->error( "Scrip prepare " . $self->id . " died. - " . $err ." ".$self->ActionObj->ExecModule);
        return (undef);
    }
        return ($return);
}

# }}}

# {{{ sub commit

=head2 commit

Calls the action object's commit method

=cut

sub commit {
    my $self = shift;
    my %args = ( TicketObj      => undef,
                 TransactionObj => undef,
                 @_ );

    my $return;
    eval {
        $return = $self->ActionObj->commit();
    };

#Searchbuilder caching isn't perfectly coherent. got to reload the ticket object, since it
# may have changed
    $args{'TicketObj'}->load( $args{'TicketObj'}->id );

    if ($@) {
        Jifty->log->error( "Scrip Commit " . $self->id . " died. - " . $@ );
        return (undef);
    }

    # Not destroying or weakening hte Action and Condition here could cause a
    # leak

    return ($return);
}

# }}}

# }}}

# {{{ ACL related methods

# {{{ sub _set

# does an acl check and then passes off the call
sub _set {
    my $self = shift;

    unless ( $self->current_user_has_right('ModifyScrips') ) {
        Jifty->log->debug(
                 "CurrentUser can't modify Scrips for " . $self->Queue . "\n" );
        return ( 0, _('Permission Denied') );
    }
    return $self->__set(@_);
}

# }}}

# {{{ sub _value
# does an acl check and then passes off the call
sub _value {
    my $self = shift;

    unless ( $self->current_user_has_right('ShowScrips') ) {
        Jifty->log->debug( "CurrentUser can't modify Scrips for "
                            . $self->__value('Queue')
                            . "\n" );
        return (undef);
    }

    return $self->__value(@_);
}

# }}}

# {{{ sub current_user_has_right

=head2 current_user_has_right

Helper menthod for has_right. Presets Principal to CurrentUser then 
calls has_right.

=cut

sub current_user_has_right {
    my $self  = shift;
    my $right = shift;
    return ( $self->has_right( Principal => $self->current_user->user_object,
                              Right     => $right ) );

}

# }}}

# {{{ sub has_right

=head2 has_right

Takes a param-hash consisting of "Right" and "Principal"  Principal is 
an RT::Model::User object or an RT::CurrentUser object. "Right" is a textual
Right string that applies to Scrips.

=cut

sub has_right {
    my $self = shift;
    my %args = ( Right     => undef,
                 Principal => undef,
                 @_ );

    if ( $self->SUPER::_value('Queue') ) {
        return $args{'Principal'}->has_right(
            Right  => $args{'Right'},
            Object => $self->QueueObj
        );
    }
    else {
        return $args{'Principal'}->has_right(
            Object => RT->system,
            Right  => $args{'Right'},
        );
    }
}

# }}}

# }}}

1;

