# BEGIN LICENSE BLOCK
# 
#  Copyright (c) 2002 Jesse Vincent <jesse@bestpractical.com>
#  
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of version 2 of the GNU General Public License 
#  as published by the Free Software Foundation.
# 
#  A copy of that license should have arrived with this
#  software, but in any event can be snarfed from www.gnu.org.
# 
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
# 
# END LICENSE BLOCK

no warnings qw/redefine/;

=item LimitToParent ID

Limit the returned set of articles to articles which are children
of article ID.
This does not recurse.

=cut

sub LimitToParent {
    my $self   = shift;
    my $parent = shift;
    $self->Limit( FIELD    => 'Parent',
                  OPERATOR => '=',
                  VALUE    => $parent );

}

=item LimitToContent  HASH

Limit to Articles which currently have content satisfying 
Content HASH{'OPERATOR'} HASH{'VALUE'}

For example  OPERATOR => 'LIKE' , VALUE => 'crunchy frogs' would
find articles containing the string 'crunchy frogs'.

=cut

sub LimitToContent {
    my $self = shift;
    my %args = ( OPERATOR        => 'LIKE',
                 ENTRYAGGREGATOR => 'AND',
                 VALUE           => undef,
                 @_ );
    my $content_alias = $self->NewAlias('Content');

    $self->Join( ALIAS1 => 'main',
                 FIELD1 => 'Content',
                 ALIAS2 => $content_alias,
                 FIELD2 => 'id' );

    $self->Limit( ALIAS           => $content_alias,
                  FIELD           => 'Body',
                  ENTRYAGGREGATOR => $args{'ENTRYAGGREGATOR'},
                  OPERATOR        => $args{'OPERATOR'},
                  VALUE           => $args{'VALUE'} );
}

=item LimitToCustomFieldValue HASH

Limit the result set to articles which have or do not have the custom field 
value listed, using a left join to catch things where no rows match.

HASH needs the following fields: 
   FIELD (A custom field id)
   ENTRYAGGREGATOR => (AND, OR)
   OPERATOR ('=', 'LIKE', '!=', 'NOT LIKE')
   VALUE ( a single scalar value or a list of possible values to be concatenated with ENTRYAGGREGATOR)
   

=cut

sub LimitToCustomFieldValue {
    my $self = shift;
    my %args = ( FIELD           => undef,
                 ENTRYAGGREGATOR => 'OR',
                 OPERATOR        => '=',
                 VALUE           => undef,
                 @_ );

    #lets get all those values in an array. regardless of # of entries
    #we'll use this for adding and deleting keywords from this object.
    my @values =
      ref( $args{'VALUE'} ) ? @{ $args{'VALUE'} } : ( $args{'VALUE'} );

    my $ObjectValuesAlias = $self->Join( TYPE   => 'left',
                                         ALIAS1 => 'main',
                                         FIELD1 => 'id',
                                         TABLE2 => 'CustomFieldObjectValues',
                                         FIELD2 => 'Article' );

    $self->SUPER::Limit( LEFTJOIN        => $ObjectValuesAlias,
                         FIELD           => 'CustomField',
                         VALUE           => $args{'FIELD'},
                         ENTRYAGGREGATOR => 'OR' );

    foreach my $value (@values) {
        $self->SUPER::Limit( ALIAS           => $ObjectValuesAlias,
                             FIELD           => 'Content',
                             OPERATOR        => $args{'OPERATOR'},
                             VALUE           => $value,
                             QUOTEVALUE      => $args{'QUOTEVALUE'},
                             ENTRYAGGREGATOR => $args{'ENTRYAGGREGATOR'}, );

        #If we're trying to find articles where a custom field value doesn't match
        # something, be sure to find  things where it's null

        if ( $args{'OPERATOR'} eq '!=' ) {
            $self->SUPER::Limit( ALIAS           => $ObjectValuesAlias,
                                 FIELD           => 'Content',
                                 OPERATOR        => 'IS',
                                 VALUE           => 'NULL',
                                 QUOTEVALUE      => 0,
                                 ENTRYAGGREGATOR => 'OR', );
        }
    }

    $self->{'RecalcTicketLimits'} = 0;

}

# }}}

=head2 LimitRefersTo URI

Limit the result set to only articles which are referred to by the URI passed in.

=cut

sub LimitRefersTo {

    my $self = shift;
    my $uri  = shift;

    my $links = $self->NewAlias('Links');
    $self->Limit( ALIAS => $links,
                  FIELD => 'Target',
                  VALUE => $uri );

    $self->Join( ALIAS1 => 'main',
                 FIELD1 => 'URI',
                 ALIAS2 => $links,
                 FIELD2 => 'Base' );

}

=head2 LimitReferredToBy URI

Limit the result set to only articles which are referred to by the URI passed in.

=begin testing

use RT::FM::ArticleCollection;
my $ac = RT::FM::ArticleCollection->new($RT::SystemUser);
ok($ac->isa('RT::FM::ArticleCollection'));
ok($ac->isa('RT::FM::SearchBuilder'));
ok ($ac->isa('DBIx::SearchBuilder'));
ok ($ac->LimitReferredToBy('http://dead.link'));
ok ($ac->Count == 0);

=end testing



=cut

sub LimitReferredToBy {
    my $self = shift;
    my $uri  = shift;

    my $links = $self->NewAlias('Links');
    $self->Limit( ALIAS => $links,
                  FIELD => 'Base',
                  VALUE => $uri );

    $self->Join( ALIAS1 => 'main',
                 FIELD1 => 'URI',
                 ALIAS2 => $links,
                 FIELD2 => 'Target' );

}

1;
