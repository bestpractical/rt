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

package RT::Test;

use strict;
use warnings;

BEGIN { $^W = 1 };

use base 'Test::More';

BEGIN {
    # Warn about role consumers overriding role methods so we catch it in tests.
    $ENV{PERL_ROLE_OVERRIDE_WARN} = 1;
}

# We use the Test::NoWarnings catching and reporting functionality, but need to
# wrap it in our own special handler because of the warn handler installed via
# RT->InitLogging().
require Test::NoWarnings;

my $Test_NoWarnings_Catcher = $SIG{__WARN__};
my $check_warnings_in_end   = 1;

use Socket;
use File::Temp qw(tempfile);
use File::Path qw(mkpath);
use File::Spec;
use File::Which qw();
use Scalar::Util qw(blessed);

our @EXPORT = qw(is_empty diag parse_mail works fails plan done_testing);

my %tmp = (
    directory => undef,
    config    => {
        RT => undef,
        apache => undef,
    },
    mailbox   => undef,
);

my %rttest_opt;

=head1 NAME

RT::Test - RT Testing

=head1 NOTES

=head2 COVERAGE

To run the rt test suite with coverage support, install L<Devel::Cover> and run:

    make test RT_DBA_USER=.. RT_DBA_PASSWORD=.. HARNESS_PERL_SWITCHES=-MDevel::Cover
    cover -ignore_re '^var/mason_data/' -ignore_re '^t/'

The coverage tests have DevelMode turned off, and have
C<named_component_subs> enabled for L<HTML::Mason> to avoid an optimizer
problem in Perl that hides the top-level optree from L<Devel::Cover>.

=cut

our $port;
our @SERVERS;
my @ports; # keep track of all the random ports we used

BEGIN {
    delete $ENV{$_} for qw/LANGUAGE LC_ALL LC_MESSAGES LANG/;
    $ENV{LANG} = "C";
};

sub import {
    my $class = shift;
    my %args = @_;
    %rttest_opt = %args;

    $rttest_opt{'nodb'} = $args{'nodb'} = 1 if $^C;

    # Spit out a plan (if we got one) *before* we load modules
    if ( $args{'tests'} ) {
        plan( tests => $args{'tests'} )
          unless $args{'tests'} eq 'no_declare';
    }
    elsif ( exists $args{'tests'} ) {
        # do nothing if they say "tests => undef" - let them make the plan
    }
    elsif ( $args{'skip_all'} ) {
        plan(skip_all => $args{'skip_all'});
    }
    else {
        $class->builder->no_plan unless $class->builder->has_plan;
    }

    push @{ $args{'plugins'} ||= [] }, @{ $args{'requires'} }
        if $args{'requires'};
    push @{ $args{'plugins'} ||= [] }, $args{'testing'}
        if $args{'testing'};
    push @{ $args{'plugins'} ||= [] }, split " ", $ENV{RT_TEST_PLUGINS}
        if $ENV{RT_TEST_PLUGINS};

    $class->bootstrap_tempdir;

    $port = $class->find_idle_port;

    $class->bootstrap_plugins_paths( %args );

    $class->bootstrap_config( %args );

    use RT;

    RT::LoadConfig;

    RT::InitPluginPaths();
    RT::InitClasses();

    RT::I18N->Init();

    $class->set_config_wrapper;
    $class->bootstrap_db( %args );

    __reconnect_rt()
        unless $args{nodb};

    __init_logging();

    RT->Plugins;

    RT->Config->PostLoadCheck;

    $class->encode_output;

    my $screen_logger = $RT::Logger->remove( 'screen' );
    require Log::Dispatch::Perl;
    $RT::Logger->add( Log::Dispatch::Perl->new
                      ( name      => 'rttest',
                        min_level => $screen_logger->min_level,
                        action => { error     => 'warn',
                                    critical  => 'warn' } ) );

    # XXX: this should really be totally isolated environment so we
    # can parallelize and be sane
    mkpath [ $RT::MasonSessionDir ]
        if RT->Config->Get('DatabaseType');

    my $level = 1;
    while ( my ($package) = caller($level-1) ) {
        last unless $package =~ /Test/;
        $level++;
    }

    # By default we test HTML templates, but text templates are
    # available on request
    if ( $args{'text_templates'} ) {
        $class->switch_templates_ok('text');
    }

    Test::More->export_to_level($level);
    Test::NoWarnings->export_to_level($level);

    # Blow away symbols we redefine to avoid warnings.
    # better than "no warnings 'redefine'" because we might accidentally
    # suppress a mistaken redefinition
    no strict 'refs';
    delete ${ caller($level) . '::' }{diag};
    delete ${ caller($level) . '::' }{plan};
    delete ${ caller($level) . '::' }{done_testing};
    __PACKAGE__->export_to_level($level);
}

sub is_empty($;$) {
    my ($v, $d) = shift;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    return Test::More::ok(1, $d) unless defined $v;
    return Test::More::ok(1, $d) unless length $v;
    return Test::More::is($v, '', $d);
}

my $created_new_db;    # have we created new db? mainly for parallel testing

sub db_requires_no_dba {
    my $self = shift;
    my $db_type = RT->Config->Get('DatabaseType');
    return 1 if $db_type eq 'SQLite';
}

sub find_idle_port {
    my $class = shift;

    my %ports;

    # Determine which ports are in use
    use Fcntl qw(:DEFAULT :flock);
    my $portfile = "$tmp{'directory'}/../ports";
    sysopen(PORTS, $portfile, O_RDWR|O_CREAT)
        or die "Can't write to ports file $portfile: $!";
    flock(PORTS, LOCK_EX)
        or die "Can't write-lock ports file $portfile: $!";
    $ports{$_}++ for split ' ', join("",<PORTS>);

    # Pick a random port, checking that the port isn't in our in-use
    # list, and that something isn't already listening there.
    my $port;
    {
        $port = 1024 + int rand(10_000) + $$ % 1024;
        redo if $ports{$port};

        # There is a race condition in here, where some non-RT::Test
        # process claims the port after we check here but before our
        # server binds.  However, since we mostly care about race
        # conditions with ourselves under high concurrency, this is
        # generally good enough.
        my $paddr = sockaddr_in( $port, inet_aton('localhost') );
        socket( SOCK, PF_INET, SOCK_STREAM, getprotobyname('tcp') )
            or die "socket: $!";
        if ( connect( SOCK, $paddr ) ) {
            close(SOCK);
            redo;
        }
        close(SOCK);
    }

    $ports{$port}++;

    # Write back out the in-use ports
    seek(PORTS, 0, 0);
    truncate(PORTS, 0);
    print PORTS "$_\n" for sort {$a <=> $b} keys %ports;
    close(PORTS) or die "Can't close ports file: $!";
    push @ports, $port;
    return $port;
}

