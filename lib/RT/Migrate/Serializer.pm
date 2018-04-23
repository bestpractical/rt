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

package RT::Migrate::Serializer;

use strict;
use warnings;

use base 'RT::DependencyWalker';

use Storable qw//;
sub cmp_version($$) { RT::Handle::cmp_version($_[0],$_[1]) };
use RT::Migrate::Incremental;
use RT::Migrate::Serializer::IncrementalRecord;
use RT::Migrate::Serializer::IncrementalRecords;
use List::MoreUtils 'none';

sub Init {
    my $self = shift;

    my %args = (
        AllUsers            => 1,
        AllGroups           => 1,
        FollowDeleted       => 1,

        FollowScrips        => 0,
        FollowTickets       => 1,
        FollowACL           => 0,
        FollowAssets        => 1,

        Clone       => 0,
        Incremental => 0,

        Verbose => 1,
        @_,
    );

    $self->{Verbose} = delete $args{Verbose};

    $self->{$_} = delete $args{$_}
        for qw/
                  AllUsers
                  AllGroups
                  FollowDeleted
                  FollowScrips
                  FollowTickets
                  FollowAssets
                  FollowACL
                  Queues
                  CustomFields
                  HyperlinkUnmigrated
                  Clone
                  Incremental
              /;

    $self->{Clone} = 1 if $self->{Incremental};

    $self->SUPER::Init(@_, First => "top");

    # Keep track of the number of each type of object written out
    $self->{ObjectCount} = {};

    if ($self->{Clone}) {
        $self->PushAll;
    } else {
        $self->PushBasics;
    }
}

sub Metadata {
    my $self = shift;

    # Determine the highest upgrade step that we run
    my @versions = ($RT::VERSION, keys %RT::Migrate::Incremental::UPGRADES);
    my ($max) = reverse sort cmp_version @versions;
    # we don't want to run upgrades to 4.2.x if we're running
    # the serializier on an 4.0 instance.
    $max = $RT::VERSION unless $self->{Incremental};

    return {
        Format       => "0.8",
        VersionFrom  => $RT::VERSION,
        Version      => $max,
        Organization => $RT::Organization,
        Clone        => $self->{Clone},
        Incremental  => $self->{Incremental},
        ObjectCount  => { $self->ObjectCount },
        @_,
    },
}

sub PushAll {
    my $self = shift;

    # To keep unique constraints happy, we need to remove old records
    # before we insert new ones.  This fixes the case where a
    # GroupMember was deleted and re-added (with a new id, but the same
    # membership).
    if ($self->{Incremental}) {
        my $removed = RT::Migrate::Serializer::IncrementalRecords->new( RT->SystemUser );
        $removed->Limit( FIELD => "UpdateType", VALUE => 3 );
        $removed->OrderBy( FIELD => 'id' );
        $self->PushObj( $removed );
    }
    # XXX: This is sadly not sufficient to deal with the general case of
    # non-id unique constraints, such as queue names.  If queues A and B
    # existed, and B->C and A->B renames were done, these will be
    # serialized with A->B first, which will fail because there already
    # exists a B.

    # Principals first; while we don't serialize these separately during
    # normal dependency walking (we fold them into users and groups),
    # having them separate during cloning makes logic simpler.
    $self->PushCollections(qw(Principals));

    # Users and groups
    $self->PushCollections(qw(Users Groups GroupMembers));

    # Tickets
    $self->PushCollections(qw(Queues Tickets Transactions Attachments Links));

    # Articles
    $self->PushCollections(qw(Articles), map { ($_, "Object$_") } qw(Classes Topics));

    # Custom Roles
    $self->PushCollections(qw(CustomRoles ObjectCustomRoles));

    # Assets
    $self->PushCollections(qw(Catalogs Assets));

    # Custom Fields
    if (RT::ObjectCustomFields->require) {
        $self->PushCollections(map { ($_, "Object$_") } qw(CustomFields CustomFieldValues));
    } elsif (RT::TicketCustomFieldValues->require) {
        $self->PushCollections(qw(CustomFields CustomFieldValues TicketCustomFieldValues));
    }

    # ACLs
    $self->PushCollections(qw(ACL));

    # Scrips
    $self->PushCollections(qw(Scrips ObjectScrips ScripActions ScripConditions Templates));

    # Attributes
    $self->PushCollections(qw(Attributes));
}

