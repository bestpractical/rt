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

package RT::Shredder;

use strict;
use warnings;



=head1 NAME

RT::Shredder - Permanently wipeout data from RT


=head1 SYNOPSIS

=head2 CLI

  rt-shredder --force --plugin 'Tickets=query,Queue="General" and Status="deleted"'

=head1 DESCRIPTION

RT::Shredder is extension to RT which allows you to permanently wipeout
data from the RT database.  Shredder supports the wiping of almost
all RT objects (Tickets, Transactions, Attachments, Users...).


=head2 "Delete" vs "Wipeout"

RT uses the term "delete" to mean "deactivate".  To avoid confusion,
RT::Shredder uses the term "Wipeout" to mean "permanently erase" (or
what most people would think of as "delete").


=head2 Why do you want this?

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


=head2 Command line tools (CLI)

L<rt-shredder> is a program which allows you to wipe objects from
command line or with system tasks scheduler (cron, for example).
See also 'rt-shredder --help'.


=head2 Web based interface (WebUI)

Shredder's WebUI integrates into RT's WebUI.  You can find it in the
Admin->Tools->Shredder tab.  The interface is similar to the
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
shredding session when the file had been created.

=head1 CONFIGURATION

=head2 $DependenciesLimit

Shredder stops with an error if the object has more than
C<$DependenciesLimit> dependencies. For example: a ticket has 1000
transactions or a transaction has 1000 attachments. This is protection
from bugs in shredder from wiping out your whole database, but
sometimes when you have big mail loops you may hit it.

Defaults to 1000.  To change this (for example, to 10000) add the
following to your F<RT_SiteConfig.pm>:

    Set( $DependenciesLimit, 10_000 );>


=head2 $ShredderStoragePath

Directory containing Shredder backup dumps; defaults to
F</opt/rt4/var/data/RT-Shredder> (assuming an /opt/rt4 installation).

To change this (for example, to /some/backup/path) add the following to
your F<RT_SiteConfig.pm>:

    Set( $ShredderStoragePath, "/some/backup/path" );>

Be sure to specify an absolute path.

=head1 Database Indexes

We have found that the following indexes significantly speed up
shredding on most databases.

    CREATE INDEX SHREDDER_CGM1 ON CachedGroupMembers(MemberId, GroupId, Disabled);
    CREATE INDEX SHREDDER_CGM2 ON CachedGroupMembers(ImmediateParentId,MemberId);
    CREATE INDEX SHREDDER_CGM3 on CachedGroupMembers (Via, Id);

    CREATE UNIQUE INDEX SHREDDER_GM1 ON GroupMembers(MemberId, GroupId);

    CREATE INDEX SHREDDER_TXN1 ON Transactions(ReferenceType, OldReference);
    CREATE INDEX SHREDDER_TXN2 ON Transactions(ReferenceType, NewReference);
    CREATE INDEX SHREDDER_TXN3 ON Transactions(Type, OldValue);
    CREATE INDEX SHREDDER_TXN4 ON Transactions(Type, NewValue);

    CREATE INDEX SHREDDER_ATTACHMENTS1 ON Attachments(Creator);

=head1 INFORMATION FOR DEVELOPERS

=head2 General API