sub bootstrap_tempdir {
    my $self = shift;
    my ($test_dir, $test_file) = ('t', '');

    if (File::Spec->rel2abs($0) =~ m{(?:^|[\\/])(x?t)[/\\](.*)}) {
        $test_dir  = $1;
        $test_file = "$2-";
        $test_file =~ s{[/\\]}{-}g;
    }

    my $dir_name = File::Spec->rel2abs("$test_dir/tmp");
    mkpath( $dir_name );
    return $tmp{'directory'} = File::Temp->newdir(
        "${test_file}XXXXXXXX",
        DIR => $dir_name
    );
}

sub bootstrap_config {
    my $self = shift;
    my %args = @_;

    $tmp{'config'}{'RT'} = File::Spec->catfile(
        "$tmp{'directory'}", 'RT_SiteConfig.pm'
    );
    open( my $config, '>', $tmp{'config'}{'RT'} )
        or die "Couldn't open $tmp{'config'}{'RT'}: $!";

    my $dbname = $ENV{RT_TEST_PARALLEL}? "rt4test_$port" : "rt4test";
    print $config qq{
Set( \$WebDomain, "localhost");
Set( \$WebPort,   $port);
Set( \$WebPath,   "");
Set( \@LexiconLanguages, qw(en zh_TW zh_CN fr ja));
Set( \$RTAddressRegexp , qr/^bad_re_that_doesnt_match\$/i);
Set( \$ShowHistory, "always");
};
    if ( $ENV{'RT_TEST_DB_SID'} ) { # oracle case
        print $config "Set( \$DatabaseName , '$ENV{'RT_TEST_DB_SID'}' );\n";
        print $config "Set( \$DatabaseUser , '$dbname');\n";
    } else {
        print $config "Set( \$DatabaseName , '$dbname');\n";
        print $config "Set( \$DatabaseUser , 'u${dbname}');\n";
    }
    if ( $ENV{'RT_TEST_DB_HOST'} ) {
        print $config "Set( \$DatabaseHost , '$ENV{'RT_TEST_DB_HOST'}');\n";
    }

    if ( $args{'plugins'} ) {
        print $config "Set( \@Plugins, qw(". join( ' ', @{ $args{'plugins'} } ) .") );\n";

        my $plugin_data = File::Spec->rel2abs("t/data/plugins");
        print $config qq[\$RT::PluginPath = "$plugin_data";\n];
    }

    if ( $INC{'Devel/Cover.pm'} ) {
        print $config "Set( \$DevelMode, 0 );\n";
    }
    elsif ( $ENV{RT_TEST_DEVEL} ) {
        print $config "Set( \$DevelMode, 1 );\n";
    }
    else {
        print $config "Set( \$DevelMode, 0 );\n";
    }

    $self->bootstrap_logging( $config );

    # set mail catcher
    my $mail_catcher = $tmp{'mailbox'} = File::Spec->catfile(
        $tmp{'directory'}->dirname, 'mailbox.eml'
    );
    print $config <<END;
Set( \$MailCommand, sub {
    my \$MIME = shift;

    open( my \$handle, '>>', '$mail_catcher' )
        or die "Unable to open '$mail_catcher' for appending: \$!";

    \$MIME->print(\$handle);
    print \$handle "%% split me! %%\n";
    close \$handle;
} );
END

    $self->bootstrap_more_config($config, \%args);

    print $config $args{'config'} if $args{'config'};

    print $config "\n1;\n";
    $ENV{'RT_SITE_CONFIG'} = $tmp{'config'}{'RT'};
    $ENV{'RT_SITE_CONFIG_DIR'} = '/dev/null';
    close $config;

    return $config;
}

sub bootstrap_more_config { }

sub bootstrap_logging {
    my $self = shift;
    my $config = shift;

    # prepare file for logging
    $tmp{'log'}{'RT'} = File::Spec->catfile(
        "$tmp{'directory'}", 'rt.debug.log'
    );
    open( my $fh, '>', $tmp{'log'}{'RT'} )
        or die "Couldn't open $tmp{'config'}{'RT'}: $!";
    # make world writable so apache under different user
    # can write into it
    chmod 0666, $tmp{'log'}{'RT'};

    print $config <<END;
Set( \$LogToSyslog , undef);
Set( \$LogToSTDERR , "warning");
Set( \$LogToFile, 'debug' );
Set( \$LogDir, q{$tmp{'directory'}} );
Set( \$LogToFileNamed, 'rt.debug.log' );
END
}