sub PushCollections {
    my $self  = shift;

    for my $type (@_) {
        my $class = "RT::\u$type";

        $class->require or next;
        my $collection = $class->new( RT->SystemUser );
        $collection->FindAllRows;   # be explicit
        $collection->CleanSlate;    # some collections (like groups and users) join in _Init
        $collection->UnLimit;
        $collection->OrderBy( FIELD => 'id' );

        if ($self->{Clone}) {
            if ($collection->isa('RT::Tickets')) {
                $collection->{allow_deleted_search} = 1;
                $collection->IgnoreType; # looking_at_type
            }
            elsif ($collection->isa('RT::Assets')) {
                $collection->{allow_deleted_search} = 1;
            }
            elsif ($collection->isa('RT::ObjectCustomFieldValues')) {
                # FindAllRows (find_disabled_rows) isn't used by OCFVs
                $collection->{find_disabled_rows} = 1;
            }

            if ($self->{Incremental}) {
                my $alias = $collection->Join(
                    ALIAS1 => "main",
                    FIELD1 => "id",
                    TABLE2 => "IncrementalRecords",
                    FIELD2 => "ObjectId",
                );
                $collection->DBIx::SearchBuilder::Limit(
                    ALIAS => $alias,
                    FIELD => "ObjectType",
                    VALUE => ref($collection->NewItem),
                );
            }
        }

        $self->PushObj( $collection );
    }
}

sub PushBasics {
    my $self = shift;

    # System users
    for my $name (qw/RT_System root nobody/) {
        my $user = RT::User->new( RT->SystemUser );
        my ($id, $msg) = $user->Load( $name );
        warn "No '$name' user found: $msg" unless $id;
        $self->PushObj( $user ) if $id;
    }

    # System groups
    foreach my $name (qw(Everyone Privileged Unprivileged)) {
        my $group = RT::Group->new( RT->SystemUser );
        my ($id, $msg) = $group->LoadSystemInternalGroup( $name );
        warn "No '$name' group found: $msg" unless $id;
        $self->PushObj( $group ) if $id;
    }

    # System role groups
    my $systemroles = RT::Groups->new( RT->SystemUser );
    $systemroles->LimitToRolesForObject( RT->System );
    $self->PushObj( $systemroles );

    # CFs on Users, Groups, Queues
    my $cfs = RT::CustomFields->new( RT->SystemUser );
    $cfs->Limit(
        FIELD => 'LookupType',
        OPERATOR => 'IN',
        VALUE => [ qw/RT::User RT::Group RT::Queue/ ],
    );

    if ($self->{CustomFields}) {
        $cfs->Limit(FIELD => 'id', OPERATOR => 'IN', VALUE => $self->{CustomFields});
    }

    $self->PushObj( $cfs );

    # Global attributes
    my $attributes = RT::Attributes->new( RT->SystemUser );
    $attributes->LimitToObject( $RT::System );
    $self->PushObj( $attributes );

    # Global ACLs
    if ($self->{FollowACL}) {
        my $acls = RT::ACL->new( RT->SystemUser );
        $acls->LimitToObject( $RT::System );
        $self->PushObj( $acls );
    }

    # Global scrips
    if ($self->{FollowScrips}) {
        my $scrips = RT::Scrips->new( RT->SystemUser );
        $scrips->LimitToGlobal;

        my $templates = RT::Templates->new( RT->SystemUser );
        $templates->LimitToGlobal;

        $self->PushObj( $scrips, $templates );
        $self->PushCollections(qw(ScripActions ScripConditions));
    }

    if ($self->{AllUsers}) {
        my $users = RT::Users->new( RT->SystemUser );
        $users->LimitToPrivileged;
        $self->PushObj( $users );
    }

    if ($self->{AllGroups}) {
        my $groups = RT::Groups->new( RT->SystemUser );
        $groups->LimitToUserDefinedGroups;
        $self->PushObj( $groups );
    }

    if (RT::Articles->require) {
        $self->PushCollections(qw(Topics Classes));
    }

    if ($self->{Queues}) {
        my $queues = RT::Queues->new(RT->SystemUser);
        $queues->Limit(FIELD => 'id', OPERATOR => 'IN', VALUE => $self->{Queues});
        $self->PushObj($queues);
    }
    else {
        $self->PushCollections(qw(Queues));
    }
    $self->PushCollections(qw(Catalogs));
}

