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

=head1 NAME

  RT::SearchBuilder - a baseclass for RT collection objects

=head1 SYNOPSIS

=head1 DESCRIPTION


=head1 METHODS




=cut

package RT::SearchBuilder;

use strict;
use warnings;
use 5.010;

use base qw(DBIx::SearchBuilder RT::Base);

use RT::Base;
use DBIx::SearchBuilder "1.40";

use Scalar::Util qw/blessed/;

sub _Init  {
    my $self = shift;
    
    $self->{'user'} = shift;
    unless(defined($self->CurrentUser)) {
        use Carp;
        Carp::confess("$self was created without a CurrentUser");
        $RT::Logger->err("$self was created without a CurrentUser");
        return(0);
    }
    $self->SUPER::_Init( 'Handle' => $RT::Handle);
}

sub _Handle { return $RT::Handle }

sub CleanSlate {
    my $self = shift;
    $self->{'_sql_aliases'} = {};
    delete $self->{'handled_disabled_column'};
    delete $self->{'find_disabled_rows'};
    return $self->SUPER::CleanSlate(@_);
}

sub Join {
    my $self = shift;
    my %args = @_;

    $args{'DISTINCT'} = 1 if
        !exists $args{'DISTINCT'}
        && $args{'TABLE2'} && lc($args{'FIELD2'}||'') eq 'id';

    return $self->SUPER::Join( %args );
}

sub JoinTransactions {
    my $self = shift;
    my %args = ( New => 0, @_ );

    return $self->{'_sql_aliases'}{'transactions'}
        if !$args{'New'} && $self->{'_sql_aliases'}{'transactions'};

    my $alias = $self->Join(
        ALIAS1 => 'main',
        FIELD1 => 'id',
        TABLE2 => 'Transactions',
        FIELD2 => 'ObjectId',
    );

    # NewItem is necessary here because of RT::Report::Tickets and RT::Report::Tickets::Entry
    my $item = $self->NewItem;
    my $object_type = $item->can('ObjectType') ? $item->ObjectType : ref $item;

    $self->RT::SearchBuilder::Limit(
        LEFTJOIN => $alias,
        FIELD    => 'ObjectType',
        VALUE    => $object_type,
    );
    $self->{'_sql_aliases'}{'transactions'} = $alias
        unless $args{'New'};

    return $alias;
}

sub _OrderByCF {
    my $self = shift;
    my ($row, $cfkey, $cf) = @_;

    $cfkey .= ".ordering" if !blessed($cf) || ($cf->MaxValues||0) != 1;
    my ($ocfvs, $CFs) = $self->_CustomFieldJoin( $cfkey, $cf );
    # this is described in _LimitCustomField
    $self->Limit(
        ALIAS      => $CFs,
        FIELD      => 'Name',
        OPERATOR   => 'IS NOT',
        VALUE      => 'NULL',
        ENTRYAGGREGATOR => 'AND',
        SUBCLAUSE  => ".ordering",
    ) if $CFs;
    my $CFvs = $self->Join(
        TYPE   => 'LEFT',
        ALIAS1 => $ocfvs,
        FIELD1 => 'CustomField',
        TABLE2 => 'CustomFieldValues',
        FIELD2 => 'CustomField',
    );
    $self->Limit(
        LEFTJOIN        => $CFvs,
        FIELD           => 'Name',
        QUOTEVALUE      => 0,
        VALUE           => "$ocfvs.Content",
        ENTRYAGGREGATOR => 'AND'
    );

    return { %$row, ALIAS => $CFvs,  FIELD => 'SortOrder' },
           { %$row, ALIAS => $ocfvs, FIELD => 'Content' };
}

sub OrderByCols {
    my $self = shift;
    my @sort;
    for my $s (@_) {
        next if defined $s->{FIELD} and $s->{FIELD} =~ /\W/;
        $s->{FIELD} = $s->{FUNCTION} if $s->{FUNCTION};
        push @sort, $s;
    }
    return $self->SUPER::OrderByCols( @sort );
}

# If we're setting RowsPerPage or FirstRow, ensure we get a natural number or undef.
sub RowsPerPage {
    my $self = shift;
    return if @_ and defined $_[0] and $_[0] =~ /\D/;
    return $self->SUPER::RowsPerPage(@_);
}

