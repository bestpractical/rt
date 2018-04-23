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

use strict;
use warnings;

package RT::Articles;

use base 'RT::SearchBuilder';

sub Table {'Articles'}

sub _Init {
    my $self = shift;
    $self->{'with_disabled_column'} = 1;
    $self->OrderByCols(
        { FIELD => 'SortOrder', ORDER => 'ASC' },
        { FIELD => 'Name',      ORDER => 'ASC' },
    );
    return $self->SUPER::_Init( @_ );
}

=head2 AddRecord

Overrides the collection to ensure that only Articles the user can see
are returned.

=cut

sub AddRecord {
    my $self = shift;
    my ($record) = @_;

    return unless $record->CurrentUserHasRight('ShowArticle');
    return $self->SUPER::AddRecord( $record );
}

=head2 Limit { FIELD  => undef, OPERATOR => '=', VALUE => 'undef'} 

Limit the result set. See DBIx::SearchBuilder docs
In addition to the "normal" stuff, value can be an array.

=cut

sub Limit {
    my $self = shift;
    my %ARGS = (
        OPERATOR => '=',
        @_
    );

    if ( ref( $ARGS{'VALUE'} ) ) {
        my @values = $ARGS{'VALUE'};
        delete $ARGS{'VALUE'};
        foreach my $v (@values) {
            $self->SUPER::Limit( %ARGS, VALUE => $v );
        }
    }
    else {
        $self->SUPER::Limit(%ARGS);
    }
}

=head2 LimitName  { OPERATOR => 'LIKE', VALUE => undef } 

Find all articles with Name fields which satisfy OPERATOR for VALUE

=cut

sub LimitName {
    my $self = shift;

    my %args = (
        FIELD         => 'Name',
        OPERATOR      => 'LIKE',
        CASESENSITIVE => 0,
        VALUE         => undef,
        @_
    );

    $self->Limit(%args);

}

=head2 LimitSummary  { OPERATOR => 'LIKE', VALUE => undef } 

Find all articles with summary fields which satisfy OPERATOR for VALUE

=cut

sub LimitSummary {
    my $self = shift;

    my %args = (
        FIELD         => 'Summary',
        OPERATOR      => 'LIKE',
        CASESENSITIVE => 0,
        VALUE         => undef,
        @_
    );

    $self->Limit(%args);

}

sub LimitCreated {
    my $self = shift;
    my %args = (
        FIELD    => 'Created',
        OPERATOR => undef,
        VALUE    => undef,
        @_
    );

    $self->Limit(%args);

}

sub LimitCreatedBy {
    my $self = shift;
    my %args = (
        FIELD    => 'CreatedBy',
        OPERATOR => '=',
        VALUE    => undef,
        @_
    );

    $self->Limit(%args);

}

sub LimitUpdated {

    my $self = shift;
    my %args = (
        FIELD    => 'Updated',
        OPERATOR => undef,
        VALUE    => undef,
        @_
    );

    $self->Limit(%args);

}

sub LimitUpdatedBy {
    my $self = shift;
    my %args = (
        FIELD    => 'UpdatedBy',
        OPERATOR => '=',
        VALUE    => undef,
        @_
    );

    $self->Limit(%args);

}

# {{{ LimitToParent ID

=head2 LimitToParent ID

Limit the returned set of articles to articles which are children
of article ID.
This does not recurse.

=cut

sub LimitToParent {
    my $self   = shift;
    my $parent = shift;
    $self->Limit(
        FIELD    => 'Parent',
        OPERATOR => '=',
        VALUE    => $parent
    );

}

# }}}
# {{{ LimitCustomField

=head2 LimitCustomField HASH

Limit the result set to articles which have or do not have the custom field 
value listed, using a left join to catch things where no rows match.

HASH needs the following fields: 
   FIELD (A custom field id) or undef for any custom field
   ENTRYAGGREGATOR => (AND, OR)
   OPERATOR ('=', 'LIKE', '!=', 'NOT LIKE')
   VALUE ( a single scalar value or a list of possible values to be concatenated with ENTRYAGGREGATOR)

