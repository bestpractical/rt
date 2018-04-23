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

package RT::Report::Tickets::Entry;

use warnings;
use strict;

use base qw/RT::Record/;

# XXX TODO: how the heck do we acl a report?
sub CurrentUserHasRight {1}

=head2 LabelValue

If you're pulling a value out of this collection and using it as a label,
you may want the "cleaned up" version.  This includes scrubbing 1970 dates
and ensuring that dates are in local not DB timezones.

=cut

sub LabelValue {
    my $self  = shift;
    my $name = shift;

    my $raw = $self->RawValue( $name, @_ );

    if ( my $code = $self->Report->LabelValueCode( $name ) ) {
        $raw = $code->( $self, %{ $self->Report->ColumnInfo( $name ) }, VALUE => $raw );
        return $self->loc('(no value)') unless defined $raw && length $raw;
        return $raw;
    }

    unless ( ref $raw ) {
        return $self->loc('(no value)') unless defined $raw && length $raw;
        return $self->loc($raw) if $self->Report->ColumnInfo( $name )->{'META'}{'Localize'};
        return $raw;
    } else {
        my $loc = $self->Report->ColumnInfo( $name )->{'META'}{'Localize'};
        my %res = %$raw;
        if ( $loc ) {
            $res{ $self->loc($_) } = delete $res{ $_ } foreach keys %res;
            $_ = $self->loc($_) foreach values %res;
        }
        $_ = $self->loc('(no value)') foreach grep !defined || !length, values %res;
        return \%res;
    }
}

sub RawValue {
    return (shift)->__Value( @_ );
}

sub ObjectType {
    return 'RT::Ticket';
}

sub CustomFieldLookupType {
    RT::Ticket->CustomFieldLookupType
}

sub Query {
    my $self = shift;

    my @parts;
    foreach my $column ( $self->Report->ColumnsList ) {
        my $info = $self->Report->ColumnInfo( $column );
        next unless $info->{'TYPE'} eq 'grouping';

        my $custom = $info->{'META'}{'Query'};
        if ( $custom and my $code = $self->Report->FindImplementationCode( $custom ) ) {
            push @parts, $code->( $self, COLUMN => $column, %$info );
        }
        else {
            my $field = join '.', grep $_, $info->{KEY}, $info->{SUBKEY};
            my $value = $self->RawValue( $column );
            my $op = '=';
            if ( defined $value ) {
                unless ( $value =~ /^\d+$/ ) {
                    $value =~ s/(['\\])/\\$1/g;
                    $value = "'$value'";
                }
            }
            else {
                ($op, $value) = ('IS', 'NULL');
            }
            unless ( $field =~ /^[{}\w\.]+$/ ) {
                $field =~ s/(['\\])/\\$1/g;
                $field = "'$field'";
            }
            push @parts, "$field $op $value";
        }
    }
    return () unless @parts;
    return join ' AND ', map "($_)", grep defined && length, @parts;
}

sub Report {
    return $_[0]->{'report'};
}

RT::Base->_ImportOverlays();

1;
