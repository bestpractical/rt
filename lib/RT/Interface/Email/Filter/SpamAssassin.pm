# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2003 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
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
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK
package RT::Interface::Email::Filter::SpamAssassin;

use Mail::SpamAssassin;
my $spamtest = Mail::SpamAssassin->new();

sub GetCurrentUser {
    my $item = shift;
    my $status = $spamtest->check ($item);
    return (undef, 0) unless $status->is_spam();
    eval { $status->rewrite_mail() };
    if ($status->get_hits > $status->get_required_hits()*1.5) { 
        # Spammy indeed
        return (undef, -1);
    }
    return (undef, 0);
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

eval "require RT::Interface::Email::Filter::SpamAssassin_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Interface/Email/Filter/SpamAssassin_Vendor.pm});
eval "require RT::Interface::Email::Filter::SpamAssassin_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Interface/Email/Filter/SpamAssassin_Local.pm});

1;
