#$Header$
#if this is a comment, mail it to the argument.

package RT::Action::MailComment;

require RT::Action::SendEmail;
@ISA = qw(RT::Action::SendEmail);

1;
