# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2011 Best Practical Solutions, LLC
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

use RT::Base;
use DBIx::SearchBuilder "1.40";

use strict;
use warnings;

use base qw(DBIx::SearchBuilder RT::Base);

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

=head2 LimitAttribute PARAMHASH

Takes NAME, OPERATOR and VALUE to find records that has the
matching Attribute.

If EMPTY is set, also select rows with an empty string as
Attribute's Content.

If NULL is set, also select rows without the named Attribute.

=cut

my %Negate = (
    '='        => '!=',
    '!='       => '=',
    '>'        => '<=',
    '<'        => '>=',
    '>='       => '<',
    '<='       => '>',
    'LIKE'     => 'NOT LIKE',
    'NOT LIKE' => 'LIKE',
    'IS'       => 'IS NOT',
    'IS NOT'   => 'IS',
);

sub LimitAttribute {
    my ($self, %args) = @_;
    my $clause = 'ALIAS';
    my $operator = ($args{OPERATOR} || '=');
    
    if ($args{NULL} and exists $args{VALUE}) {
	$clause = 'LEFTJOIN';
	$operator = $Negate{$operator};
    }
    elsif ($args{NEGATE}) {
	$operator = $Negate{$operator};
    }
    
    my $alias = $self->Join(
	TYPE   => 'left',
	ALIAS1 => $args{ALIAS} || 'main',
	FIELD1 => 'id',
	TABLE2 => 'Attributes',
	FIELD2 => 'ObjectId'
    );

    my $type = ref($self);
    $type =~ s/(?:s|Collection)$//; # XXX - Hack!

    $self->Limit(
	$clause	   => $alias,
	FIELD      => 'ObjectType',
	OPERATOR   => '=',
	VALUE      => $type,
    );
    $self->Limit(
	$clause	   => $alias,
	FIELD      => 'Name',
	OPERATOR   => '=',
	VALUE      => $args{NAME},
    ) if exists $args{NAME};

    return unless exists $args{VALUE};

    $self->Limit(
	$clause	   => $alias,
	FIELD      => 'Content',
	OPERATOR   => $operator,
	VALUE      => $args{VALUE},
    );

    # Capture rows with the attribute defined as an empty string.
    $self->Limit(
	$clause    => $alias,
	FIELD      => 'Content',
	OPERATOR   => '=',
	VALUE      => '',
	ENTRYAGGREGATOR => $args{NULL} ? 'AND' : 'OR',
    ) if $args{EMPTY};

    # Capture rows without the attribute defined
    $self->Limit(
	%args,
	ALIAS      => $alias,
	FIELD	   => 'id',
	OPERATOR   => ($args{NEGATE} ? 'IS NOT' : 'IS'),
	VALUE      => 'NULL',
    ) if $args{NULL};
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
    my $class = ref($self);
    $class =~ s/s$// or die "Cannot deduce SingularClass for $class";
    return $class;
}

sub LimitCustomField {
    my $self = shift;
    my %args = ( VALUE        => undef,
                 CUSTOMFIELD  => undef,
                 OPERATOR     => '=',
                 @_ );

    my $alias = $self->Join(
	TYPE       => 'left',
	ALIAS1     => 'main',
	FIELD1     => 'id',
	TABLE2     => 'ObjectCustomFieldValues',
	FIELD2     => 'ObjectId'
    );
    $self->Limit(
	ALIAS      => $alias,
	FIELD      => 'CustomField',
	OPERATOR   => '=',
	VALUE      => $args{'CUSTOMFIELD'},
    ) if ($args{'CUSTOMFIELD'});
    $self->Limit(
	ALIAS      => $alias,
	FIELD      => 'ObjectType',
	OPERATOR   => '=',
	VALUE      => $self->_SingularClass,
    );
    $self->Limit(
	ALIAS      => $alias,
	FIELD      => 'Content',
	OPERATOR   => $args{'OPERATOR'},
	VALUE      => $args{'VALUE'},
    );
}

=head2 Limit PARAMHASH

This Limit sub calls SUPER::Limit, but defaults "CASESENSITIVE" to 1, thus
making sure that by default lots of things don't do extra work trying to 
match lower(colname) agaist lc($val);

=cut

sub Limit {
    my $self = shift;
    my %args = ( CASESENSITIVE => 1,
                 @_ );

    return $self->SUPER::Limit(%args);
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
  
    if ($self->NewItem()->_Accessible('SortOrder','read')) {
        $items = [ sort { $a->SortOrder <=> $b->SortOrder } @{$items} ];
    }
    elsif ($self->NewItem()->_Accessible('Name','read')) {
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

eval "require RT::SearchBuilder_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/SearchBuilder_Vendor.pm});
eval "require RT::SearchBuilder_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/SearchBuilder_Local.pm});

1;
