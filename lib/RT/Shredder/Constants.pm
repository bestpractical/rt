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

package RT::Shredder::Constants;

use strict;
use warnings;

=head1 NAME

RT::Shredder::Constants -  RT::Shredder constants that is used to mark state of RT objects.

=head1 DESCRIPTION

This module contains two group of bit constants.
First group is group of flags which are used to clarify dependecies between objects, and
second group is states of RT objects in Shredder cache.

=head1 FLAGS

=head2 DEPENDS_ON

Targets that has such dependency flag set should be wiped out with base object.

=head2 WIPE_AFTER

If dependency has such flag then target object would be wiped only
after base object. You should mark dependencies with this flag
if two objects depends on each other, for example Group and Principal
have such relationship, this mean Group depends on Principal record and
that Principal record depends on the same Group record. Other examples:
User and Principal, User and its ACL equivalence group.

=head2 VARIABLE

This flag is used to mark dependencies that can be resolved with changing
value in target object. For example ticket can be created by user we can
change this reference when we delete user.

=cut

use constant {
    DEPENDS_ON => 0x001,
    WIPE_AFTER => 0x002,
    VARIABLE   => 0x004,
};

=head1 STATES

=head2 ON_STACK

Default state of object in Shredder cache that means that object is
loaded and placed into cache.

=head2 WIPED

Objects with this state are not exist any more in DB, but perl
object is still in memory. This state is used to be shure that
delete query is called once.

=cut

use constant {
    ON_STACK  => 0x000,
    IN_WIPING => 0x010,
    WIPED     => 0x020,
};

1;
