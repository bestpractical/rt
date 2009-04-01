package RT::Lorzy::Dispatcher;
use strict;
use warnings;
#use base 'RT::Ruleset';

sub reset_rules {
    my $rules = RT::Model::RuleCollection->new( current_user => RT::CurrentUser->superuser);
    for (@$rules) {
        $_->delete;
    }
}

sub rules {
    my $rules = RT::Model::RuleCollection->new( current_user => RT::CurrentUser->superuser);
    $rules->unlimit;
    return [ map {
        RT::Lorzy::RuleFactory->make_factory(
            { condition     => Jifty::YAML::Load($_->condition),
              prepare       => Jifty::YAML::Load($_->prepare),
              action        => Jifty::YAML::Load($_->action),
              description   => $_->description,
              _stage        => 'transaction_create' })
        } @$rules];

    return $rules;
}

1;
