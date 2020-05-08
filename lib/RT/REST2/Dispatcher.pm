package RT::REST2::Dispatcher;
use strict;
use warnings;
use Moose;
use Web::Machine;
use Path::Dispatcher;
use Plack::Request;
use List::MoreUtils 'uniq';

use Module::Pluggable (
    search_path => ['RT::REST2::Resource'],
    sub_name    => '_resource_classes',
    require     => 1,
    max_depth   => 5,
);

has _dispatcher => (
    is         => 'ro',
    isa        => 'Path::Dispatcher',
    builder    => '_build_dispatcher',
);

sub _build_dispatcher {
    my $self = shift;
    my $dispatcher = Path::Dispatcher->new;

    for my $resource_class ($self->_resource_classes) {
        if ($resource_class->can('dispatch_rules')) {
            my @rules = $resource_class->dispatch_rules;
            for my $rule (@rules) {
                $rule->{_rest2_resource} = $resource_class;
                $dispatcher->add_rule($rule);
            }
        }
    }

    return $dispatcher;
}

sub to_psgi_app {
    my $class = shift;
    my $self = $class->new;

    return sub {
        my $env = shift;

        RT::ConnectToDatabase();
        my $dispatch = $self->_dispatcher->dispatch($env->{PATH_INFO});

        return [404, ['Content-Type' => 'text/plain'], 'Not Found']
            if !$dispatch->has_matches;

        my @matches = $dispatch->matches;
        my @matched_resources = uniq map { $_->rule->{_rest2_resource} } @matches;
        if (@matched_resources > 1) {
            RT->Logger->error("Path $env->{PATH_INFO} erroneously matched " . scalar(@matched_resources) . " resources: " . (join ', ', @matched_resources) . ". Refusing to dispatch.");
            return [500, ['Content-Type' => 'text/plain'], 'Internal Server Error']
        }

        my $match = shift @matches;

        my $rule = $match->rule;
        my $resource = $rule->{_rest2_resource};
        my $args = $rule->block ? $match->run(Plack::Request->new($env)) : {};
        my $machine = Web::Machine->new(
            resource      => $resource,
            resource_args => [%$args],
        );
        return $machine->call($env);
    };
}

1;
