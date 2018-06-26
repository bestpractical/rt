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

package RT::URI::fsck_com_article;

use strict;
use warnings;
no warnings 'redefine';

use base qw/RT::URI::base/;
use RT::Article;

=head2 LocalURIPrefix 

Returns the prefix for a local article URI

=cut

sub LocalURIPrefix {
    my $self = shift;
    my $prefix = $self->Scheme. "://". RT->Config->Get('Organization');
    return ($prefix);
}

=head2 URIForObject RT::article

Returns the RT URI for a local RT::article object

=cut

sub URIForObject {

    my $self = shift;

    my $obj = shift;
    return ($self->LocalURIPrefix . "/article/" . $obj->Id);
}


=head2 ParseObject $ArticleObj

When handed an L<RT::Article> object, figure out its URI

=cut

=head2 ParseURI URI

When handed an fsck.com-article URI, figures out things like whether its a local article
and what its ID is

=cut

sub ParseURI { 
    my $self = shift;
    my $uri = shift;

    my $article;

    if ($uri =~ /^(\d+)$/) {
        $article = RT::Article->new($self->CurrentUser);
        $article->Load($uri);
        $self->{'uri'} = $article->URI;
    }
    else {
        $self->{'uri'} = $uri;
    }

       #If it's a local URI, load the article object and return its URI
    if ( $self->IsLocal) {
        my $local_uri_prefix = $self->LocalURIPrefix;
        if ($self->{'uri'} =~ /^$local_uri_prefix\/article\/(\d+)$/) {
            my $id = $1;
            $article = RT::Article->new( $self->CurrentUser );
            my ($ret, $msg) = $article->Load($id);

            #If we couldn't find a article, return undef.
            unless ( $article and $article->Id ) {
                # We got an id, but couldn't load it, so warn that it may
                # have been deleted.
                RT::Logger->warning("Unable to load article for id $id. It may"
                    . " have been deleted: $msg");
                return undef;
            }
        } else {
            return undef;
        }
    }

    #If we couldn't find a article, return undef.
    unless ( $article and $article->Id ) {
        return undef;
    }

    $self->{'object'} = $article;
    return ($article->Id);
}

=head2 IsLocal 

Returns true if this URI is for a local article.
Returns undef otherwise.

=cut

sub IsLocal {
    my $self = shift;
    my $local_uri_prefix = $self->LocalURIPrefix;
    if ($self->{'uri'} =~ /^$local_uri_prefix/) {
        return 1;
    }
    else {
        return undef;
    }
}



=head2 Object

Returns the object for this URI, if it's local. Otherwise returns undef.

=cut

sub Object {
    my $self = shift;
    return ($self->{'object'});

}

=head2 Scheme

Return the URI scheme for RT articles

=cut

sub Scheme {
    my $self = shift;
    return "fsck.com-article";
}

=head2 HREF

If this is a local article, return an HTTP url to it.
Otherwise, return its URI

=cut

sub HREF {
    my $self = shift;
    if ($self->IsLocal && $self->Object) {
        return ( RT->Config->Get('WebURL') . "Articles/Article/Display.html?id=".$self->Object->Id);
    }   
    else {
        return ($self->URI);
    }
}

=head2 AsString

Return "Article 23"

=cut

sub AsString {
    my $self = shift;
    if ($self->IsLocal && ( my $object = $self->Object )) {
        if ( $object->Name ) {
            return $self->loc('Article #[_1]: [_2]', $object->id, $object->Name);
        } else {
            return $self->loc('Article #[_1]', $object->id);
        }
    } else {
        return $self->SUPER::AsString(@_);
    }

}


1;