sub FirstRow {
    my $self = shift;
    return if @_ and defined $_[0] and $_[0] =~ /\D/;
    return $self->SUPER::FirstRow(@_);
}

=head2 LimitToEnabled

Only find items that haven't been disabled

=cut

sub LimitToEnabled {
    my $self = shift;

    $self->{'handled_disabled_column'} = 1;
    $self->Limit( FIELD => 'Disabled', VALUE => '0' );
}

=head2 LimitToDeleted

Only find items that have been deleted.

=cut

sub LimitToDeleted {
    my $self = shift;

    $self->{'handled_disabled_column'} = $self->{'find_disabled_rows'} = 1;
    $self->Limit( FIELD => 'Disabled', VALUE => '1' );
}

=head2 FindAllRows

Find all matching rows, regardless of whether they are disabled or not

=cut

sub FindAllRows {
    shift->{'find_disabled_rows'} = 1;
}

=head2 LimitCustomField

Takes a paramhash of key/value pairs with the following keys:

=over 4

=item CUSTOMFIELD - CustomField id. Optional

=item OPERATOR - The usual Limit operators

=item VALUE - The value to compare against

=back

=cut

sub _SingularClass {
    my $self = shift;
    my $class = ref($self) || $self;
    $class =~ s/s$// or die "Cannot deduce SingularClass for $class";
    return $class;
}

=head2 RecordClass

Returns class name of records in this collection. This generic implementation
just strips trailing 's'.

=cut

sub RecordClass {
    $_[0]->_SingularClass
}

=head2 RegisterCustomFieldJoin

Takes a pair of arguments, the first a class name and the second a callback
function.  The class will be used to call
L<RT::Record/CustomFieldLookupType>.  The callback will be called when
limiting a collection of the caller's class by a CF of the passed class's
lookup type.

The callback is passed a single argument, the current collection object (C<$self>).

An example from L<RT::Tickets>:

    __PACKAGE__->RegisterCustomFieldJoin(
        "RT::Transaction" => sub { $_[0]->JoinTransactions }
    );

Returns true on success, undef on failure.

=cut

sub RegisterCustomFieldJoin {
    my $class = shift;
    my ($type, $callback) = @_;

    $type = $type->CustomFieldLookupType if $type;

    die "Unknown LookupType '$type'"
        unless $type and grep { $_ eq $type } RT::CustomField->LookupTypes;

    die "Custom field join callbacks must be CODE references"
        unless ref($callback) eq 'CODE';

    warn "Another custom field join callback is already registered for '$type'"
        if $class->_JOINS_FOR_LOOKUP_TYPES->{$type};

    # Stash the callback on ourselves
    $class->_JOINS_FOR_LOOKUP_TYPES->{ $type } = $callback;

    return 1;
}

=head2 _JoinForLookupType

Takes an L<RT::CustomField> LookupType and joins this collection as
appropriate to reach the object records to which LookupType applies.  The
object records will be of the class returned by
L<RT::CustomField/ObjectTypeFromLookupType>.

Returns the join alias suitable for further limiting against object
properties.

Returns undef on failure.

Used by L</_CustomFieldJoin>.

=cut

sub _JoinForLookupType {
    my $self = shift;
    my $type = shift or return;

    # Convenience shortcut so that classes don't need to register a handler
    # for their native lookup type
    return "main" if $type eq $self->RecordClass->CustomFieldLookupType
        and grep { $_ eq $type } RT::CustomField->LookupTypes;

    my $JOINS = $self->_JOINS_FOR_LOOKUP_TYPES;
    return $JOINS->{$type}->($self)
        if ref $JOINS->{$type} eq 'CODE';

    return;
}

sub _JOINS_FOR_LOOKUP_TYPES {
    my $class = blessed($_[0]) || $_[0];
    state %JOINS;
    return $JOINS{$class} ||= {};
}

=head2 _CustomFieldJoin

Factor out the Join of custom fields so we can use it for sorting too

=cut

