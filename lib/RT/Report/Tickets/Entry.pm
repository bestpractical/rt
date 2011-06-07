# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2013 Best Practical Solutions, LLC
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

package RT::Report::Tickets::Entry;

use warnings;
use strict;

use base qw/RT::Record/;

# XXX TODO: how the heck do we acl a report?
sub CurrentUserHasRight {1}

sub ColumnType {
    my $self = shift;
    my $column = shift;

    return $self->{'column_types'}{$column};
}


=head2 LabelValue

If you're pulling a value out of this collection and using it as a label,
you may want the "cleaned up" version.  This includes scrubbing 1970 dates
and ensuring that dates are in local not DB timezones.

=cut

sub LabelValue {
    my $self  = shift;
    my $name = shift;

    my $raw = $self->RawValue( $name, @_ );

    my $type = $self->ColumnType( $name );
    my $meta = $self->FieldMeta( $type->{'KEY'} );
    return $raw unless $meta && $meta->{'Display'};

    my $code;
    unless ( ref $meta->{'Display'} ) {
        $code = $self->can( $meta->{'Display'} );
        unless ( $code ) {
            $RT::Logger->error("No method ". $meta->{'Display'} );
            return $raw;
        }
    }
    elsif ( ref( $meta->{'Display'} ) eq 'CODE' ) {
        $code = $meta->{'Display'};
    }
    else {
        return $raw;
    }

    return $code->( $self, %$type, VALUE => $raw );
}

sub RawValue {
    return (shift)->__Value( @_ );
}

sub ObjectType {
    return 'RT::Ticket';
}

sub FieldMeta {
    my $self = shift;
    my $field = shift or return undef;

    %RT::Report::Tickets::GROUPINGS
        = @RT::Report::Tickets::GROUPINGS
        unless keys %RT::Report::Tickets::GROUPINGS;

    return $RT::Report::Tickets::GROUPINGS_META{
        $RT::Report::Tickets::GROUPINGS{ $field }
    };
}

RT::Base->_ImportOverlays();

1;
