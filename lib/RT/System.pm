
=head1 name 

RT::System

=head1 DESCRIPTION

RT::System is a simple global object used as a focal point for things
that are system-wide.

It works sort of like an RT::Record, except it's really a single object that has
an id of "1" when instantiated.

This gets used by the ACL system so that you can have rights for the scope "RT::System"

In the future, there will probably be other API goodness encapsulated here.

=cut

use warnings;
use strict;

package RT::System;
use base qw/RT::Record/;

our $RIGHTS;

use RT::Model::ACECollection;

# System rights are rights granted to the whole system
# XXX TODO Can't localize these outside of having an object around.
$RIGHTS = {
    SuperUser => 'Do anything and everything',    # loc_pair
    AdminAllPersonalGroups =>
        "Create, delete and modify the members of any user's personal groups"
    ,                                             # loc_pair
    AdminOwnPersonalGroups =>
        'Create, delete and modify the members of personal groups', # loc_pair
    AdminUsers => 'Create, delete and modify users',                # loc_pair
    ModifySelf => "Modify one's own RT account",                    # loc_pair
    DelegateRights =>
        "Delegate specific rights which have been granted to you.", # loc_pair
    ShowConfigTab     => "show Configuration tab",                  # loc_pair
    LoadSavedSearch   => "allow loading of saved searches",         # loc_pair
    CreateSavedSearch => "allow creation of saved searches",        # loc_pair
};

# Tell RT::Model::ACE that this sort of object can get acls granted
$RT::Model::ACE::OBJECT_TYPES{'RT::System'} = 1;

foreach my $right ( keys %{$RIGHTS} ) {
    $RT::Model::ACE::LOWERCASERIGHTNAMES{ lc $right } = $right;
}

=head2 AvailableRights

Returns a hash of available rights for this object.
The keys are the right names and the values are a
description of what the rights do.

This method as well returns rights of other RT objects,
like L<RT::Model::Queue> or L<RT::Model::Group>. To allow users to apply
those rights globally.

=cut

sub available_rights {
    my $self = shift;

    my $queue = RT::Model::Queue->new( current_user => RT->system_user );
    my $group = RT::Model::Group->new( current_user => RT->system_user );
    my $cf = RT::Model::CustomField->new( current_user => RT->system_user );

    my $qr = $queue->available_rights();
    my $gr = $group->available_rights();
    my $cr = $cf->available_rights();

# Build a merged list of all system wide rights, queue rights and group rights.
    my %rights = ( %{$RIGHTS}, %{$gr}, %{$qr}, %{$cr} );
    return ( \%rights );
}

=head2 id

Returns RT::System's id. It's 1. 




=cut

*Id = \&id;
sub id      { return (1); }
sub load    { return (1); }
sub name    { return 'RT System'; }
sub __set   {0}
sub __value {0}
sub create  {0}
sub delete  {0}

1;
