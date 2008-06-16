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

=head1 description


=head1 METHODS


=cut

package RT::Model::Scrip;

use strict;
no warnings qw(redefine);

use base qw'RT::Record';
sub table {'Scrips'}
use Jifty::DBI::Schema;
use Jifty::DBI::Record schema {

    column queue                     => references RT::Model::Queue;
    column template                  => references RT::Model::Template;
    column scrip_action              => references RT::Model::ScripAction;
    column scrip_condition           => references RT::Model::ScripCondition;
    column stage                     => type is 'varchar(32)', default is 'TransactionCreate';
    column description               => type is 'text';
    column custom_prepare_code       => type is 'text';
    column custom_commit_code        => type is 'text';
    column custom_is_applicable_code => type is 'text';
};

=head2 create

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
        queue                     => 0,
        template                  => 0,                     # name or id
        scrip_action              => 0,                     # name or id
        scrip_condition           => 0,                     # name or id
        stage                     => 'TransactionCreate',
        description               => undef,
        custom_prepare_code       => undef,
        custom_commit_code        => undef,
        custom_is_applicable_code => undef,
        @_
    );

    unless ( $args{'queue'} ) {
        unless (
            $self->current_user->has_right(
                object => RT->system,
                right  => 'ModifyScrips'
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
        queue                     => $args{'queue'},
        template                  => $template->id,
        scrip_condition           => $condition->id,
        stage                     => $args{'stage'},
        scrip_action              => $action->id,
        description               => $args{'description'},
        custom_prepare_code       => $args{'custom_prepare_code'},
        custom_commit_code        => $args{'custom_commit_code'},
        custom_is_applicable_code => $args{'custom_is_applicable_code'},
    );

    if ($id) {
        return ( $id, _('Scrip Created') );
    } else {
        return ( $id, $msg );
    }
}

sub scrip_action {
    my $self = shift;
    Jifty->log->debug( "loading scripaction " . $self->__value('scrip_action') );

    # jfity returns a new object each time you call the accessor. I'm not sure that's right, but it blows our behaviour
    unless ( $self->{'scrip_action'} ) {
        $self->{'scrip_action'} = RT::Model::ScripAction->new();
        $self->{'scrip_action'}->load( $self->_value('scrip_action'), $self->_value('template') );
    }
    return $self->{'scrip_action'};

}

=head2 delete

Delete this object

=cut

sub delete {
    my $self = shift;

    unless ( $self->current_user_has_right('ModifyScrips') ) {
        return ( 0, _('Permission Denied') );
    }

    return ( $self->SUPER::delete(@_) );
}

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

=head2 template_obj

Retuns an L<RT::Model::Template> object with this Scrip\'s template

=cut

sub template_obj {
    my $self = shift;

    unless ( defined $self->{'template_obj'} ) {
        require RT::Model::Template;
        $self->{'template_obj'} = RT::Model::Template->new;
        $self->{'template_obj'}->load( $self->template->id );
    }
    return ( $self->{'template_obj'} );
}

=head2 apply { ticket_obj => undef, transaction_obj => undef}

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

    Jifty->log->debug( "Now applying scrip " . $self->id . " for transaction " . $args{'transaction_obj'}->id );
    my $applicable_trans = $self->is_applicable(
        ticket_obj      => $args{'ticket_obj'},
        transaction_obj => $args{'transaction_obj'}
    );
    unless ($applicable_trans) {
        return undef;
    }

    if ( $applicable_trans->id != $args{'transaction_obj'}->id ) {
        Jifty->log->debug( "Found an applicable transaction " . $applicable_trans->id . " in the same batch with txn " . $args{'transaction_obj'}->id );
    }

    #If it's applicable, prepare and commit it
    Jifty->log->debug( "Now preparing scrip " . $self->id . " for transaction " . $applicable_trans->id );
    unless (
        $self->prepare(
            ticket_obj      => $args{'ticket_obj'},
            transaction_obj => $applicable_trans
        )
        )
    {
        return undef;
    }

    Jifty->log->debug( "Now commiting scrip " . $self->id . " for transaction " . $applicable_trans->id );
    unless (
        $self->commit(
            ticket_obj      => $args{'ticket_obj'},
            transaction_obj => $applicable_trans
        )
        )
    {
        return undef;
    }

    Jifty->log->debug( "We actually finished scrip " . $self->id . " for transaction " . $applicable_trans->id );
    return (1);

}

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

        Jifty->log->debug( "In the eval for stage " . $self->stage );
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
        foreach my $transaction_obj (@Transactions) {

            Jifty->log->debug("I found the transaction");

            # in TxnBatch stage we can select scrips that are not applicable to all txns
            my $txn_type = $transaction_obj->type;

            my $condition = $self->scrip_condition;

            next
                unless ( $condition->applicable_trans_types =~ /(?:^|,)(?:Any|\Q$txn_type\E)(?:,|$)/i );

            # Load the scrip's Condition object
            $condition->load_condition(
                scrip_obj       => $self,
                ticket_obj      => $args{'ticket_obj'},
                transaction_obj => $transaction_obj,
            );
            Jifty->log->debug("I loaded the condition");
            if ( $condition->is_applicable() ) {
                Jifty->log->debug("It's applicable");

                # We found an application Transaction -- return it
                $return = $transaction_obj;
                last;
            } else {
                Jifty->log->debug("It's not applicable");

            }
        }
    };

    if ( my $err = $@ ) {
        Jifty->log->error( "Scrip is_applicable " . $self->id . " died. - " . $err );
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
        $self->scrip_action->load_action(
            scrip_obj       => $self,
            ticket_obj      => $args{'ticket_obj'},
            transaction_obj => $args{'transaction_obj'},
        );
        $return = $self->scrip_action->prepare();
    };
    if ( my $err = $@ ) {
        Jifty->log->error( "Scrip prepare " . $self->id . " died. - " . $err . " " . $self->scrip_action->exec_module );
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
    eval { $return = $self->scrip_action->commit(); };

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

# does an acl check and then passes off the call
sub _set {
    my $self = shift;

    unless ( $self->current_user_has_right('ModifyScrips') ) {
        Jifty->log->debug( "CurrentUser can't modify Scrips for " . $self->queue . "\n" );
        return ( 0, _('Permission Denied') );
    }
    return $self->__set(@_);
}

# does an acl check and then passes off the call
sub _value {
    my $self = shift;

    unless ( $self->current_user_has_right('ShowScrips') ) {
        Jifty->log->debug( "CurrentUser can't modify Scrips for " . $self->__value('queue') . "\n" );
        return (undef);
    }

    return $self->__value(@_);
}

=head2 current_user_has_right

Helper menthod for has_right. Presets Principal to current_user then 
calls has_right.

=cut

sub current_user_has_right {
    my $self  = shift;
    my $right = shift;
    return (
        $self->has_right(
            principal => $self->current_user->user_object,
            right     => $right
        )
    );

}

=head2 has_right

Takes a param-hash consisting of "right" and "Principal"  Principal is 
an RT::Model::User object or an RT::CurrentUser object. "right" is a textual
right string that applies to Scrips.

=cut

sub has_right {
    my $self = shift;
    my %args = (
        right     => undef,
        principal => undef,
        @_
    );

    if ( $self->SUPER::_value('queue') ) {
        return $args{'principal'}->has_right(
            right  => $args{'right'},
            object => $self->queue_obj
        );
    } else {
        return $args{'principal'}->has_right(
            object => RT->system,
            right  => $args{'right'},
        );
    }
}

1;

