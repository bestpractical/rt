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
package RT::Shredder;

use strict;
use warnings;

=head1 name

RT::Shredder - Permanently wipeout data from RT


=head1 SYNOPSIS

=head2 CLI

  rt-shredder --force --plugin 'Tickets=queue,general;status,deleted'


=head1 description

RT::Shredder is extention to RT which allows you to permanently wipeout
data from the RT database.  Shredder supports the wiping of almost
all RT objects (Tickets, Transactions, Attachments, Users...).


=head2 "Delete" vs "Wipeout"

RT uses the term "delete" to mean "deactivate".  To avoid confusion,
RT::Shredder uses the term "Wipeout" to mean "permanently erase" (or
what most people would think of as "delete").


=head2 why do you want this?

Normally in RT, "deleting" an item simply deactivates it and makes it
invisible from view.  This is done to retain full history and
auditability of your tickets.  For most RT users this is fine and they
have no need of RT::Shredder.

But in some large and heavily used RT instances the database can get
clogged up with junk, particularly spam.  This can slow down searches
and bloat the size of the database.  For these users, RT::Shredder
allows them to completely clear the database of this unwanted junk.

An additional use of Shredder is to obliterate sensitive information
(passwords, credit card numbers, ...) which might have made their way
into RT.


=head2 command line tools (CLI)

L<rt-shredder> is a program which allows you to wipe objects from
command line or with system tasks scheduler (cron, for example).
See also 'rt-shredder --help'.


=head2 web based interface (WebUI)

Shredder's WebUI integrates into RT's WebUI.  You can find it in the
Configuration->tools->shredder tab.  The interface is similar to the
CLI and gives you the same functionality. You can find 'Shredder' link
at the bottom of tickets search results, so you could wipeout tickets
in the way similar to the bulk update.


=head1 DATA STORAGE AND BACKUPS

Shredder allows you to store data you wiped in files as scripts with SQL
commands.

=head3 Restoring from backup

Should you wipeout something you did not intend to the objects can be
restored by using the storage files.  These files are a simple set of
SQL commands to re-insert your objects into the RT database.

1) Locate the appropriate shredder SQL dump file.  In the WebUI, when
   you use shredder, the path to the dump file is displayed.  It also
   gives the option to download the dump file after each wipeout.  Or
   it can be found in your C<$ShredderStoragePath>.

2) Load the shredder SQL dump into your RT database.  The details will
   be different for each database and RT configuration, consult your
   database manual and RT config.  For example, in MySQL...

    mysql -u your_rt_user -p your_rt_database < /path/to/rt/var/data/shredder/dump.sql

That's it.i This will restore everything you'd deleted during a
shredding session when the file had been Created.

=head1 CONFIGURATION

=head2 $RT::DependenciesLimit

Shredder stops with an error if the object has more than
C<$RT::DependenciesLimit> dependencies. For example: a ticket has 1000
transactions or a transaction has 1000 attachments. This is protection
from bugs in shredder from wiping out your whole database, but
sometimes when you have big mail loops you may hit it.

Defaults to 1000.

You can change the default value, in F<RT_SiteConfig.pm> add C<Set(
$DependenciesLimit, new_limit );>


=head2 $ShredderStoragePath

Directory containing Shredder backup dumps.

Defaults to F</path-to-RT-var-dir/data/RT-Shredder>.

You can change the default value, in F<RT_SiteConfig.pm> add C<Set(
$ShredderStoragePath, new_path );>  Be sure to use an absolute path.


=head1 INFORMATION FOR DEVELOPERS

=head2 general API

