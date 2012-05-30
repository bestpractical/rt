# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2011 Best Practical Solutions, LLC
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
use DateTime;

sub Init {
    my $self = shift;

    my %args = (
        Directory   => undef,
        Force       => undef,
        MaxFileSize => 32,

        AllUsers            => 1,
        AllGroups           => 1,
        FollowDeleted       => 1,

        FollowScrips        => 0,
        FollowTickets       => 1,
        FollowACL           => 0,

        Clone   => 0,

        Verbose => 1,
        @_,
    );

    # Set up the output directory we'll be writing to
    $args{Directory} = $RT::Organization . ":" . DateTime->now->ymd
        unless defined $args{Directory};
    system("rm", "-rf", $args{Directory}) if $args{Force};
    die "Output directory $args{Directory} already exists"
        if -d $args{Directory};
    mkdir $args{Directory}
        or die "Can't create output directory $args{Directory}: $!\n";
    $self->{Directory} = delete $args{Directory};

    # How many megabytes each chunk should be, approximitely
    $self->{MaxFileSize} = delete $args{MaxFileSize};

    $self->{Verbose} = delete $args{Verbose};

    $self->{$_} = delete $args{$_}
        for qw/
                  AllUsers
                  AllGroups
                  FollowDeleted
                  FollowScrips
                  FollowTickets
                  FollowACL
                  Clone
              /;

    $self->SUPER::Init(@_, First => "top");

    # Keep track of the number of each type of object written out
    $self->{ObjectCount} = {};

    # Which file we're writing to
    $self->{FileCount} = 1;

    if ($self->{Clone}) {
        $self->PushAll;
    } else {
        $self->PushBasics;
    }
}

sub Metadata {
    my $self = shift;
    return {
        Format       => "0.5",
        Version      => $RT::VERSION,
        Organization => $RT::Organization,
        Files        => [ $self->Files ],
        ObjectCount  => { $self->ObjectCount },
        @_,
    },
}

sub PushAll {
    my $self = shift;

    # Ordering _shouldn't_ matter since we don't convert FK references to UIDs
    # and hence don't have to look them up during import.

    # Users and groups
    $self->PushCollections(qw(Users Groups GroupMembers));

    # Tickets
    $self->PushCollections(qw(Queues Tickets Transactions Attachments Links));

    # Articles
    $self->PushCollections(qw(Articles), map { ($_, "Object$_") } qw(Classes Topics));

    # Custom Fields
    $self->PushCollections(map { ($_, "Object$_") } qw(CustomFields CustomFieldValues));

    # ACLs
    $self->PushCollections(qw(ACL));

    # Scrips
    $self->PushCollections(qw(Scrips ScripActions ScripConditions Templates));

    # Attributes
    $self->PushCollections(qw(Attributes));
}

sub PushCollections {
    my $self  = shift;

    for my $type (@_) {
        my $class = "RT::\u$type";
        my $collection = $class->new( RT->SystemUser );
        $collection->FindAllRows;   # be explicit
        $collection->UnLimit;
        $collection->OrderBy( FIELD => 'id' );

        if ($self->{Clone}) {
            if ($collection->isa('RT::Tickets')) {
                $collection->{allow_deleted_search} = 1;
                $collection->IgnoreType; # looking_at_type
            }
            elsif ($collection->isa('RT::ObjectCustomFieldValues')) {
                # FindAllRows (find_disabled_rows) isn't used by OCFVs
                $collection->{find_expired_rows} = 1;
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
    $systemroles->LimitToRolesForSystem;
    $self->PushObj( $systemroles );

    # CFs on Users, Groups, Queues
    my $cfs = RT::CustomFields->new( RT->SystemUser );
    $cfs->Limit(
        FIELD => 'LookupType',
        VALUE => $_
    ) for qw/RT::User RT::Group RT::Queue/;
    $self->PushObj( $cfs );

    # Global attributes
    my $attributes = RT::System->new( RT->SystemUser )->Attributes;
    $self->PushObj( $attributes );

    # Global ACLs
    if ($self->{FollowACL}) {
        my $acls = RT::ACL->new( RT->SystemUser );
        $acls->LimitToObject( RT->System );
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

    $self->PushCollections(qw(Topics Classes));

    $self->PushCollections(qw(Queues));
}

sub Walk {
    my $self = shift;

    # Set up our output file
    $self->OpenFile;

    # Write the initial metadata
    $! = 0;
    Storable::nstore_fd( $self->Metadata, $self->{Filehandle});
    die "Failed to write metadata to @{[$self->Filename]}: $!" if $!;

    # Walk the objects
    $self->SUPER::Walk( @_ );

    # Close everything back up
    $self->CloseFile;

    # Write the summary file
    Storable::nstore(
        $self->Metadata( Final => 1 ),
        $self->Directory . "/rt-serialized"
    );

    return $self->ObjectCount;
}

sub NextPage {
    my ($self, $collection, $last) = @_;

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

    my $uid = $args{object}->UID;

    # Skip all dependency walking if we're cloning.  Marking UIDs as seen
    # forces them to be visited immediately.
    $self->{seen}{$uid}++
        if $self->{Clone} and $uid;

    return $self->SUPER::Process( @_ );
}

sub Files {
    my $self = shift;
    return @{ $self->{Files} };
}

sub Filename {
    my $self = shift;
    return sprintf(
        "%s/%03d.dat",
        $self->{Directory},
        $self->{FileCount}
    );
}

sub Directory {
    my $self = shift;
    return $self->{Directory};
}

sub OpenFile {
    my $self = shift;
    open($self->{Filehandle}, ">", $self->Filename)
        or die "Can't write to file @{[$self->Filename]}: $!";
    push @{$self->{Files}}, $self->Filename;
}

sub CloseFile {
    my $self = shift;
    close($self->{Filehandle})
        or die "Can't close @{[$self->Filename]}: $!";
    $self->{FileCount}++;
}

sub RotateFile {
    my $self = shift;
    $self->CloseFile;
    $self->OpenFile;
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
        return $self->{FollowTickets};
    } elsif ($obj->isa("RT::ACE")) {
        return $self->{FollowACL};
    } elsif ($obj->isa("RT::Scrip") or $obj->isa("RT::Template")) {
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
        object    => undef,
        @_
    );

    # Rotate if we get too big
    my $maxsize = 1024 * 1024 * $self->{MaxFileSize};
    $self->RotateFile if tell($self->{Filehandle}) > $maxsize;

    # Serialize it
    my $obj = $args{object};
    warn "Writing ".$obj->UID."\n" if $self->{Verbose};
    my @store = (
        ref($obj),
        $obj->UID,
        { $obj->Serialize( UIDs => !$self->{Clone} ) },
    );

    # Write it out; nstore_fd doesn't trap failures to write, so we have
    # to; by clearing $! and checking it afterwards.
    $! = 0;
    Storable::nstore_fd(\@store, $self->{Filehandle});
    die "Failed to write to @{[$self->Filename]}: $!" if $!;

    $self->{ObjectCount}{ref($obj)}++;
}

1;
