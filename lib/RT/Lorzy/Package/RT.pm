package RT::Lorzy::Package::RT;
use strict;
use base 'Lorzy::Package';

# TODO: make create_scripish resolve from this map and call the
# condtion function here without RT.Condition.Applicable

my %mymap = ( 'On Create' => 'OnCreate',
              'On Transaction' => 'OnTransaction',
              'On Correspond' => 'OnCorrespond',
              'On comment' => 'OnComment',
              'On Status Change' => 'OnStatusChange',
              'On owner Change' => 'OnOwnerChange',
              'On priority Change' => 'OnPriorityChange',
              'On Resolve' => 'OnResolve',
              'On Close' => 'OnClose',
              'On Reopen' => 'OnReopen',
          );

my $sig_ticket_txn = {
        'ticket' => Lorzy::FunctionArgument->new( name => 'ticket', type => 'RT::Model::Ticket' ),
        'transaction' => Lorzy::FunctionArgument->new( name => 'transaction', type => 'RT::Model::Transaction' ),
    };

__PACKAGE__->defun( 'Condition.OnTransaction',
    signature => $sig_ticket_txn,
    native => sub {
        return 1;
    },
);

__PACKAGE__->defun( 'Condition.OnOwnerChange',
    signature => $sig_ticket_txn,
    native => sub {
        my $args = shift;
        return ( $args->{transaction}->field || '' ) eq 'owner';
    },
);

__PACKAGE__->defun( 'Condition.OnQueueChange',
    signature => $sig_ticket_txn,
    native => sub {
        my $args = shift;
        return $args->{transaction}->type eq 'set'
            && ( $args->{transaction}->field || '' ) eq 'queue';
    },
);

__PACKAGE__->defun( 'Condition.OnPriorityChange',
    signature => $sig_ticket_txn,
    native => sub {
        my $args = shift;
        return $args->{transaction}->type eq 'set'
            && ( $args->{transaction}->field || '' ) eq 'priority';
    },
);

__PACKAGE__->defun( 'Condition.OnResolve',
    signature => $sig_ticket_txn,
    native => sub {
        my $args = shift;
        return $args->{transaction}->type eq 'status'
            && ( $args->{transaction}->field || '' ) eq 'status'
            && $args->{transaction}->new_value() eq 'resolved';
    },
);

__PACKAGE__->defun( 'Condition.OnClose',
    signature => $sig_ticket_txn,
    native => sub {
        my $args = shift;
        my $txn = $args->{transaction};
        return 0
            unless $txn->type eq "status"
                || ( $txn->type eq "set" && $txn->field eq "status" );

        my $queue = $args->{ticket}->queue;
        return 0 unless $queue->status_schema->is_active( $txn->old_value );
        return 0 unless $queue->status_schema->is_inactive( $txn->new_value );

        return 1;
    },
);

__PACKAGE__->defun( 'Condition.OnReopen',
    signature => $sig_ticket_txn,
    native => sub {
        my $args = shift;
        my $txn = $args->{transaction};
        return 0
            unless $txn->type eq "status"
                || ( $txn->type eq "set" && $txn->field eq "status" );

        my $queue = $args->{ticket}->queue;
        return 0 unless $queue->status_schema->is_inactive( $txn->old_value );
        return 0 unless $queue->status_schema->is_active( $txn->new_value );

        return 1;
    },
);

__PACKAGE__->defun( 'Condition.BeforeDue', # XXX: lambday required, doesn't work yet
    signature => $sig_ticket_txn,
    native => sub {
        my $args = shift;

        # Parse date string.  format is "1d2h3m4s" for 1 day and 2 hours
        # and 3 minutes and 4 seconds.
        my %e;
        foreach (qw(d h m s)) {
            my @vals = $args->{argument} =~ m/(\d+)$_/;
            $e{$_} = pop @vals || 0;
        }
        my $elapse = $e{'d'} * 24 * 60 * 60 + $e{'h'} * 60 * 60 + $e{'m'} * 60 + $e{'s'};

        my $cur = RT::DateTime->now;
        my $due = $args->{ticket}->due;
        return (undef) if $due->epoch <= 0;

        my $diff = $due->diff($cur);
        if ( $diff >= 0 and $diff <= $elapse ) {
            return (1);
        } else {
            return (undef);
        }

    },
);

__PACKAGE__->defun( 'Condition.PriorityExceeds', # XXX: lambday required, doesn't work yet
    signature => $sig_ticket_txn,
    native => sub {
        my $args = shift;
        return $args->{ticket}->priority > $args->{argument};
    },
);

__PACKAGE__->defun( 'Condition.Overdue',
    signature => $sig_ticket_txn,
    native => sub {
        my $args = shift;
        my $ticket = $args->{ticket};
        return $ticket->due->epoch > 0 && $ticket->due->epoch < time();
    },
);

my %simple_txn_cond = ( 'OnCreate' => 'create',
                        'OnCorrespond' => 'correspond',
                        'OnComment' => 'comment',
                        'OnStatusChange' => 'status',
                    );

for my $name ( keys %simple_txn_cond ) {
    __PACKAGE__->defun( "Condition.$name",
        signature => $sig_ticket_txn,
        native => sub {
            my $args = shift;
            return $args->{transaction}->type eq $simple_txn_cond{$name};
        },
    );
}

__PACKAGE__->defun( 'Condition.Applicable',
    signature => {
        'name'   => Lorzy::FunctionArgument->new( name => 'name' ),
        %$sig_ticket_txn,
    },
    native => sub {
        my $args = shift;
        my $eval = shift;

        my $lorzy_cond = $mymap{$args->{name}}
            or die "no compat mapping for scrip condition $args->{name}";
        $lorzy_cond = 'RT.Condition.'.$lorzy_cond;
        return $eval->resolve_symbol_name($lorzy_cond)->apply
            ( $eval,
              { transaction => $args->{transaction},
                ticket => $args->{ticket}
            });
    },
);

__PACKAGE__->defun( 'ScripAction.Prepare',
    signature => {
        'name'     => Lorzy::FunctionArgument->new( name => 'name' ),
        'context'  => Lorzy::FunctionArgument->new( name => 'context' ),
        'template' => Lorzy::FunctionArgument->new( name => 'template' ),
        %$sig_ticket_txn,
    },
    native => sub {
        my $args   = shift;
        my $rule = RT::Rule->new( current_user => $args->{ticket}->current_user,
                                  ticket_obj => $args->{ticket},
                                  transaction_obj => $args->{transaction}
                              );
        my $action = $rule->get_scrip_action(@{$args}{qw(name template)});
        $action->prepare or return;
        $args->{context}{hints} = $action->hints;
        $args->{context}{action} = $action;
    },
);

__PACKAGE__->defun( 'ScripAction.Run',
    signature => {
        'name'     => Lorzy::FunctionArgument->new( name => 'name' ),
        'context'  => Lorzy::FunctionArgument->new( name => 'context' ),
        'template' => Lorzy::FunctionArgument->new( name => 'template' ),
        %$sig_ticket_txn,
    },
    native => sub {
        my $args   = shift;
        my $action = $args->{context}{action};
        unless ($action) {
            my $rule = RT::Rule->new( current_user => $args->{ticket}->current_user,
                                                ticket_obj => $args->{ticket},
                                                transaction_obj => $args->{transaction}
                                            );
            $action = $rule->get_scrip_action(@{$args}{qw(name template)});
            $action->prepare or return;
        }
        $action->commit;
    },
);


1;
