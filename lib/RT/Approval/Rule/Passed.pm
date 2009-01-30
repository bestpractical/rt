# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
# 
# This software is Copyright (c) 1996-2009 Best Practical Solutions, LLC
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

package RT::Approval::Rule::Passed;
use strict;
use warnings;
use base 'RT::Approval::Rule';

use constant description => "Notify Owner of their ticket has been approved by some or all approvers"; # loc

sub prepare {
    my $self = shift;
    return unless $self->SUPER::prepare();

    $self->on_status_change('resolved');
}

sub commit {
    my $self = shift;
    my $note;
    my $t = $self->ticket_obj->transactions;

    while ( my $o = $t->next ) {
        next unless $o->type eq 'correspond';
        $note .= $o->content . "\n" if $o->content_obj;
    }
    my ($top) = $self->ticket_obj->all_depended_on_by( Type => 'ticket' );
    my $links  = $self->ticket_obj->depended_on_by;

    while ( my $link = $links->next ) {
        my $obj = $link->base_obj;
        next unless $obj->type eq 'approval';
        next if $obj->has_unresolved_dependencies( type => 'approval' );

        $obj->set_status( status => 'open', force => 1 );
    }

    my $passed = !$top->has_unresolved_dependencies( type => 'approval' );
    my $template = $self->get_template(
        $passed ? 'All Approvals Passed' : 'Approval Passed',
        ticket_obj => $top,
        approval => $self->ticket_obj,
        notes => $note,
    ) or die;

    $top->correspond( mime_obj => $template->mime_obj );

    if ($passed) {
        $self->run_scrip_action('Notify Owner', 'Approval Ready for Owner',
                              ticket_obj => $top);
    }

    return;
}

1;
