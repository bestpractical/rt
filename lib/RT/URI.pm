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
package RT::URI;;

use strict;
use vars qw/@ISA/;
@ISA = qw(RT::Base);

use RT::URI::base;
use Carp;

=head1 NAME

RT::URI

=head1 DESCRIPTION

This class provides a base class for URIs, such as those handled
by RT::Link objects.  

=head1 API



=cut




=head2 new

Create a new RT::URI object.

=cut

                         
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};
    bless( $self, $class );

    $self->CurrentUser(@_);

    return ($self);
}



# {{{ FromObject

=head2 FromObject <Object>

Given a local object, such as an RT::Ticket or an RT::FM::Article, this routine will return a URI for
the local object

=cut

sub FromObject {
    my $self = shift;
    my $obj = shift;

    return undef unless  $obj->can('URI');
    return $self->FromURI($obj->URI);
}

# }}}

# {{{ FromURI

=head2 FromURI <URI>

Returns a local object id for this content.  You are expected to know what sort of object this is the Id 
of 

=cut

sub FromURI {
    my $self = shift;
    my $uri = shift;    

    return undef unless ($uri);

	my $scheme;
	# Special case: integers passed in as URIs must be ticket ids
	if ($uri =~ /^(\d+)$/) {
		$scheme = "fsck.com-rt";
	} elsif ($uri =~ /^((?:\w|\.|-)+?):/) {
         $scheme = $1;
    }
    else {
        $RT::Logger->warning("$self Could not determine a URI scheme for $uri");
		return (undef);
    }
     
    # load up a resolver object for this scheme  
    $self->_GetResolver($scheme);
    
    unless ($self->Resolver->ParseURI($uri)) {
        $RT::Logger->warning("Resolver ".ref($self->Resolver)." could not parse $uri");
    	return (undef);
    }

}

# }}}

# {{{ _GetResolver

=private _GetResolver <scheme>

Gets an RT URI resolver for the scheme <scheme>. 
Falls back to a null resolver. RT::URI::base.

=cut

sub _GetResolver {
    my $self = shift;
    my $scheme = shift;

    $scheme =~ s/(\.|-)/_/g;
    my $resolver;

    
       eval " 
            require RT::URI::$scheme;
            \$resolver = RT::URI::$scheme->new(\$self->CurrentUser);
       ";
     
        if ($resolver) {
        $self->{'resolver'} = $resolver;
        } else {
        $self->{'resolver'} = RT::URI::base->new($self->CurrentUser); 
        }

}

# }}}

# {{{ Scheme

=head2 Scheme

Returns a local object id for this content.  You are expected to know what sort of object this is the Id 
of 

=cut

sub Scheme {
    my $self = shift;
    return ($self->Resolver->Scheme);

}
# }}}
# {{{ URI

=head2 URI

Returns a local object id for this content.  You are expected to know what sort of object this is the Id 
of 

=cut

sub URI {
    my $self = shift;
    return ($self->Resolver->URI);

}
# }}}

# {{{ Object

=head2 Object

Returns a local object for this content. This will usually be an RT::Ticket or somesuch

=cut


sub Object {   
    my $self = shift;
    return($self->Resolver->Object);

}


# }}}

# {{{ IsLocal

=head2 IsLocal

Returns a local object for this content. This will usually be an RT::Ticket or somesuch

=cut

sub IsLocal {
    my $self = shift;
    return $self->Resolver->IsLocal;     
}


# }}}


=head Resolver

Returns this URI's URI resolver object

=cut


sub Resolver {
    my $self =shift;
    return ($self->{'resolver'});
}

eval "require RT::URI_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/URI_Vendor.pm});
eval "require RT::URI_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/URI_Local.pm});

1;
