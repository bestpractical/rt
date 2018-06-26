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

package RT::CustomFieldValues::External;

use strict;
use warnings;

use base qw(RT::CustomFieldValues);

=head1 NAME

RT::CustomFieldValues::External - Pull possible values for a custom
field from an arbitrary external data source.

=head1 SYNOPSIS

Custom field value lists can be produced by creating a class that
inherits from C<RT::CustomFieldValues::External>, and overloading
C<SourceDescription> and C<ExternalValues>.  See
L<RT::CustomFieldValues::Groups> for a simple example.

=head1 DESCRIPTION

Subclasses should implement the following methods:

=head2 SourceDescription

This method should return a string describing the data source; this is
the identifier by which the user will see the dropdown.

=head2 ExternalValues

This method should return an array reference of hash references.  The
hash references must contain a key for C<name> and can optionally contain
keys for C<description>, C<sortorder>, and C<category>. If supplying a
category, you must also set the category the custom field is based on in
the custom field configuration page.

=head1 SEE ALSO

F<docs/extending/external_custom_fields.pod>

=cut

sub _Init {
    my $self = shift;
    $self->Table( '' );
    return ( $self->SUPER::_Init(@_) );
}

sub CleanSlate {
    my $self = shift;
    delete $self->{ $_ } foreach qw(
        __external_cf
        __external_cf_limits
    );
    return $self->SUPER::CleanSlate(@_);
}

sub _ClonedAttributes {
    my $self = shift;
    return qw(
        __external_cf
        __external_cf_limits
    ), $self->SUPER::_ClonedAttributes;
}

sub Limit {
    my $self = shift;
    my %args = (@_);
    push @{ $self->{'__external_cf_limits'} ||= [] }, {
        %args,
        CALLBACK => $self->__BuildLimitCheck( %args ),
    };
    return $self->SUPER::Limit( %args );
}

sub __BuildLimitCheck {
    my ($self, %args) = (@_);
    return undef unless $args{'FIELD'} =~ /^(?:Name|Description)$/;

    my $condition = $args{VALUE};
    my $op = $args{'OPERATOR'} || '=';
    my $field = $args{FIELD};

    return sub {
        my $record = shift;
        my $value = $record->$field;
        return 0 unless defined $value;
        if ($op eq "=") {
            return 0 unless $value eq $condition;
        } elsif ($op eq "!=" or $op eq "<>") {
            return 0 unless $value ne $condition;
        } elsif (uc($op) eq "LIKE") {
            return 0 unless $value =~ /\Q$condition\E/i;
        } elsif (uc($op) eq "NOT LIKE") {
            return 0 unless $value !~ /\Q$condition\E/i;
        } else {
            return 0;
        }
        return 1;
    };
}

sub __BuildAggregatorsCheck {
    my $self = shift;
    my @cbs = grep {$_->{CALLBACK}} @{ $self->{'__external_cf_limits'} };
    return undef unless @cbs;

    my %h = (
        OR  => sub { defined $_[0] ? ($_[0] || $_[1]) : $_[1] },
        AND => sub { defined $_[0] ? ($_[0] && $_[1]) : $_[1] },
    );

    return sub {
        my ($sb, $record) = @_;
        my $ok;
        for my $limit ( @cbs ) {
            $ok = $h{$limit->{ENTRYAGGREGATOR} || 'OR'}->(
                $ok, $limit->{CALLBACK}->($record),
            );
        }
        return $ok;
    };
}

sub _DoSearch {
    my $self = shift;

    delete $self->{'items'};

    my %defaults = (
            id => 1,
            name => '',
            customfield => $self->{'__external_cf'},
            sortorder => 0,
            description => '',
            category => undef,
            creator => RT->SystemUser->id,
            created => undef,
            lastupdatedby => RT->SystemUser->id,
            lastupdated => undef,
    );

    my $i = 0;

    my $check = $self->__BuildAggregatorsCheck;
    foreach( @{ $self->ExternalValues } ) {
        my $value = $self->NewItem;
        $value->LoadFromHash( { %defaults, %$_ } );
        next if $check && !$check->( $self, $value );
        $self->AddRecord( $value );
        last if $self->RowsPerPage and ++$i >= $self->RowsPerPage;
    }
    $self->{'must_redo_search'} = 0;
    return $self->_RecordCount;
}

sub _DoCount {
    my $self = shift;

    my $count;
    $count = $self->_DoSearch if $self->{'must_redo_search'};
    $count = $self->_RecordCount unless defined $count;

    return $self->{'count_all'} = $self->{'raw_rows'} = $count;
}

sub LimitToCustomField {
    my $self = shift;
    $self->{'__external_cf'} = $_[0];
    return $self->SUPER::LimitToCustomField( @_ );
}

sub _SingularClass {
    "RT::CustomFieldValue"
}

RT::Base->_ImportOverlays();

1;
