package RT::Approval::Rule;
use strict;
use warnings;

use base 'RT::Rule';

use constant _Queue => '___Approvals';

sub Prepare {
    my $self = shift;
    return unless $self->SUPER::Prepare();
    $self->TicketObj->Type eq 'approval';
}

sub GetTemplate {
    my ($self, $template_name, %args) = @_;
    my $template = RT::Template->new($self->CurrentUser);
    $template->Load($template_name) or return;
    my ($result, $msg) = $template->Parse(%args);

    # XXX: error handling

    return $template;
}

1;

