# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2010 Best Practical Solutions, LLC
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
package RT::FM;

use 5.008003;
use strict;
use warnings;

our $VERSION = '2.4.HEAD';

# Create a system object for RTFM
use RT::FM::System;
our $System = RT::FM::System->new( $RT::SystemUser );

# blow in a format for the CF Applies To UI new in 3.8.8
if (RT->can('Config') && RT->Config->can('Get')) {
    if (my $admin_formats = RT->Config->Get('AdminSearchResultFormat')) {
        $admin_formats->{'FM::ClassCollection'} ||=
             q{ '<a href="__WebPath__/Admin/RTFM/Classes/Modify.html?id=__id__">__id__</a>/TITLE:#'}
            .q{,'<a href="__WebPath__/Admin/RTFM/Classes/Modify.html?id=__id__">__Name__</a>/TITLE:Name'}
            .q{,__Description__};
        RT->Config->Set('AdminSearchResultFormat',%$admin_formats);
    }
}

1;
