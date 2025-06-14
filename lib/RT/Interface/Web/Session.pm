# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2025 Best Practical Solutions, LLC
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

package RT::Interface::Web::Session;
use warnings;
use strict;

use RT::CurrentUser;
use Clone;

=head1 NAME

RT::Interface::Web::Session - RT web session class

=head1 SYNOPSIS


=head1 DESCRIPTION

RT session class and utilities.

CLASS METHODS can be used without creating object instances,
it's mainly utilities to clean unused session records.

Object is tied hash and can be used to access session data.

=head1 METHODS

=head2 CLASS METHODS

=head3 Class

Returns name of the class that is used as sessions storage.

=cut

sub Class {
    my $self = shift;

    my $class = RT->Config->Get('WebSessionClass')
             || $self->Backends->{RT->Config->Get('DatabaseType')}
             || 'Apache::Session::File';
    RT::StaticUtil::RequireModule($class) or die "Can't load $class: $@";
    return $class;
}

=head3 Backends

Returns hash reference with names of the databases as keys and
sessions class names as values.

=cut

sub Backends {
    return {
        mysql  => 'Apache::Session::MySQL',
        Pg     => 'Apache::Session::Postgres',
        Oracle => 'Apache::Session::Oracle',
    };
}

=head3 Attributes

Returns hash reference with attributes that are used to create
new session objects.

=cut

sub Attributes {
    my $class = $_[0]->Class;
    my $res;
    if ( my %props = RT->Config->Get('WebSessionProperties') ) {
        $res = \%props;
    }
    elsif ( $class->isa('Apache::Session::File') ) {
        $res = {
            Directory     => $RT::MasonSessionDir,
            LockDirectory => $RT::MasonSessionDir,
            Transaction   => 1,
        };
    }
    else {
        $res = {
            Handle      => $RT::Handle->dbh,
            LockHandle  => $RT::Handle->dbh,
            Transaction => 1,
        };
    }
    $res->{LongReadLen} = RT->Config->Get('MaxAttachmentSize')
        if $class->isa('Apache::Session::Oracle');
    return $res;
}

=head3 Ids

Returns array ref with list of the session IDs.

=cut

sub Ids {
    my $self = shift || __PACKAGE__;
    my $attributes = $self->Attributes;
    if( $attributes->{Directory} ) {
        return $self->_IdsDir( $attributes->{Directory} );
    } else {
        return $self->_IdsDB( $RT::Handle->dbh );
    }
}

sub _IdsDir {
    my ($self, $dir) = @_;
    require File::Find;
    my %file;
    File::Find::find(
        sub { return unless /^[a-zA-Z0-9]+$/;
              $file{$_} = (stat($_))[9];
            },
        $dir,
    );

    return [ sort { $file{$a} <=> $file{$b} } keys %file ];
}

sub _IdsDB {
    my ($self, $dbh) = @_;
    my $ids = $dbh->selectcol_arrayref("SELECT id FROM sessions ORDER BY LastUpdated DESC");
    die "couldn't get ids: ". $dbh->errstr if $dbh->errstr;
    return $ids;
}

=head3 ClearOld

Takes seconds and deletes all sessions that are older.

=cut

sub ClearOld {
    my $class = shift || __PACKAGE__;
    my $attributes = $class->Attributes;
    if( $attributes->{Directory} ) {
        return $class->_ClearOldDir( $attributes->{Directory}, @_ );
    } else {
        return $class->_ClearOldDB( $RT::Handle->dbh, @_ );
    }
}

sub _ClearOldDB {
    my ($self, $dbh, $older_than) = @_;
    my $rows;
    unless( int $older_than ) {
        $rows = $dbh->do("DELETE FROM sessions");
        die "couldn't delete sessions: ". $dbh->errstr unless defined $rows;
    } else {
        require POSIX;
        my $date = POSIX::strftime("%Y-%m-%d %H:%M", gmtime( time - int $older_than ) );

        my $sth = $dbh->prepare("DELETE FROM sessions WHERE LastUpdated < ?");
        die "couldn't prepare query: ". $dbh->errstr unless $sth;
        $rows = $sth->execute( $date );
        die "couldn't execute query: ". $dbh->errstr unless defined $rows;
    }

    $RT::Logger->info("successfully deleted $rows sessions");
    return;
}

