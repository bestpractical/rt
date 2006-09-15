package RT::Shredder;

use strict;
use warnings;

=head1 NAME

RT::Shredder - Cleanup RT database

=head1 SYNOPSIS

=head2 CLI

  rt-shredder --force --plugin 'Tickets=queue,general;status,deleted'

=head2 API

Same action as in CLI example, but from perl script:

  use RT::Shredder;
  RT::Shredder::Init( force => 1 );
  my $deleted = RT::Tickets->new( $RT::SystemUser );
  $deleted->{'allow_deleted_search'} = 1;
  $deleted->LimitQueue( VALUE => 'general' );
  $deleted->LimitStatus( VALUE => 'deleted' );
  while( my $t = $deleted->Next ) {
      $t->Wipeout;
  }

=head1 DESCRIPTION

RT::Shredder is extention to RT API which allow you to delete data
from RT database. Now Shredder support wipe out of almost all RT objects
 (Tickets, Transactions, Attachments, Users...)

=head2 Command line tools(CLI)

L<rt-shredder> script that is shipped with the distribution allow
you to delete objects from command line or with system tasks
scheduler(cron or other).

=head2 Web based interface(WebUI)

Shredder's WebUI integrates into RT's WebUI and you can find it
under Configuration->Tools->Shredder tab. This interface is similar
to CLI and give you the same functionality, but it's available
from browser.

=head2 API