sub _CustomFieldJoin {
    my ($self, $cfkey, $cf, $type) = @_;
    $type ||= $self->RecordClass->CustomFieldLookupType;

    # Perform one Join per CustomField
    if ( $self->{_sql_object_cfv_alias}{$cfkey} ||
         $self->{_sql_cf_alias}{$cfkey} )
    {
        return ( $self->{_sql_object_cfv_alias}{$cfkey},
                 $self->{_sql_cf_alias}{$cfkey} );
    }

    my $ObjectAlias = $self->_JoinForLookupType($type)
        or die "We don't know how to join for LookupType $type";

    my ($ocfvalias, $CFs);
    if ( blessed($cf) ) {
        $ocfvalias = $self->{_sql_object_cfv_alias}{$cfkey} = $self->Join(
            TYPE   => 'LEFT',
            ALIAS1 => $ObjectAlias,
            FIELD1 => 'id',
            TABLE2 => 'ObjectCustomFieldValues',
            FIELD2 => 'ObjectId',
            $cf->SingleValue? (DISTINCT => 1) : (),
        );
        $self->Limit(
            LEFTJOIN        => $ocfvalias,
            FIELD           => 'CustomField',
            VALUE           => $cf->id,
            ENTRYAGGREGATOR => 'AND'
        );
    }
    else {
        ($ocfvalias, $CFs) = $self->_CustomFieldJoinByName( $ObjectAlias, $cf, $type );
        $self->{_sql_cf_alias}{$cfkey} = $CFs;
        $self->{_sql_object_cfv_alias}{$cfkey} = $ocfvalias;
    }
    $self->Limit(
        LEFTJOIN        => $ocfvalias,
        FIELD           => 'ObjectType',
        VALUE           => RT::CustomField->ObjectTypeFromLookupType($type),
        ENTRYAGGREGATOR => 'AND'
    );
    $self->Limit(
        LEFTJOIN        => $ocfvalias,
        FIELD           => 'Disabled',
        OPERATOR        => '=',
        VALUE           => '0',
        ENTRYAGGREGATOR => 'AND'
    );

    return ($ocfvalias, $CFs);
}

sub _CustomFieldJoinByName {
    my $self = shift;
    my ($ObjectAlias, $cf, $type) = @_;
    my $ocfalias = $self->Join(
        TYPE       => 'LEFT',
        EXPRESSION => q|'0'|,
        TABLE2     => 'ObjectCustomFields',
        FIELD2     => 'ObjectId',
    );

    my $CFs = $self->Join(
        TYPE       => 'LEFT',
        ALIAS1     => $ocfalias,
        FIELD1     => 'CustomField',
        TABLE2     => 'CustomFields',
        FIELD2     => 'id',
    );
    $self->Limit(
        LEFTJOIN        => $CFs,
        ENTRYAGGREGATOR => 'AND',
        FIELD           => 'LookupType',
        VALUE           => $type,
    );
    $self->Limit(
        LEFTJOIN        => $CFs,
        ENTRYAGGREGATOR => 'AND',
        FIELD           => 'Name',
        CASESENSITIVE   => 0,
        VALUE           => $cf,
    );

    my $ocfvalias = $self->Join(
        TYPE   => 'LEFT',
        ALIAS1 => $CFs,
        FIELD1 => 'id',
        TABLE2 => 'ObjectCustomFieldValues',
        FIELD2 => 'CustomField',
    );
    $self->Limit(
        LEFTJOIN        => $ocfvalias,
        FIELD           => 'ObjectId',
        VALUE           => "$ObjectAlias.id",
        QUOTEVALUE      => 0,
        ENTRYAGGREGATOR => 'AND',
    );

    return ($ocfvalias, $CFs, $ocfalias);
}

sub LimitCustomField {
    my $self = shift;
    return $self->_LimitCustomField( @_ );
}

use Regexp::Common qw(RE_net_IPv4);
use Regexp::Common::net::CIDR;

