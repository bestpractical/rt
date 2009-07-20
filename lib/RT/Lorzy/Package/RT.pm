package RT::Lorzy::Package::RT;
use strict;
use base 'Lorzy::Package';

sub lcore_defun {
    my ($env, $name, %args) = @_;
    $RT::Lorzy::LCORE->env->set_symbol('RT.'.$name => LCore::Primitive->new(
        body => sub {
            my ($ticket, $transaction) = @_;
            $args{native}->(
                { ticket      => $ticket,
                  transaction => $transaction });
        },
        lazy => 0,
        parameters => [ LCore::Parameter->new({ name => 'ticket', type => 'RT::Model::Ticket' }),
                        LCore::Parameter->new({ name => 'transaction', type => 'RT::Model::Transaction' }) ],
    ));
}

__PACKAGE__->lcore_defun( 'Condition.OnTransaction',
    native => sub {
        return 1;
    },
);

__PACKAGE__->lcore_defun( 'Condition.OnOwnerChange',
    native => sub {
        my $args = shift;
        return ( $args->{transaction}->field || '' ) eq 'owner';
    },
);

__PACKAGE__->lcore_defun( 'Condition.OnQueueChange',
    native => sub {
        my $args = shift;
        return $args->{transaction}->type eq 'set'
            && ( $args->{transaction}->field || '' ) eq 'queue';
    },
);

__PACKAGE__->lcore_defun( 'Condition.OnPriorityChange',
    native => sub {
        my $args = shift;
        return $args->{transaction}->type eq 'set'
            && ( $args->{transaction}->field || '' ) eq 'priority';
    },
);

__PACKAGE__->lcore_defun( 'Condition.OnResolve',
    native => sub {
        my $args = shift;
        return ($args->{transaction}->type ||'') eq 'status'
            && ( $args->{transaction}->field || '' ) eq 'status'
            && ($args->{transaction}->new_value()||'') eq 'resolved';
    },
);

__PACKAGE__->lcore_defun( 'Condition.OnClose',
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

__PACKAGE__->lcore_defun( 'Condition.OnReopen',
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

=begin comment

__PACKAGE__->defun( 'Condition.BeforeDue',
    # format is "1d2h3m4s" for 1 day and 2 hours and 3 minutes and 4 seconds.
    signature => { 'datestring' => Lorzy::FunctionArgument->new( name => 'datestring', type => 'Str' ) },

    native => sub {
        my $xargs = shift;
        my %e;
        foreach (qw(d h m s)) {
            my @vals = $xargs->{datestring} =~ m/(\d+)$_/;
            $e{$_} = pop @vals || 0;
        }
        my $elapse = $e{'d'} * 24 * 60 * 60 + $e{'h'} * 60 * 60 + $e{'m'} * 60 + $e{'s'};

        return Lorzy::Lambda::Native->new
            ( body => sub {
                  my $args = shift;
                  my $cur = RT::DateTime->now;
                  my $due = $args->{ticket}->due;
                  return (undef) if $due->epoch <= 0;

                  my $diff = $due->diff($cur);
                  return ($diff >= 0 and $diff <= $elapse);
              },
              signature => $sig_ticket_txn );
    },
);

__PACKAGE__->defun( 'Condition.PriorityExceeds',
    signature => { 'priority' => Lorzy::FunctionArgument->new( name => 'priority', type => 'Int' ),
               },
    native => sub {
        my $xargs = shift;
        return Lorzy::Lambda::Native->new
            ( body => sub {
                  my $args = shift;
                  $args->{ticket}->priority > $xargs->{priority};
              },
              signature => $sig_ticket_txn );
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

=cut

my %simple_txn_cond = ( 'OnCreate' => 'create',
                        'OnCorrespond' => 'correspond',
                        'OnComment' => 'comment',
                        'OnStatusChange' => 'status',
                    );

for my $name ( keys %simple_txn_cond ) {
    __PACKAGE__->lcore_defun( "Condition.$name",
        native => sub {
return 0;
            my $args = shift;
            return ($args->{transaction}->type||'') eq ($simple_txn_cond{$name} ||'');
        },
    );
}

=begin comment

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

=cut

1;
