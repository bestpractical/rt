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

use strict;
use warnings;

package RT::Test::Shredder;
use base 'RT::Test';

require File::Copy;
require Cwd;

=head1 DESCRIPTION

RT::Shredder test suite utilities

=head1 TESTING

Since RT:Shredder 0.01_03 we have a test suite. You
can run tests and see if everything works as expected
before you try shredder on your actual data.
Tests also help in the development process.

The test suite uses SQLite databases to store data in individual files,
so you could sun tests on your production servers without risking
damage to your production data.

You'll want to run the test suite almost every time you install or update
the shredder distribution, especialy if you have local customizations of
the DB schema and/or RT code.

Tests are one thing you can write even if you don't know much perl,
but want to learn more about RT's internals. New tests are very welcome.

=head2 WRITING TESTS

The shredder distribution has several files to help write new tests.

  t/shredder/utils.pl - this file, utilities
  t/00skeleton.t - skeleteton .t file for new tests

All tests follow this algorithm:

  require "t/shredder/utils.pl"; # plug in utilities
  init_db(); # create new tmp RT DB and init RT API
  # create RT data you want to be always in the RT DB
  # ...
  create_savepoint('mysp'); # create DB savepoint
  # create data you want delete with shredder
  # ...
  # run shredder on the objects you've created
  # ...
  # check that shredder deletes things you want
  # this command will compare savepoint DB with current
  cmp_deeply( dump_current_and_savepoint('mysp'), "current DB equal to savepoint");
  # then you can create another object and delete it, then check again

Savepoints are named and you can create two or more savepoints.

=cut

sub import {
    my $class = shift;

    $class->SUPER::import(@_, tests => undef );

    RT::Test::plan( skip_all => 'Shredder tests only work on SQLite' )
          unless RT->Config->Get('DatabaseType') eq 'SQLite';

    my %args = @_;
    RT::Test::plan( tests => $args{'tests'} ) if $args{tests};

    $class->export_to_level(1);
}

=head1 FUNCTIONS

=head2 DATABASES

=head3 db_name

Returns the absolute file path to the current DB.
It is C<<RT::Test->temp_directory . "rt4test" >>.

=cut

sub db_name { return RT->Config->Get("DatabaseName") }

=head3 connect_sqlite

Returns connected DBI DB handle.

Takes path to sqlite db.

=cut

sub connect_sqlite
{
    my $self = shift;
    return DBI->connect("dbi:SQLite:dbname=". shift, "", "");
}

=head2 SHREDDER

=head3 shredder_new

Creates and returns a new RT::Shredder object.

=cut

sub shredder_new
{
    my $self = shift;

    require RT::Shredder;
    my $obj = RT::Shredder->new;

    my $file = File::Spec->catfile( $self->temp_directory, 'dump.XXXX.sql' );
    $obj->AddDumpPlugin( Arguments => {
        file_name    => $file,
        from_storage => 0,
    } );

    return $obj;
}


=head2 SAVEPOINTS

=head3 savepoint_name

Returns the absolute path to the named savepoint DB file.
Takes one argument - savepoint name, by default C<sp>.

=cut

sub savepoint_name
{
    my $self  = shift;
    my $name = shift || 'default';
    return File::Spec->catfile( $self->temp_directory, "sp.$name.db" );
}

=head3 create_savepoint

Creates savepoint DB from the current DB.
Takes name of the savepoint as argument.

=head3 restore_savepoint

Restores current DB to savepoint state.
Takes name of the savepoint as argument.

=cut

sub create_savepoint {
    my $self = shift;
    return $self->__cp_db( $self->db_name => $self->savepoint_name( shift ) );
}
sub restore_savepoint {
    my $self = shift;
    return $self->__cp_db( $self->savepoint_name( shift ) => $self->db_name );
}
sub __cp_db
{
    my $self  = shift;
    my( $orig, $dest ) = @_;
    RT::Test::__disconnect_rt();
    File::Copy::copy( $orig, $dest ) or die "Couldn't copy '$orig' => '$dest': $!";
    RT::Test::__reconnect_rt();
    return;
}


=head2 DUMPS

=head3 dump_sqlite

Returns DB dump as a complex hash structure:
    {
    TableName => {
        #id => {
            lc_field => 'value',
        }
    }
    }

Takes named argument C<CleanDates>. If true, clean all date fields from
dump. True by default.

=cut

sub dump_sqlite
{
    my $self = shift;
    my $dbh = shift;
    my %args = ( CleanDates => 1, @_ );

    my $old_fhkn = $dbh->{'FetchHashKeyName'};
    $dbh->{'FetchHashKeyName'} = 'NAME_lc';

    my @tables = $RT::Handle->_TableNames( $dbh );

    my $res = {};
    foreach my $t( @tables ) {
        next if lc($t) eq 'sessions';
        $res->{$t} = $dbh->selectall_hashref(
            "SELECT * FROM $t". $self->dump_sqlite_exceptions($t), 'id'
        );
        $self->clean_dates( $res->{$t} ) if $args{'CleanDates'};
        die $DBI::err if $DBI::err;
    }

    $dbh->{'FetchHashKeyName'} = $old_fhkn;
    return $res;
}

=head3 dump_sqlite_exceptions

If there are parts of the DB which can change from creating and deleting
a queue, skip them when doing the comparison.  One example is the global
queue cache attribute on RT::System which will be updated on Queue creation
and can't be rolled back by the shredder.  It may actually make sense for
Shredder to be updating this at some point in the future.

=cut

sub dump_sqlite_exceptions {
    my $self = shift;
    my $table = shift;

    my $special_wheres = {
        attributes => " WHERE Name != 'QueueCacheNeedsUpdate'"
    };

    return $special_wheres->{lc $table}||'';

}

=head3 dump_current_and_savepoint

Returns dump of the current DB and of the named savepoint.
Takes one argument - savepoint name.

=cut

sub dump_current_and_savepoint
{
    my $self = shift;
    my $orig = $self->savepoint_name( shift );
    die "Couldn't find savepoint file" unless -f $orig && -r _;
    my $odbh = $self->connect_sqlite( $orig );
    return ( $self->dump_sqlite( $RT::Handle->dbh, @_ ), $self->dump_sqlite( $odbh, @_ ) );
}

=head3 dump_savepoint_and_current

Returns the same data as C<dump_current_and_savepoint> function,
but in reversed order.

=cut

sub dump_savepoint_and_current { return reverse (shift)->dump_current_and_savepoint(@_) }

sub clean_dates
{
    my $self = shift;
    my $h = shift;
    my $date_re = qr/^\d\d\d\d\-\d\d\-\d\d\s*\d\d\:\d\d(\:\d\d)?$/i;
    foreach my $id ( keys %{ $h } ) {
        next unless $h->{ $id };
        foreach ( keys %{ $h->{ $id } } ) {
            delete $h->{$id}{$_} if $h->{$id}{$_} &&
              $h->{$id}{$_} =~ /$date_re/;
        }
    }
}

1;
