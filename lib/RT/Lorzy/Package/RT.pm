package RT::Lorzy::Package::RT;
use strict;
use base 'Lorzy::Package';

my %mymap = ( 'On Create' => 'OnCreate',
              'On Transaction' => 'OnTransaction',
              'On Correspond' => 'OnCorrespond',
              'On comment' => 'OnComment',
              'On Status Change' => 'OnStatusChange',
          );

my @scrip_conditions = (
    {

      name                 => 'On priority Change',                       # loc
      description          => 'Whenever a ticket\'s priority changes',    # loc
      applicable_trans_types => 'set',
      exec_module           => 'priorityChange',
    },
    {

      name                 => 'On owner Change',                           # loc
      description          => 'Whenever a ticket\'s owner changes',        # loc
      applicable_trans_types => 'any',
      exec_module           => 'OwnerChange',

    },
    {

      name                 => 'On queue Change',                           # loc
      description          => 'Whenever a ticket\'s queue changes',        # loc
      applicable_trans_types => 'set',
      exec_module           => 'QueueChange',

    },
    # not tested
    {  name                 => 'On Resolve',                               # loc
       description          => 'Whenever a ticket is resolved',            # loc
       applicable_trans_types => 'status',
       exec_module           => 'StatusChange',
       argument             => 'resolved'

    },

    # not tested
    {  name                 => 'On Close',                                 # loc
       description          => 'Whenever a ticket is closed', # loc
       applicable_trans_types => 'status,set',
       exec_module           => 'CloseTicket',
    },
    {  name                 => 'On Reopen',                                # loc
       description          => 'Whenever a ticket is reopened', # loc
       applicable_trans_types => 'status,set',
       exec_module           => 'ReopenTicket',
    },

);

__PACKAGE__->defun( 'Condition.OnTransaction',
    signature => {
        'ticket' => Lorzy::FunctionArgument->new( name => 'ticket', type => 'RT::Model::Ticket' ),
        'transaction' => Lorzy::FunctionArgument->new( name => 'transaction', type => 'RT::Model::Transaction' ),
    },
    native => sub {
        return 1;
    },
);

my %simple_txn_cond = ( 'OnCreate' => 'create',
                        'OnCorrespond' => 'correspond',
                        'OnComment' => 'comment',
                        'OnStatusChange' => 'status',
                    );

for my $name ( keys %simple_txn_cond ) {
    __PACKAGE__->defun( "Condition.$name",
        signature => {
            'ticket' => Lorzy::FunctionArgument->new( name => 'ticket', type => 'RT::Model::Ticket' ),
            'transaction' => Lorzy::FunctionArgument->new( name => 'transaction', type => 'RT::Model::Transaction' ),
        },
        native => sub {
            my $args = shift;
            return $args->{transaction}->type eq $simple_txn_cond{$name};
        },
    );
}

__PACKAGE__->defun( 'Condition.Applicable',
    signature => {
        'name'   => Lorzy::FunctionArgument->new( name => 'name' ),
        'ticket' => Lorzy::FunctionArgument->new( name => 'ticket', type => 'RT::Model::Ticket' ),
        'transaction' => Lorzy::FunctionArgument->new( name => 'transaction', type => 'RT::Model::Transaction' ),
    },
    native => sub {
        my $args = shift;
        my $eval = shift;

        if (my $lorzy_cond = $mymap{$args->{name}}) {
            $lorzy_cond = 'RT.Condition.'.$lorzy_cond;
            return $eval->resolve_symbol_name($lorzy_cond)->apply
                ( $eval, 
                  { transaction => $args->{transaction},
                    ticket => $args->{ticket}
                });
        }

        my $txn_type = $args->{transaction}->type;

        my ($condition_config) = grep { $args->{name} eq $_->{name} } @scrip_conditions
            or  die "Can't load scrip condition: $args->{name}";

        my $type = "RT::Condition::" . $condition_config->{exec_module};

        Jifty::Util->require($type);

        my $condition = $type->new(
                ticket_obj      => $args->{'ticket'},
                transaction_obj => $args->{'transaction'},
                'argument'       => $condition_config->{argument},
                'applicable_trans_types' => $condition_config->{applicable_trans_types},
            );

        return 0
            unless ( $condition_config->{applicable_trans_types} =~ /(?:^|,)(?:Any|\Q$txn_type\E)(?:,|$)/i );

        return $condition->is_applicable();
    },
);

__PACKAGE__->defun( 'ScripAction.Prepare',
    signature => {
        'name'     => Lorzy::FunctionArgument->new( name => 'name' ),
        'context'  => Lorzy::FunctionArgument->new( name => 'context' ),
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
        'ticket'   => Lorzy::FunctionArgument->new( name => 'ticket', type => 'RT::Model::Ticket' ),
        'transaction' => Lorzy::FunctionArgument->new( name => 'transaction', type => 'RT::Model::Transaction' ),
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