sub _ClearOldDir {
    my ($self, $dir, $older_than) = @_;

    require File::Spec if int $older_than;
    
    my $now = time;
    my $class = $self->Class;
    my $attrs = $self->Attributes;

    foreach my $id( @{ $self->Ids } ) {
        if( int $older_than ) {
            my $mtime = (stat(File::Spec->catfile($dir,$id)))[9];
            if( $mtime > $now - $older_than ) {
                $RT::Logger->debug("skipped session '$id', isn't old");
                next;
            }
        }

        my %session;
        local $@;
        eval { tie %session, $class, $id, $attrs };
        if( $@ ) {
            $RT::Logger->debug("skipped session '$id', couldn't load: $@");
            next;
        }
        tied(%session)->delete;
        $RT::Logger->info("successfully deleted session '$id'");
    }

    # Apache::Session::Lock::File will clean out locks older than X, but it
    # leaves around bogus locks if they're too new, even though they're
    # guaranteed dead.  On even just largeish installs, the accumulated number
    # of them may bump into ext3/4 filesystem limits since Apache::Session
    # doesn't use a fan-out tree.
    my $lock = Apache::Session::Lock::File->new;
    $lock->clean( $dir, $older_than );

    # Take matters into our own hands and clear bogus locks hanging around
    # regardless of how recent they are.
    $self->ClearOrphanLockFiles($dir);

    return;
}

=head3 ClearOrphanLockFiles

Takes a directory in which to look for L<Apache::Session::Lock::File> locks
which no longer have a corresponding session file.  If not provided, the
directory is taken from the session configuration data.

=cut

sub ClearOrphanLockFiles {
    my $class = shift;
    my $dir   = shift || $class->Attributes->{Directory}
        or return;

    if (opendir my $dh, $dir) {
        for (readdir $dh) {
            next unless /^Apache-Session-([0-9a-f]{32})\.lock$/;
            next if -e "$dir/$1";

            RT->Logger->debug("deleting orphaned session lockfile '$_'");

            unlink "$dir/$_"
                or warn "Failed to unlink session lockfile $dir/$_: $!";
        }
        closedir $dh;
    } else {
        warn "Unable to open directory '$dir' for reading: $!";
    }
}

=head3 ClearByUser

Checks all sessions and if user has more then one session
then leave only the latest one.

=cut

sub ClearByUser {
    my $self = shift || __PACKAGE__;
    my $class = $self->Class;
    my $attrs = $self->Attributes;

    my $deleted;
    my %seen = ();
    foreach my $id( @{ $self->Ids } ) {
        my %session;
        local $@;
        eval { tie %session, $class, $id, $attrs };
        if( $@ ) {
            $RT::Logger->debug("skipped session '$id', couldn't load: $@");
            next;
        }
        if( $session{'CurrentUser'} && $session{'CurrentUser'}->id ) {
            unless( $seen{ $session{'CurrentUser'}->id }++ ) {
                $RT::Logger->debug("skipped session '$id', first user's session");
                next;
            }
        }
        tied(%session)->delete;
        $RT::Logger->info("successfully deleted session '$id'");
        $deleted++;
    }
    $self->ClearOrphanLockFiles if $deleted;
}

=head3 Load

Load a session or create a new one.

Accepts: Ref, Id

Ref is a reference to a hash which will be loaded with
session data.

Id is the id of an existing session. If set to undef or
omitted, an empty new session will be created with a session id
set with the key '_session_id'.

=cut

sub Load {
    my %args = (
        Ref => \%HTML::Mason::Commands::session,
        Id  => undef,
        @_
    );

    my %local_session;
    tie %local_session, 'RT::Interface::Web::Session', $args{'Id'};

    # Use { %local_session } instead of \%local_session to not clone the tie part.
    %{ $args{'Ref'} } = %{ Clone::clone( {%local_session} ) };

    untie %local_session;

    return 1;
}

=head3 Set

Set a value in the session.

Accepts: Ref, Key, SubKey, SubSubKey, Value

Ref is a reference to a hash for an existing session.
It is expected to have a key '_session_id' with the id of the
current session. The referenced hash will be also be updated
with the new value.

