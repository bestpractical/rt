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

package RT::Approval::Rule::Rejected;
use strict;
use warnings;
use base 'RT::Approval::Rule';

use constant Description => "If an approval is rejected, reject the original and delete pending approvals"; # loc

sub prepare {
    my $self = shift;
    return unless $self->SUPER::prepare();

    return (0)
        unless $self->on_status_change('rejected') or $self->on_status_change('deleted')
}

sub commit {    # XXX: from custom prepare code
    my $self = shift;
    if ( my ($rejected) =
        $self->ticket_obj->all_depended_on_by( type => 'ticket' ) ) {
        my $template = $self->GetTemplate('Approval Rejected',
                                          ticket_obj => $rejected,
                                          approval  => $self->ticket_obj,
                                          notes     => '');

        $rejected->Correspond( mime_obj => $template->mime_obj );
        $rejected->SetStatus(
            status => 'rejected',
            force  => 1,
        );
    }
    my $links = $self->ticket_obj->depended_on_by;
    foreach my $link ( @{ $links->items_array_ref } ) {
        my $obj = $link->base_obj;
        if ( $obj->queue_obj->is_active_status( $obj->status ) ) {
            if ( $obj->type eq 'approval' ) {
                $obj->set_status(
                    status => 'deleted',
                    force  => 1,
                );
            }
        }
    }

    $links = $self->ticket_obj->depends_on;
    foreach my $link ( @{ $links->items_array_ref } ) {
        my $obj = $link->target_obj;
        if ( $obj->queue_obj->is_active_status( $obj->status ) ) {
            $obj->set_status(
                status => 'deleted',
                force  => 1,
            );
        }
    }

}

1;
