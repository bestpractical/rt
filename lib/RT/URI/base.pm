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
package RT::URI::base;

use strict;
use base qw(RT::Base);

=head1 name

RT::URI::base

=head1 description

A baseclass (and fallback) RT::URI handler. Every URI handler needs to 
handle the API presented here

=cut

=head1 API

=head2 new

Create a new URI handler

=cut

sub new {
    my $class = shift;
    my $self  = {};
    bless $self => ref($class) || $class;
    $self->_get_current_user(@_);
    return $self;

}

sub parse_object {
    my $self = shift;
    my $obj  = shift;
    $self->{'uri'} = "unknown-object:" . ref($obj);
}

sub parse_uri {
    my $self = shift;
    my $uri  = shift;

    if ( $uri =~ /^(.*?):/ ) {
        $self->{'scheme'} = $1;
    }
    $self->{'uri'} = $uri;

}

sub object {
    my $self = shift;
    return undef;

}

sub uri {
    my $self = shift;
    return ( $self->{'uri'} );
}

sub scheme {
    my $self = shift;
    return ( $self->{'scheme'} );

}

sub href {
    my $self = shift;
    return ( $self->{'href'} || $self->{'uri'} );
}

sub is_local {
    my $self = shift;
    return undef;
}

=head2 AsString

Return a "pretty" string representing the URI object.

This is meant to be used like this:

 % $re = $uri->resolver;
 <A HREF="<% $re->href %>"><% $re->as_string %></A>

=cut

sub as_string {
    my $self = shift;
    return $self->uri;
}

eval "require RT::URI::base_Vendor";
die $@ if ( $@ && $@ !~ qr{^Can't locate RT/URI/base_Vendor.pm} );
eval "require RT::URI::base_Local";
die $@ if ( $@ && $@ !~ qr{^Can't locate RT/URI/base_Local.pm} );

1;