sub InitStream {
    my $self = shift;

    # Write the initial metadata
    my $meta = $self->Metadata;
    $! = 0;
    Storable::nstore_fd( $meta, $self->{Filehandle} );
    die "Failed to write metadata: $!" if $!;

    return unless cmp_version($meta->{VersionFrom}, $meta->{Version}) < 0;

    my %transforms;
    for my $v (sort cmp_version keys %RT::Migrate::Incremental::UPGRADES) {
        for my $ref (keys %{$RT::Migrate::Incremental::UPGRADES{$v}}) {
            push @{$transforms{$ref}}, $RT::Migrate::Incremental::UPGRADES{$v}{$ref};
        }
    }
    for my $ref (keys %transforms) {
        # XXX Does not correctly deal with updates of $classref, which
        # should technically apply all later transforms of the _new_
        # class.  This is not relevant in the current upgrades, as
        # RT::ObjectCustomFieldValues do not have interesting later
        # upgrades if you start from 3.2 (which does
        # RT::TicketCustomFieldValues -> RT::ObjectCustomFieldValues)
        $self->{Transform}{$ref} = sub {
            my ($dat, $classref) = @_;
            my @extra;
            for my $c (@{$transforms{$ref}}) {
                push @extra, $c->($dat, $classref);
                return @extra if not $$classref;
            }
            return @extra;
        };
    }
}

sub NextPage {
    my $self = shift;
    my ($collection, $last) = @_;

    $last ||= 0;

    if ($self->{Clone}) {
        # Clone provides guaranteed ordering by id and with no other id limits
        # worry about trampling

        # Use DBIx::SearchBuilder::Limit explicitly to avoid shenanigans in RT::Tickets
        $collection->DBIx::SearchBuilder::Limit(
            FIELD           => 'id',
            OPERATOR        => '>',
            VALUE           => $last,
            ENTRYAGGREGATOR => 'none', # replaces last limit on this field
        );
    } else {
        # XXX TODO: this could dig around inside the collection to see how it's
        # limited and do the faster paging above under other conditions.
        $self->SUPER::NextPage(@_);
    }
}

sub Process {
    my $self = shift;
    my %args = (
        object => undef,
        @_
    );

    my $obj = $args{object};
    my $uid = $obj->UID;

    # Skip all dependency walking if we're cloning; go straight to
    # visiting them.
    if ($self->{Clone} and $uid) {
        return if $obj->isa("RT::System");
        $self->{progress}->($obj) if $self->{progress};
        return $self->Visit(%args);
    }

    return $self->SUPER::Process( @_ );
}

sub StackSize {
    my $self = shift;
    return scalar @{$self->{stack}};
}

sub ObjectCount {
    my $self = shift;
    return %{ $self->{ObjectCount} };
}