The subclause that the LIMIT statement(s) should be done in can also
be passed in with a SUBCLAUSE parameter.

=cut

sub LimitCustomField {
    my $self = shift;
    my %args = (
        FIELD           => undef,
        ENTRYAGGREGATOR => 'OR',
        OPERATOR        => '=',
        QUOTEVALUE      => 1,
        VALUE           => undef,
        SUBCLAUSE       => undef,
        @_
    );

    my $value = $args{'VALUE'};
    # XXX: this work in a different way than RT
    return unless $value;    #strip out total blank wildcards

    my $ObjectValuesAlias = $self->Join(
        TYPE   => 'left',
        ALIAS1 => 'main',
        FIELD1 => 'id',
        TABLE2 => 'ObjectCustomFieldValues',
        FIELD2 => 'ObjectId',
        EXPRESSION => 'main.id'
    );

    $self->Limit(
        LEFTJOIN => $ObjectValuesAlias,
        FIELD    => 'Disabled',
        VALUE    => '0'
    );

    if ( $args{'FIELD'} ) {

        my $field_id;
        if (UNIVERSAL::isa($args{'FIELD'} ,'RT::CustomField')) {
            $field_id = $args{'FIELD'}->id;
        } elsif($args{'FIELD'} =~ /^\d+$/) {
            $field_id = $args{'FIELD'};
        }
        if ($field_id) {
            $self->Limit( LEFTJOIN        => $ObjectValuesAlias,
                          FIELD           => 'CustomField',
                          VALUE           => $field_id,
                          ENTRYAGGREGATOR => 'AND');
            # Could convert the above to a non-left join and also enable the thing below
            # $self->SUPER::Limit( ALIAS           => $ObjectValuesAlias,
            #                      FIELD           => 'CustomField',
            #                      OPERATOR        => 'IS',
            #                      VALUE           => 'NULL',
            #                      QUOTEVALUE      => 0,
            #                      ENTRYAGGREGATOR => 'OR',);
        } else {
            # Search for things by name if the cf was specced by name.
            my $fields = $self->NewAlias('CustomFields');
            $self->Join( TYPE => 'left',
                         ALIAS1 => $ObjectValuesAlias , FIELD1 => 'CustomField',
                         ALIAS2 => $fields, FIELD2=> 'id');
            $self->Limit( ALIAS => $fields,
                          FIELD => 'Name',
                          VALUE => $args{'FIELD'},
                          ENTRYAGGREGATOR  => 'OR',
                          CASESENSITIVE => 0);
            $self->Limit(
                ALIAS => $fields,
                FIELD => 'LookupType',
                VALUE =>
                  RT::Article->new($RT::SystemUser)->CustomFieldLookupType()
            );

        }
    }
    # If we're trying to find articles where a custom field value
    # doesn't match something, be sure to find things where it's null

    # basically, we do a left join on the value being applicable to
    # the article and then we turn around and make sure that it's
    # actually null in practise

    # TODO this should deal with starts with and ends with

    my $fix_op = sub {
        my $op = shift;
        return $op unless RT->Config->Get('DatabaseType') eq 'Oracle';
        return 'MATCHES' if $op eq '=';
        return 'NOT MATCHES' if $op eq '!=';
        return $op;
    };

    my $clause = $args{'SUBCLAUSE'} || $ObjectValuesAlias;
    
    if ( $args{'OPERATOR'} eq '!=' || $args{'OPERATOR'} =~ /^not like$/i ) {
        my $op;
        if ( $args{'OPERATOR'} eq '!=' ) {
            $op = "=";
        }
        elsif ( $args{'OPERATOR'} =~ /^not like$/i ) {
            $op = 'LIKE';
        }

        $self->SUPER::Limit(
            LEFTJOIN        => $ObjectValuesAlias,
            FIELD           => 'Content',
            OPERATOR        => $op,
            VALUE           => $value,
            QUOTEVALUE      => $args{'QUOTEVALUE'},
            ENTRYAGGREGATOR => 'AND', #$args{'ENTRYAGGREGATOR'},
            SUBCLAUSE       => $clause,
            CASESENSITIVE   => 0,
        );
        $self->SUPER::Limit(
            ALIAS           => $ObjectValuesAlias,
            FIELD           => 'Content',
            OPERATOR        => 'IS',
            VALUE           => 'NULL',
            QUOTEVALUE      => 0,
            ENTRYAGGREGATOR => 'AND',
            SUBCLAUSE       => $clause,
        );
    }
    else {
        $self->SUPER::Limit(
            ALIAS           => $ObjectValuesAlias,
            FIELD           => 'LargeContent',
            OPERATOR        => $fix_op->($args{'OPERATOR'}),
            VALUE           => $value,
            QUOTEVALUE      => $args{'QUOTEVALUE'},
            ENTRYAGGREGATOR => $args{'ENTRYAGGREGATOR'},
            SUBCLAUSE       => $clause,
            CASESENSITIVE   => 0,
        );
        $self->SUPER::Limit(
            ALIAS           => $ObjectValuesAlias,
            FIELD           => 'Content',
            OPERATOR        => $args{'OPERATOR'},
            VALUE           => $value,
            QUOTEVALUE      => $args{'QUOTEVALUE'},
            ENTRYAGGREGATOR => $args{'ENTRYAGGREGATOR'},
            SUBCLAUSE       => $clause,
            CASESENSITIVE   => 0,
        );
    }
}