L<RT::Shredder> is an extension to RT which adds shredder methods to
RT objects and classes.  The API is not well documented yet, but you
can find usage examples in L<rt-shredder> and the
F<lib/t/regression/shredder/*.t> test files.

However, here is a small example that do the same action as in CLI
example from L</SYNOPSIS>:

  use RT::Shredder;
  RT::Shredder::Init( force => 1 );
  my $deleted = RT::Model::TicketCollection->new(current_user => RT->system_user );
  $deleted->{'allow_deleted_search'} = 1;
  $deleted->limit_queue( value => 'general' );
  $deleted->limit_status( value => 'deleted' );
  while( my $t = $deleted->next ) {
      $t->wipeout;
  }


=head2 RT::Shredder class' API

L<RT::Shredder> implements interfaces to objects cache, actions on the
objects in the cache and backups storage.

=cut

our $VERSION = '0.04';
use File::Spec ();

BEGIN {

    # I can't use 'use lib' here since it breakes tests
    # because test suite uses old RT::Shredder setup from
    # RT lib path

### after:     push @INC, qw(@RT_LIB_PATH@);
    push @INC, qw(/opt/rt3/local/lib /opt/rt3/lib);
    use RT::Shredder::Constants;
    use RT::Shredder::Exceptions;

    require RT;

    require RT::Shredder::Record;

    require RT::Shredder::ACE;
    require RT::Shredder::Attachment;
    require RT::Shredder::CachedGroupMember;
    require RT::Shredder::CustomField;
    require RT::Shredder::CustomFieldValue;
    require RT::Shredder::GroupMember;
    require RT::Shredder::Group;
    require RT::Shredder::Link;
    require RT::Shredder::Principal;
    require RT::Shredder::Queue;
    require RT::Shredder::Scrip;
    require RT::Shredder::ScripAction;
    require RT::Shredder::ScripCondition;
    require RT::Shredder::Template;
    require RT::Shredder::ObjectCustomFieldValue;
    require RT::Shredder::Ticket;
    require RT::Shredder::Transaction;
    require RT::Shredder::User;
}

our @SUPPORTED_OBJECTS = qw(
    ACE
    Attachment
    CachedGroupMember
    CustomField
    CustomFieldValue
    GroupMember
    Group
    Link
    Principal
    Queue
    Scrip
    ScripAction
    ScripCondition
    Template
    ObjectCustomFieldValue
    Ticket
    Transaction
    User
);

=head3 GENERIC

=head4 Init

    RT::Shredder::Init( %default_options );

C<RT::Shredder::Init()> should be called before creating an
RT::Shredder object.  It iniitalizes RT and loads the RT
configuration.

%default_options are passed to every C<<RT::Shredder->new>> call.

=cut

our %opt = ();

sub init {
    %opt = @_;
    RT::load_config();
    RT::init();
}

=head4 new

  my $shredder = RT::Shredder->new(%options);

Construct a RT::Shredder->new Object.

There currently are no %options.

=cut

sub new {
    my $proto = shift;
    my $self = bless( {}, ref $proto || $proto );
    $self->_init(@_);
    return $self;
}

sub _init {
    my $self = shift;
    $self->{'opt'}          = { %opt, @_ };
    $self->{'cache'}        = {};
    $self->{'resolver'}     = {};
    $self->{'dump_plugins'} = [];
}

=head4 CastobjectsToRecords( objects => undef )

Cast objects to the C<RT::Record> objects or its ancesstors.
objects can be passed as SCALAR (format C<< <class>-<id> >>),
ARRAY, C<RT::Record> ancesstors or C<RT::SearchBuilder> ancesstor.

Most methods that takes C<objects> argument use this method to
cast argument value to list of records.

Returns an array of records.

For example:

    my @objs = $shredder->cast_objects_to_records(
        objects => [             # ARRAY reference
            'RT::Model::Attachment-10', # SCALAR or SCALAR reference
            $tickets,            # RT::Model::TicketCollection object (isa RT::SearchBuilder)
            $user,               # RT::Model::User object (isa RT::Record)
        ],
    );

=cut

sub cast_objects_to_records {
    my $self = shift;
    my %args = ( objects => undef, @_ );

    my @res;
    my $targets = delete $args{'objects'};
    unless ($targets) {
        RT::Shredder::Exception->throw("Undefined objects argument");
    }

    if ( UNIVERSAL::isa( $targets, 'RT::SearchBuilder' ) ) {

        #XXX: try to use ->_do_search + ->items_array_ref in feature
        #     like we do in Record with links, but change only when
        #     more tests would be available
        while ( my $tmp = $targets->next ) { push @res, $tmp }
    } elsif ( UNIVERSAL::isa( $targets, 'RT::Record' ) ) {
        push @res, $targets;
    } elsif ( UNIVERSAL::isa( $targets, 'ARRAY' ) ) {
        foreach (@$targets) {
            push @res, $self->cast_objects_to_records( objects => $_ );
        }
    } elsif ( UNIVERSAL::isa( $targets, 'SCALAR' ) || !ref $targets ) {
        $targets = $$targets if ref $targets;
        my ( $class, $id ) = split /-/, $targets;
        $class = 'RT::' . $class unless $class =~ /^RTx?::/i;
        eval "require $class";
        die "Couldn't load '$class' module" if $@;
        my $obj = $class->new( current_user => RT->system_user );
        die "Couldn't construct new '$class' object" unless $obj;
        $obj->load($id);

        unless ( $obj->id ) {
            Jifty->log->error("Couldn't load '$class' object with id '$id'");
            RT::Shredder::Exception::Info->throw('CouldntLoadobject');
        }
        die "Loaded object has different id" unless ( $id eq $obj->id );
        push @res, $obj;
    } else {
        RT::Shredder::Exception->throw( "Unsupported type " . ref $targets );
    }
    return @res;
}

=head3 OBJECTS CACHE

=head4 Putobjects( objects => undef )

Puts objects into cache.

Returns array of the cache entries.

See C<CastobjectsToRecords> method for supported types of the C<objects>
argument.

=cut

sub put_objects {
    my $self = shift;
    my %args = ( objects => undef, @_ );

    my @res;
    for ( $self->cast_objects_to_records( objects => delete $args{'objects'} ) ) {
        push @res, $self->put_object( %args, object => $_ );
    }

    return @res;
}

=head4 Putobject( object => undef )

Puts record object into cache and returns its cache entry.

B<NOTE> that this method support B<only C<RT::Record> object or its ancesstor
objects>, if you want put mutliple objects or objects represented by different
classes then use C<Putobjects> method instead.

=cut

sub put_object {
    my $self = shift;
    my %args = ( object => undef, @_ );

    my $obj = $args{'object'};
    unless ( UNIVERSAL::isa( $obj, 'RT::Record' ) ) {
        RT::Shredder::Exception->throw( "Unsupported type '" . ( ref $obj || $obj || '(undef)' ) . "'" );
    }

    my $str = $obj->_as_string;
    return ( $self->{'cache'}->{$str} ||= { state => ON_STACK, object => $obj } );
}

=head4 Getobject, GetState, GetRecord( String => ''| object => '' )

Returns record object from cache, cache entry state or cache entry accordingly.

All three methods takes C<String> (format C<< <class>-<id> >>) or C<object> argument.
C<String> argument has more priority than C<object> so if it's not empty then methods
leave C<object> argument unchecked.

You can read about possible states and their meanings in L<RT::Shredder::Constants> docs.

=cut

sub _parse_ref_str_args {
    my $self = shift;
    my %args = (
        string => '',
        object => undef,
        @_
    );
    if ( $args{'string'} && $args{'object'} ) {
        require Carp;
        Carp::croak("both String and object args passed");
    }
    return $args{'string'} if $args{'string'};
    return $args{'object'}->_as_string
        if UNIVERSAL::can( $args{'object'}, '_as_string' );
    return '';
}

sub get_object { return (shift)->get_record(@_)->{'object'} }
sub get_state  { return (shift)->get_record(@_)->{'state'} }

sub get_record {
    my $self = shift;
    my $str  = $self->_parse_ref_str_args(@_);
    return $self->{'cache'}->{$str};
}

=head3 Dependencies resolvers

=head4 PutResolver, GetResolvers and ApplyResolvers

TODO: These methods have no documentation.

=cut

sub put_resolver {
    my $self = shift;
    my %args = (
        base_class   => '',
        target_class => '',
        code         => undef,
        @_,
    );
    unless ( UNIVERSAL::isa( $args{'code'} => 'CODE' ) ) {
        die "Resolver '$args{Code}' is not code reference";
    }

    my $resolvers = ( ( $self->{'resolver'}->{ $args{'base_class'} } ||= {} )->{ $args{'target_class'} || '' } ||= [] );
    unshift @$resolvers, $args{'code'};
    return;
}

sub get_resolvers {
    my $self = shift;
    my %args = (
        base_class   => '',
        target_class => '',
        @_,
    );

    my @res;
    if ( $args{'target_class'}
        && exists $self->{'resolver'}->{ $args{'base_class'} }->{ $args{'target_class'} } )
    {
        push @res, @{ $self->{'resolver'}->{ $args{'base_class'} }->{ $args{'target_class'} || '' } };
    }
    if ( exists $self->{'resolver'}->{ $args{'base_class'} }->{''} ) {
        push @res, @{ $self->{'resolver'}->{ $args{'base_class'} }->{''} };
    }

    return @res;
}

sub apply_resolvers {
    my $self = shift;
    my %args = ( dependency => undef, @_ );
    my $dep  = $args{'dependency'};

    my @resolvers = $self->get_resolvers(
        base_class   => $dep->base_class,
        target_class => $dep->target_class,
    );

    unless (@resolvers) {
        RT::Shredder::Exception::Info->throw(
            tag   => 'NoResolver',
            error => "Couldn't find resolver for dependency '" . $dep->as_string . "'",
        );
    }
    $_->(
        shredder      => $self,
        base_object   => $dep->base_object,
        target_object => $dep->target_object,
    ) foreach @resolvers;

    return;
}

sub wipeout_all {
    my $self = $_[0];

    while ( my ( $k, $v ) = each %{ $self->{'cache'} } ) {
        next if $v->{'state'} & ( WIPED | IN_WIPING );
        $self->wipeout( object => $v->{'object'} );
    }
}

sub wipeout {
    my $self = shift;
    my $mark;
    eval {
        die "Couldn't begin transaction"
            unless Jifty->handle->begin_transaction;
        $mark = $self->push_dump_mark or die "Couldn't get dump mark";
        $self->_wipeout(@_);
        $self->pop_dump_mark( mark => $mark );
        die "Couldn't commit transaction" unless Jifty->handle->commit;
    };
    if ($@) {
        Jifty->handle->rollback('force');
        $self->rollback_dump_to( mark => $mark ) if $mark;
        die $@ if RT::Shredder::Exception::Info->caught;
        die "Couldn't wipeout object: $@";
    }
}

sub _wipeout {
    my $self = shift;
    my %args = ( cache_record => undef, object => undef, @_ );

    my $record = $args{'cache_record'};
    $record = $self->put_object( object => $args{'object'} ) unless $record;
    return if $record->{'state'} & ( WIPED | IN_WIPING );

    $record->{'state'} |= IN_WIPING;
    my $object = $record->{'object'};

    $self->dump_object( object => $object, state => 'before any action' );

    unless ( $object->before_wipeout ) {
        RT::Shredder::Exception->throw("BeforeWipeout check returned error");
    }

    my $deps = $object->dependencies( shredder => $self );
    $deps->list(
        with_flags => DEPENDS_ON | VARIABLE,
        callback   => sub { $self->apply_resolvers( dependency => $_[0] ) },
    );
    $self->dump_object( object => $object, state => 'after resolvers' );

    $deps->list(
        with_flags    => DEPENDS_ON,
        without_flags => WIPE_AFTER | VARIABLE,
        callback      => sub { $self->_wipeout( object => $_[0]->target_object ) },
    );
    $self->dump_object(
        object => $object,
        state  => 'after wiping dependencies'
    );

    $object->__wipeout;
    $record->{'state'} |= WIPED;
    delete $record->{'object'};
    $self->dump_object( object => $object, state => 'after wipeout' );

    $deps->list(
        with_flags    => DEPENDS_ON | WIPE_AFTER,
        without_flags => VARIABLE,
        callback      => sub { $self->_wipeout( object => $_[0]->target_object ) },
    );
    $self->dump_object(
        object => $object,
        state  => 'after late dependencies'
    );

    return;
}

sub validate_relations {
    my $self = shift;
    my %args = (@_);

    foreach my $record ( values %{ $self->{'cache'} } ) {
        next if ( $record->{'state'} & VALID );
        $record->{'object'}->validate_relations( shredder => $self );
    }
}

=head3 Data storage and backups

=head4 GetFilename( Filename => '<ISO DATETIME>-XXXX.sql', FromStorage => 1 )

Takes desired C<Filename> and flag C<FromStorage> then translate file name to absolute
path by next rules:

* Default value of the C<Filename> option is C<< <ISO DATETIME>-XXXX.sql >>;

* if C<Filename> has C<XXXX> (exactly four uppercase C<X> letters) then it would be changed with digits from 0000 to 9999 range, with first one free value;

* if C<Filename> has C<%T> then it would be replaced with the current date and time in the C<YYYY-MM-DDTHH:MM:SS> format. Note that using C<%t> may still generate not unique names, using C<XXXX> recomended.

* if C<FromStorage> argument is true (default behaviour) then result path would always be relative to C<StoragePath>;

* if C<FromStorage> argument is false then result would be relative to the current dir unless it's already absolute path.

Returns an absolute path of the file.

Examples:
    # file from storage with default name format
    my $fname = $shredder->get_filename;

    # file from storage with custom name format
    my $fname = $shredder->get_filename( Filename => 'shredder-XXXX.backup' );

    # file with path relative to the current dir
    my $fname = $shredder->get_filename(
        FromStorage => 0,
        Filename => 'backups/shredder.sql',
    );

    # file with absolute path
    my $fname = $shredder->get_filename(
        FromStorage => 0,
        Filename => '/var/backups/shredder-XXXX.sql'
    );

=cut

sub get_filename {
    my $self = shift;
    my %args = ( filename => '', from_storage => 1, @_ );

    # default value
    my $file = $args{'filename'} || '%t-XXXX.sql';
    if ( $file =~ /\%t/i ) {
        require POSIX;
        my $date_time = POSIX::strftime( "%Y%m%dT%H%M%S", gmtime );
        $file =~ s/\%t/$date_time/gi;
    }

    # convert to absolute path
    if ( $args{'from_storage'} ) {
        $file = File::Spec->catfile( $self->storage_path, $file );
    } elsif ( !File::Spec->file_name_is_absolute($file) ) {
        $file = File::Spec->rel2abs($file);
    }

    # check mask
    if ( $file =~ /XXXX[^\/\\]*$/ ) {
        my ( $tmp, $i ) = ( $file, 0 );
        do {
            $i++;
            $tmp = $file;
            $tmp =~ s/XXXX([^\/\\]*)$/sprintf("%04d", $i).$1/e;
        } while ( -e $tmp && $i < 9999 );
        $file = $tmp;
    }

    if ( -f $file ) {
        unless ( -w _ ) {
            die "File '$file' exists, but is read-only";
        }
    } elsif ( !-e _ ) {
        unless ( File::Spec->file_name_is_absolute($file) ) {
            $file = File::Spec->rel2abs($file);
        }

        # check base dir
        my $dir = File::Spec->join( ( File::Spec->splitpath($file) )[ 0, 1 ] );
        unless ( -e $dir && -d _ ) {
            die "base directory '$dir' for file '$file' doesn't exist";
        }
        unless ( -w $dir ) {
            die "base directory '$dir' is not writable";
        }
    } else {
        die "'$file' is not regular file";
    }

    return $file;
}

=head4 StoragePath

Returns an absolute path to the storage dir.  See
L<CONFIGURATION/$ShredderStoragePath>.

See also description of the L</GetFilename> method.

=cut

sub storage_path {
    return scalar( RT->config->get('ShredderStoragePath') )
        || File::Spec->catdir( $RT::VarPath, qw(data RT-Shredder) );
}

my %active_dump_state = ();

sub add_dump_plugin {
    my $self = shift;
    my %args = ( object => undef, name => 'SQLDump', arguments => undef, @_ );

    my $plugin = $args{'object'};
    unless ($plugin) {
        require RT::Shredder::Plugin;
        $plugin = RT::Shredder::Plugin->new;
        my ( $status, $msg ) = $plugin->load_by_name( $args{'name'} );
        die "Couldn't load dump plugin: $msg\n" unless $status;
    }
    die "Plugin is not of correct type" unless lc $plugin->type eq 'dump';

    if ( my $pargs = $args{'arguments'} ) {
        my ( $status, $msg ) = $plugin->test_args(%$pargs);
        die "Couldn't set plugin args: $msg\n" unless $status;
    }

    my @applies_to = $plugin->applies_to_states;
    die "Plugin doesn't apply to any state" unless @applies_to;
    $active_dump_state{ lc $_ } = 1 foreach @applies_to;

    push @{ $self->{'dump_plugins'} }, $plugin;

    return $plugin;
}

sub dump_object {
    my $self = shift;
    my %args = ( object => undef, state => undef, @_ );
    die "No state passed" unless $args{'state'};
    return unless $active_dump_state{ lc $args{'state'} };

    foreach ( @{ $self->{'dump_plugins'} } ) {
        next unless grep lc $args{'state'} eq lc $_, $_->applies_to_states;
        my ( $state, $msg ) = $_->run(%args);
        die "Couldn't run plugin: $msg" unless $state;
    }
}

{
    my $mark = 1;    # XXX: integer overflows?

    sub push_dump_mark {
        my $self = shift;
        $mark++;
        foreach ( @{ $self->{'dump_plugins'} } ) {
            my ( $state, $msg ) = $_->push_mark( mark => $mark );
            die "Couldn't push mark: $msg" unless $state;
        }
        return $mark;
    }

    sub pop_dump_mark {
        my $self = shift;
        foreach ( @{ $self->{'dump_plugins'} } ) {
            my ( $state, $msg ) = $_->push_mark(@_);
            die "Couldn't pop mark: $msg" unless $state;
        }
    }

    sub rollback_dump_to {
        my $self = shift;
        foreach ( @{ $self->{'dump_plugins'} } ) {
            my ( $state, $msg ) = $_->rollback_to(@_);
            die "Couldn't rollback to mark: $msg" unless $state;
        }
    }
}

1;
__END__

=head1 NOTES

=head2 database transactions support

Since 0.03_01 RT::Shredder uses database transactions and should be
much safer to run on production servers.

=head2 foreign keys

Mainstream RT doesn't use FKs, but at least I posted DDL script that creates them
in mysql DB, note that if you use FKs then this two valid keys don't allow delete
Tickets because of bug in MySQL:

  ALTER TABLE Tickets ADD FOREIGN KEY (effective_id) REFERENCES Tickets(id);
  ALTER TABLE CachedGroupMembers ADD FOREIGN KEY (Via) REFERENCES CachedGroupMembers(id);

L<http://bugs.mysql.com/bug.php?id=4042>

=head1 BUGS AND HOW TO CONTRIBUTE

We need your feedback in all cases: if you use it or not,
is it works for you or not.

=head2 testing

Don't skip C<make test> step while install and send me reports if it's fails.
Add your own tests, it's easy enough if you've writen at list one perl script
that works with RT. Read more about testing in F<t/utils.pl>.

=head2 reporting

Send reports to L</AUTHOR> or to the RT mailing lists.

=head2 documentation

Many bugs in the docs: insanity, spelling, gramar and so on.
Patches are wellcome.

=head2 todo

Please, see Todo file, it has some technical notes
about what I plan to do, when I'll do it, also it
describes some problems code has.

=head2 repository

Since RT-3.7 shredder is a part of the RT distribution.
Versions of the RTx::Shredder extension could
be downloaded from the CPAN. Those work with older
RT versions or you can find repository at
L<https://opensvn.csie.org/rtx_shredder>

=head1 AUTHOR

    Ruslan U. Zakirov <Ruslan.Zakirov@gmail.com>

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
Perl distribution.

=head1 SEE ALSO

L<rt-shredder>, L<rt-validator>

=cut