L<RT::Shredder> modules is extension to RT API which add(push) methods
into base RT classes. API is not well documented yet, but you can find
usage examples in L<rt-shredder> script code and in F<t/*> files.

=head1 CONFIGURATION

=head2 $RT::DependenciesLimit

Shredder stops with error if object has more then C<$RT::DependenciesLimit>
dependencies. By default this value is 1000. For example: ticket has 1000
transactions or transaction has 1000 attachments. This is protection
from bugs in shredder code, but sometimes when you have big mail loops
you may hit it. You can change default value, in
F<RT_SiteConfig.pm> add C<Set( $DependenciesLimit, new_limit );>

=head2 $RT::ShredderStoragePath

By default shredder saves dumps in F</path-to-RT-var-dir/data/Rt-Shredder>,
with this option you can change path, but B<note> that value should be absolute
path to the dir you want.

=head1 API DESCRIPTION

L<RT::Shredder> class implements interfaces to objects cache, actions
on the objects in the cache and backups storage.

=head2 Dependencies

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

=head2 GENERIC

=head3 Init( %options )

Sets shredder defaults, loads RT config and init RT interface.
Defaults could later be overriden by object constructor and
if you allready loaded config and initalized RT then you may
skip this function call.

B<NOTE> that this is function and must be called with C<RT::Shredder::Init();>.

B<TODO:> describe possible shredder options.

=cut

our %opt = ();

sub Init
{
    %opt = @_;
    RT::LoadConfig();
    RT::Init();
}

=head3 new( %options )

Shredder object constructor takes options hash and returns new object.

=cut

sub new
{
    my $proto = shift;
    my $self = bless( {}, ref $proto || $proto );
    $self->_Init( @_ );
    return $self;
}

sub _Init
{
    my $self = shift;
    $self->{'opt'} = { %opt, @_ };
    $self->{'cache'} = {};
    $self->{'resolver'} = {};
}

=head3 CastObjectsToRecords( Objects => undef )

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
        my ($class, $id) = split /-/, $targets;
        $class = 'RT::'. $class unless $class =~ /^RTx?::/i;
        eval "require $class";
        die "Couldn't load '$class' module" if $@;
        my $obj = $class->new( $RT::SystemUser );
        die "Couldn't construct new '$class' object" unless $obj;
        $obj->Load( $id );
        unless ( $obj->id ) {
            $RT::Logger->error( "Couldn't load '$class' object with id '$id'" );
            RT::Shredder::Exception::Info->throw( 'CouldntLoadObject' );
        }
        die "Loaded object has different id" unless( $id eq $obj->id );
        push @res, $obj;
    } else {
        RT::Shredder::Exception->throw( "Unsupported type ". ref $targets );
    }
    return @res;
}

=head2 OBJECTS CACHE

=head3 PutObjects( Objects => undef )

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

=head3 PutObject( Object => undef )

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

    my $str = $obj->_AsString;
    return ($self->{'cache'}->{ $str } ||= { State => ON_STACK, Object => $obj } );
}

=head3 GetObject, GetState, GetRecord( String => ''| Object => '' )

Returns record object from cache, cache entry state or cache entry accordingly.

All three methods takes C<String> (format C<< <class>-<id> >>) or C<Object> argument.
C<String> argument has more priority than C<Object> so if it's not empty then methods
leave C<Object> argument unchecked.

You can read about possible states and thier meaning in L<RT::Shredder::Constants> docs.

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
    return $args{'Object'}->_AsString if UNIVERSAL::can($args{'Object'}, '_AsString' );
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

=head2 DEPENDENCIES RESOLVERS

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

    while ( my ($k, $v) = each %{ $self->{'cache'} } ) {
        next if $v->{'State'} & (WIPED | IN_WIPING);
        $self->Wipeout( Object => $v->{'Object'} );
    }
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
        $RT::Handle->Rollback('force');
        $self->RollbackDumpTo( Mark => $mark ) if $mark;
        die $@ if RT::Shredder::Exception::Info->caught;
        die "Couldn't wipeout object: $@";
    }
}

sub _Wipeout
{
    my $self = shift;
    my %args = ( CacheRecord => undef, Object => undef, @_ );

    my $record = $args{'CacheRecord'};
    $record = $self->PutObject( Object => $args{'Object'} ) unless $record;
    return if $record->{'State'} & (WIPED | IN_WIPING);

    $record->{'State'} |= IN_WIPING;
    my $object = $record->{'Object'};

    $self->DumpObject( Object => $object, State => 'before any action' );

    unless( $object->BeforeWipeout ) {
        RT::Shredder::Exception->throw( "BeforeWipeout check returned error" );
    }

    my $deps = $object->Dependencies( Shredder => $self );
    $deps->List(
        WithFlags => DEPENDS_ON | VARIABLE,
        Callback  => sub { $self->ApplyResolvers( Dependency => $_[0] ) },
    );
    $self->DumpObject( Object => $object, State => 'after resolvers' );

    $deps->List(
        WithFlags    => DEPENDS_ON,
        WithoutFlags => WIPE_AFTER | VARIABLE,
        Callback     => sub { $self->_Wipeout( Object => $_[0]->TargetObject ) },
    );
    $self->DumpObject( Object => $object, State => 'after wiping dependencies' );

    $object->__Wipeout;
    $record->{'State'} |= WIPED; delete $record->{'Object'};
    $self->DumpObject( Object => $object, State => 'after wipeout' );

    $deps->List(
        WithFlags => DEPENDS_ON | WIPE_AFTER,
        WithoutFlags => VARIABLE,
        Callback => sub { $self->_Wipeout( Object => $_[0]->TargetObject ) },
    );
    $self->DumpObject( Object => $object, State => 'after late dependencies' );

    return;
}

sub ValidateRelations
{
    my $self = shift;
    my %args = ( @_ );

    foreach my $record( values %{ $self->{'cache'} } ) {
        next if( $record->{'State'} & VALID );
        $record->{'Object'}->ValidateRelations( Shredder => $self );
    }
}

=head2 DATA STORAGE AND BACKUPS

Shredder allow you to store data you delete in files as scripts with SQL
commands.

=head3 GetFileName( FileName => '<ISO DATETIME>-XXXX.sql', FromStorage => 1 )

Takes desired C<FileName> and flag C<FromStorage> then translate file name to absolute
path by next rules:

* Default value of the C<FileName> option is C<< <ISO DATETIME>-XXXX.sql >>;

* if C<FileName> has C<XXXX> (exactly four uppercase C<X> letters) then it would be changed with digits from 0000 to 9999 range, with first one free value;

* if C<FromStorage> argument is true (default behaviour) then result path would always be relative to C<StoragePath>;

* if C<FromStorage> argument is false then result would be relative to the current dir unless it's allready absolute path.

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
    my $file = $args{'FileName'};
    unless( $file ) {
        require POSIX;
        $file = POSIX::strftime( "%Y%m%dT%H%M%S-XXXX.sql", gmtime );
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

=head3 StoragePath

Returns absolute path to storage dir. By default it's
F</path-to-RT-var-dir/data/RT-Shredder/>
(in default RT install would be F</opt/rt3/var/data/RT-Shredder>),
but you can change this value with config option C<$RT::ShredderStoragePath>.
See L</CONFIGURATION> sections.

See also description of the L</GetFileName> method.

=cut

sub StoragePath
{
    return $RT::ShredderStoragePath if $RT::ShredderStoragePath;
    return File::Spec->catdir( $RT::VarPath, qw(data RT-Shredder) );
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

    push @{ $self->{'opt'}{'dump_plugins'} ||= [] }, $plugin;

    return $plugin;
}

sub DumpObject {
    my $self = shift;
    my %args = (Object => undef, State => undef, @_);
    die "No state passed" unless $args{'State'};
    return unless $active_dump_state{ lc $args{'State'} };

    foreach ( @{ $self->{'opt'}->{'dump_plugins'} } ) {
        next unless grep lc $args{'State'} eq lc $_, $_->AppliesToStates;
        my ($state, $msg) = $_->Run( %args );
        die "Couldn't run plugin: $msg" unless $state;
    }
}

{ my $mark = 1; # XXX: integer overflows?
sub PushDumpMark {
    my $self = shift;
    $mark++;
    foreach ( @{ $self->{'opt'}->{'dump_plugins'} } ) {
        my ($state, $msg) = $_->PushMark( Mark => $mark );
        die "Couldn't push mark: $msg" unless $state;
    }
    return $mark;
}
sub PopDumpMark {
    my $self = shift;
    foreach ( @{ $self->{'opt'}->{'dump_plugins'} } ) {
        my ($state, $msg) = $_->PushMark( @_ );
        die "Couldn't pop mark: $msg" unless $state;
    }
}
sub RollbackDumpTo {
    my $self = shift;
    foreach ( @{ $self->{'opt'}->{'dump_plugins'} } ) {
        my ($state, $msg) = $_->RollbackTo( @_ );
        die "Couldn't rollback to mark: $msg" unless $state;
    }
}
}

1;
__END__

=head1 NOTES

=head2 Database transactions support

Since 0.03_01 RT::Shredder uses database transactions and should be
much safer to run on production servers.

=head2 Foreign keys

Mainstream RT doesn't use FKs, but at least I posted DDL script that creates them
in mysql DB, note that if you use FKs then this two valid keys don't allow delete
Tickets because of bug in MySQL:

  ALTER TABLE Tickets ADD FOREIGN KEY (EffectiveId) REFERENCES Tickets(id);
  ALTER TABLE CachedGroupMembers ADD FOREIGN KEY (Via) REFERENCES CachedGroupMembers(id);

L<http://bugs.mysql.com/bug.php?id=4042>

=head1 BUGS AND HOW TO CONTRIBUTE

We need your feedback in all cases: if you use it or not,
is it works for you or not.

=head2 Testing

Don't skip C<make test> step while install and send me reports if it's fails.
Add your own tests, it's easy enough if you've writen at list one perl script
that works with RT. Read more about testing in F<t/utils.pl>.

=head2 Reporting

Send reports to L</AUTHOR> or to the RT mailing lists.

=head2 Documentation

Many bugs in the docs: insanity, spelling, gramar and so on.
Patches are wellcome.

=head2 Todo

Please, see Todo file, it has some technical notes
about what I plan to do, when I'll do it, also it
describes some problems code has.

=head2 Repository

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
