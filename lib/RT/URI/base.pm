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
package RT::URI::base;

use strict;
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

eval "require RT::URI::base_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/URI/base_Vendor.pm});
eval "require RT::URI::base_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/URI/base_Local.pm});

1;
