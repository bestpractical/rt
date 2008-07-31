# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2008 Best Practical Solutions, LLC 
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

=head1 NAME 

RT::FM::System

=head1 DESCRIPTION

RT::FM::System is a simple global object used as a focal point for things
that are system-wide.

It works sort of like an RT::Record, except it's really a single object that has
an id of "1" when instantiated.

This gets used by the ACL system so that you can have rights for the scope "RT::FM::System"

In the future, there will probably be other API goodness encapsulated here.

=cut


no warnings 'redefine';
package RT::FM::System;
use RT::ACL;
use base qw /RT::Base/;
use strict;
use vars qw/ $RIGHTS/;


# Tell RT::ACE that this sort of object can get acls granted
$RT::ACE::OBJECT_TYPES{'RT::FM::System'} = 1;


# System rights are rights granted to the whole system
# XXX TODO Can't localize these outside of having an object around.
$RIGHTS = {
};


foreach my $right ( keys %{$RIGHTS} ) {
    $RT::ACE::LOWERCASERIGHTNAMES{ lc $right } = $right;
}


=head2 AvailableRights

Returns a hash of available rights for this object. The keys are the right names and the values are a description of what the rights do

=cut

sub AvailableRights {
    my $self = shift;
    my $class = RT::FM::Class->new($RT::SystemUser);
    my $classrights = $class->AvailableRights();
    my $CustomField = RT::CustomField->new($RT::SystemUser);
    my $cfrights = $CustomField->AvailableRights();
    my %rights = (%{$cfrights}, %{$classrights});
    
    return(\%rights);
}


=head2 new

Create a new RT::FM::System object. Really, you should be using $RT::FM::System

=cut

                         
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};
    bless( $self, $class );


    return ($self);
}

=head2 id

Returns RT::FM::System's id. It's 1. 


=cut

*Id = \&id;

sub id {
    return (1);
}

=head2 Load

for compatibility. dummy method

=cut

sub Load {
    return(1);
}
1;
