#$Header$
#What this needs to do:
#
# Basically, send mail to all interested parties for a ticket
# but only if it's correspondence.

package RT::Action::MailCorrespondence;

require RT::Action::SendEmail;
@ISA = qw(RT::Action::SendEmail);

1;