sub _LimitCustomField {
    my $self = shift;
    my %args = ( VALUE        => undef,
                 CUSTOMFIELD  => undef,
                 OPERATOR     => '=',
                 KEY          => undef,
                 PREPARSE     => 1,
                 @_ );

    my $op     = delete $args{OPERATOR};
    my $value  = delete $args{VALUE};
    my $ltype  = delete $args{LOOKUPTYPE} || $self->RecordClass->CustomFieldLookupType;
    my $cf     = delete $args{CUSTOMFIELD};
    my $column = delete $args{COLUMN};
    my $cfkey  = delete $args{KEY};
    if (blessed($cf) and $cf->id) {
        $cfkey ||= $cf->id;
    } elsif ($cf =~ /^\d+$/) {
        # Intentionally load as the system user, so we can build better
        # queries; this is necessary as we don't have a context object
        # which might grant the user rights to see the CF.  This object
        # is only used to inspect the properties of the CF itself.
        my $obj = RT::CustomField->new( RT->SystemUser );
        $obj->Load($cf);
        if ($obj->id) {
            $cf = $obj;
            $cfkey ||= $cf->id;
        } else {
            $cfkey ||= "$ltype-$cf";
        }
    } else {
        $cfkey ||= "$ltype-$cf";
    }

    $args{SUBCLAUSE} ||= "cf-$cfkey";


    my $fix_op = sub {
        return @_ unless RT->Config->Get('DatabaseType') eq 'Oracle';

        my %args = @_;
        return %args unless $args{'FIELD'} eq 'LargeContent';

        my $op = $args{'OPERATOR'};
        if ( $op eq '=' ) {
            $args{'OPERATOR'} = 'MATCHES';
        }
        elsif ( $op eq '!=' ) {
            $args{'OPERATOR'} = 'NOT MATCHES';
        }
        elsif ( $op =~ /^[<>]=?$/ ) {
            $args{'FUNCTION'} = "TO_CHAR( $args{'ALIAS'}.LargeContent )";
        }
        return %args;
    };

    # Special Limit (we can exit early)
    # IS NULL and IS NOT NULL checks
    if ( $op =~ /^IS( NOT)?$/i ) {
        my ($ocfvalias, $CFs) = $self->_CustomFieldJoin( $cfkey, $cf, $ltype );
        $self->_OpenParen( $args{SUBCLAUSE} );
        $self->Limit(
            %args,
            ALIAS    => $ocfvalias,
            FIELD    => ($column || 'id'),
            OPERATOR => $op,
            VALUE    => $value,
        );
        # See below for an explanation of this limit
        $self->Limit(
            ALIAS      => $CFs,
            FIELD      => 'Name',
            OPERATOR   => 'IS NOT',
            VALUE      => 'NULL',
            ENTRYAGGREGATOR => 'AND',
            SUBCLAUSE  => $args{SUBCLAUSE},
        ) if $CFs;
        $self->_CloseParen( $args{SUBCLAUSE} );
        return;
    }

    ########## Content pre-parsing if we know things about the CF
    if ( blessed($cf) and delete $args{PREPARSE} ) {
        my $type = $cf->Type;
        if ( $type eq 'IPAddress' ) {
            my $parsed = RT::ObjectCustomFieldValue->ParseIP($value);
            if ($parsed) {
                $value = $parsed;
            } else {
                $RT::Logger->warn("$value is not a valid IPAddress");
            }
        } elsif ( $type eq 'IPAddressRange' ) {
            my ( $start_ip, $end_ip ) =
              RT::ObjectCustomFieldValue->ParseIPRange($value);
            if ( $start_ip && $end_ip ) {
                if ( $op =~ /^<=?$/ ) {
                    $value = $start_ip;
                } elsif ($op =~ /^>=?$/ ) {
                    $value = $end_ip;
                } else {
                    $value = join '-', $start_ip, $end_ip;
                }
            } else {
                $RT::Logger->warn("$value is not a valid IPAddressRange");
            }

            # Recurse if they want a range comparison
            if ( $op !~ /^[<>]=?$/ ) {
                my ($start_ip, $end_ip) = split /-/, $value;
                $self->_OpenParen( $args{SUBCLAUSE} );
                # Ideally we would limit >= 000.000.000.000 and <=
                # 255.255.255.255 so DB optimizers could use better
                # estimations and scan less rows, but this breaks with IPv6.
                if ( $op !~ /NOT|!=|<>/i ) { # positive equation
                    $self->_LimitCustomField(
                        %args,
                        OPERATOR    => '<=',
                        VALUE       => $end_ip,
                        LOOKUPTYPE  => $ltype,
                        CUSTOMFIELD => $cf,
                        COLUMN      => 'Content',
                        PREPARSE    => 0,
                    );
                    $self->_LimitCustomField(
                        %args,
                        OPERATOR    => '>=',
                        VALUE       => $start_ip,
                        LOOKUPTYPE  => $ltype,
                        CUSTOMFIELD => $cf,
                        COLUMN      => 'LargeContent',
                        ENTRYAGGREGATOR => 'AND',
                        PREPARSE    => 0,
                    );
                } else { # negative equation
                    $self->_LimitCustomField(
                        %args,
                        OPERATOR    => '>',
                        VALUE       => $end_ip,
                        LOOKUPTYPE  => $ltype,
                        CUSTOMFIELD => $cf,
                        COLUMN      => 'Content',
                        PREPARSE    => 0,
                    );
                    $self->_LimitCustomField(
                        %args,
                        OPERATOR    => '<',
                        VALUE       => $start_ip,
                        LOOKUPTYPE  => $ltype,
                        CUSTOMFIELD => $cf,
                        COLUMN      => 'LargeContent',
                        ENTRYAGGREGATOR => 'OR',
                        PREPARSE    => 0,
                    );
                }
                $self->_CloseParen( $args{SUBCLAUSE} );
                return;
            }
        } elsif ( $type =~ /^Date(?:Time)?$/ ) {
            my $date = RT::Date->new( $self->CurrentUser );
            $date->Set( Format => 'unknown', Value => $value );
            if ( $date->IsSet ) {
                if (
                       $type eq 'Date'
                           # Heuristics to determine if a date, and not
                           # a datetime, was entered:
                    || $value =~ /^\s*(?:today|tomorrow|yesterday)\s*$/i
                    || (   $value !~ /midnight|\d+:\d+:\d+/i
                        && $date->Time( Timezone => 'user' ) eq '00:00:00' )
                  )
                {
                    $value = $date->Date( Timezone => 'user' );
                } else {
                    $value = $date->DateTime;
                }
            } else {
                $RT::Logger->warn("$value is not a valid date string");
            }

            # Recurse if day equality is being checked on a datetime
            if ( $type eq 'DateTime' and $op eq '=' && $value !~ /:/ ) {
                my $date = RT::Date->new( $self->CurrentUser );
                $date->Set( Format => 'unknown', Value => $value );
                my $daystart = $date->ISO;
                $date->AddDay;
                my $dayend = $date->ISO;

                $self->_OpenParen( $args{SUBCLAUSE} );
                $self->_LimitCustomField(
                    %args,
                    OPERATOR        => ">=",
                    VALUE           => $daystart,
                    LOOKUPTYPE      => $ltype,
                    CUSTOMFIELD     => $cf,
                    COLUMN          => 'Content',
                    ENTRYAGGREGATOR => 'AND',
                    PREPARSE        => 0,
                );

                $self->_LimitCustomField(
                    %args,
                    OPERATOR        => "<",
                    VALUE           => $dayend,
                    LOOKUPTYPE      => $ltype,
                    CUSTOMFIELD     => $cf,
                    COLUMN          => 'Content',
                    ENTRYAGGREGATOR => 'AND',
                    PREPARSE        => 0,
                );
                $self->_CloseParen( $args{SUBCLAUSE} );
                return;
            }
        }
    }

    ########## Limits

    my $single_value = !blessed($cf) || $cf->SingleValue;
    my $negative_op = ($op eq '!=' || $op =~ /\bNOT\b/i);
    my $value_is_long = (length( Encode::encode( "UTF-8", $value)) > 255) ? 1 : 0;

    $cfkey .= '.'. $self->{'_sql_multiple_cfs_index'}++
        if not $single_value and $op =~ /^(!?=|(NOT )?LIKE)$/i;
    my ($ocfvalias, $CFs) = $self->_CustomFieldJoin( $cfkey, $cf, $ltype );

    # A negative limit on a multi-value CF means _none_ of the values
    # are the given value
    if ( $negative_op and not $single_value ) {
        # Reverse the limit we apply to the join, and check IS NULL
        $op =~ s/!|NOT\s+//i;

        # Ideally we would check both Content and LargeContent here, as
        # the positive searches do below -- however, we cannot place
        # complex limits inside LEFTJOINs due to searchbuilder
        # limitations.  Guessing which to check based on the value's
        # string length is sufficient for !=, but sadly insufficient for
        # NOT LIKE checks, giving false positives.
        $column ||= $value_is_long ? 'LargeContent' : 'Content';
        $self->Limit( $fix_op->(
            LEFTJOIN   => $ocfvalias,
            ALIAS      => $ocfvalias,
            FIELD      => $column,
            OPERATOR   => $op,
            VALUE      => $value,
            CASESENSITIVE => 0,
        ) );
        $self->Limit(
            %args,
            ALIAS      => $ocfvalias,
            FIELD      => 'id',
            OPERATOR   => 'IS',
            VALUE      => 'NULL',
        );
        return;
    }

    # If column is defined, then we just search it that, with no magic
    if ( $column ) {
        $self->_OpenParen( $args{SUBCLAUSE} );
        $self->Limit( $fix_op->(
            %args,
            ALIAS      => $ocfvalias,
            FIELD      => $column,
            OPERATOR   => $op,
            VALUE      => $value,
            CASESENSITIVE => 0,
        ) );
        $self->Limit(
            ALIAS           => $ocfvalias,
            FIELD           => $column,
            OPERATOR        => 'IS',
            VALUE           => 'NULL',
            ENTRYAGGREGATOR => 'OR',
            SUBCLAUSE       => $args{SUBCLAUSE},
        ) if $negative_op;
        $self->_CloseParen( $args{SUBCLAUSE} );
        return;
    }

    $self->_OpenParen( $args{SUBCLAUSE} ); # For negative_op "OR it is null" clause
    $self->_OpenParen( $args{SUBCLAUSE} ); # NAME IS NOT NULL clause

    $self->_OpenParen( $args{SUBCLAUSE} ); # Check Content / LargeContent
    if ($value_is_long and $op eq "=") {
        # Doesn't matter what Content contains, as it cannot match the
        # too-long value; we just look in LargeContent, below.
    } elsif ($value_is_long and $op =~ /^(!=|<>)$/) {
        # If Content is non-null, that's a valid way to _not_ contain the too-long value.
        $self->Limit(
            %args,
            ALIAS    => $ocfvalias,
            FIELD    => 'Content',
            OPERATOR => 'IS NOT',
            VALUE    => 'NULL',
        );
    } else {
        # Otherwise, go looking at the Content
        $self->Limit(
            %args,
            ALIAS    => $ocfvalias,
            FIELD    => 'Content',
            OPERATOR => $op,
            VALUE    => $value,
            CASESENSITIVE => 0,
        );
    }

    if (!$value_is_long and $op eq "=") {
        # Doesn't matter what LargeContent contains, as it cannot match
        # the short value.
    } elsif (!$value_is_long and $op =~ /^(!=|<>)$/) {
        # If LargeContent is non-null, that's a valid way to _not_
        # contain the too-short value.
        $self->Limit(
            %args,
            ALIAS    => $ocfvalias,
            FIELD    => 'LargeContent',
            OPERATOR => 'IS NOT',
            VALUE    => 'NULL',
            ENTRYAGGREGATOR => 'OR',
        );
    } else {
        $self->_OpenParen( $args{SUBCLAUSE} ); # LargeContent check
        $self->_OpenParen( $args{SUBCLAUSE} ); # Content is null?
        $self->Limit(
            ALIAS           => $ocfvalias,
            FIELD           => 'Content',
            OPERATOR        => '=',
            VALUE           => '',
            ENTRYAGGREGATOR => 'OR',
            SUBCLAUSE       => $args{SUBCLAUSE},
        );
        $self->Limit(
            ALIAS           => $ocfvalias,
            FIELD           => 'Content',
            OPERATOR        => 'IS',
            VALUE           => 'NULL',
            ENTRYAGGREGATOR => 'OR',
            SUBCLAUSE       => $args{SUBCLAUSE},
        );
        $self->_CloseParen( $args{SUBCLAUSE} ); # Content is null?
        $self->Limit( $fix_op->(
            ALIAS           => $ocfvalias,
            FIELD           => 'LargeContent',
            OPERATOR        => $op,
            VALUE           => $value,
            ENTRYAGGREGATOR => 'AND',
            SUBCLAUSE       => $args{SUBCLAUSE},
            CASESENSITIVE => 0,
        ) );
        $self->_CloseParen( $args{SUBCLAUSE} ); # LargeContent check
    }

    $self->_CloseParen( $args{SUBCLAUSE} ); # Check Content/LargeContent

    # XXX: if we join via CustomFields table then
    # because of order of left joins we get NULLs in
    # CF table and then get nulls for those records
    # in OCFVs table what result in wrong results
    # as decifer method now tries to load a CF then
    # we fall into this situation only when there
    # are more than one CF with the name in the DB.
    # the same thing applies to order by call.
    # TODO: reorder joins T <- OCFVs <- CFs <- OCFs if
    # we want treat IS NULL as (not applies or has
    # no value)
    $self->Limit(
        ALIAS           => $CFs,
        FIELD           => 'Name',
        OPERATOR        => 'IS NOT',
        VALUE           => 'NULL',
        ENTRYAGGREGATOR => 'AND',
        SUBCLAUSE       => $args{SUBCLAUSE},
    ) if $CFs;
    $self->_CloseParen( $args{SUBCLAUSE} ); # Name IS NOT NULL clause

    # If we were looking for != or NOT LIKE, we need to include the
    # possibility that the row had no value.
    $self->Limit(
        ALIAS           => $ocfvalias,
        FIELD           => 'id',
        OPERATOR        => 'IS',
        VALUE           => 'NULL',
        ENTRYAGGREGATOR => 'OR',
        SUBCLAUSE       => $args{SUBCLAUSE},
    ) if $negative_op;
    $self->_CloseParen( $args{SUBCLAUSE} ); # negative_op clause
}