# }}}

# {{{ LimitTopics
sub LimitTopics {
    my $self   = shift;
    my @topics = @_;
    return unless @topics;

    my $topics = $self->NewAlias('ObjectTopics');
    $self->Limit(
        ALIAS    => $topics,
        FIELD    => 'Topic',
        OPERATOR => 'IN',
        VALUE    => [ @topics ],
    );

    $self->Limit(
        ALIAS => $topics,
        FIELD => 'ObjectType',
        VALUE => 'RT::Article',
    );
    $self->Join(
        ALIAS1 => 'main',
        FIELD1 => 'id',
        ALIAS2 => $topics,
        FIELD2 => 'ObjectId',
    );
}

# }}}

# {{{ LimitRefersTo URI

=head2 LimitRefersTo URI

Limit the result set to only articles which are referred to by the URI passed in.

=cut

sub LimitRefersTo {
    my $self = shift;
    my $uri  = shift;

    my $uri_obj = RT::URI->new($self->CurrentUser);
    $uri_obj->FromURI($uri);   
    my $links = $self->NewAlias('Links');
    $self->Limit(
        ALIAS => $links,
        FIELD => 'Target',
        VALUE => $uri_obj->URI
    );

    $self->Join(
        ALIAS1 => 'main',
        FIELD1 => 'URI',
        ALIAS2 => $links,
        FIELD2 => 'Base'
    );

}

# }}}

# {{{ LimitReferredToBy URI

=head2 LimitReferredToBy URI

Limit the result set to only articles which are referred to by the URI passed in.

=cut

sub LimitReferredToBy {
    my $self = shift;
    my $uri  = shift;

    my $uri_obj = RT::URI->new($self->CurrentUser);
    $uri_obj->FromURI($uri);    
    my $links = $self->NewAlias('Links');
    $self->Limit(
        ALIAS => $links,
        FIELD => 'Base',
        VALUE => $uri_obj->URI
    );

    $self->Join(
        ALIAS1 => 'main',
        FIELD1 => 'URI',
        ALIAS2 => $links,
        FIELD2 => 'Target'
    );

}

# }}}

=head2 LimitHostlistClasses

Only fetch Articles from classes where Hotlist is true.

=cut

sub LimitHotlistClasses {
    my $self = shift;

    my $classes = $self->Join(
        ALIAS1 => 'main',
        FIELD1 => 'Class',
        TABLE2 => 'Classes',
        FIELD2 => 'id',
    );
    $self->Limit( ALIAS => $classes, FIELD => 'HotList', VALUE => 1 );
}

=head2 LimitAppliedClasses Queue => QueueObj

Takes a Queue and limits articles returned to classes which are applied to that Queue

Accepts either a Queue obj or a Queue id

