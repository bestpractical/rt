package RT::Lorzy::Package::RT;
use strict;
use base 'Lorzy::Package';

__PACKAGE__->defun( 'Condition.Applicable',
    signature => {
        'name'   => Lorzy::FunctionArgument->new( name => 'name' ),
        'ticket' => Lorzy::FunctionArgument->new( name => 'ticket', type => 'RT::Model::Ticket' ),
        'transaction' => Lorzy::FunctionArgument->new( name => 'transaction', type => 'RT::Model::Transaction' ),
    },
    native => sub {
        my $args   = shift;
        my $scrip_condition = RT::Model::ScripCondition->new;
        $scrip_condition->load($args->{name}) or die "Can't load scrip condition: $args->{name}";
        $scrip_condition->load_condition(
                ticket_obj      => $args->{'ticket'},
                transaction_obj => $args->{'transaction'},
            ) or die "Can't load condition: $args->{name}";


        # XXX: this is so wrong, the applicable_trans_type check is
        # done in scrip level rather than condition level. see
        # RT::Model::Scrip.

        my $txn_type = $args->{transaction}->type;
        return 0
            unless ( $scrip_condition->applicable_trans_types =~ /(?:^|,)(?:Any|\Q$txn_type\E)(?:,|$)/i );

        return $scrip_condition->is_applicable();
    },
);

__PACKAGE__->defun( 'ScripAction.Run',
    signature => {
        'name'     => Lorzy::FunctionArgument->new( name => 'name' ),
        'template' => Lorzy::FunctionArgument->new( name => 'template' ),
        'ticket'   => Lorzy::FunctionArgument->new( name => 'ticket', type => 'RT::Model::Ticket' ),
        'transaction' => Lorzy::FunctionArgument->new( name => 'transaction', type => 'RT::Model::Transaction' ),
    },
    native => sub {
        my $args   = shift;
        my $rule = RT::Rule->new( current_user => $args->{ticket}->current_user,
                                  ticket_obj => $args->{ticket},
                                  transaction_obj => $args->{transaction}
                              );
        $rule->run_scrip_action(@{$args}{qw(name template)});
    },
);

1;