=head2 Limit PARAMHASH

This Limit sub calls SUPER::Limit, but defaults "CASESENSITIVE" to 1, thus
making sure that by default lots of things don't do extra work trying to 
match lower(colname) agaist lc($val);

We also force VALUE to C<NULL> when the OPERATOR is C<IS> or C<IS NOT>.
This ensures that we don't pass invalid SQL to the database or allow SQL
injection attacks when we pass through user specified values.

=cut

my %check_case_sensitivity = (
    groups => { 'name' => 1, domain => 1 },
    queues => { 'name' => 1 },
    users => { 'name' => 1, emailaddress => 1 },
    customfields => { 'name' => 1 },
);

my %deprecated = (
);

sub Limit {
    my $self = shift;
    my %ARGS = (
        OPERATOR => '=',
        @_,
    );

    # We use the same regex here that DBIx::SearchBuilder uses to exclude
    # values from quoting
    if ( $ARGS{'OPERATOR'} =~ /IS/i ) {
        # Don't pass anything but NULL for IS and IS NOT
        $ARGS{'VALUE'} = 'NULL';
    }

    if (($ARGS{FIELD}||'') =~ /\W/
          or $ARGS{OPERATOR} !~ /^(=|<|>|!=|<>|<=|>=
                                  |(NOT\s*)?LIKE
                                  |(NOT\s*)?(STARTS|ENDS)WITH
                                  |(NOT\s*)?MATCHES
                                  |IS(\s*NOT)?
                                  |(NOT\s*)?IN
                                  |\@\@
                                  |AGAINST)$/ix) {
        $RT::Logger->crit("Possible SQL injection attack: $ARGS{FIELD} $ARGS{OPERATOR}");
        %ARGS = (
            %ARGS,
            FIELD    => 'id',
            OPERATOR => '<',
            VALUE    => '0',
        );
    }

    my $table;
    ($table) = $ARGS{'ALIAS'} && $ARGS{'ALIAS'} ne 'main'
        ? ($ARGS{'ALIAS'} =~ /^(.*)_\d+$/)
        : $self->Table
    ;

    if ( $table and $ARGS{FIELD} and my $instead = $deprecated{ lc $table }{ lc $ARGS{'FIELD'} } ) {
        RT->Deprecated(
            Message => "$table.$ARGS{'FIELD'} column is deprecated",
            Instead => $instead, Remove => '4.6'
        );
    }

    unless ( exists $ARGS{CASESENSITIVE} or (exists $ARGS{QUOTEVALUE} and not $ARGS{QUOTEVALUE}) ) {
        if ( $ARGS{FIELD} and $ARGS{'OPERATOR'} !~ /IS/i
            && $table && $check_case_sensitivity{ lc $table }{ lc $ARGS{'FIELD'} }
        ) {
            RT->Logger->warning(
                "Case sensitive search by $table.$ARGS{'FIELD'}"
                ." at ". (caller)[1] . " line ". (caller)[2]
            );
        }
        $ARGS{'CASESENSITIVE'} = 1;
    }

    return $self->SUPER::Limit( %ARGS );
}

