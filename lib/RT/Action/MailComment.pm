#$Header$
#if this is a comment, mail it to the argument.

package RT::Action::MailComment;

require RT::Action::SendEmail;
@ISA = qw(RT::Action::SendEmail);

# TODO: Override SetReceipients and avoid sending to the Requestor
# ... or anybody else which shouldn't have access to the comments.

1;
