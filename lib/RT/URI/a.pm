# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2003 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
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
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK
package RT::URI::a;

use RT::FM::Article;

use strict;
use base qw/RT::URI::fsck_com_rtfm/;

my $scheme = "a";

=head2 ParseURI URI

When handed an a: URI, figures out if it is an RTFM article.

=begin testing

use_ok("RT::URI::a");
my $uri = RT::URI::a->new($RT::SystemUser);
ok(ref($uri), "URI object exists");

my $class = RT::FM::Class->new($RT::SystemUser);
$class->Create(Name => 'URItest');
my $article = RT::FM::Article->new($RT::SystemUser);
$article->Create(Name => 'Testing URI parsing',
		 Summary => 'In which this should load',
		 Class => $class->Id);


my $uristr = "a:" . $article->Id;
$uri->ParseURI($uristr);
is(ref($uri->Object), "RT::FM::Article", "Object loaded is an article");
is($uri->Object->Id, $article->Id, "Object loaded has correct ID");
is($uri->URI, 'fsck.com-rtfm://example.com/article/'.$article->Id, 
   "URI object has correct URI string");

=end testing

=cut

sub ParseURI { 
    my $self = shift;
    my $uri = shift;

    # "a:<articlenum>"
    # Pass this off to fsck_com_rtfm, which is equipped to deal with
    # articles after stripping off the a: prefix.

    if ($uri =~ /^$scheme:(\d+)/) {
        warn $1;
	return $self->SUPER::ParseURI($1);
    } else {
	$self->{'uri'} = $uri;
	return undef;
    }
}

=head2 Scheme

Return the URI scheme 

=cut

sub Scheme {
  return $scheme;
}

1;
