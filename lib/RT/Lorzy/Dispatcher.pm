package RT::Lorzy::Dispatcher;
use strict;
use warnings;
#use base 'RT::Ruleset';

sub reset_rules {
    my $rules = RT::Model::RuleCollection->new( current_user => RT::CurrentUser->superuser);
    $rules->unlimit;
    for (@$rules) {
        $_->delete;
    }
}

sub rules {
    my $rules = RT::Model::RuleCollection->new( current_user => RT::CurrentUser->superuser);
    $rules->unlimit;
    my $l = $RT::Lorzy::LCORE;
    return [ map {
        RT::Lorzy::RuleFactory->make_factory(
            { condition     => $l->analyze_it($_->condition_code)->($l->env),
              prepare       => $_->prepare_code ? $l->analyze_it($_->prepare_code)->($l->env) : undef,
              action        => $l->analyze_it($_->action_code)->($l->env),
              description   => $_->description,
              _stage        => 'transaction_create' })
        } @$rules];

    return $rules;
}

1;
