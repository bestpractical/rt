# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2018 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
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

package RT::Interface::Email::Role;

use strict;
use warnings;

use Role::Basic;

use RT::Interface::Email;

=head1 NAME

RT::Interface::Email::Role - Role for mail plugins

=head1 SYNOPSIS

    package RT::Interface::Email::Action::Something;

    use Role::Basic 'with';
    with 'RT::Interface::Email::Role';

    sub CheckACL { ... }
    sub HandleSomething { ... }

=head1 DESCRIPTION

Provides a means to affect the handling of RT's mail gateway.  Mail
plugins (which appear in L<RT_Config/@MailPlugins> should implement this
role.

See F<docs/extending/mail_plugins.pod> for a list of hook points which
plugins can implement.

=head1 METHODS

=head2 TMPFAIL

This should be called for configuration errors.  It results in a
temporary failure code to the MTA, ensuring that the message is not
lost, and will be retried later.

This function should be passed the warning message to log with the
temporary failure.  Does not return.


=head2 FAILURE

This should be used upon rejection of a message.  It will B<not> be
retried by the MTA; as such, it should be used sparingly, and in
conjunction with L</MailError> such that the sender is aware of the
failure.

The function should be passed a message to return to the mailgate.  Does
not return.


=head2 SUCCESS

The message was successfully parsed.  The function takes an optional
L<RT::Ticket> object to return to the mailgate. Does not return.


=head2 MailError

Sends an error concerning the email, or the processing thereof.  Takes
the following arguments:

=over

=item To

Only necessary in L</BeforeDecode> and L<BeforeDecrypt> hooks, where it
defaults to L<RT_Config/OwnerEmail>; otherwise, defaults to the
originator of the message.

=item Subject

Subject of the email

=item Explanation

The body of the email

=item FAILURE

If passed a true value, will call L</FAILURE> after sending the message.

=back

=cut

sub TMPFAIL { RT::Interface::Email::TMPFAIL(@_) }
sub FAILURE { RT::Interface::Email::FAILURE(@_) }
sub SUCCESS { RT::Interface::Email::SUCCESS(@_) }

sub MailError { RT::Interface::Email::MailError(@_) }

1;
