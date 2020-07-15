# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2020 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
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
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
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
