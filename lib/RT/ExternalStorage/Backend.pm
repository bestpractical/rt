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

use warnings;
use strict;

package RT::ExternalStorage::Backend;

use Role::Basic;

requires 'Init';
requires 'Get';
requires 'Store';
requires 'DownloadURLFor';

sub new {
    my $class = shift;
    my %args = @_;

    $class = delete $args{Type};
    if (not $class) {
        RT->Logger->error("No storage engine type provided");
        return undef;
    } elsif ($class->require) {
        # no action needed; $class was loaded
    } else {
        my $long = "RT::ExternalStorage::$class";
        if ($long->require) {
            $class = $long;
        } else {
            RT->Logger->error("Can't load external storage engine $class: $@");
            return undef;
        }
    }

    unless ($class->DOES("RT::ExternalStorage::Backend")) {
        RT->Logger->error("External storage engine $class doesn't implement RT::ExternalStorage::Backend");
        return undef;
    }

    my $self = bless \%args, $class;
    $self->Init;
}

RT::Base->_ImportOverlays();

1;
