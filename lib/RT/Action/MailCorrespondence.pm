#$Header$


package RT::Action::MailCorrespondence;

require RT::Action::SendEmail;
@ISA = qw(RT::Action::SendEmail);

# TODO: overload the SetReceipients and avoid sending to the originator

1;

