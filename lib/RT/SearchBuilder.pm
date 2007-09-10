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
=head1 NAME

  RT::SearchBuilder - a baseclass for RT collection objects

=head1 SYNOPSIS

=head1 DESCRIPTION


=head1 METHODS




=cut

package RT::SearchBuilder;

use RT::Base;

use strict;
use base qw/RT::Base/;
use base qw/Jifty::DBI::Collection/;
use UNIVERSAL::require;

sub new {
    my $self = shift->SUPER::new();
    $self->_set_current_user(@_);
    $self->_init();
    return $self;
}

sub _handle {

    return RT->DatabaseHandle;
}

# {{{ sub _init 
sub _set_current_user  {
    my $self = shift;
    
    $self->{'user'} = shift;
    unless(defined($self->current_user)) {
	use Carp;
	Carp::confess("$self was Created without a CurrentUser");
	$RT::Logger->err("$self was Created without a CurrentUser");
	return(0);
    }
    $self->SUPER::_init( 'handle' => Jifty->handle);
}

=head2 LimitToEnabled

Only find items that haven't been disabled

=cut

sub LimitToEnabled {
    my $self = shift;
    
    $self->limit( column => 'Disabled',
		  value => '0',
		  operator => '=' );
}

=head2 LimitToDeleted

Only find items that have been deleted.

=cut

sub LimitToDeleted {
    my $self = shift;
    
    $self->{'find_disabled_rows'} = 1;
    $self->limit( column => 'Disabled',
		  operator => '=',
		  value => '1'
		);
}

=head2 LimitAttribute PARAMHASH

Takes NAME, operator and value to find records that has the
matching Attribute.

If EMPTY is set, also select rows with an empty string as
Attribute's Content.

If NULL is set, also select rows without the named Attribute.

=cut

my %Negate = qw(
    =		!=
    !=		=
    >		<=
    <		>=
    >=		<
    <=		>
    LIKE	NOT LIKE
    NOT LIKE	LIKE
    IS		IS NOT
    IS NOT	IS
);

sub LimitAttribute {
    my ($self, %args) = @_;
    my $clause = 'alias';
    my $operator = ($args{operator} || '=');
    
    if ($args{NULL} and exists $args{value}) {
	$clause = 'leftjoin';
	$operator = $Negate{$operator};
    }
    elsif ($args{NEGATE}) {
	$operator = $Negate{$operator};
    }
    
    my $alias = $self->join(
	type => 'left',
	alias1 => $args{alias} || 'main',
	column1 => 'id',
	table2 => 'Attributes',
	column2 => 'ObjectId'
    );

    my $type = ref($self);
    $type =~ s/(?:s|Collection)$//; # XXX - Hack!

    $self->limit(
	$clause	   => $alias,
	column      => 'ObjectType',
	operator   => '=',
	value      => $type,
    );
    $self->limit(
	$clause	   => $alias,
	column      => 'Name',
	operator   => '=',
	value      => $args{NAME},
    ) if exists $args{NAME};

    return unless exists $args{value};

    $self->limit(
	$clause	   => $alias,
	column      => 'Content',
	operator   => $operator,
	value      => $args{value},
    );

    # Capture rows with the attribute defined as an empty string.
    $self->limit(
	$clause    => $alias,
	column      => 'Content',
	operator   => '=',
	value      => '',
	entry_aggregator => $args{NULL} ? 'AND' : 'OR',
    ) if $args{EMPTY};

    # Capture rows without the attribute defined
    $self->limit(
	%args,
	alias      => $alias,
	column	   => 'id',
	operator   => ($args{NEGATE} ? 'IS NOT' : 'IS'),
	value      => 'NULL',
    ) if $args{NULL};
}

=head2 LimitCustomField

Takes a paramhash of key/value pairs with the following keys:

=over 4

=item customfield - CustomField id. Optional

=item operator - The usual Limit operators

=item value - The value to compare against

=back

=cut

sub _SingularClass {
    my $self = shift;
    my $class = ref($self);
    $class =~ s/Collection$// or die "Cannot deduce SingularClass for $class";
    return $class;
}

sub LimitCustomField {
    my $self = shift;
    my %args = ( value        => undef,
                 customfield  => undef,
                 operator     => '=',
                 @_ );

    my $alias = $self->join(
	type => 'left',
	alias1     => 'main',
	column1     => 'id',
	table2     => 'ObjectCustomFieldValues',
	column2     => 'ObjectId'
    );
    $self->limit(
	alias      => $alias,
	column      => 'CustomField',
	operator   => '=',
	value      => $args{'customfield'},
    ) if ($args{'customfield'});
    $self->limit(
	alias      => $alias,
	column      => 'ObjectType',
	operator   => '=',
	value      => $self->_SingularClass,
    );
    $self->limit(
	alias      => $alias,
	column      => 'Content',
	operator   => $args{'operator'},
	value      => $args{'value'},
    );
}

=head2 FindAllRows

Find all matching rows, regardless of whether they are disabled or not

=cut

sub FindAllRows {
    shift->{'find_disabled_rows'} = 1;
}

=head2 Limit PARAMHASH

This Limit sub calls SUPER::limit, but defaults "case_sensitive" to 1, thus
making sure that by default lots of things don't do extra work trying to 
match lower(colname) agaist lc($val);

=cut

sub limit {
    my $self = shift;
    my %args = (operator => '=',@_);
    $args{'operator'} =~ s/like/matches/i;
    return $self->SUPER::limit(case_sensitive => 1, %args);
}

# }}}

# {{{ sub items_order_by

=head2 items_order_by

If it has a SortOrder attribute, sort the array by SortOrder.
Otherwise, if it has a "Name" attribute, sort alphabetically by Name
Otherwise, just give up and return it in the order it came from the
db.

=cut

sub items_order_by {
    my $self = shift;
    my $items = shift;
  
    if ($self->new_item()->can('SortOrder')) {
        $items = [ sort { $a->SortOrder <=> $b->SortOrder } @{$items} ];
    }
    elsif ($self->new_item()->can('Name')) {
        $items = [ sort { lc($a->Name) cmp lc($b->Name) } @{$items} ];
    }

    return $items;
}

# }}}

# {{{ sub items_array_ref

=head2 items_array_ref

Return this object's ItemsArray, in the order that items_order_by sorts
it.


=cut

sub items_array_ref {
    my $self = shift;
    my @items;
    
    return $self->items_order_by($self->SUPER::items_array_ref());
}

# }}}

sub new_item {
    my $self  = shift;
    my $class = $self->record_class();

    die "Jifty::DBI::Collection needs to be subclassed; override new_item\n"
        unless $class;
    $class->require();
    return $class->new( $self->current_user);
}

1;


