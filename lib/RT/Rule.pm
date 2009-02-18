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

package RT::Rule;
use strict;
use warnings;
use base 'RT::ScripAction';

use constant _stage => 'transaction_create';
use constant _queue => undef;

sub prepare {
    my $self = shift;
    return (0) if $self->_queue && $self->ticket_obj->queue->name ne $self->_queue;
    return 1;
}

sub commit  {
    my $self = shift;
    return(0, _("Commit Stubbed"));
}

sub describe {
    my $self = shift;
    return _( $self->description );
}

sub on_status_change {
    my ($self, $value) = @_;

    $self->transaction_obj->type eq 'status' and
    $self->transaction_obj->field eq 'status' and
    $self->transaction_obj->new_value eq $value
}

sub run_scrip_action {
    my ($self, $scrip_action, $template, %args) = @_;
    my $ScripAction = RT::Model::ScripAction->new( current_user => $self->current_user);
    $ScripAction->load($scrip_action) or die ;
    unless (ref($template)) {
        # XXX: load per-queue template
        #    $template->LoadQueueTemplate( Queue => ..., ) || $template->LoadGlobalTemplate(...)

        my $t = RT::Model::Template->new( current_user => $self->current_user);
        $t->load($template) or die;
        $template = $t;
    }

    my $action = $ScripAction->load_action(
        transaction_obj         => $self->transaction_obj,
        ticket_obj              => $self->ticket_obj,
        source_scripaction_name => $scrip_action,
        %args,
    );

    # XXX: fix template to allow additional arguments to be passed from here
    $action->{'template_obj'} = $template;
    $action->prepare or return;
    $action->commit;

}

1;
