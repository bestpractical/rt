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
              /;

    $self->SUPER::Init(@_, First => "top");

    # Keep track of the number of each type of object written out
    $self->{ObjectCount} = {};

    # Which file we're writing to
    $self->{FileCount} = 1;

    $self->PushBasics;
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

    # Global scrips
    if ($self->{FollowScrips}) {
        my $scrips = RT::Scrips->new( RT->SystemUser );
        $scrips->LimitToGlobal;

        my $templates = RT::Templates->new( RT->SystemUser );
        $templates->LimitToGlobal;

        my $actions = RT::ScripActions->new( RT->SystemUser );
        $actions->UnLimit;

        my $conditions = RT::ScripConditions->new( RT->SystemUser );
        $conditions->UnLimit;
        $self->PushObj( $scrips, $templates, $actions, $conditions );
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

    my $topics = RT::Topics->new( RT->SystemUser );
    $topics->UnLimit;

    my $classes = RT::Classes->new( RT->SystemUser );
    $classes->UnLimit;
    $self->PushObj( $topics, $classes );

    my $queues = RT::Queues->new( RT->SystemUser );
    $queues->UnLimit;
    $self->PushObj( $queues );
}

sub Walk {
    my $self = shift;

    # Set up our output file
    open($self->{Filehandle}, ">", $self->Filename)
        or die "Can't write to file @{[$self->Filename]}: $!";
    $! = 0;
    Storable::nstore_fd( \$RT::Organization, $self->{Filehandle});
    die "Failed to write to @{[$self->Filename]}: $!" if $!;
    push @{$self->{Files}}, $self->Filename;

    # Walk the objects
    $self->SUPER::Walk( @_ );

    # Close everything back up
    close($self->{Filehandle})
        or die "Can't close @{[$self->Filename]}: $!";
    $self->{FileCount}++;

    # Write the summary file
    Storable::nstore( {
        files  => [ $self->Files ],
        counts => { $self->ObjectCount },
    }, $self->Directory . "/rt-serialized");

    return $self->ObjectCount;
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

sub RotateFile {
    my $self = shift;
    close($self->{Filehandle})
        or die "Can't close @{[$self->Filename]}: $!";
    $self->{FileCount}++;

    open($self->{Filehandle}, ">", $self->Filename)
        or die "Can't write to file @{[$self->Filename]}: $!";
    $! = 0;
    Storable::nstore_fd( \$RT::Organization, $self->{Filehandle});
    die "Failed to write to @{[$self->Filename]}: $!" if $!;

    push @{$self->{Files}}, $self->Filename;
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
    } elsif ($obj->isa("RT::ObjectCustomField")) {
        return 0 if $from =~ /^RT::CustomField-/;
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
        { $obj->Serialize },
    );

    # Write it out; nstore_fd doesn't trap failures to write, so we have
    # to; by clearing $! and checking it afterwards.
    $! = 0;
    Storable::nstore_fd(\@store, $self->{Filehandle});
    die "Failed to write to @{[$self->Filename]}: $!" if $!;

    $self->{ObjectCount}{ref($obj)}++;
}

1;
