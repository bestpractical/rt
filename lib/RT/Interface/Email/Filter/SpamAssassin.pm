# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2011 Best Practical Solutions, LLC
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

package RT::Interface::Email::Filter::SpamAssassin;

use Mail::SpamAssassin;
my $spamtest = Mail::SpamAssassin->new();

sub GetCurrentUser {
    my %args = (
        Message     => undef,
        CurrentUser => undef,
        AuthLevel   => undef,
        @_
    );
    my $status = $spamtest->check( $args{'Message'} );
    return ( $args{'CurrentUser'}, $args{'AuthLevel'} )
      unless $status->is_spam();

    eval { $status->rewrite_mail() };
    if ( $status->get_hits > $status->get_required_hits() * 1.5 ) {

        # Spammy indeed
        return ( $args{'CurrentUser'}, -1 );
    }
    return ( $args{'CurrentUser'}, $args{'AuthLevel'} );

}

=head1 NAME

RT::Interface::Email::Filter::SpamAssassin - Spam filter for RT

=head1 SYNOPSIS

    # in RT config
    Set(@MailPlugins, 'Filter::SpamAssassin', ...other filters...);

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
