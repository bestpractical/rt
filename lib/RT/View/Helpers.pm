# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC
#                                          <jesse@bestpractical.com>
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
# http://www.gnu.org/copyleft/gpl.html.
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
use warnings;
use strict;

package RT::View::Helpers;
use Jifty::View::Declare -base;

use base qw/Exporter/;
our @EXPORT    = ();
our @EXPORT_OK = qw(render_user render_user_concise render_user_verbose);

sub render_user {
    my $user = shift;

    if (!ref($user)) {
        my $user_object = RT::Model::User->new;
        $user_object->load($user);
        $user = $user_object;
    }

    my $style = RT->config->get('username_format', Jifty->web->current_user);
    return render_user_concise($user)
        if $style eq 'concise';
    return render_user_verbose($user);
}

sub render_user_concise {
    my $user = shift;

    if ($user->privileged) {
        return $user->real_name
            || $user->nickname
            || $user->name
            || $user->email;
    }

    return $user->email
        || $user->name
        || $user->real_name
        || $user->nickname;
}

sub render_user_verbose {
    my $user = shift;

    my ($phrase, $comment);
    my $addr = $user->email;

    $phrase = $user->real_name
        if $user->real_name
        && lc $user->real_name ne lc $addr;

    $comment = $user->name
        if lc $user->name ne lc $addr;

    $comment = "($comment)"
        if defined $comment and length $comment;

    my $address = Email::Address->new($phrase, $addr, $comment);

    $address->comment('')
        if $comment && lc $address->user eq lc $comment;

    if ( $phrase and my ($l, $r) = ($phrase =~ /^(\w+) (\w+)$/) ) {
        $address->phrase('')
            if $address->user =~ /^\Q$l\E.\Q$r\E$/
            || $address->user =~ /^\Q$r\E.\Q$l\E$/;
    }

    return $address->format;
}


1;