=head2 ItemsOrderBy

If it has a SortOrder attribute, sort the array by SortOrder.
Otherwise, if it has a "Name" attribute, sort alphabetically by Name
Otherwise, just give up and return it in the order it came from the
db.

=cut

sub ItemsOrderBy {
    my $self = shift;
    my $items = shift;
  
    if ($self->RecordClass->_Accessible('SortOrder','read')) {
        $items = [ sort { $a->SortOrder <=> $b->SortOrder } @{$items} ];
    }
    elsif ($self->RecordClass->_Accessible('Name','read')) {
        $items = [ sort { lc($a->Name) cmp lc($b->Name) } @{$items} ];
    }

    return $items;
}

=head2 ItemsArrayRef

Return this object's ItemsArray, in the order that ItemsOrderBy sorts
it.

=cut

sub ItemsArrayRef {
    my $self = shift;
    return $self->ItemsOrderBy($self->SUPER::ItemsArrayRef());
}

# make sure that Disabled rows never get seen unless
# we're explicitly trying to see them.

sub _DoSearch {
    my $self = shift;

    if ( $self->{'with_disabled_column'}
        && !$self->{'handled_disabled_column'}
        && !$self->{'find_disabled_rows'}
    ) {
        $self->LimitToEnabled;
    }
    return $self->SUPER::_DoSearch(@_);
}
sub _DoCount {
    my $self = shift;

    if ( $self->{'with_disabled_column'}
        && !$self->{'handled_disabled_column'}
        && !$self->{'find_disabled_rows'}
    ) {
        $self->LimitToEnabled;
    }
    return $self->SUPER::_DoCount(@_);
}