sub Observe {
    my $self = shift;
    my %args = (
        object    => undef,
        direction => undef,
        from      => undef,
        @_
    );

    my $obj = $args{object};
    my $from = $args{from};
    if ($obj->isa("RT::Ticket")) {
        return 0 if $obj->Status eq "deleted" and not $self->{FollowDeleted};
        my $queue = $obj->Queue;
        return 0 if $self->{Queues} && none { $queue == $_ } @{ $self->{Queues} };
        return $self->{FollowTickets};
    } elsif ($obj->isa("RT::Queue")) {
        my $id = $obj->Id;
        return 0 if $self->{Queues} && none { $id == $_ } @{ $self->{Queues} };
        return 1;
    } elsif ($obj->isa("RT::CustomField")) {
        my $id = $obj->Id;
        return 0 if $self->{CustomFields} && none { $id == $_ } @{ $self->{CustomFields} };
        return 1;
    } elsif ($obj->isa("RT::ObjectCustomFieldValue")) {
        my $id = $obj->CustomField;
        return 0 if $self->{CustomFields} && none { $id == $_ } @{ $self->{CustomFields} };
        return 1;
    } elsif ($obj->isa("RT::ObjectCustomField")) {
        my $id = $obj->CustomField;
        return 0 if $self->{CustomFields} && none { $id == $_ } @{ $self->{CustomFields} };
        return 1;
    } elsif ($obj->isa("RT::Asset")) {
        return 0 if $obj->Status eq "deleted" and not $self->{FollowDeleted};
        return $self->{FollowAssets};
    } elsif ($obj->isa("RT::ACE")) {
        return $self->{FollowACL};
    } elsif ($obj->isa("RT::Scrip") or $obj->isa("RT::Template") or $obj->isa("RT::ObjectScrip")) {
        return $self->{FollowScrips};
    } elsif ($obj->isa("RT::GroupMember")) {
        my $grp = $obj->GroupObj->Object;
        if ($grp->Domain =~ /^RT::(Queue|Ticket)-Role$/) {
            return 0 unless $grp->UID eq $from;
        } elsif ($grp->Domain eq "SystemInternal") {
            return 0 if $grp->UID eq $from;
        }
    }

    return 1;
}

sub Visit {
    my $self = shift;
    my %args = (
        object => undef,
        @_
    );

    # Serialize it
    my $obj = $args{object};
    warn "Writing ".$obj->UID."\n" if $self->{Verbose};
    my @store;
    if ($obj->isa("RT::Migrate::Serializer::IncrementalRecord")) {
        # These are stand-ins for record removals
        my $class = $obj->ObjectType;
        my %data  = ( id => $obj->ObjectId );
        # -class is used for transforms when dropping a record
        if ($self->{Transform}{"-$class"}) {
            $self->{Transform}{"-$class"}->(\%data,\$class)
        }
        @store = (
            $class,
            undef,
            \%data,
        );
    } elsif ($self->{Clone}) {
        # Short-circuit and get Just The Basics, Sir if we're cloning
        my $class = ref($obj);
        my $uid   = $obj->UID;
        my %data  = $obj->RT::Record::Serialize( UIDs => 0 );

        # +class is used when seeing a record of one class might insert
        # a separate record into the stream
        if ($self->{Transform}{"+$class"}) {
            my @extra = $self->{Transform}{"+$class"}->(\%data,\$class);
            for my $e (@extra) {
                $! = 0;
                Storable::nstore_fd($e, $self->{Filehandle});
                die "Failed to write: $!" if $!;
                $self->{ObjectCount}{$e->[0]}++;
            }
        }

        # Upgrade the record if necessary
        if ($self->{Transform}{$class}) {
            $self->{Transform}{$class}->(\%data,\$class);
        }

        # Transforms set $class to undef to drop the record
        return unless $class;

        @store = (
            $class,
            $uid,
            \%data,
        );
    } else {
        my %serialized = $obj->Serialize(serializer => $self);
        return unless %serialized;

        @store = (
            ref($obj),
            $obj->UID,
            \%serialized,
        );
    }

    # Write it out; nstore_fd doesn't trap failures to write, so we have
    # to; by clearing $! and checking it afterwards.
    $! = 0;
    Storable::nstore_fd(\@store, $self->{Filehandle});
    die "Failed to write: $!" if $!;

    $self->{ObjectCount}{$store[0]}++;
}

1;
