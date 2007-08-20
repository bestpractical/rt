package RT::Shredder::Constants;

use base qw(Exporter);

=head1 NAME

RT::Shredder::Constants -  RT::Shredder constants that is used to mark state of RT objects.

=head1 DESCRIPTION

This module exports two group of bit constants.
First group is group of flags which are used to clarify dependecies between objects, and
second group is states of RT objects in Shredder cache.

=head1 FLAGS

=head2 DEPENDS_ON

Targets that has such dependency flag set should be wiped out with base object.

=head2 WIPE_AFTER

If dependency has such flag then target object would be wiped only
after base object. You should mark dependencies with this flag
if two objects depends on each other, for example Group and Principal
have such relationship, this mean Group depends on Principal record and
that Principal record depends on the same Group record. Other examples:
User and Principal, User and its ACL equivalence group.

=head2 VARIABLE

This flag is used to mark dependencies that can be resolved with changing
value in target object. For example ticket can be created by user we can
change this reference when we delete user.

=head2 RELATES

This flag is used to validate relationships integrity. Base object
is valid only when all target objects which are marked with this flags
exist.

=cut

use constant {
    DEPENDS_ON    => 0x000001,
    WIPE_AFTER    => 0x000010,
    RELATES        => 0x000100,
    VARIABLE    => 0x001000,
};

=head1 STATES

=head2 ON_STACK

Default state of object in Shredder cache that means that object is
loaded and placed into cache.

=head2 WIPED

Objects with this state are not exist any more in DB, but perl
object is still in memory. This state is used to be shure that
delete query is called once.

=head2 VALID

Object is marked with this state only when its relationships
are valid.

=head2 INVALID

=cut

use constant {
    ON_STACK    => 0x00000,
    IN_WIPING    => 0x00001,
    WIPED        => 0x00010,
    VALID        => 0x00100,
    INVALID        => 0x01000,
};

our @EXPORT = qw(
        DEPENDS_ON
        WIPE_AFTER
        RELATES
        VARIABLE
        ON_STACK
        IN_WIPING
        WIPED
        VALID
        INVALID
        );

1;
