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

package RT::View::Ticket::Create;
use Jifty::View::Declare -base;

__PACKAGE__->use_mason_wrapper;

template 'create' => page { title => _('Create a new ticket') } content {
    # If we have a create_ticket action, pluck the queue out, otherwise,
    # check the regular queue query parameter
    my $action = Jifty->web->request->action('create_ticket');
    my $queue = $action ? $action->argument('queue') : get('queue');
    $queue or die "Queue not specified";

    my $create = new_action(
        class   => 'CreateTicket',
        moniker => 'create_ticket',
    );
    $create->set_queue($queue);

    my $actions = {
        A => {
            html => q[<a href="#basics" onclick="jQuery('#Ticket-Create-details').hide(); jQuery('#Ticket-Create-basics').show(); return false;">] . _('Show basics') . q[</a>],
        },
        B => {
            html => q[<a href="#details" onclick="jQuery('#Ticket-Create-basics').hide(); jQuery('#Ticket-Create-details').show(); return false;">] . _('Show details') . q[</a>],
        },
    };

    render_mason('/Elements/Tabs', {
        current_toptab => 'ticket/create',
        title          => _("Create a new ticket"),
        actions        => $actions,
    });

    form {
        form_next_page url => '/Ticket/Display.html';

        show_basics($create);
        show_details($create);
    };
};

sub show_basics {
    my $create = shift;
    my $queue = $create->queue;

    div {
        attr { id => "Ticket-Create-basics" };
        a { attr { name => "basics" } };

        render_param($create, 'queue');

        # Jifty should do this for us when we render a read-only parameter
        # The only worry is that the user does what we're doing here so that
        # the parameter is now an arrayref instead of a plain scalar
        render_hidden($create, 'queue', $queue);

        render_param($create, 'status');
        render_param($create, 'owner');

        for my $role_group ($create->role_group_parameters) {
            render_param($create, $role_group);
        }

        for my $custom_field ($create->ticket_custom_field_parameters) {
            render_param($create, $custom_field);
        }

        for my $custom_field ($create->transaction_custom_field_parameters) {
            render_param($create, $custom_field);
        }

        render_param($create, 'subject');
        render_param($create, 'attachments');

        render_param($create, 'content');

        $create->button(label => _('Create'));
    };
}

sub show_details {
    my $create = shift;

    div {
        attr {
            id    => "Ticket-Create-details",
            class => "jshide",
        };
        a { attr { name => "details" } };

        render_param($create, 'initial_priority');
        render_param($create, 'final_priority');

        for my $duration_type ($create->duration_parameters) {
            render_param($create, $duration_type);
        }

        hr {};

        for my $datetime_type ($create->datetime_parameters) {
            render_param($create, $datetime_type);
        }

        hr {};

        for my $link_type ($create->link_parameters) {
            render_param($create, $link_type);
        }

        $create->button(label => _('Create'));
    };
}

1;