=cut

sub LimitAppliedClasses {
    my $self = shift;
    my %args = @_;

    unless (ref $args{Queue} || $args{Queue} =~/^[0-9]+$/) {
        $RT::Logger->error("Not a valid Queue: $args{Queue}");
        return;
    }

    my $queue = ( ref $args{Queue} ? $args{Queue}->Id : $args{Queue} );

    my $oc_alias = $self->Join(
        ALIAS1 => 'main',
        FIELD1 => 'Class',
        TABLE2 => 'ObjectClasses',
        FIELD2 => 'Class'
    );

    my $subclause = "possibleobjectclasses";
    $self->_OpenParen($subclause);
    $self->Limit( ALIAS => $oc_alias,
                  FIELD => 'ObjectId',
                  VALUE => $queue,
                  SUBCLAUSE => $subclause,
                  ENTRYAGGREGATOR => 'OR' );
    $self->Limit( ALIAS => $oc_alias,
                  FIELD => 'ObjectType',
                  VALUE => 'RT::Queue',
                  SUBCLAUSE => $subclause,
                  ENTRYAGGREGATOR => 'AND' );
    $self->_CloseParen($subclause);

    $self->_OpenParen($subclause);
    $self->Limit( ALIAS => $oc_alias,
                  FIELD => 'ObjectId',
                  VALUE => 0,
                  SUBCLAUSE => $subclause,
                  ENTRYAGGREGATOR => 'OR' );
    $self->Limit( ALIAS => $oc_alias,
                  FIELD => 'ObjectType',
                  VALUE => 'RT::System',
                  SUBCLAUSE => $subclause,
                  ENTRYAGGREGATOR => 'AND' );
    $self->_CloseParen($subclause);

    return $self;

}

