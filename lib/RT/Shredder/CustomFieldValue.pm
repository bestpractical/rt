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
use RT::Model::CustomFieldValue ();

package RT::Model::CustomFieldValue;

use strict;
use warnings;
use warnings FATAL => 'redefine';

use RT::Shredder::Constants;
use RT::Shredder::Exceptions;
use RT::Shredder::Dependencies;

# No dependencies that should be deleted with record
# I should decide is TicketCustomFieldValue depends by this or not.
# Today I think no. What would be tomorrow I don't know.

sub __Relates {
    my $self = shift;
    my %args = (
        shredder     => undef,
        dependencies => undef,
        @_,
    );
    my $deps = $args{'dependencies'};
    my $list = [];

    my $obj = $self->custom_field_obj;
    if ( $obj && defined $obj->id ) {
        push( @$list, $obj );
    } else {
        my $rec = $args{'shredder'}->get_record( object => $self );
        $self = $rec->{'object'};
        $rec->{'state'} |= INVALID;
        $rec->{'description'}
            = "Have no related CustomField #" . $self->id . " object";
    }

    $deps->_push_dependencies(
        base_object   => $self,
        flags         => RELATES,
        target_objects => $list,
        shredder      => $args{'shredder'}
    );
    return $self->__relates(%args);
}

1;