=head2 ColumnMapClassName

ColumnMap needs a Collection name to load the correct list display.
Depluralization is hard, so provide an easy way to correct the naive
algorithm that this code uses.

=cut

sub ColumnMapClassName {
    my $self  = shift;
    my $Class = $self->_SingularClass;
       $Class =~ s/:/_/g;
    return $Class;
}

=head2 NewItem

Returns a new item based on L</RecordClass> using the current user.

=cut

sub NewItem {
    my $self = shift;
    return $self->RecordClass->new($self->CurrentUser);
}

=head2 NotSetDateToNullFunction

Takes a paramhash with an optional FIELD key whose value is the name of a date
column.  If no FIELD is provided, a literal C<?> placeholder is used so the
caller can fill in the field later.

Returns a SQL function which evaluates to C<NULL> if the FIELD is set to the
Unix epoch; otherwise it evaluates to FIELD.  This is useful because RT
currently stores unset dates as a Unix epoch timestamp instead of NULL, but
NULLs are often more desireable.

=cut

sub NotSetDateToNullFunction {
    my $self = shift;
    my %args = ( FIELD => undef, @_ );

    my $res = "CASE WHEN ? BETWEEN '1969-12-31 11:59:59' AND '1970-01-01 12:00:01' THEN NULL ELSE ? END";
    if ( $args{FIELD} ) {
        $res = $self->CombineFunctionWithField( %args, FUNCTION => $res );
    }
    return $res;
}

RT::Base->_ImportOverlays();

1;
