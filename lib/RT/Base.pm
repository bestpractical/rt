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
package RT::Base;
use Carp;
use Scalar::Util;

use strict;
use vars qw(@EXPORT);

@EXPORT=qw(loc CurrentUser);

=head1 FUNCTIONS



# {{{ sub CurrentUser 

=head2 CurrentUser

If called with an argument, sets the current user to that user object.
This will affect ACL decisions, etc.  
Returns the current user

=cut

sub CurrentUser {
    my $self = shift;

    if (@_) {
        $self->{'original_user'} = $self->{'user'};
        $self->{'user'} = shift;
        Scalar::Util::weaken($self->{'user'}) if (ref($self->{'user'}) &&
                                                    $self->{'user'} == $self );
    }

    unless ( ref( $self->{'user'}) ) {
        $RT::Logger->err( "$self was created without a CurrentUser\n" . Carp::cluck() );
        return (0);
        die;
    }
    return ( $self->{'user'} );
}

# }}}

sub OriginalUser {
    my $self = shift;

    if (@_) {
        $self->{'original_user'} = shift;
        Scalar::Util::weaken($self->{'original_user'})
            if (ref($self->{'original_user'}) && $self->{'original_user'} == $self );
    }
    return ( $self->{'original_user'} || $self->{'user'} );
}


=item loc LOC_STRING

l is a method which takes a loc string
to this object's CurrentUser->LanguageHandle for localization. 

you call it like this:

    $self->loc("I have [quant,_1,concrete mixer].", 6);

In english, this would return:
    I have 6 concrete mixers.


=cut

sub loc {
    my $self = shift;
    if (my $user = $self->OriginalUser) {
        return $user->loc(@_);
    }
    else {
        use Carp;
        Carp::confess("No currentuser");
        return ("Critical error:$self has no CurrentUser", $self);
    }
}

eval "require RT::Base_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Base_Vendor.pm});
eval "require RT::Base_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Base_Local.pm});


1;
