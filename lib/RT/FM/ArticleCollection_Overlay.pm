# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2010 Best Practical Solutions, LLC
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
use strict;

package RT::FM::ArticleCollection;

no warnings qw/redefine/;

=head2 Next

Returns the next article that this user can see.

=cut

sub Next {
    my $self = shift;

    my $Object = $self->SUPER::Next();
    if ( ( defined($Object) ) and ( ref($Object) ) ) {

        if ( $Object->CurrentUserHasRight('ShowArticle') ) {
            return ($Object);
        }

        #If the user doesn't have the right to show this Object
        else {
            return ( $self->Next() );
        }
    }

    #if there never was any queue
    else {
        return (undef);
    }

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

=item LimitToParent ID

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

=item LimitCustomField HASH

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
                          ENTRYAGGREGATOR  => 'OR');
            $self->Limit(
                ALIAS => $fields,
                FIELD => 'LookupType',
                VALUE =>
                  RT::FM::Article->new($RT::SystemUser)->CustomFieldLookupType()
            );

        }
    }
    # If we're trying to find articles where a custom field value
    # doesn't match something, be sure to find things where it's null

    # basically, we do a left join on the value being applicable to
    # the article and then we turn around and make sure that it's
    # actually null in practise

    # TODO this should deal with starts with and ends with

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
            FIELD           => 'Largecontent',
            OPERATOR        => $args{'OPERATOR'},
            VALUE           => $value,
            QUOTEVALUE      => $args{'QUOTEVALUE'},
            ENTRYAGGREGATOR => $args{'ENTRYAGGREGATOR'},
            SUBCLAUSE       => $clause,
        );
        $self->SUPER::Limit(
            ALIAS           => $ObjectValuesAlias,
            FIELD           => 'Content',
            OPERATOR        => $args{'OPERATOR'},
            VALUE           => $value,
            QUOTEVALUE      => $args{'QUOTEVALUE'},
            ENTRYAGGREGATOR => $args{'ENTRYAGGREGATOR'},
            SUBCLAUSE       => $clause,
        );
    }
}

# }}}

# {{{ LimitTopics
sub LimitTopics {
    my $self   = shift;
    my @topics = @_;

    my $topics = $self->NewAlias('FM_ObjectTopics');
    $self->Limit(
        ALIAS           => $topics,
        FIELD           => 'Topic',
        VALUE           => $_,
        ENTRYAGGREGATOR => 'OR'
      )
      for @topics;

    $self->Limit(
        ALIAS => $topics,
        FIELD => 'ObjectType',
        VALUE => 'RT::FM::Article',
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

1;
