# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2023 Best Practical Solutions, LLC
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

package RT::Report::Entry;

use warnings;
use strict;

use base qw/RT::Record/;

=head1 NAME

RT::Report::Entry - Base class of each entry in RT search charts

=head1 DESCRIPTION

This class defines fundamental bits of code that each real entry in
search charts like L<RT::Report::Tickets::Entry> can subclass from.

Subclasses generally just need to follow the class name convension, e.g.
the entry class for L<RT::Report::Tickets> is L<RT::Report::Tickets::Entry>.

=head1 METHODS

=cut

# XXX TODO: how the heck do we acl a report?
sub CurrentUserHasRight {1}

# RT::Transactions::AddRecord calls CurrentUserCanSee
sub CurrentUserCanSee {1}

=head2 LabelValue

If you're pulling a value out of this collection and using it as a label,
you may want the "cleaned up" version.  This includes scrubbing 1970 dates
and ensuring that dates are in local not DB timezones.

=cut

sub LabelValue {
    my $self  = shift;
    my $name = shift;
    my $format = shift || 'text';

    my $raw = $self->RawValue( $name, @_ );
    if ( my $code = $self->Report->LabelValueCode( $name ) ) {
        $raw = $code->( $self, %{ $self->Report->ColumnInfo( $name ) }, VALUE => $raw, FORMAT => $format );
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
    my $self = shift;
    my $report_class = ref $self || $self;
    $report_class =~ s!::Entry$!!;
    return $report_class->_RoleGroupClass;
}

sub CustomFieldLookupType {
    my $self = shift;
    return $self->ObjectType->CustomFieldLookupType;
}

sub Query {
    my $self = shift;

    if ( my $ids = $self->{values}{ids} ) {
        return join ' OR ', map "id=$_", @$ids;
    }

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
                if ( $info->{INFO} eq 'Watcher' && $info->{FIELD} eq 'id' ) {

                    # convert id to name
                    my $princ = RT::Principal->new( $self->CurrentUser );
                    $princ->Load($value);
                    $value = $princ->Object->Name if $princ->Object;
                }

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

sub DurationValue {
    my $self  = shift;
    my $value = $self->__Value(@_);

    return 0 unless $value;

    my $number;
    my $unit;
    if ( $value =~ /([\d,]+)(?:s| second)/ ) {
        $number = $1;
        $unit = 1;
    }
    elsif ( $value =~ /([\d,]+)(?:m| minute)/ ) {
        $number = $1;
        $unit = $RT::Date::MINUTE;
    }
    elsif ( $value =~ /([\d,]+)(?:h| hour)/ ) {
        $number = $1;
        $unit = $RT::Date::HOUR;
    }
    elsif ( $value =~ /([\d,]+)(?:d| day)/ ) {
        $number = $1;
        $unit = $RT::Date::DAY;
    }
    elsif ( $value =~ /([\d,]+)(?:W| week)/ ) {
        $number = $1;
        $unit = $RT::Date::WEEK;
    }
    elsif ( $value =~ /([\d,]+)(?:M| month)/ ) {
        $number = $1;
        $unit = $RT::Date::MONTH;
    }
    elsif ( $value =~ /([\d,]+)(?:Y| year)/ ) {
        $number = $1;
        $unit = $RT::Date::YEAR;
    }
    else {
        return -.1; # Mark "(no value)" as -1 so it comes before 0
    }

    $number =~ s!,!!g;
    my $seconds = $number * $unit;

    if ( $value =~ /([<|>])/ ) {
        $seconds += $1 eq '<' ? -1 : 1;
    }
    return $seconds;
}

RT::Base->_ImportOverlays();

1;
