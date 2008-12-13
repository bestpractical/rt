package RT::Rule;
use strict;
use warnings;
use base 'RT::Action';

use constant _Stage => 'TransactionCreate';
use constant _Queue => undef;

sub Prepare {
    my $self = shift;
    return (0) if $self->_Queue && $self->TicketObj->QueueObj->Name ne $self->_Queue;
    return 1;
}

sub Commit  {
    my $self = shift;
    return(0, $self->loc("Commit Stubbed"));
}

sub Describe {
    my $self = shift;
    return $self->loc( $self->Description );
}

sub OnStatusChange {
    my ($self, $value) = @_;

    $self->TransactionObj->Type eq 'Status' and
    $self->TransactionObj->Field eq 'Status' and
    $self->TransactionObj->NewValue eq $value
}

sub RunScripAction {
    my ($self, $scrip_action, $template, %args) = @_;
    my $ScripAction = RT::ScripAction->new($self->CurrentUser);
    $ScripAction->Load($scrip_action) or die ;

    unless (ref($template)) {
        # XXX: load per-queue template
        #    $template->LoadQueueTemplate( Queue => ..., ) || $template->LoadGlobalTemplate(...)

        my $t = RT::Template->new($self->CurrentUser);
        $t->Load($template) or die;
        $template = $t;
    }

    my $action = $ScripAction->LoadAction( TransactionObj => $self->TransactionObj,
                                           TicketObj => $self->TicketObj,
                                           %args,
                                       );

    # XXX: fix template to allow additional arguments to be passed from here
    $action->{'TemplateObj'} = $template;
    $action->{'ScripObj'} = RT::Scrip->new($self->CurrentUser); # Stub. sendemail action really wants a scripobj available
    $action->Prepare or return;
    $action->Commit;

}

1;
