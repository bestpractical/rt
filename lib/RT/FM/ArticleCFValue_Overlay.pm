# BEGIN LICENSE BLOCK
# 
#  Copyright (c) 2002-2003 Jesse Vincent <jesse@bestpractical.com>
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

use strict;

use RT::FM::ArticleCollection;

use Text::WikiFormat;
%RT::FM::WikiTags = (

);





=head2 Create { } 

    add a custom field value to an article

    takes a param hash


        Article   The id of the article we're adding to
        CustomField  The id of the custom field we're working with
        Content     The content of the custom field value we're adding
                    It's either a scalar or a b<single part> MIME object




=cut



sub Create {
    my $self = shift;
    my %args = ( Content     => '',
                 Article     => undef,
                 CustomField => undef,
                 @_ );


    # {{{ Validate the article
    my $art = RT::FM::Article->new( $self->CurrentUser );
    $art->Load( $args{'Article'} );
    unless ( $art->Id ) {
        return ( 0, $self->loc("Invalid article") );
    }

    # }}}
    # {{{ Validate the custom field
    my $cf = RT::FM::CustomField->new($self->CurrentUser);
    $cf->Load( $args{'CustomField'} );
    unless ( $cf->Id ) {
        return ( 0, $self->loc("Custom field not found") );
    }


    # }}}
# {{{ Validate the content



    unless ( defined $args{'Content'} ) {
        return ( 0, $self->loc("Content not set") );
    }

    # If this custom field is a "select from a list" 
    # make sure that we're not supplying invalid values
    unless ( $cf->ValidateValueForArticle( Value => $args{'Content'}, Article => $args{'Article'} ) ) {
        return ( 0, $self->loc("[_1] is an invalid value for custom field [_2] for article [_3]", $args{'Content'}, $cf->Name, $args{'Article'}) );
    }
    # }}}

    my $ret = $self->SUPER::Create(%args);
    return ($ret, $self->loc("Value added"));
 }


sub WikiFormattedContent {
    my $self = shift;
    my %wiki_options = (
        prefix => 'Display.html?Class='.$self->ArticleObj->ClassObj->id.'&Name=',
        extended => '1'
 );

  return Text::WikiFormat::format($self->Content , \%RT::FM::WikiTags, \%wiki_options);
    

}


1;