sub set_config_wrapper {
    my $self = shift;

    my $old_sub = \&RT::Config::Set;
    no warnings 'redefine';

    *RT::Config::WriteSet = sub {
        my ($self, $name) = @_;
        my $type = $RT::Config::META{$name}->{'Type'} || 'SCALAR';
        my %sigils = (
            HASH   => '%',
            ARRAY  => '@',
            SCALAR => '$',
        );
        my $sigil = $sigils{$type} || $sigils{'SCALAR'};
        open( my $fh, '<', $tmp{'config'}{'RT'} )
            or die "Couldn't open config file: $!";
        my @lines;
        while (<$fh>) {
            if (not @lines or /^Set\(/) {
                push @lines, $_;
            } else {
                $lines[-1] .= $_;
            }
        }
        close $fh;

        # Traim trailing newlines and "1;"
        $lines[-1] =~ s/(^1;\n|^\n)*\Z//m;

        # Remove any previous definitions of this var
        @lines = grep {not /^Set\(\s*\Q$sigil$name\E\b/} @lines;

        # Format the new value for output
        require Data::Dumper;
        local $Data::Dumper::Terse = 1;
        my $dump = Data::Dumper::Dumper([@_[2 .. $#_]]);
        $dump =~ s/;?\s+\Z//;
        push @lines, "Set( ${sigil}${name}, \@{". $dump ."});\n";
        push @lines, "\n1;\n";

        # Re-write the configuration file
        open( $fh, '>', $tmp{'config'}{'RT'} )
            or die "Couldn't open config file: $!";
        print $fh $_ for @lines;
        close $fh;

        if ( @SERVERS ) {
            warn "you're changing config option in a test file"
                ." when server is active";
        }

        return $old_sub->(@_);
    };

    *RT::Config::Set = sub {
        # Determine if the caller is either from a test script, or
        # from helper functions called by test script to alter
        # configuration that should be written.  This is necessary
        # because some extensions (RTIR, for example) temporarily swap
        # configuration values out and back in Mason during requests.
        my @caller = caller(1); # preserve list context
        @caller = caller(0) unless @caller;

        return RT::Config::WriteSet(@_)
            if ($caller[1]||'') =~ /\.t$/;

        return $old_sub->(@_);
    };
}

sub encode_output {
    my $builder = Test::More->builder;
    binmode $builder->output,         ":encoding(utf8)";
    binmode $builder->failure_output, ":encoding(utf8)";
    binmode $builder->todo_output,    ":encoding(utf8)";
}

sub bootstrap_db {
    my $self = shift;
    my %args = @_;

    unless (defined $ENV{'RT_DBA_USER'} && defined $ENV{'RT_DBA_PASSWORD'}) {
        Test::More::BAIL_OUT(
            "RT_DBA_USER and RT_DBA_PASSWORD environment variables need"
            ." to be set in order to run 'make test'"
        ) unless $self->db_requires_no_dba;
    }

    require RT::Handle;
    if (my $forceopt = $ENV{RT_TEST_FORCE_OPT}) {
        Test::More::diag "forcing $forceopt";
        $args{$forceopt}=1;
    }

    # Short-circuit the rest of ourselves if we don't want a db
    if ($args{nodb}) {
        __drop_database();
        return;
    }

    my $db_type = RT->Config->Get('DatabaseType');

    if ($db_type eq "SQLite") {
        RT->Config->WriteSet( DatabaseName => File::Spec->catfile( $self->temp_directory, "rt4test" ) );
    }

    __create_database();
    __reconnect_rt('as dba');
    $RT::Handle->InsertSchema;
    $RT::Handle->InsertACL unless $db_type eq 'Oracle';

    __init_logging();
    __reconnect_rt();

    $RT::Handle->InsertInitialData
        unless $args{noinitialdata};

    $RT::Handle->InsertData( $RT::EtcPath . "/initialdata" )
        unless $args{noinitialdata} or $args{nodata};

    $self->bootstrap_plugins_db( %args );
}

sub bootstrap_plugins_paths {
    my $self = shift;
    my %args = @_;

    return unless $args{'plugins'};
    my @plugins = @{ $args{'plugins'} };

    my $cwd;
    if ( $args{'testing'} ) {
        require Cwd;
        $cwd = Cwd::getcwd();
    }

    require RT::Plugin;
    my $old_func = \&RT::Plugin::_BasePath;
    no warnings 'redefine';
    *RT::Plugin::_BasePath = sub {
        my $name = $_[0]->{'name'};

        return $cwd if $args{'testing'} && $name eq $args{'testing'};

        if ( grep $name eq $_, @plugins ) {
            my $variants = join "(?:|::|-|_)", map "\Q$_\E", split /::/, $name;
            my ($path) = map $ENV{$_}, grep /^RT_TEST_PLUGIN_(?:$variants).*_ROOT$/i, keys %ENV;
            return $path if $path;
        }
        return $old_func->(@_);
    };
}

sub bootstrap_plugins_db {
    my $self = shift;
    my %args = @_;

    return unless $args{'plugins'};

    require File::Spec;

    my @plugins = @{ $args{'plugins'} };
    foreach my $name ( @plugins ) {
        my $plugin = RT::Plugin->new( name => $name );
        Test::More::diag( "Initializing DB for the $name plugin" )
            if $ENV{'TEST_VERBOSE'};

        my $etc_path = $plugin->Path('etc');
        Test::More::diag( "etc path of the plugin is '$etc_path'" )
            if $ENV{'TEST_VERBOSE'};

        unless ( -e $etc_path ) {
            # We can't tell if the plugin has no data, or we screwed up the etc/ path
            Test::More::ok(1, "There is no etc dir: no schema" );
            Test::More::ok(1, "There is no etc dir: no ACLs" );
            Test::More::ok(1, "There is no etc dir: no data" );
            next;
        }

        __reconnect_rt('as dba');

        { # schema
            my ($ret, $msg) = $RT::Handle->InsertSchema( undef, $etc_path );
            Test::More::ok($ret || $msg =~ /^Couldn't find schema/, "Created schema: ".($msg||''));
        }

        { # ACLs
            my ($ret, $msg) = $RT::Handle->InsertACL( undef, $etc_path );
            Test::More::ok($ret || $msg =~ /^Couldn't find ACLs/, "Created ACL: ".($msg||''));
        }

        # data
        my $data_file = File::Spec->catfile( $etc_path, 'initialdata' );
        if ( -e $data_file ) {
            __reconnect_rt();
            my ($ret, $msg) = $RT::Handle->InsertData( $data_file );;
            Test::More::ok($ret, "Inserted data".($msg||''));
        } else {
            Test::More::ok(1, "There is no data file" );
        }
    }
    __reconnect_rt();
}

sub _get_dbh {
    my ($dsn, $user, $pass) = @_;
    if ( $dsn =~ /Oracle/i ) {
        $ENV{'NLS_LANG'} = "AMERICAN_AMERICA.AL32UTF8";
        $ENV{'NLS_NCHAR'} = "AL32UTF8";
    }
    my $dbh = DBI->connect(
        $dsn, $user, $pass,
        { RaiseError => 0, PrintError => 1 },
    );
    unless ( $dbh ) {
        my $msg = "Failed to connect to $dsn as user '$user': ". $DBI::errstr;
        print STDERR $msg; exit -1;
    }
    return $dbh;
}

sub __create_database {
    my %args = (
        # already dropped db in parallel tests, need to do so for other cases.
        DropDatabase => $ENV{RT_TEST_PARALLEL} ? 0 : 1,

        @_,
    );

    # bootstrap with dba cred
    my $dbh = _get_dbh(
        RT::Handle->SystemDSN,
        $ENV{RT_DBA_USER}, $ENV{RT_DBA_PASSWORD}
    );

    if ($args{DropDatabase}) {
        __drop_database( $dbh );

    }
    RT::Handle->CreateDatabase( $dbh );
    $dbh->disconnect;
    $created_new_db++;
}

sub __drop_database {
    my $dbh = shift;

    # Pg doesn't like if you issue a DROP DATABASE while still connected
    # it's still may fail if web-server is out there and holding a connection
    __disconnect_rt();

    my $my_dbh = $dbh? 0 : 1;
    $dbh ||= _get_dbh(
        RT::Handle->SystemDSN,
        $ENV{RT_DBA_USER}, $ENV{RT_DBA_PASSWORD}
    );

    # We ignore errors intentionally by not checking the return value of
    # DropDatabase below, so let's also suppress DBI's printing of errors when
    # we overzealously drop.
    local $dbh->{PrintError} = 0;
    local $dbh->{PrintWarn} = 0;

    RT::Handle->DropDatabase( $dbh );
    $dbh->disconnect if $my_dbh;
}

sub __reconnect_rt {
    my $as_dba = shift;
    __disconnect_rt();

    # look at %DBIHandle and $PrevHandle in DBIx::SB::Handle for explanation
    $RT::Handle = RT::Handle->new;
    $RT::Handle->dbh( undef );
    $RT::Handle->Connect(
        $as_dba
        ? (User => $ENV{RT_DBA_USER}, Password => $ENV{RT_DBA_PASSWORD})
        : ()
    );
    $RT::Handle->PrintError;
    $RT::Handle->dbh->{PrintError} = 1;
    return $RT::Handle->dbh;
}

sub __disconnect_rt {
    # look at %DBIHandle and $PrevHandle in DBIx::SB::Handle for explanation
    $RT::Handle->dbh->disconnect if $RT::Handle and $RT::Handle->dbh;

    %DBIx::SearchBuilder::Handle::DBIHandle = ();
    $DBIx::SearchBuilder::Handle::PrevHandle = undef;

    $RT::Handle = undef;

    delete $RT::System->{attributes};

    DBIx::SearchBuilder::Record::Cachable->FlushCache
          if DBIx::SearchBuilder::Record::Cachable->can("FlushCache");
}

sub __init_logging {
    my $filter;
    {
        # We use local to ensure that the $filter we grab is from InitLogging
        # and not the handler generated by a previous call to this function
        # itself.
        local $SIG{__WARN__};
        RT::InitLogging();
        $filter = $SIG{__WARN__};
    }
    $SIG{__WARN__} = sub {
        $filter->(@_) if $filter;
        # Avoid reporting this anonymous call frame as the source of the warning.
        goto &$Test_NoWarnings_Catcher;
    };
}


=head1 UTILITIES

=head2 load_or_create_user

=cut

sub load_or_create_user {
    my $self = shift;
    my %args = ( Privileged => 1, Disabled => 0, @_ );
    
    my $MemberOf = delete $args{'MemberOf'};
    $MemberOf = [ $MemberOf ] if defined $MemberOf && !ref $MemberOf;
    $MemberOf ||= [];

    my $obj = RT::User->new( RT->SystemUser );
    if ( $args{'Name'} ) {
        $obj->LoadByCols( Name => $args{'Name'} );
    } elsif ( $args{'EmailAddress'} ) {
        $obj->LoadByCols( EmailAddress => $args{'EmailAddress'} );
    } else {
        die "Name or EmailAddress is required";
    }
    if ( $obj->id ) {
        # cool
        $obj->SetPrivileged( $args{'Privileged'} || 0 )
            if ($args{'Privileged'}||0) != ($obj->Privileged||0);
        $obj->SetDisabled( $args{'Disabled'} || 0 )
            if ($args{'Disabled'}||0) != ($obj->Disabled||0);
    } else {
        my ($val, $msg) = $obj->Create( %args );
        die "$msg" unless $val;
    }

    # clean group membership
    {
        require RT::GroupMembers;
        my $gms = RT::GroupMembers->new( RT->SystemUser );
        my $groups_alias = $gms->Join(
            FIELD1 => 'GroupId', TABLE2 => 'Groups', FIELD2 => 'id',
        );
        $gms->Limit(
            ALIAS => $groups_alias, FIELD => 'Domain', VALUE => 'UserDefined',
            CASESENSITIVE => 0,
        );
        $gms->Limit( FIELD => 'MemberId', VALUE => $obj->id );
        while ( my $group_member_record = $gms->Next ) {
            $group_member_record->Delete;
        }
    }

    # add new user to groups
    foreach ( @$MemberOf ) {
        my $group = RT::Group->new( RT::SystemUser() );
        $group->LoadUserDefinedGroup( $_ );
        die "couldn't load group '$_'" unless $group->id;
        $group->AddMember( $obj->id );
    }

    return $obj;
}


sub load_or_create_group {
    my $self = shift;
    my $name = shift;
    my %args = (@_);

    my $group = RT::Group->new( RT->SystemUser );
    $group->LoadUserDefinedGroup( $name );
    unless ( $group->id ) {
        my ($id, $msg) = $group->CreateUserDefinedGroup(
            Name => $name,
        );
        die "$msg" unless $id;
    }

    if ( $args{Members} ) {
        my $cur = $group->MembersObj;
        while ( my $entry = $cur->Next ) {
            my ($status, $msg) = $entry->Delete;
            die "$msg" unless $status;
        }

        foreach my $new ( @{ $args{Members} } ) {
            my ($status, $msg) = $group->AddMember(
                ref($new)? $new->id : $new,
            );
            die "$msg" unless $status;
        }
    }

    return $group;
}

=head2 load_or_create_queue

=cut

sub load_or_create_queue {
    my $self = shift;
    my %args = ( Disabled => 0, @_ );
    my $obj = RT::Queue->new( RT->SystemUser );
    if ( $args{'Name'} ) {
        $obj->LoadByCols( Name => $args{'Name'} );
    } else {
        die "Name is required";
    }
    unless ( $obj->id ) {
        my ($val, $msg) = $obj->Create( %args );
        die "$msg" unless $val;
    } else {
        my @fields = qw(CorrespondAddress CommentAddress SLADisabled);
        foreach my $field ( @fields ) {
            next unless exists $args{ $field };
            next if $args{ $field } eq ($obj->$field || '');
            
            no warnings 'uninitialized';
            my $method = 'Set'. $field;
            my ($val, $msg) = $obj->$method( $args{ $field } );
            die "$msg" unless $val;
        }
    }

    return $obj;
}

sub delete_queue_watchers {
    my $self = shift;
    my @queues = @_;

    foreach my $q ( @queues ) {
        foreach my $t (qw(Cc AdminCc) ) {
            $q->DeleteWatcher( Type => $t, PrincipalId => $_->MemberId )
                foreach @{ $q->$t()->MembersObj->ItemsArrayRef };
        }
    }
}

sub create_tickets {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $self = shift;
    my $defaults = shift;
    my @data = @_;
    @data = sort { rand(100) <=> rand(100) } @data
        if delete $defaults->{'RandomOrder'};

    $defaults->{'Queue'} ||= 'General';

    my @res = ();
    while ( @data ) {
        my %args = %{ shift @data };
        $args{$_} = $res[ $args{$_} ]->id foreach
            grep $args{ $_ }, keys %RT::Link::TYPEMAP;
        push @res, $self->create_ticket( %$defaults, %args );
    }
    return @res;
}

sub create_ticket {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $self = shift;
    my %args = @_;

    if ( blessed $args{'Queue'} ) {
        $args{Queue} = $args{'Queue'}->id;
    }
    elsif ($args{Queue} && $args{Queue} =~ /\D/) {
        my $queue = RT::Queue->new(RT->SystemUser);
        if (my $id = $queue->Load($args{Queue}) ) {
            $args{Queue} = $id;
        } else {
            die ("Error: Invalid queue $args{Queue}");
        }
    }

    if ( my $content = delete $args{'Content'} ) {
        $args{'MIMEObj'} = MIME::Entity->build(
            From    => Encode::encode( "UTF-8", $args{'Requestor'} ),
            Subject => RT::Interface::Email::EncodeToMIME( String => $args{'Subject'} ),
            Type    => (defined $args{ContentType} ? $args{ContentType} : "text/plain"),
            Charset => "UTF-8",
            Data    => Encode::encode( "UTF-8", $content ),
        );
    }

    if ( my $cfs = delete $args{'CustomFields'} ) {
        my $q = RT::Queue->new( RT->SystemUser );
        $q->Load( $args{'Queue'} );
        while ( my ($k, $v) = each %$cfs ) {
            my $cf = $q->CustomField( $k );
            unless ($cf->id) {
                RT->Logger->error("Couldn't load custom field $k");
                next;
            }

            $args{'CustomField-'. $cf->id} = $v;
        }
    }

    my $ticket = RT::Ticket->new( RT->SystemUser );
    my ( $id, undef, $msg ) = $ticket->Create( %args );
    Test::More::ok( $id, "ticket created" )
        or Test::More::diag("error: $msg");

    # hackish, but simpler
    if ( $args{'LastUpdatedBy'} ) {
        $ticket->__Set( Field => 'LastUpdatedBy', Value => $args{'LastUpdatedBy'} );
    }


    for my $field ( keys %args ) {
        #TODO check links and watchers

        if ( $field =~ /CustomField-(\d+)/ ) {
            my $cf = $1;
            my $got = join ',', sort map $_->Content,
                @{ $ticket->CustomFieldValues($cf)->ItemsArrayRef };
            my $expected = ref $args{$field}
                ? join( ',', sort @{ $args{$field} } )
                : $args{$field};
            Test::More::is( $got, $expected, 'correct CF values' );
        }
        else {
            next if ref $args{$field};
            next unless $ticket->can($field) or $ticket->_Accessible($field,"read");
            next if ref $ticket->$field();
            Test::More::is( $ticket->$field(), $args{$field}, "$field is correct" );
        }
    }

    return $ticket;
}

sub delete_tickets {
    my $self = shift;
    my $query = shift;
    my $tickets = RT::Tickets->new( RT->SystemUser );
    if ( $query ) {
        $tickets->FromSQL( $query );
    }
    else {
        $tickets->UnLimit;
    }
    while ( my $ticket = $tickets->Next ) {
        $ticket->Delete;
    }
}

=head2 load_or_create_custom_field

=cut

sub load_or_create_custom_field {
    my $self = shift;
    my %args = ( Disabled => 0, @_ );
    my $obj = RT::CustomField->new( RT->SystemUser );
    if ( $args{'Name'} ) {
        $obj->LoadByName(
            Name       => $args{'Name'},
            LookupType => RT::Ticket->CustomFieldLookupType,
            ObjectId   => $args{'Queue'},
        );
    } else {
        die "Name is required";
    }
    unless ( $obj->id ) {
        my ($val, $msg) = $obj->Create( %args );
        die "$msg" unless $val;
    }

    return $obj;
}

sub last_ticket {
    my $self = shift;
    my $current = shift;
    $current = $current ? RT::CurrentUser->new($current) : RT->SystemUser;
    my $tickets = RT::Tickets->new( $current );
    $tickets->OrderBy( FIELD => 'id', ORDER => 'DESC' );
    $tickets->Limit( FIELD => 'id', OPERATOR => '>', VALUE => '0' );
    $tickets->RowsPerPage( 1 );
    return $tickets->First;
}

sub store_rights {
    my $self = shift;

    require RT::ACE;
    # fake construction
    RT::ACE->new( RT->SystemUser );
    my @fields = keys %{ RT::ACE->_ClassAccessible };

    require RT::ACL;
    my $acl = RT::ACL->new( RT->SystemUser );
    $acl->Limit( FIELD => 'RightName', OPERATOR => '!=', VALUE => 'SuperUser' );

    my @res;
    while ( my $ace = $acl->Next ) {
        my $obj = $ace->PrincipalObj->Object;
        if ( $obj->isa('RT::Group') && $obj->Domain eq 'ACLEquivalence' && $obj->Instance == RT->Nobody->id ) {
            next;
        }

        my %tmp = ();
        foreach my $field( @fields ) {
            $tmp{ $field } = $ace->__Value( $field );
        }
        push @res, \%tmp;
    }
    return @res;
}

sub restore_rights {
    my $self = shift;
    my @entries = @_;
    foreach my $entry ( @entries ) {
        my $ace = RT::ACE->new( RT->SystemUser );
        my ($status, $msg) = $ace->RT::Record::Create( %$entry );
        unless ( $status ) {
            Test::More::diag "couldn't create a record: $msg";
        }
    }
}

sub set_rights {
    my $self = shift;

    require RT::ACL;
    my $acl = RT::ACL->new( RT->SystemUser );
    $acl->Limit( FIELD => 'RightName', OPERATOR => '!=', VALUE => 'SuperUser' );
    while ( my $ace = $acl->Next ) {
        my $obj = $ace->PrincipalObj->Object;
        if ( $obj->isa('RT::Group') && $obj->Domain eq 'ACLEquivalence' && $obj->Instance == RT->Nobody->id ) {
            next;
        }
        $ace->Delete;
    }
    return $self->add_rights( @_ );
}

sub add_rights {
    my $self = shift;
    my @list = ref $_[0]? @_: @_? { @_ }: ();

    require RT::ACL;
    foreach my $e (@list) {
        my $principal = delete $e->{'Principal'};
        unless ( ref $principal ) {
            if ( $principal =~ /^(everyone|(?:un)?privileged)$/i ) {
                $principal = RT::Group->new( RT->SystemUser );
                $principal->LoadSystemInternalGroup($1);
            } else {
                my $type = $principal;
                $principal = RT::Group->new( RT->SystemUser );
                $principal->LoadRoleGroup(
                    Object  => ($e->{'Object'} || RT->System),
                    Name    => $type
                );
            }
            die "Principal is not an object nor the name of a system or role group"
                unless $principal->id;
        }
        unless ( $principal->isa('RT::Principal') ) {
            if ( $principal->can('PrincipalObj') ) {
                $principal = $principal->PrincipalObj;
            }
        }
        my @rights = ref $e->{'Right'}? @{ $e->{'Right'} }: ($e->{'Right'});
        foreach my $right ( @rights ) {
            my ($status, $msg) = $principal->GrantRight( %$e, Right => $right );
            $RT::Logger->debug($msg);
        }
    }
    return 1;
}

=head2 switch_templates_to TYPE

This runs /opt/rt4/etc/upgrade/switch-templates-to in order to change the templates from
HTML to text or vice versa.  TYPE is the type to switch to, either C<html> or
C<text>.

=cut

sub switch_templates_to {
    my $self = shift;
    my $type = shift;

    return $self->run_and_capture(
        command => "$RT::EtcPath/upgrade/switch-templates-to",
        args    => $type,
    );
}

=head2 switch_templates_ok TYPE

Calls L<switch_template_to> and tests the return values.

=cut

sub switch_templates_ok {
    my $self = shift;
    my $type = shift;

    my ($exit, $output) = $self->switch_templates_to($type);
    
    if ($exit >> 8) {
        Test::More::fail("Switched templates to $type cleanly");
        diag("**** $RT::EtcPath/upgrade/switch-templates-to exited with ".($exit >> 8).":\n$output");
    } else {
        Test::More::pass("Switched templates to $type cleanly");
    }

    return ($exit, $output);
}

sub run_mailgate {
    my $self = shift;

    require RT::Test::Web;
    my %args = (
        url     => RT::Test::Web->rt_base_url,
        message => '',
        action  => 'correspond',
        queue   => 'General',
        debug   => 1,
        command => $RT::BinPath .'/rt-mailgate',
        @_
    );
    my $message = delete $args{'message'};

    $args{after_open} = sub {
        my $child_in = shift;
        if ( UNIVERSAL::isa($message, 'MIME::Entity') ) {
            $message->print( $child_in );
        } else {
            print $child_in $message;
        }
    };

    $self->run_and_capture(%args);
}

sub run_and_capture {
    my $self = shift;
    my %args = @_;

    my $after_open = delete $args{after_open};

    my $cmd = delete $args{'command'};
    die "Couldn't find command ($cmd)" unless -f $cmd;

    $cmd .= ' --debug' if delete $args{'debug'};

    my $args = delete $args{'args'};

    while( my ($k,$v) = each %args ) {
        next unless $v;
        $cmd .= " --$k '$v'";
    }
    $cmd .= " $args" if defined $args;
    $cmd .= ' 2>&1';

    DBIx::SearchBuilder::Record::Cachable->FlushCache;

    require IPC::Open2;
    my ($child_out, $child_in);
    my $pid = IPC::Open2::open2($child_out, $child_in, $cmd);

    $after_open->($child_in, $child_out) if $after_open;

    close $child_in;

    my $result = do { local $/; <$child_out> };
    close $child_out;
    waitpid $pid, 0;
    return ($?, $result);
}

sub send_via_mailgate_and_http {
    my $self = shift;
    my $message = shift;
    my %args = (@_);

    my ($status, $gate_result) = $self->run_mailgate(
        message => $message, %args
    );

    my $id;
    unless ( $status >> 8 ) {
        ($id) = ($gate_result =~ /Ticket:\s*(\d+)/i);
        unless ( $id ) {
            Test::More::diag "Couldn't find ticket id in text:\n$gate_result"
                if $ENV{'TEST_VERBOSE'};
        }
    } else {
        Test::More::diag "Mailgate output:\n$gate_result"
            if $ENV{'TEST_VERBOSE'};
    }
    return ($status, $id);
}


sub send_via_mailgate {
    my $self    = shift;
    my $message = shift;
    my %args = ( action => 'correspond',
                 queue  => 'General',
                 @_
               );

    if ( UNIVERSAL::isa( $message, 'MIME::Entity' ) ) {
        $message = $message->as_string;
    }

    my ( $status, $error_message, $ticket )
        = RT::Interface::Email::Gateway( {%args, message => $message} );

    # Invert the status to act like a syscall; failing return code is 1,
    # and it will be right-shifted before being examined.
    $status = ($status == 1)  ? 0
            : ($status == -75) ? (-75 << 8)
            : (1 << 8);

    return ( $status, $ticket ? $ticket->id : 0 );

}


sub open_mailgate_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $class   = shift;
    my $baseurl = shift;
    my $queue   = shift || 'general';
    my $action  = shift || 'correspond';
    Test::More::ok(open(my $mail, '|-', "$RT::BinPath/rt-mailgate --url $baseurl --queue $queue --action $action"), "Opened the mailgate - $!");
    return $mail;
}


sub close_mailgate_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $class = shift;
    my $mail  = shift;
    close $mail;
    Test::More::is ($? >> 8, 0, "The mail gateway exited normally. yay");
}

sub mailsent_ok {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $class = shift;
    my $expected  = shift;

    my $mailsent = scalar grep /\S/, split /%% split me! %%\n/,
        RT::Test->file_content(
            $tmp{'mailbox'},
            'unlink' => 0,
            noexist => 1
        );

    Test::More::is(
        $mailsent, $expected,
        "The number of mail sent ($expected) matches. yay"
    );
}

sub fetch_caught_mails {
    my $self = shift;
    return grep /\S/, split /%% split me! %%\n/,
        RT::Test->file_content(
            $tmp{'mailbox'},
            'unlink' => 1,
            noexist => 1
        );
}

sub clean_caught_mails {
    unlink $tmp{'mailbox'};
}

sub run_validator {
    my $self = shift;
    my %args = (check => 1, resolve => 0, force => 1, timeout => 0, @_ );

    my $cmd = "$RT::SbinPath/rt-validator";
    die "Couldn't find $cmd command" unless -f $cmd;

    my $timeout = delete $args{timeout};

    while( my ($k,$v) = each %args ) {
        next unless $v;
        $cmd .= " --$k '$v'";
    }
    $cmd .= ' 2>&1';

    require IPC::Open2;
    my ($child_out, $child_in);
    my $pid = IPC::Open2::open2($child_out, $child_in, $cmd);
    close $child_in;

    local $SIG{ALRM} = sub { kill KILL => $pid; die "Timeout!" };

    alarm $timeout if $timeout;
    my $result = eval { local $/; <$child_out> };
    warn $@ if $@;
    close $child_out;
    waitpid $pid, 0;
    alarm 0;

    DBIx::SearchBuilder::Record::Cachable->FlushCache
        if $args{'resolve'};

    return ($?, $result);
}

sub db_is_valid {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $self = shift;
    my ($ecode, $res) = $self->run_validator;
    Test::More::is( $ecode, 0, 'no invalid records' )
        or Test::More::diag "errors:\n$res";
}

=head2 object_scrips_are

Takes an L<RT::Scrip> object or ID as the first argument and an arrayref of
L<RT::Queue> objects and/or Queue IDs as the second argument.

The scrip's applications (L<RT::ObjectScrip> records) are tested to ensure they
exactly match the arrayref.

An optional third arrayref may be passed to enumerate and test the queues the
scrip is B<not> added to.  This is most useful for testing the API returns the
correct results.

=cut

sub object_scrips_are {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $self    = shift;
    my $scrip   = shift;
    my $to      = shift || [];
    my $not_to  = shift;

    unless (blessed($scrip)) {
        my $id = $scrip;
        $scrip = RT::Scrip->new( RT->SystemUser );
        $scrip->Load($id);
    }

    $to = [ map { blessed($_) ? $_->id : $_ } @$to ];
    Test::More::ok($scrip->IsAdded($_), "added to queue $_" ) foreach @$to;
    Test::More::is_deeply(
        [sort map $_->id, @{ $scrip->AddedTo->ItemsArrayRef }],
        [sort grep $_, @$to ],
        'correct list of added to queues',
    );

    if ($not_to) {
        $not_to = [ map { blessed($_) ? $_->id : $_ } @$not_to ];
        Test::More::ok(!$scrip->IsAdded($_), "not added to queue $_" ) foreach @$not_to;
        Test::More::is_deeply(
            [sort map $_->id, @{ $scrip->NotAddedTo->ItemsArrayRef }],
            [sort grep $_, @$not_to ],
            'correct list of not added to queues',
        );
    }
}

=head2 get_relocatable_dir

Takes a path relative to the location of the test file that is being
run and returns a path that takes the invocation path into account.

e.g. C<RT::Test::get_relocatable_dir(File::Spec->updir(), 'data', 'emails')>

Parent directory traversals (C<..> or File::Spec->updir()) are naively
canonicalized based on the test file path (C<$0>) so that symlinks aren't
followed.  This is the exact opposite behaviour of most filesystems and is
considered "wrong", however it is necessary for some subsets of tests which are
symlinked into the testing tree.

=cut

sub get_relocatable_dir {
    my @directories = File::Spec->splitdir(
        File::Spec->rel2abs((File::Spec->splitpath($0))[1])
    );
    push @directories, File::Spec->splitdir($_) for @_;

    my @clean;
    for (@directories) {
        if    ($_ eq "..") { pop @clean      }
        elsif ($_ ne ".")  { push @clean, $_ }
    }
    return File::Spec->catdir(@clean);
}

=head2 get_relocatable_file

Same as get_relocatable_dir, but takes a file and a path instead
of just a path.

e.g. RT::Test::get_relocatable_file('test-email',
        (File::Spec->updir(), 'data', 'emails'))

=cut

sub get_relocatable_file {
    my $file = shift;
    return File::Spec->catfile(get_relocatable_dir(@_), $file);
}

sub find_relocatable_path {
    my @path = @_;

    # A simple strategy to find e.g., t/data/gnupg/keys, from the dir
    # where test file lives. We try up to 3 directories up
    my $path = File::Spec->catfile( @path );
    for my $up ( 0 .. 2 ) {
        my $p = get_relocatable_dir($path);
        return $p if -e $p;

        $path = File::Spec->catfile( File::Spec->updir(), $path );
    }
    return undef;
}

sub get_abs_relocatable_dir {
    (my $volume, my $directories, my $file) = File::Spec->splitpath($0);
    if (File::Spec->file_name_is_absolute($directories)) {
        return File::Spec->catdir($directories, @_);
    } else {
        return File::Spec->catdir(Cwd->getcwd(), $directories, @_);
    }
}

sub gnupg_homedir {
    my $self = shift;
    File::Temp->newdir(
        DIR => $tmp{directory},
        CLEANUP => 0,
    );
}

sub import_gnupg_key {
    my $self = shift;
    my $key  = shift;
    my $type = shift || 'secret';

    $key =~ s/\@/-at-/g;
    $key .= ".$type.key";

    my $path = find_relocatable_path( 'data', 'gnupg', 'keys' );

    die "can't find the dir where gnupg keys are stored"
      unless $path;

    return RT::Crypt::GnuPG->ImportKey(
        RT::Test->file_content( [ $path, $key ] ) );
}

sub lsign_gnupg_key {
    my $self = shift;
    my $key = shift;

    return RT::Crypt::GnuPG->CallGnuPG(
        Command     => '--lsign-key',
        CommandArgs => [$key],
        Callback    => sub {
            my %handle = @_;
            while ( my $str = readline $handle{'status'} ) {
                if ( $str =~ /^\[GNUPG:\]\s*GET_BOOL sign_uid\..*/ ) {
                    print { $handle{'command'} } "y\n";
                }
            }
        },
    );
}

sub trust_gnupg_key {
    my $self = shift;
    my $key = shift;

    return RT::Crypt::GnuPG->CallGnuPG(
        Command     => '--edit-key',
        CommandArgs => [$key],
        Callback    => sub {
            my %handle = @_;
            my $done = 0;
            while ( my $str = readline $handle{'status'} ) {
                if ( $str =~ /^\[GNUPG:\]\s*\QGET_LINE keyedit.prompt/ ) {
                    if ( $done ) {
                        print { $handle{'command'} } "quit\n";
                    } else {
                        print { $handle{'command'} } "trust\n";
                    }
                } elsif ( $str =~ /^\[GNUPG:\]\s*\QGET_LINE edit_ownertrust.value/ ) {
                    print { $handle{'command'} } "5\n";
                } elsif ( $str =~ /^\[GNUPG:\]\s*\QGET_BOOL edit_ownertrust.set_ultimate.okay/ ) {
                    print { $handle{'command'} } "y\n";
                    $done = 1;
                }
            }
        },
    );
}

sub started_ok {
    my $self = shift;

    require RT::Test::Web;

    if ($rttest_opt{nodb} and not $rttest_opt{server_ok}) {
        die "You are trying to use a test web server without a database. "
           ."You may want noinitialdata => 1 instead. "
           ."Pass server_ok => 1 if you know what you're doing.";
    }


    $ENV{'RT_TEST_WEB_HANDLER'} = undef
        if $rttest_opt{actual_server} && ($ENV{'RT_TEST_WEB_HANDLER'}||'') eq 'inline';
    $ENV{'RT_TEST_WEB_HANDLER'} ||= 'plack';
    my $which = $ENV{'RT_TEST_WEB_HANDLER'};
    my ($server, $variant) = split /\+/, $which, 2;

    my $function = 'start_'. $server .'_server';
    unless ( $self->can($function) ) {
        die "Don't know how to start server '$server'";
    }
    return $self->$function( variant => $variant, @_ );
}

sub test_app {
    my $self = shift;
    my %server_opt = @_;

    my $app;

    my $warnings = "";
    open( my $warn_fh, ">", \$warnings );
    local *STDERR = $warn_fh;

    if ($server_opt{variant} and $server_opt{variant} eq 'rt-server') {
        $app = do {
            my $file = "$RT::SbinPath/rt-server";
            my $psgi = do $file;
            unless ($psgi) {
                die "Couldn't parse $file: $@" if $@;
                die "Couldn't do $file: $!"    unless defined $psgi;
                die "Couldn't run $file"       unless $psgi;
            }
            $psgi;
        };
    } else {
        require RT::Interface::Web::Handler;
        $app = RT::Interface::Web::Handler->PSGIApp;
    }

    require Plack::Middleware::Test::StashWarnings;
    my $stashwarnings = Plack::Middleware::Test::StashWarnings->new(
        $ENV{'RT_TEST_WEB_HANDLER'} && $ENV{'RT_TEST_WEB_HANDLER'} eq 'inline' ? ( verbose => 0 ) : () );
    $app = $stashwarnings->wrap($app);

    if ($server_opt{basic_auth}) {
        require Plack::Middleware::Auth::Basic;
        $app = Plack::Middleware::Auth::Basic->wrap(
            $app,
            authenticator => $server_opt{basic_auth} eq 'anon' ? sub { 1 } : sub {
                my ($username, $password) = @_;
                return $username eq 'root' && $password eq 'password';
            }
        );
    }

    close $warn_fh;
    $stashwarnings->add_warning( $warnings ) if $warnings;

    return $app;
}

sub start_plack_server {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $self = shift;

    require Plack::Loader;
    my $plack_server = Plack::Loader->load
        ('Standalone',
         port => $port,
         server_ready => sub {
             kill 'USR1' => getppid();
         });

    # We are expecting a USR1 from the child process after it's ready
    # to listen.  We set this up _before_ we fork to avoid race
    # conditions.
    my $handled;
    local $SIG{USR1} = sub { $handled = 1};

    __disconnect_rt();
    my $pid = fork();
    die "failed to fork" unless defined $pid;

    if ($pid) {
        sleep 15 unless $handled;
        Test::More::diag "did not get expected USR1 for test server readiness"
            unless $handled;
        push @SERVERS, $pid;
        my $Tester = Test::Builder->new;
        $Tester->ok(1, "started plack server ok");

        __reconnect_rt()
            unless $rttest_opt{nodb};
        return ("http://localhost:$port", RT::Test::Web->new);
    }

    require POSIX;
    POSIX::setsid()
          or die "Can't start a new session: $!";

    # stick this in a scope so that when $app is garbage collected,
    # StashWarnings can complain about unhandled warnings
    do {
        $plack_server->run($self->test_app(@_));
    };

    exit;
}

our $TEST_APP;
sub start_inline_server {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $self = shift;

    require Test::WWW::Mechanize::PSGI;
    unshift @RT::Test::Web::ISA, 'Test::WWW::Mechanize::PSGI';

    # Clear out squished CSS and JS cache, since it's retained across
    # servers, since it's in-process
    RT::Interface::Web->ClearSquished;
    require RT::Interface::Web::Request;
    RT::Interface::Web::Request->clear_callback_cache;

    Test::More::ok(1, "psgi test server ok");
    $TEST_APP = $self->test_app(@_);
    return ("http://localhost:$port", RT::Test::Web->new);
}

sub start_apache_server {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $self = shift;
    my %server_opt = @_;
    $server_opt{variant} ||= 'mod_perl';
    $ENV{RT_TEST_WEB_HANDLER} = "apache+$server_opt{variant}";

    require RT::Test::Apache;
    my $pid = RT::Test::Apache->start_server(
        %server_opt,
        port => $port,
        tmp => \%tmp
    );
    push @SERVERS, $pid;

    my $url = RT->Config->Get('WebURL');
    $url =~ s!/$!!;
    return ($url, RT::Test::Web->new);
}

sub stop_server {
    my $self = shift;
    my $in_end = shift;
    return unless @SERVERS;

    kill 'TERM', @SERVERS;
    foreach my $pid (@SERVERS) {
        if ($ENV{RT_TEST_WEB_HANDLER} =~ /^apache/) {
            sleep 1 while kill 0, $pid;
        } else {
            waitpid $pid, 0;
        }
    }

    @SERVERS = ();
}

sub temp_directory {
    return $tmp{'directory'};
}

sub file_content {
    my $self = shift;
    my $path = shift;
    my %args = @_;

    $path = File::Spec->catfile( @$path ) if ref $path eq 'ARRAY';

    open( my $fh, "<:raw", $path )
        or do {
            warn "couldn't open file '$path': $!" unless $args{noexist};
            return ''
        };
    my $content = do { local $/; <$fh> };
    close $fh;

    unlink $path if $args{'unlink'};

    return $content;
}

sub find_executable {
    my ( $self, $exe ) = @_;

    return File::Which::which( $exe );
}

sub diag {
    return unless $ENV{RT_TEST_VERBOSE} || $ENV{TEST_VERBOSE};
    goto \&Test::More::diag;
}

sub parse_mail {
    my $mail = shift;
    require RT::EmailParser;
    my $parser = RT::EmailParser->new;
    $parser->ParseMIMEEntityFromScalar( $mail );
    my $entity = $parser->Entity;
    $entity->{__store_link_to_object_to_avoid_early_cleanup} = $parser;
    return $entity;
}

sub works {
    Test::More::ok($_[0], $_[1] || 'This works');
}

sub fails {
    Test::More::ok(!$_[0], $_[1] || 'This should fail');
}

sub plan {
    my ($cmd, @args) = @_;
    my $builder = RT::Test->builder;

    if ($cmd eq "skip_all") {
        $check_warnings_in_end = 0;
    } elsif ($cmd eq "tests") {
        # Increment the test count for the warnings check
        $args[0]++;
    }
    $builder->plan($cmd, @args);
}

sub done_testing {
    my $builder = RT::Test->builder;

    Test::NoWarnings::had_no_warnings();
    $check_warnings_in_end = 0;

    if ($RT::Test::Web::INSTANCES) {
        my $cleanup = RT::Test::Web->new;
        undef $RT::Test::Web::INSTANCES;
        $cleanup->no_warnings_ok;
    }

    $builder->done_testing(@_);
}

END {
    my $Test = RT::Test->builder;
    return if $Test->{Original_Pid} != $$;

    # we are in END block and should protect our exit code
    # so calls below may call system or kill that clobbers $?
    local $?;

    Test::NoWarnings::had_no_warnings() if $check_warnings_in_end;

    RT::Test->stop_server(1);

    # not success
    if ( !$Test->is_passing ) {
        $tmp{'directory'}->unlink_on_destroy(0);

        Test::More::diag(
            "Some tests failed or we bailed out, tmp directory"
            ." '$tmp{directory}' is not cleaned"
        );
    }

    if ( $ENV{RT_TEST_PARALLEL} && $created_new_db ) {
        __drop_database();
    }

    # Drop our port from t/tmp/ports; do this after dropping the
    # database, as our port lock is also a lock on the database name.
    if (@ports) {
        my %ports;
        my $portfile = "$tmp{'directory'}/../ports";
        sysopen(PORTS, $portfile, O_RDWR|O_CREAT)
            or die "Can't write to ports file $portfile: $!";
        flock(PORTS, LOCK_EX)
            or die "Can't write-lock ports file $portfile: $!";
        $ports{$_}++ for split ' ', join("",<PORTS>);
        delete $ports{$_} for @ports;
        seek(PORTS, 0, 0);
        truncate(PORTS, 0);
        print PORTS "$_\n" for sort {$a <=> $b} keys %ports;
        close(PORTS) or die "Can't close ports file: $!";
    }
}

{ 
    # ease the used only once warning
    no warnings;
    no strict 'refs';
    %{'RT::I18N::en_us::Lexicon'};
    %{'Win32::Locale::Lexicon'};
}

1;
