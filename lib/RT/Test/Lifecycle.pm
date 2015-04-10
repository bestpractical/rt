# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2015 Best Practical Solutions, LLC
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

use strict;
use warnings;

package RT::Test::Lifecycle;
use base 'RT::Test';

sub bootstrap_more_config {
    my $self = shift;
    my ($config, $args) = @_;
    print $config <<'EOT';
Set(%Lifecycles,
    default => {
        initial  => [qw(new)],
        active   => [qw(open stalled)],
        inactive => [qw(resolved rejected deleted)],
        defaults => {
            on_create => 'new',
            on_merge => 'resolved',
        },
        transitions => {
            ''       => [qw(new open resolved)],
            new      => [qw(open resolved rejected deleted)],
            open     => [qw(stalled resolved rejected deleted)],
            stalled  => [qw(open)],
            resolved => [qw(open)],
            rejected => [qw(open)],
            deleted  => [qw(open)],
        },
        actions => {
            'new -> open'     => {label => 'Open It', update => 'Respond'},
            'new -> resolved' => {label => 'Resolve', update => 'Comment'},
            'new -> rejected' => {label => 'Reject',  update => 'Respond'},
            'new -> deleted'  => {label => 'Delete',  update => ''},

            'open -> stalled'  => {label => 'Stall',   update => 'Comment'},
            'open -> resolved' => {label => 'Resolve', update => 'Comment'},
            'open -> rejected' => {label => 'Reject',  update => 'Respond'},

            'stalled -> open'  => {label => 'Open It',  update => ''},
            'resolved -> open' => {label => 'Re-open',  update => 'Comment'},
            'rejected -> open' => {label => 'Re-open',  update => 'Comment'},
            'deleted -> open'  => {label => 'Undelete', update => ''},
        },
    },
    delivery => {
        initial  => ['ordered'],
        active   => ['on way', 'delayed'],
        inactive => ['delivered'],
        defaults => {
            on_create => 'ordered',
            on_merge => 'delivered',
        },
        transitions => {
            ''        => ['ordered'],
            ordered   => ['on way', 'delayed'],
            'on way'  => ['delivered'],
            delayed   => ['on way'],
            delivered => [],
        },
        actions => {
            'ordered -> on way'   => {label => 'Put On Way', update => 'Respond'},
            'ordered -> delayed'  => {label => 'Delay',      update => 'Respond'},

            'on way -> delivered' => {label => 'Done',       update => 'Respond'},
            'delayed -> on way'   => {label => 'Put On Way', update => 'Respond'},
        },
    },
    racing => {
        type => 'racecar',
        active => ['on-your-mark', 'get-set', 'go'],
        inactive => ['first', 'second', 'third', 'no-place'],
    },
);
EOT
}

1;
