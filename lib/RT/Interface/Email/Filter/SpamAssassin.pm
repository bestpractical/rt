package RT::Interface::Email::Filter::SpamAssassin;

use Mail::SpamAssassin;
my $spamtest = Mail::SpamAssassin->new();

sub GetCurrentUser {
    my $item = shift;
    my $status = $spamtest->check ($item);
    return (0, undef) unless $status->is_spam();
    eval { $status->rewrite_mail() };
    if ($status->get_hits > $status->get_required_hits()*1.5) { 
        # Spammy indeed
        return (-1, undef);
    }
    return (0, undef);
}

=head1 NAME

RT::Interface::Email::Filter::SpamAssassin - Spam filter for RT

=head1 SYNOPSIS

    @RT::MailPlugins = ("Filter::SpamAssassin", ...);

=head1 DESCRIPTION

This plugin checks to see if an incoming mail is spam (using
C<spamassassin>) and if so, rewrites its headers. If the mail is very
definitely spam - 1.5x more hits than required - then it is dropped on
the floor; otherwise, it is passed on as normal.

=cut