L<RT::Shredder> is an extension to RT which adds shredder methods to
RT objects and classes.  The API is not well documented yet, but you
can find usage examples in L<rt-shredder> and the
F<lib/t/regression/shredder/*.t> test files.

However, here is a small example that do the same action as in CLI
example from L</SYNOPSIS>:

  use RT::Shredder;
  RT::Shredder::Init( force => 1 );
  my $deleted = RT::Tickets->new( RT->SystemUser );
  $deleted->{'allow_deleted_search'} = 1;
  $deleted->LimitQueue( VALUE => 'general' );
  $deleted->LimitStatus( VALUE => 'deleted' );
  while( my $t = $deleted->Next ) {
      $t->Wipeout;
  }


=head2 RT::Shredder class' API

L<RT::Shredder> implements interfaces to objects cache, actions on the
objects in the cache and backups storage.

=cut

use File::Spec ();


BEGIN {
# I can't use 'use lib' here since it breakes tests
# because test suite uses old RT::Shredder setup from
# RT lib path

### after:     push @INC, qw(@RT_LIB_PATH@);
    use RT::Shredder::Constants;
    use RT::Shredder::Exceptions;
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

sub Init
{
    %opt = @_;
    RT::LoadConfig();
    RT::Init();
    return;
}

=head4 new

  my $shredder = RT::Shredder->new(%options);

Construct a new RT::Shredder object.

There currently are no %options.

=cut

sub new
{
    my $proto = shift;
    my $self = bless( {}, ref $proto || $proto );
    return $self->_Init( @_ );
}

sub _Init
{
    my $self = shift;
    $self->{'opt'}          = { %opt, @_ };
    $self->{'cache'}        = {};
    $self->{'resolver'}     = {};
    $self->{'dump_plugins'} = [];
    return $self;
}

=head4 CastObjectsToRecords( Objects => undef )

Cast objects to the C<RT::Record> objects or its ancesstors.
Objects can be passed as SCALAR (format C<< <class>-<id> >>),
ARRAY, C<RT::Record> ancesstors or C<RT::SearchBuilder> ancesstor.

Most methods that takes C<Objects> argument use this method to
cast argument value to list of records.

Returns an array of records.

For example:

    my @objs = $shredder->CastObjectsToRecords(
        Objects => [             # ARRAY reference
            'RT::Attachment-10', # SCALAR or SCALAR reference
            $tickets,            # RT::Tickets object (isa RT::SearchBuilder)
            $user,               # RT::User object (isa RT::Record)
        ],
    );

=cut

sub CastObjectsToRecords
{
    my $self = shift;
    my %args = ( Objects => undef, @_ );

    my @res;
    my $targets = delete $args{'Objects'};
    unless( $targets ) {
        RT::Shredder::Exception->throw( "Undefined Objects argument" );
    }

    if( UNIVERSAL::isa( $targets, 'RT::SearchBuilder' ) ) {
        #XXX: try to use ->_DoSearch + ->ItemsArrayRef in feature
        #     like we do in Record with links, but change only when
        #     more tests would be available
        while( my $tmp = $targets->Next ) { push @res, $tmp };
    } elsif ( UNIVERSAL::isa( $targets, 'RT::Record' ) ) {
        push @res, $targets;
    } elsif ( UNIVERSAL::isa( $targets, 'ARRAY' ) ) {
        foreach( @$targets ) {
            push @res, $self->CastObjectsToRecords( Objects => $_ );
        }
    } elsif ( UNIVERSAL::isa( $targets, 'SCALAR' ) || !ref $targets ) {
        $targets = $$targets if ref $targets;
        my ($class, $org, $id);
        if ($targets =~ /-.*-/) {
            ($class, $org, $id) = split /-/, $targets;
            RT::Shredder::Exception->throw( "Can't wipeout remote object $targets" )
                  unless $org eq RT->Config->Get('Organization');
        } else {
            ($class, $id) = split /-/, $targets;
        }
        RT::Shredder::Exception->throw( "Unsupported class $class" )
              unless $class =~ /^\w+(::\w+)*$/;
        $class = 'RT::'. $class unless $class =~ /^RTx?::/i;
        $class->require or die "Failed to load $class: $@";
        my $obj = $class->new( RT->SystemUser );
        die "Couldn't construct new '$class' object" unless $obj;
        $obj->Load( $id );
        unless ( $obj->id ) {
            $RT::Logger->error( "Couldn't load '$class' object with id '$id'" );
            RT::Shredder::Exception::Info->throw( 'CouldntLoadObject' );
        }

        if ( $id =~ /^\d+$/ ) {
            if ( $id ne $obj->Id ) {
                die 'Loaded object id ' . $obj->Id . " is different from passed id $id";
            }
        }
        else {
            if ( $obj->_Accessible( 'Name', 'read' ) && $id ne $obj->Name ) {
                die 'Loaded object name ' . $obj->Name . " is different from passed name $id";
            }
        }
        push @res, $obj;
    } else {
        RT::Shredder::Exception->throw( "Unsupported type ". ref $targets );
    }
    return @res;
}

=head3 OBJECTS CACHE

=head4 PutObjects( Objects => undef )

Puts objects into cache.

Returns array of the cache entries.

See C<CastObjectsToRecords> method for supported types of the C<Objects>
argument.

=cut

sub PutObjects
{
    my $self = shift;
    my %args = ( Objects => undef, @_ );

    my @res;
    for( $self->CastObjectsToRecords( Objects => delete $args{'Objects'} ) ) {
        push @res, $self->PutObject( %args, Object => $_ )
    }

    return @res;
}

=head4 PutObject( Object => undef )

Puts record object into cache and returns its cache entry.

B<NOTE> that this method support B<only C<RT::Record> object or its ancesstor
objects>, if you want put mutliple objects or objects represented by different
classes then use C<PutObjects> method instead.

=cut

sub PutObject
{
    my $self = shift;
    my %args = ( Object => undef, @_ );

    my $obj = $args{'Object'};
    unless( UNIVERSAL::isa( $obj, 'RT::Record' ) ) {
        RT::Shredder::Exception->throw( "Unsupported type '". (ref $obj || $obj || '(undef)')."'" );
    }

    my $str = $obj->UID;
    return ($self->{'cache'}->{ $str } ||= {
        State  => RT::Shredder::Constants::ON_STACK,
        Object => $obj
    } );
}

=head4 GetObject, GetState, GetRecord( String => ''| Object => '' )

Returns record object from cache, cache entry state or cache entry accordingly.

All three methods takes C<String> (format C<< <class>-<id> >>) or C<Object> argument.
C<String> argument has more priority than C<Object> so if it's not empty then methods
leave C<Object> argument unchecked.

You can read about possible states and their meanings in L<RT::Shredder::Constants> docs.

=cut

sub _ParseRefStrArgs
{
    my $self = shift;
    my %args = (
        String => '',
        Object => undef,
        @_
    );
    if( $args{'String'} && $args{'Object'} ) {
        require Carp;
        Carp::croak( "both String and Object args passed" );
    }
    return $args{'String'} if $args{'String'};
    return $args{'Object'}->UID if UNIVERSAL::can($args{'Object'}, 'UID' );
    return '';
}

sub GetObject { return (shift)->GetRecord( @_ )->{'Object'} }
sub GetState { return (shift)->GetRecord( @_ )->{'State'} }
sub GetRecord
{
    my $self = shift;
    my $str = $self->_ParseRefStrArgs( @_ );
    return $self->{'cache'}->{ $str };
}

=head3 Dependencies resolvers

=head4 PutResolver, GetResolvers and ApplyResolvers

TODO: These methods have no documentation.

=cut

sub PutResolver
{
    my $self = shift;
    my %args = (
        BaseClass => '',
        TargetClass => '',
        Code => undef,
        @_,
    );
    unless( UNIVERSAL::isa( $args{'Code'} => 'CODE' ) ) {
        die "Resolver '$args{Code}' is not code reference";
    }

    my $resolvers = (
        (
            $self->{'resolver'}->{ $args{'BaseClass'} } ||= {}
        )->{  $args{'TargetClass'} || '' } ||= []
    );
    unshift @$resolvers, $args{'Code'};
    return;
}

sub GetResolvers
{
    my $self = shift;
    my %args = (
        BaseClass => '',
        TargetClass => '',
        @_,
    );

    my @res;
    if( $args{'TargetClass'} && exists $self->{'resolver'}->{ $args{'BaseClass'} }->{ $args{'TargetClass'} } ) {
        push @res, @{ $self->{'resolver'}->{ $args{'BaseClass'} }->{ $args{'TargetClass'} || '' } };
    }
    if( exists $self->{'resolver'}->{ $args{'BaseClass'} }->{ '' } ) {
        push @res, @{ $self->{'resolver'}->{ $args{'BaseClass'} }->{''} };
    }

    return @res;
}

sub ApplyResolvers
{
    my $self = shift;
    my %args = ( Dependency => undef, @_ );
    my $dep = $args{'Dependency'};

    my @resolvers = $self->GetResolvers(
        BaseClass   => $dep->BaseClass,
        TargetClass => $dep->TargetClass,
    );

    unless( @resolvers ) {
        RT::Shredder::Exception::Info->throw(
            tag   => 'NoResolver',
            error => "Couldn't find resolver for dependency '". $dep->AsString ."'",
        );
    }
    $_->(
        Shredder     => $self,
        BaseObject   => $dep->BaseObject,
        TargetObject => $dep->TargetObject,
    ) foreach @resolvers;

    return;
}

sub WipeoutAll
{
    my $self = $_[0];

    foreach my $cache_val ( values %{ $self->{'cache'} } ) {
        next if $cache_val->{'State'} & (RT::Shredder::Constants::WIPED | RT::Shredder::Constants::IN_WIPING);
        $self->Wipeout( Object => $cache_val->{'Object'} );
    }
    return;
}

sub Wipeout
{
    my $self = shift;
    my $mark;
    eval {
        die "Couldn't begin transaction" unless $RT::Handle->BeginTransaction;
        $mark = $self->PushDumpMark or die "Couldn't get dump mark";
        $self->_Wipeout( @_ );
        $self->PopDumpMark( Mark => $mark );
        die "Couldn't commit transaction" unless $RT::Handle->Commit;
    };
    if( $@ ) {
        my $error = $@;
        $RT::Handle->Rollback('force');
        $self->RollbackDumpTo( Mark => $mark ) if $mark;
        die $error if RT::Shredder::Exception::Info->caught;
        die "Couldn't wipeout object: $error";
    }
    return;
}

sub _Wipeout
{
    my $self = shift;
    my %args = ( CacheRecord => undef, Object => undef, @_ );

    my $record = $args{'CacheRecord'};
    $record = $self->PutObject( Object => $args{'Object'} ) unless $record;
    return if $record->{'State'} & (RT::Shredder::Constants::WIPED | RT::Shredder::Constants::IN_WIPING);

    $record->{'State'} |= RT::Shredder::Constants::IN_WIPING;
    my $object = $record->{'Object'};

    $self->DumpObject( Object => $object, State => 'before any action' );

    unless( $object->BeforeWipeout ) {
        RT::Shredder::Exception->throw( "BeforeWipeout check returned error" );
    }

    my $deps = $object->Dependencies( Shredder => $self );
    $deps->List(
        WithFlags => RT::Shredder::Constants::DEPENDS_ON | RT::Shredder::Constants::VARIABLE,
        Callback  => sub { $self->ApplyResolvers( Dependency => $_[0] ) },
    );
    $self->DumpObject( Object => $object, State => 'after resolvers' );

    $deps->List(
        WithFlags    => RT::Shredder::Constants::DEPENDS_ON,
        WithoutFlags => RT::Shredder::Constants::WIPE_AFTER | RT::Shredder::Constants::VARIABLE,
        Callback     => sub { $self->_Wipeout( Object => $_[0]->TargetObject ) },
    );
    $self->DumpObject( Object => $object, State => 'after wiping dependencies' );

    $object->__Wipeout;
    $record->{'State'} |= RT::Shredder::Constants::WIPED; delete $record->{'Object'};
    $self->DumpObject( Object => $object, State => 'after wipeout' );

    $deps->List(
        WithFlags => RT::Shredder::Constants::DEPENDS_ON | RT::Shredder::Constants::WIPE_AFTER,
        WithoutFlags => RT::Shredder::Constants::VARIABLE,
        Callback => sub { $self->_Wipeout( Object => $_[0]->TargetObject ) },
    );
    $self->DumpObject( Object => $object, State => 'after late dependencies' );

    return;
}

=head3 Data storage and backups

=head4 GetFileName( FileName => '<ISO DATETIME>-XXXX.sql', FromStorage => 1 )

Takes desired C<FileName> and flag C<FromStorage> then translate file name to absolute
path by next rules:

* Default value of the C<FileName> option is C<< <ISO DATETIME>-XXXX.sql >>;

* if C<FileName> has C<XXXX> (exactly four uppercase C<X> letters) then it would be changed with digits from 0000 to 9999 range, with first one free value;

* if C<FileName> has C<%T> then it would be replaced with the current date and time in the C<YYYY-MM-DDTHH:MM:SS> format. Note that using C<%t> may still generate not unique names, using C<XXXX> recomended.

* if C<FromStorage> argument is true (default behaviour) then result path would always be relative to C<StoragePath>;

* if C<FromStorage> argument is false then result would be relative to the current dir unless it's already absolute path.

Returns an absolute path of the file.

Examples:
    # file from storage with default name format
    my $fname = $shredder->GetFileName;

    # file from storage with custom name format
    my $fname = $shredder->GetFileName( FileName => 'shredder-XXXX.backup' );

    # file with path relative to the current dir
    my $fname = $shredder->GetFileName(
        FromStorage => 0,
        FileName => 'backups/shredder.sql',
    );

    # file with absolute path
    my $fname = $shredder->GetFileName(
        FromStorage => 0,
        FileName => '/var/backups/shredder-XXXX.sql'
    );

=cut

sub GetFileName
{
    my $self = shift;
    my %args = ( FileName => '', FromStorage => 1, @_ );

    # default value
    my $file = $args{'FileName'} || '%t-XXXX.sql';
    if( $file =~ /\%t/i ) {
        require POSIX;
        my $date_time = POSIX::strftime( "%Y%m%dT%H%M%S", gmtime );
        $file =~ s/\%t/$date_time/gi;
    }

    # convert to absolute path
    if( $args{'FromStorage'} ) {
        $file = File::Spec->catfile( $self->StoragePath, $file );
    } elsif( !File::Spec->file_name_is_absolute( $file ) ) {
        $file = File::Spec->rel2abs( $file );
    }

    # check mask
    if( $file =~ /XXXX[^\/\\]*$/ ) {
        my( $tmp, $i ) = ( $file, 0 );
        do {
            $i++;
            $tmp = $file;
            $tmp =~ s/XXXX([^\/\\]*)$/sprintf("%04d", $i).$1/e;
        } while( -e $tmp && $i < 9999 );
        $file = $tmp;
    }

    if( -f $file ) {
        unless( -w _ ) {
            die "File '$file' exists, but is read-only";
        }
    } elsif( !-e _ ) {
        unless( File::Spec->file_name_is_absolute( $file ) ) {
            $file = File::Spec->rel2abs( $file );
        }

        # check base dir
        my $dir = File::Spec->join( (File::Spec->splitpath( $file ))[0,1] );
        unless( -e $dir && -d _) {
            die "Base directory '$dir' for file '$file' doesn't exist";
        }
        unless( -w $dir ) {
            die "Base directory '$dir' is not writable";
        }
    } else {
        die "'$file' is not regular file";
    }

    return $file;
}

=head4 StoragePath

Returns an absolute path to the storage dir.  See
L</$ShredderStoragePath>.

See also description of the L</GetFileName> method.

=cut

sub StoragePath
{
    return scalar( RT->Config->Get('ShredderStoragePath') )
        || File::Spec->catdir( $RT::VarPath, qw(data RT-Shredder) );
}

my %active_dump_state = ();
sub AddDumpPlugin {
    my $self = shift;
    my %args = ( Object => undef, Name => 'SQLDump', Arguments => undef, @_ );

    my $plugin = $args{'Object'};
    unless ( $plugin ) {
        require RT::Shredder::Plugin;
        $plugin = RT::Shredder::Plugin->new;
        my( $status, $msg ) = $plugin->LoadByName( $args{'Name'} );
        die "Couldn't load dump plugin: $msg\n" unless $status;
    }
    die "Plugin is not of correct type" unless lc $plugin->Type eq 'dump';

    if ( my $pargs = $args{'Arguments'} ) {
        my ($status, $msg) = $plugin->TestArgs( %$pargs );
        die "Couldn't set plugin args: $msg\n" unless $status;
    }

    my @applies_to = $plugin->AppliesToStates;
    die "Plugin doesn't apply to any state" unless @applies_to;
    $active_dump_state{ lc $_ } = 1 foreach @applies_to;

    push @{ $self->{'dump_plugins'} }, $plugin;

    return $plugin;
}

sub DumpObject {
    my $self = shift;
    my %args = (Object => undef, State => undef, @_);
    die "No state passed" unless $args{'State'};
    return unless $active_dump_state{ lc $args{'State'} };

    foreach (@{ $self->{'dump_plugins'} }) {
        next unless grep lc $args{'State'} eq lc $_, $_->AppliesToStates;
        my ($state, $msg) = $_->Run( %args );
        die "Couldn't run plugin: $msg" unless $state;
    }
    return;
}

{ my $mark = 1; # XXX: integer overflows?
sub PushDumpMark {
    my $self = shift;
    $mark++;
    foreach (@{ $self->{'dump_plugins'} }) {
        my ($state, $msg) = $_->PushMark( Mark => $mark );
        die "Couldn't push mark: $msg" unless $state;
    }
    return $mark;
}
sub PopDumpMark {
    my $self = shift;
    foreach (@{ $self->{'dump_plugins'} }) {
        my ($state, $msg) = $_->PopMark( @_ );
        die "Couldn't pop mark: $msg" unless $state;
    }
    return;
}
sub RollbackDumpTo {
    my $self = shift;
    foreach (@{ $self->{'dump_plugins'} }) {
        my ($state, $msg) = $_->RollbackTo( @_ );
        die "Couldn't rollback to mark: $msg" unless $state;
    }
    return;
}
}

1;
__END__

=head1 SEE ALSO

L<rt-shredder>, L<rt-validator>

=cut