sub Search {
    my $self     = shift;
    my %args     = @_;
    my $customfields = $args{CustomFields}
      || RT::CustomFields->new( $self->CurrentUser );
    my $dates = $args{Dates} || {};
    my $order_by = $args{OrderBy};
    my $order = $args{Order};
    if ( $args{'q'} ) {
        $self->Limit(
            FIELD           => 'Name',
            SUBCLAUSE       => 'NameOrSummary',
            OPERATOR        => 'LIKE',
            ENTRYAGGREGATOR => 'OR',
            CASESENSITIVE   => 0,
            VALUE           => $args{'q'}
        );
        $self->Limit(
            FIELD           => 'Summary',
            SUBCLAUSE       => 'NameOrSummary',
            OPERATOR        => 'LIKE',
            ENTRYAGGREGATOR => 'OR',
            CASESENSITIVE   => 0,
            VALUE           => $args{'q'}
        );
    }


    foreach my $date (qw(Created< Created> LastUpdated< LastUpdated>)) {
        next unless ( $args{$date} );
        my $date_obj = RT::Date->new( $self->CurrentUser );
        $date_obj->Set( Format => 'unknown', Value => $args{$date} );
        $dates->{$date} = $date_obj;

        if ( $date =~ /^(.*?)<$/i ) {
            $self->Limit(
                FIELD           => $1,
                OPERATOR        => "<=",
                ENTRYAGGREGATOR => "AND",
                VALUE           => $date_obj->ISO
            );
        }

        if ( $date =~ /^(.*?)>$/i ) {
            $self->Limit(
                FIELD           => $1,
                OPERATOR        => ">=",
                ENTRYAGGREGATOR => "AND",
                VALUE           => $date_obj->ISO
            );
        }

    }

    if ($args{'RefersTo'}) {
        foreach my $link ( split( /\s+/, $args{'RefersTo'} ) ) {
            next unless ($link);
            $self->LimitRefersTo($link);
        }
    }

    if ($args{'ReferredToBy'}) {
        foreach my $link ( split( /\s+/, $args{'ReferredToBy'} ) ) {
            next unless ($link);
            $self->LimitReferredToBy($link);
        }
    }

    if ( $args{'Topics'} ) {
        my @Topics =
          ( ref $args{'Topics'} eq 'ARRAY' )
          ? @{ $args{'Topics'} }
          : ( $args{'Topics'} );
        @Topics = map { split } @Topics;
        if ( $args{'ExpandTopics'} ) {
            my %topics;
            while (@Topics) {
                my $id = shift @Topics;
                next if $topics{$id};
                my $Topics =
                  RT::Topics->new( $self->CurrentUser );
                $Topics->Limit( FIELD => 'Parent', VALUE => $id );
                push @Topics, $_->Id while $_ = $Topics->Next;
                $topics{$id}++;
            }
            @Topics = keys %topics;
            $args{'Topics'} = \@Topics;
        }
        $self->LimitTopics(@Topics);
    }

    my %cfs;
    $customfields->LimitToLookupType(
        RT::Article->new( $self->CurrentUser )
          ->CustomFieldLookupType );
    if ( $args{'Class'} ) {
        my @Classes =
          ( ref $args{'Class'} eq 'ARRAY' )
          ? @{ $args{'Class'} }
          : ( $args{'Class'} );
        foreach my $class (@Classes) {
            $customfields->LimitToGlobalOrObjectId($class);
        }
    }
    else {
        $customfields->LimitToGlobalOrObjectId();
    }
    while ( my $cf = $customfields->Next ) {
        $cfs{ $cf->Name } = $cf->Id;
    }

    # reset the iterator because we use this to build the UI
    $customfields->GotoFirstItem;

    foreach my $field ( keys %cfs ) {

        my @MatchLike =
          ( ref $args{ $field . "~" } eq 'ARRAY' )
          ? @{ $args{ $field . "~" } }
          : ( $args{ $field . "~" } );
        my @NoMatchLike =
          ( ref $args{ $field . "!~" } eq 'ARRAY' )
          ? @{ $args{ $field . "!~" } }
          : ( $args{ $field . "!~" } );

        my @Match =
          ( ref $args{$field} eq 'ARRAY' )
          ? @{ $args{$field} }
          : ( $args{$field} );
        my @NoMatch =
          ( ref $args{ $field . "!" } eq 'ARRAY' )
          ? @{ $args{ $field . "!" } }
          : ( $args{ $field . "!" } );

        foreach my $val (@MatchLike) {
            next unless $val;
            push @Match, "~" . $val;
        }

        foreach my $val (@NoMatchLike) {
            next unless $val;
            push @NoMatch, "~" . $val;
        }

        foreach my $value (@Match) {
            next unless $value;
            my $op;
            if ( $value =~ /^~(.*)$/ ) {
                $value = "%$1%";
                $op    = 'LIKE';
            }
            else {
                $op = '=';
            }
            $self->LimitCustomField(
                FIELD           => $cfs{$field},
                VALUE           => $value,
                CASESENSITIVE   => 0,
                ENTRYAGGREGATOR => 'OR',
                OPERATOR        => $op
            );
        }
        foreach my $value (@NoMatch) {
            next unless $value;
            my $op;
            if ( $value =~ /^~(.*)$/ ) {
                $value = "%$1%";
                $op    = 'NOT LIKE';
            }
            else {
                $op = '!=';
            }
            $self->LimitCustomField(
                FIELD           => $cfs{$field},
                VALUE           => $value,
                CASESENSITIVE   => 0,
                ENTRYAGGREGATOR => 'OR',
                OPERATOR        => $op
            );
        }
    }

### Searches for any field

    if ( $args{'Article~'} ) {
        $self->LimitCustomField(
            VALUE           => $args{'Article~'},
            ENTRYAGGREGATOR => 'OR',
            OPERATOR        => 'LIKE',
            CASESENSITIVE   => 0,
            SUBCLAUSE       => 'SearchAll'
        );
        $self->Limit(
            SUBCLAUSE       => 'SearchAll',
            FIELD           => "Name",
            VALUE           => $args{'Article~'},
            ENTRYAGGREGATOR => 'OR',
            CASESENSITIVE   => 0,
            OPERATOR        => 'LIKE'
        );
        $self->Limit(
            SUBCLAUSE       => 'SearchAll',
            FIELD           => "Summary",
            VALUE           => $args{'Article~'},
            ENTRYAGGREGATOR => 'OR',
            CASESENSITIVE   => 0,
            OPERATOR        => 'LIKE'
        );
    }

    if ( $args{'Article!~'} ) {
        $self->LimitCustomField(
            VALUE         => $args{'Article!~'},
            OPERATOR      => 'NOT LIKE',
            CASESENSITIVE => 0,
            SUBCLAUSE     => 'SearchAll'
        );
        $self->Limit(
            SUBCLAUSE       => 'SearchAll',
            FIELD           => "Name",
            VALUE           => $args{'Article!~'},
            ENTRYAGGREGATOR => 'AND',
            CASESENSITIVE   => 0,
            OPERATOR        => 'NOT LIKE'
        );
        $self->Limit(
            SUBCLAUSE       => 'SearchAll',
            FIELD           => "Summary",
            VALUE           => $args{'Article!~'},
            ENTRYAGGREGATOR => 'AND',
            CASESENSITIVE   => 0,
            OPERATOR        => 'NOT LIKE'
        );
    }

    foreach my $field (qw(Name Summary Class)) {

        my @MatchLike =
          ( ref $args{ $field . "~" } eq 'ARRAY' )
          ? @{ $args{ $field . "~" } }
          : ( $args{ $field . "~" } );
        my @NoMatchLike =
          ( ref $args{ $field . "!~" } eq 'ARRAY' )
          ? @{ $args{ $field . "!~" } }
          : ( $args{ $field . "!~" } );

        my @Match =
          ( ref $args{$field} eq 'ARRAY' )
          ? @{ $args{$field} }
          : ( $args{$field} );
        my @NoMatch =
          ( ref $args{ $field . "!" } eq 'ARRAY' )
          ? @{ $args{ $field . "!" } }
          : ( $args{ $field . "!" } );

        foreach my $val (@MatchLike) {
            next unless $val;
            push @Match, "~" . $val;
        }

        foreach my $val (@NoMatchLike) {
            next unless $val;
            push @NoMatch, "~" . $val;
        }

        my $op;
        foreach my $value (@Match) {
            if ( $value && $value =~ /^~(.*)$/ ) {
                $value = "%$1%";
                $op    = 'LIKE';
            }
            else {
                $op = '=';
            }

            # preprocess Classes, so we can search on class
            if ( $field eq 'Class' && $value ) {
                my $class = RT::Class->new($RT::SystemUser);
                $class->Load($value);
                $value = $class->Id;
            }

            # now that we've pruned the value, get out if it's different.
            next unless $value;

            $self->Limit(
                SUBCLAUSE       => $field . 'Match',
                FIELD           => $field,
                OPERATOR        => $op,
                CASESENSITIVE   => 0,
                VALUE           => $value,
                ENTRYAGGREGATOR => 'OR'
            );

        }
        foreach my $value (@NoMatch) {

            # preprocess Classes, so we can search on class
            if ( $value && $value =~ /^~(.*)/ ) {
                $value = "%$1%";
                $op    = 'NOT LIKE';
            }
            else {
                $op = '!=';
            }
            if ( $field eq 'Class' ) {
                my $class = RT::Class->new($RT::SystemUser);
                $class->Load($value);
                $value = $class->Id;
            }

            # now that we've pruned the value, get out if it's different.
            next unless $value;

            $self->Limit(
                SUBCLAUSE       => $field . 'NoMatch',
                OPERATOR        => $op,
                VALUE           => $value,
                CASESENSITIVE   => 0,
                FIELD           => $field,
                ENTRYAGGREGATOR => 'AND'
            );

        }
    }

    if ($order_by && @$order_by) {
        if ( $order_by->[0] && $order_by->[0] =~ /\|/ ) {
            @$order_by = split '|', $order_by->[0];
            @$order   = split '|', $order->[0];
        }
        my @tmp =
          map { { FIELD => $order_by->[$_], ORDER => $order->[$_] } } 0 .. $#{$order_by};
        $self->OrderByCols(@tmp);
    }

    return 1;
}

RT::Base->_ImportOverlays();

1;
