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

package RT::URI::base;

use strict;
use warnings;
use base qw(RT::Base);

=head1 NAME

RT::URI::base

=head1 DESCRIPTION

A baseclass (and fallback) RT::URI handler. Every URI handler needs to 
handle the API presented here

=cut


=head1 API

=head2 new

Create a new URI handler

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};
    bless( $self, $class );
    $self->CurrentUser(@_);
    return ($self);
}

sub ParseObject  {
    my $self = shift;
    my $obj = shift;
    $self->{'uri'} = "unknown-object:".ref($obj);
}

sub ParseURI { 
    my $self = shift;
    my $uri = shift;

    if ($uri =~  /^(.*?):/) { 
        $self->{'scheme'} = $1;
    }
    $self->{'uri'} = $uri;
   
    
}


sub Object {
    my $self = shift;
    return undef;

}

sub URI {
    my $self = shift;
    return($self->{'uri'});
}

sub Scheme { 
    my $self = shift;
    return($self->{'scheme'});

}

sub HREF {
    my $self = shift;
    return($self->{'href'} || $self->{'uri'});
}

sub IsLocal {
    my $self = shift;
    return undef;
}

=head2 AsString

Return a "pretty" string representing the URI object.

This is meant to be used like this:

 % $re = $uri->Resolver;
 <A HREF="<% $re->HREF %>"><% $re->AsString %></A>

=cut

sub AsString {
    my $self = shift;
    return $self->URI;
}

RT::Base->_ImportOverlays();

1;