Key and the SubKey parameters indicate where in the hash
to set the value. The multiple subkey arguments handle multiple
hash levels from the previous direct hash implementation.

Value is the value to set in the indicated key.

If _session_id is not set, it simply updates Ref.

=cut

sub Set {
    my %args = (
        Ref => \%HTML::Mason::Commands::session,
        Key       => undef,
        SubKey    => undef,
        SubSubKey => undef,
        Value     => undef,
        @_
    );

    my $session_id = $args{'Ref'}->{'_session_id'};

    my %local_session;
    my $target;

    if ($session_id) {
        tie %local_session, 'RT::Interface::Web::Session', $session_id;
        $target = \%local_session;
    }
    else {
        # No session_id means not tied, in which case Ref is a plain hashref.
        $target = $args{'Ref'};
    }

    # Set the value, which will automagically set it in the back-end session storage
    if ( defined $args{'SubSubKey'} ) {
        $target->{ $args{'Key'} }{ $args{'SubKey'} }{ $args{'SubSubKey'} } = $args{'Value'};
    }
    elsif ( defined $args{'SubKey'} ) {
        $target->{ $args{'Key'} }{ $args{'SubKey'} } = $args{'Value'};
    }
    else {
        $target->{ $args{'Key'} } = $args{'Value'};
    }

    if ( tied %local_session ) {

        # Clone it back so we update the copy of the session with the latest values
        # Use { %local_session } instead of \%local_session to not clone the tie part.
        %{ $args{'Ref'} } = %{ Clone::clone( {%local_session} ) };

        # Apache::Session doesn't sync changes to subkeys, so force a sync
        # with a change at the top level.
        $local_session{i}++;

        untie %local_session;
    }

    return 1;
}

=head3 Delete

Delete a key from the session.

Accepts: Ref, Key, SubKey, SubSubKey

Ref is a reference to a hash for an existing session.
It is expected to have a key '_session_id' with the id of the
current session. The referenced hash will be also be updated
with the new value.

Key and the SubKey parameters indicate where in the hash
to delete the key. The multiple subkey arguments handle multiple
hash levels from the previous direct hash implementation.

If _session_id is not set, it simply deletes from Ref.

=cut

sub Delete {
    my %args = (
        Ref       => \%HTML::Mason::Commands::session,
        Key       => undef,
        SubKey    => undef,
        SubSubKey => undef,
        @_
    );

    my $session_id = $args{'Ref'}->{'_session_id'};
    my %local_session;

    my $target;

    if ($session_id) {
        tie %local_session, 'RT::Interface::Web::Session', $session_id;
        $target = \%local_session;
    }
    else {
        # No session_id means not tied, in which case Ref is a plain hashref.
        $target = $args{'Ref'};
    }

    if ( $args{'Key'} ) {

        # Delete requested item from the session
        if ( defined $args{'SubSubKey'} ) {
            delete $target->{ $args{'Key'} }{ $args{'SubKey'} }{ $args{'SubSubKey'} };
        }
        elsif ( defined $args{'SubKey'} ) {
            delete $target->{ $args{'Key'} }{ $args{'SubKey'} };
        }
        else {
            delete $target->{ $args{'Key'} };
        }

        if ( tied %local_session ) {

            # Apache::Session doesn't sync changes to subkeys, so force a sync
            # with a change at the top level.
            $local_session{i}++;

            # Use { %local_session } instead of \%local_session to not clone the tie part.
            %{ $args{'Ref'} } = %{ Clone::clone( {%local_session} ) };
        }
    }
    else {
        # No key provided, delete the whole session
        tied(%local_session)->delete if tied %local_session;
        %{ $args{'Ref'} } = ();
    }

    untie %local_session if tied %local_session;

    return 1;
}

sub TIEHASH {
    my $self = shift;
    my $id = shift;

    my $class = $self->Class;
    my $attrs = $self->Attributes;

    my %session;

    local $@;
    eval { tie %session, $class, $id, $attrs };
    eval { tie %session, $class, undef, $attrs } if $@;
    if ( $@ ) {
        die "RT couldn't store your session.  "
          . "This may mean that that the directory '$RT::MasonSessionDir' isn't writable or a database table is missing or corrupt.\n\n"
          . $@;
    }

    return tied %session;
}

RT::Base->_ImportOverlays();

1;
