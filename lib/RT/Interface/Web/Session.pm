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
package RT::Interface::Web::Session;
use warnings;
use strict;

use RT::CurrentUser;

=head1 name

RT::Interface::Web::Session - RT web session class

=head1 SYNOPSYS


=head1 description

RT session class and utilities.

CLASS METHODS can be used without creating object instances,
it's mainly utilities to clean unused session records.

object is tied hash and can be used to access session data.

=head1 METHODS

=head2 CLASS METHODS

=head3 Class

Returns name of the class that is used as sessions storage.

=cut

sub class {
    my $self = shift;

    my $class 
        = RT->config->get('WebSessionClass')
        || $self->backends->{ RT->config->get('DatabaseType') }
        || 'Apache::Session::File';
    eval "require $class";
    die $@ if $@;
    return $class;
}

=head3 Backends

Returns hash reference with names of the databases as keys and
sessions class names as values.

=cut

sub backends {
    return {
        mysql => 'Apache::Session::MySQL',
        Pg    => 'Apache::Session::Postgres',
    };
}

=head3 Attributes

Returns hash reference with attributes that are used to create
new session objects.

=cut

sub attributes {

    return $_[0]->backends->{ RT->config->get('DatabaseType') }
        ? {
        Handle      => Jifty->handle->dbh,
        LockHandle  => Jifty->handle->dbh,
        Transaction => 1,
        }
        : {
        Directory     => $RT::MasonSessionDir,
        LockDirectory => $RT::MasonSessionDir,
        Transaction   => 1,
        };
}

=head3 Ids

Returns array ref with list of the session IDs.

=cut

sub ids {
    my $self = shift || __PACKAGE__;
    my $attributes = $self->attributes;
    if ( $attributes->{Directory} ) {
        return $self->_ids_dir( $attributes->{Directory} );
    } else {
        return $self->_ids_db( Jifty->handle->dbh );
    }
}

sub _ids_dir {
    my ( $self, $dir ) = @_;
    require File::Find;
    my %file;
    File::Find::find(
        sub {
            return unless /^[a-zA-Z0-9]+$/;
            $file{$_} = ( stat($_) )[9];
        },
        $dir,
    );

    return [ sort { $file{$a} <=> $file{$b} } keys %file ];
}

sub _ids_db {
    my ( $self, $dbh ) = @_;
    my $ids = $dbh->selectcol_arrayref("SELECT id FROM sessions order BY last_updated DESC");
    die "couldn't get ids: " . $dbh->errstr if $dbh->errstr;
    return $ids;
}

=head3 ClearOld

Takes seconds and deletes all sessions that are older.

=cut

sub clear_old {
    my $class = shift || __PACKAGE__;
    my $attributes = $class->attributes;
    if ( $attributes->{Directory} ) {
        return $class->_cleari_old_dir( $attributes->{Directory}, @_ );
    } else {
        return $class->clear_old_db( Jifty->handle->dbh, @_ );
    }
}

sub clear_old_db {
    my ( $self, $dbh, $older_than ) = @_;
    my $rows;
    unless ( int $older_than ) {
        $rows = $dbh->do("DELETE FROM sessions");
        die "couldn't delete sessions: " . $dbh->errstr unless defined $rows;
    } else {
        require POSIX;
        my $date = POSIX::strftime( "%Y-%m-%d %H:%M", localtime( time - int $older_than ) );

        my $sth = $dbh->prepare("DELETE FROM sessions WHERE last_updated < ?");
        die "couldn't prepare query: " . $dbh->errstr unless $sth;
        $rows = $sth->execute($date);
        die "couldn't execute query: " . $dbh->errstr unless defined $rows;
    }

    Jifty->log->info("successfuly deleted $rows sessions");
    return;
}

sub _clear_old_dir {
    my ( $self, $dir, $older_than ) = @_;

    require File::Spec if int $older_than;

    my $now   = time;
    my $class = $self->class;
    my $attrs = $self->attributes;

    foreach my $id ( @{ $self->ids } ) {
        if ( int $older_than ) {
            my $ctime = ( stat( File::Spec->catfile( $dir, $id ) ) )[9];
            if ( $ctime > $now - $older_than ) {
                Jifty->log->debug("skipped session '$id', isn't old");
                next;
            }
        }

        my %session;
        local $@;
        eval { tie %session, $class, $id, $attrs };
        if ($@) {
            Jifty->log->debug("skipped session '$id', couldn't load: $@");
            next;
        }
        tied(%session)->delete;
        Jifty->log->info("successfuly deleted session '$id'");
    }
    return;
}

=head3 ClearByUser

Checks all sessions and if user has more then one session
then leave only the latest one.

=cut

sub clear_by_user {
    my $self  = shift || __PACKAGE__;
    my $class = $self->class;
    my $attrs = $self->attributes;

    my %seen = ();
    foreach my $id ( @{ $self->ids } ) {
        my %session;
        local $@;
        eval { tie %session, $class, $id, $attrs };
        if ($@) {
            Jifty->log->debug("skipped session '$id', couldn't load: $@");
            next;
        }
        if ( Jifty->web->current_user && Jifty->web->current_user->id ) {
            unless ( $seen{ Jifty->web->current_user->id }++ ) {
                Jifty->log->debug("skipped session '$id', first user's session");
                next;
            }
        }
        tied(%session)->delete;
        Jifty->log->info("successfuly deleted session '$id'");
    }
}

sub TIEHASH {
    my $self = shift;
    my $id   = shift;

    my $class = $self->class;
    my $attrs = $self->attributes;

    my %session;

    local $@;
    eval { tie %session, $class, $id, $attrs };
    eval { tie %session, $class, undef, $attrs } if $@;
    if ($@) {
        die _("RT couldn't store your session.") . "\n"
            . _( "This may mean that that the directory '%1' isn't writable or a database table is missing or corrupt.", $RT::MasonSessionDir ) . "\n\n"
            . $@;
    }

    return tied %session;
}

1;
