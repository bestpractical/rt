package RT::URI::fsck_com_rtfm;

use RT::FM::Article;

use RT::URI::base;

use vars qw (@ISA);
@ISA = qw/RT::URI::base/;




=head2 LocalURIPrefix 

Returns the prefix for a local article URI

=begin testing

use_ok("RT::URI::fsck_com_rtfm");
my $uri = RT::URI::fsck_com_rtfm->new($RT::SystemUser);

ok(ref($uri));

use Data::Dumper;


ok (UNIVERSAL::isa($uri,RT::URI::fsck_com_rtfm), "It's an RT::URI::fsck_com_rtfm");

ok ($uri->isa('RT::URI::base'), "It's an RT::URI::base");
ok ($uri->isa('RT::Base'), "It's an RT::Base");

is ($uri->LocalURIPrefix , 'fsck.com-rtfm://example.com/article/');

=end testing



=cut

sub LocalURIPrefix {
    my $self = shift;
    my $prefix = $self->Scheme. "://$RT::Organization/article/";
    return ($prefix);
}





=head2 URIForObject RT::article

Returns the RT URI for a local RT::article object

=begin testing

my $article = RT::FM::Article->new($RT::SystemUser);
$article->Load(1);
my $uri = RT::URI::fsck_com_rtfm->new($article->CurrentUser);
is($uri->LocalURIPrefix . "1" , $uri->URIForObject($article));

=end testing

=cut

sub URIForObject {

    my $self = shift;

    my $obj = shift;
    return ($self->LocalURIPrefix. $obj->Id);
}


=head2 ParseObject $ArticleObj

When handed an RT::FM::Article object, figure out its URI


=cut



=head2 ParseURI URI

When handed an fsck.com-rtfm: URI, figures out things like whether its a local article
and what its ID is

=cut


sub ParseURI { 
    my $self = shift;
    my $uri = shift;

	my $article;
 
 	if ($uri =~ /^(\d+)$/) {
 		$article = RT::FM::Article->new($self->CurrentUser);
 		$article->Load($uri);	
 		$self->{'uri'} = $article->URI;
 	}
 	else {
	    $self->{'uri'} = $uri;
 	}
 
 
 
       #If it's a local URI, load the article object and return its URI
    if ( $self->IsLocal) {
   
        my $local_uri_prefix = $self->LocalURIPrefix;
    	if ($self->{'uri'} =~ /^$local_uri_prefix(\d+)$/) {
    		my $id = $1;
    	
    
	        $article = RT::FM::Article->new( $self->CurrentUser );
    	    $article->Load($id);

    	    #If we couldn't find a article, return undef.
    	    unless ( defined $article->Id ) {
    	    	return undef;
    	    }
    	    } else {
    	    return undef;
    	    }	
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
	return "fsck.com-rtfm";
}

=head2 HREF

If this is a local article, return an HTTP url to it.
Otherwise, return its URI

=cut


sub HREF {
    my $self = shift;
    if ($self->IsLocal) {
        return ( $RT::WebURL . "/RTFM/Article/Display.html?id=".$self->Object->Id);
    }   
    else {
        return ($self->URI);
    }
}


1;
