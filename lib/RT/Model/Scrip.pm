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

    column queue          => type is 'int';
    column template       => type is 'int';
    column scrip_action    => type is 'int';
    column scrip_condition => type is 'int';
    column stage => type is 'varchar(32)', default is 'TransactionCreate';
    column description            => type is 'text';
    column custom_prepare_code      => type is 'text';
    column custom_commit_code       => type is 'text';
    column custom_is_applicable_code => type is 'text';
};

# {{{ sub create

=head2 Create

Creates a new entry in the Scrips table. Takes a paramhash with:

        queue                  => 0,
        description            => undef,
        template               => undef,
        scrip_action            => undef,
        scrip_condition         => undef,
        custom_prepare_code      => undef,
        custom_commit_code       => undef,
        custom_is_applicable_code => undef,




Returns (retval, msg);
retval is 0 for failure or scrip id.  msg is a textual description of what happened.

=cut

sub create {
    my $self = shift;
    my %args = (
        queue                  => 0,
        template               => 0,                     # name or id
        scrip_action            => 0,                     # name or id
        scrip_condition         => 0,                     # name or id
        stage                  => 'TransactionCreate',
        description            => undef,
        custom_prepare_code      => undef,
        custom_commit_code       => undef,
        custom_is_applicable_code => undef,
        @_
    );

    unless ( $args{'queue'} ) {
        unless (
            $self->current_user->has_right(
                Object => RT->system,
                Right  => 'ModifyScrips'
            )
            )
        {
            return ( 0, _('Permission Denied') );
        }
        $args{'queue'} = 0;    # avoid undef sneaking in
    } else {
        my $queue_obj = RT::Model::Queue->new;
        $queue_obj->load( $args{'queue'} );
        unless ( $queue_obj->id ) {
            return ( 0, _('Invalid queue') );
        }
        unless ( $queue_obj->current_user_has_right('ModifyScrips') ) {
            return ( 0, _('Permission Denied') );
        }
        $args{'queue'} = $queue_obj->id;
    }

    #TODO +++ validate input

    require RT::Model::ScripAction;
    return ( 0, _("Action is mandatory argument") )
        unless $args{'scrip_action'};
    my $action = RT::Model::ScripAction->new;
    $action->load( $args{'scrip_action'} );
    return ( 0, _( "Action '%1' not found", $args{'scrip_action'} ) )
        unless $action->id;

    require RT::Model::Template;
    return ( 0, _("template is mandatory argument") )
        unless $args{'template'};
    my $template = RT::Model::Template->new;
    $template->load( $args{'template'} );
    return ( 0, _( "Template '%1' not found", $args{'template'} ) )
        unless $template->id;

    require RT::Model::ScripCondition;
    return ( 0, _("Condition is mandatory argument") )
        unless $args{'scrip_condition'};
    my $condition = RT::Model::ScripCondition->new;
    $condition->load( $args{'scrip_condition'} );
    return ( 0, _( "Condition '%1' not found", $args{'scrip_condition'} ) )
        unless $condition->id;

    my ( $id, $msg ) = $self->SUPER::create(
        queue                  => $args{'queue'},
        template               => $template->id,
        scrip_condition         => $condition->id,
        stage                  => $args{'stage'},
        scrip_action            => $action->id,
        description            => $args{'description'},
        custom_prepare_code      => $args{'custom_prepare_code'},
        custom_commit_code       => $args{'custom_commit_code'},
        custom_is_applicable_code => $args{'custom_is_applicable_code'},
    );

    if ($id) {
        return ( $id, _('Scrip Created') );
    } else {
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

# {{{ sub queue_obj

=head2 queue_obj

Retuns an RT::Model::Queue object with this Scrip\'s queue

=cut

sub queue_obj {
    my $self = shift;

    if ( !$self->{'queue_obj'} ) {
        require RT::Model::Queue;
        $self->{'queue_obj'} = RT::Model::Queue->new;
        $self->{'queue_obj'}->load( $self->__value('queue') );
    }
    return ( $self->{'queue_obj'} );
}

# }}}

# {{{ sub action_obj

=head2 action_obj

Retuns an RT::ScripAction object with this Scrip\'s Action

=cut

sub action_obj {
    my $self = shift;

    unless ( defined $self->{'ScripActionObj'} ) {
        require RT::Model::ScripAction;

        $self->{'ScripActionObj'} = RT::Model::ScripAction->new;

        #TODO: why are we loading Actions with templates like this.
        # two separate methods might make more sense
        $self->{'ScripActionObj'}
            ->load( $self->scrip_action, $self->template );
    }
    return ( $self->{'ScripActionObj'} );
}

# }}}

# {{{ sub condition_obj

=head2 condition_obj

Retuns an L<RT::Model::ScripCondition> object with this Scrip's is_applicable

=cut

sub condition_obj {
    my $self = shift;

    my $res = RT::Model::ScripCondition->new;
    $res->load( $self->scrip_condition );
    return $res;
}

# }}}

# {{{ sub template_obj

=head2 template_obj

Retuns an L<RT::Model::Template> object with this Scrip\'s template

=cut

sub template_obj {
    my $self = shift;

    unless ( defined $self->{'template_obj'} ) {
        require RT::Model::Template;
        $self->{'template_obj'} = RT::Model::Template->new;
        $self->{'template_obj'}->load( $self->template );
    }
    return ( $self->{'template_obj'} );
}

# }}}

# {{{ Dealing with this instance of a scrip

# {{{ sub Apply

=head2 Apply { ticket_obj => undef, transaction_obj => undef}

This method instantiates the ScripCondition and ScripAction objects for a
single execution of this scrip. it then calls the is_applicable method of the 
ScripCondition.
If that succeeds, it calls the prepare method of the
ScripAction. If that succeeds, it calls the Commit method of the ScripAction.

Usually, the ticket and transaction objects passed to this method
should be loaded by the SuperUser role

=cut

# XXX TODO : This code appears to be obsoleted in favor of similar code in Scrips->apply.
# Why is this here? Is it still called?

sub apply {
    my $self = shift;
    my %args = (
        ticket_obj      => undef,
        transaction_obj => undef,
        @_
    );

    Jifty->log->debug( "Now applying scrip "
            . $self->id
            . " for transaction "
            . $args{'transaction_obj'}->id );

    my $Applicabletransaction_obj = $self->is_applicable(
        ticket_obj      => $args{'ticket_obj'},
        transaction_obj => $args{'transaction_obj'}
    );
    unless ($Applicabletransaction_obj) {
        return undef;
    }

    if ( $Applicabletransaction_obj->id != $args{'transaction_obj'}->id ) {
        Jifty->log->debug( "Found an applicable transaction "
                . $Applicabletransaction_obj->id
                . " in the same batch with transaction "
                . $args{'transaction_obj'}->id );
    }

    #If it's applicable, prepare and commit it
    Jifty->log->debug( "Now preparing scrip "
            . $self->id
            . " for transaction "
            . $Applicabletransaction_obj->id );
    unless (
        $self->prepare(
            ticket_obj      => $args{'ticket_obj'},
            transaction_obj => $Applicabletransaction_obj
        )
        )
    {
        return undef;
    }

    Jifty->log->debug( "Now commiting scrip "
            . $self->id
            . " for transaction "
            . $Applicabletransaction_obj->id );
    unless (
        $self->commit(
            ticket_obj      => $args{'ticket_obj'},
            transaction_obj => $Applicabletransaction_obj
        )
        )
    {
        return undef;
    }

    Jifty->log->debug( "We actually finished scrip "
            . $self->id
            . " for transaction "
            . $Applicabletransaction_obj->id );
    return (1);

}

# }}}

# {{{ sub is_applicable

=head2 is_applicable

Calls the  Condition object\'s is_applicable method

Upon success, returns the applicable Transaction object.
Otherwise, undef is returned.

If the Scrip is in the TransactionCreate stage (the usual case), only test
the associated Transaction object to see if it is applicable.

For Scrips in the transaction_batch stage, test all Transaction objects
Created during the Ticket object's lifetime, and returns the first one
that is applicable.

=cut

sub is_applicable {
    my $self = shift;
    my %args = (
        ticket_obj      => undef,
        transaction_obj => undef,
        @_
    );

    my $return;
    eval {

        my @Transactions;

        if ( $self->stage eq 'TransactionCreate' ) {

            # Only look at our current Transaction
            @Transactions = ( $args{'transaction_obj'} );
        } elsif ( $self->stage eq 'transaction_batch' ) {

            # Look at all Transactions in this Batch
            @Transactions = @{ $args{'ticket_obj'}->transaction_batch || [] };
        } else {
            Jifty->log->error( "Unknown Scrip stage:" . $self->stage );
            return (undef);
        }
        my $ConditionObj = $self->condition_obj;
        foreach my $transaction_obj (@Transactions) {

  # in TxnBatch stage we can select scrips that are not applicable to all txns
            my $txn_type = $transaction_obj->type;
            next
                unless ( $ConditionObj->applicable_trans_types
                =~ /(?:^|,)(?:Any|\Q$txn_type\E)(?:,|$)/i );

            # Load the scrip's Condition object
            $ConditionObj->load_condition(
                scrip_obj       => $self,
                ticket_obj      => $args{'ticket_obj'},
                transaction_obj => $transaction_obj,
            );

            if ( $ConditionObj->is_applicable() ) {

                # We found an application Transaction -- return it
                $return = $transaction_obj;
                last;
            }
        }
    };

    if ($@) {
        Jifty->log->error(
            "Scrip is_applicable " . $self->id . " died. - " . $@ );
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
    my %args = (
        ticket_obj      => undef,
        transaction_obj => undef,
        @_
    );

    my $return;
    eval {
        $self->action_obj->load_action(
            scrip_obj       => $self,
            ticket_obj      => $args{'ticket_obj'},
            transaction_obj => $args{'transaction_obj'},
        );
        $return = $self->action_obj->prepare();
    };
    if ( my $err = $@ ) {
        Jifty->log->error( "Scrip prepare "
                . $self->id
                . " died. - "
                . $err . " "
                . $self->action_obj->exec_module );
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
    my %args = (
        ticket_obj      => undef,
        transaction_obj => undef,
        @_
    );

    my $return;
    eval { $return = $self->action_obj->commit(); };

#Searchbuilder caching isn't perfectly coherent. got to reload the ticket object, since it
# may have changed

    if ($@) {
        Jifty->log->error( "Scrip Commit " . $self->id . " died. - " . $@ );
        return (undef);
    }

    $args{'ticket_obj'}->load( $args{'ticket_obj'}->id );
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
            "CurrentUser can't modify Scrips for " . $self->queue . "\n" );
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
                . $self->__value('queue')
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
    return (
        $self->has_right(
            Principal => $self->current_user->user_object,
            Right     => $right
        )
    );

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
    my %args = (
        Right     => undef,
        Principal => undef,
        @_
    );

    if ( $self->SUPER::_value('queue') ) {
        return $args{'Principal'}->has_right(
            Right  => $args{'Right'},
            Object => $self->queue_obj
        );
    } else {
        return $args{'Principal'}->has_right(
            Object => RT->system,
            Right  => $args{'Right'},
        );
    }
}

# }}}

# }}}

1;

