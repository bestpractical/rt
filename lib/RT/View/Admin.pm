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
use warnings;
use strict;

package RT::View::Admin;
use Jifty::View::Declare -base;

require RT::View::Admin::Groups;
alias RT::View::Admin::Groups under 'groups/';

require RT::View::Admin::Users;
alias RT::View::Admin::Users under 'users/';

require RT::View::Admin::Queues;
alias RT::View::Admin::Queues under 'queues/';

require RT::View::Admin::CustomFields;
alias RT::View::Admin::CustomFields under 'custom_fields/';

require RT::View::Admin::Rules;
alias RT::View::Admin::Rules under 'rules/';

require RT::View::Admin::Global;
alias RT::View::Admin::Global under 'global/';

require RT::View::Admin::Tools;
alias RT::View::Admin::Tools under 'tools/';

template 'index.html' => page { title => _('RT Administration') } content {
    my $items = {
        A => {
            title       => _('Users'),
            path        => '/admin/users',
            description => _('Manage users and passwords'),
        },
        B => {
            title       => _('Groups'),
            path        => '/admin/groups',
            description => _('Manage groups and group membership'),
        },
        C => {
            title       => _('Queues'),
            path        => '/admin/queues',
            description => _('Manage queues and queue-specific properties'),
        },
        D => {
            'title'     => _('Custom Fields'),
            description => _('Manage custom fields and custom field values'),
            path        => '/admin/custom_fields',
        },
        E => {
            'title'     => _('Global'),
            path        => '/admin/global',
            description => _(
                'Manage properties and configuration which apply to all queues'
            ),
        },
        F => {
            'title'     => _('Tools'),
            path        => '/admin/tools',
            description => _('Use other RT administrative tools')
        },
    };

    ul {
        attr { class => 'list-menu' };
        foreach my $key ( sort keys %$items ) {
            li {
                span {
                    attr { class => 'menu-item' };
                    a {
                        attr { href => RT->config->get('web_path')
                              . $items->{$key}->{'path'} };
                        $items->{$key}->{'title'};
                    }
                }
                span {
                    attr { class => 'description' }
                      $items->{$key}->{description}
                }

            }
        }
    };
}

1;

