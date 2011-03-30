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

package RT::Test;

use strict;
use warnings;

use base 'Test::More';

use Socket;
use File::Temp qw(tempfile);
use File::Path qw(mkpath);
use File::Spec;

our $SKIP_REQUEST_WORK_AROUND = 0;

use HTTP::Request::Common ();
use Hook::LexWrap;
wrap 'HTTP::Request::Common::form_data',
   post => sub {
       return if $SKIP_REQUEST_WORK_AROUND;
       my $data = $_[-1];
       if (ref $data) {
       $data->[0] = Encode::encode_utf8($data->[0]);
       }
       else {
       $_[-1] = Encode::encode_utf8($_[-1]);
       }
   };


our @EXPORT = qw(is_empty parse_mail);
our ($port, $dbname);
our @SERVERS;

my %tmp = (
    directory => undef,
    config    => {
        RT => undef,
        apache => undef,
    },
    mailbox   => undef,
);

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

sub generate_port {
    my $self = shift;
    my $port = 1024 + int rand(10000) + $$ % 1024;

    my $paddr = sockaddr_in( $port, inet_aton('localhost') );
    socket( SOCK, PF_INET, SOCK_STREAM, getprotobyname('tcp') )
      or die "socket: $!";
    if ( connect( SOCK, $paddr ) ) {
        close(SOCK);
        return generate_port();
    }
    close(SOCK);

    return $port;
}

BEGIN {
    $port   = generate_port();
    $dbname = $ENV{RT_TEST_PARALLEL}? "rt3test_$port" : "rt3test";
};

sub import {
    my $class = shift;
    my %args = @_;

    # Spit out a plan (if we got one) *before* we load modules
    if ( $args{'tests'} ) {
        $class->builder->plan( tests => $args{'tests'} )
          unless $args{'tests'} eq 'no_declare';
    }
    else {
        $class->builder->no_plan unless $class->builder->has_plan;
    }

    $class->bootstrap_tempdir;

    $class->bootstrap_config( %args );

    use RT;
    RT::LoadConfig;

    if (RT->Config->Get('DevelMode')) { require Module::Refresh; }

    $class->bootstrap_db( %args );

    RT->Init;

    $class->bootstrap_plugins( %args );

    $class->set_config_wrapper;

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

    Test::More->export_to_level($level);
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

sub bootstrap_tempdir {
    my $self = shift;
    my $test_file = (
        File::Spec->rel2abs((caller)[1])
            =~ m{(?:^|[\\/])t[/\\](.*)}
    );
    my $dir_name = File::Spec->rel2abs('t/tmp/'. $test_file);
    mkpath( $dir_name );
    return $tmp{'directory'} = File::Temp->newdir(
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

    print $config qq{
Set( \$WebDomain, "localhost");
Set( \$WebPort,   $port);
Set( \$WebPath,   "");
Set( \$RTAddressRegexp , qr/^bad_re_that_doesnt_match\$/);
};
    if ( $ENV{'RT_TEST_DB_SID'} ) { # oracle case
        print $config "Set( \$DatabaseName , '$ENV{'RT_TEST_DB_SID'}' );\n";
        print $config "Set( \$DatabaseUser , '$dbname');\n";
    } else {
        print $config "Set( \$DatabaseName , '$dbname');\n";
        print $config "Set( \$DatabaseUser , 'u${dbname}');\n";
    }
    print $config "Set( \$DevelMode, 0 );\n"
        if $INC{'Devel/Cover.pm'};

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
    
    print $config $args{'config'} if $args{'config'};

    print $config "\n1;\n";
    $ENV{'RT_SITE_CONFIG'} = $tmp{'config'}{'RT'};
    close $config;

    return $config;
}

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
Set( \$LogToScreen , "warning");
Set( \$LogToFile, 'debug' );
Set( \$LogDir, q{$tmp{'directory'}} );
Set( \$LogToFileNamed, 'rt.debug.log' );
END
}

sub set_config_wrapper {
    my $self = shift;

    my $old_sub = \&RT::Config::Set;
    no warnings 'redefine';
    *RT::Config::Set = sub {
        my @caller = caller;
        if ( ($caller[1]||'') =~ /\.t$/ ) {
            my ($self, $name) = @_;
            my $type = $RT::Config::META{$name}->{'Type'} || 'SCALAR';
            my %sigils = (
                HASH   => '%',
                ARRAY  => '@',
                SCALAR => '$',
            );
            my $sigil = $sigils{$type} || $sigils{'SCALAR'};
            open( my $fh, '>>', $tmp{'config'}{'RT'} )
                or die "Couldn't open config file: $!";
            require Data::Dumper;
            my $dump = Data::Dumper::Dumper([@_[2 .. $#_]]);
            $dump =~ s/;\s+$//;
            print $fh
                "\nSet(${sigil}${name}, \@{". $dump ."}); 1;\n";
            close $fh;

            if ( @SERVERS ) {
                warn "you're changing config option in a test file"
                    ." when server is active";
            }
        }
        return $old_sub->(@_);
    };
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
    # bootstrap with dba cred
    my $dbh = _get_dbh(RT::Handle->SystemDSN,
               $ENV{RT_DBA_USER}, $ENV{RT_DBA_PASSWORD});

    unless ( $ENV{RT_TEST_PARALLEL} ) {
        # already dropped db in parallel tests, need to do so for other cases.
        RT::Handle->DropDatabase( $dbh, Force => 1 );
    }

    RT::Handle->CreateDatabase( $dbh );
    $dbh->disconnect;
    $created_new_db++;

    $dbh = _get_dbh(RT::Handle->DSN,
            $ENV{RT_DBA_USER}, $ENV{RT_DBA_PASSWORD});

    $RT::Handle = new RT::Handle;
    $RT::Handle->dbh( $dbh );
    $RT::Handle->InsertSchema( $dbh );

    my $db_type = RT->Config->Get('DatabaseType');
    $RT::Handle->InsertACL( $dbh ) unless $db_type eq 'Oracle';

    $RT::Handle = new RT::Handle;
    $RT::Handle->dbh( undef );
    RT->ConnectToDatabase;
    RT->InitLogging;
    RT->InitSystemObjects;
    $RT::Handle->InsertInitialData;

    DBIx::SearchBuilder::Record::Cachable->FlushCache;
    $RT::Handle = new RT::Handle;
    $RT::Handle->dbh( undef );
    RT->Init;

    $RT::Handle->PrintError;
    $RT::Handle->dbh->{PrintError} = 1;

    unless ( $args{'nodata'} ) {
        $RT::Handle->InsertData( $RT::EtcPath . "/initialdata" );
    }
    DBIx::SearchBuilder::Record::Cachable->FlushCache;
}

sub bootstrap_plugins {
    my $self = shift;
    my %args = @_;

    return unless $args{'requires'};

    my @plugins = @{ $args{'requires'} };
    push @plugins, $args{'testing'}
        if $args{'testing'};

    require RT::Plugin;
    my $cwd;
    if ( $args{'testing'} ) {
        require Cwd;
        $cwd = Cwd::getcwd();
    }

    my $old_func = \&RT::Plugin::_BasePath;
    no warnings 'redefine';
    *RT::Plugin::_BasePath = sub {
        my $name = $_[0]->{'name'};

        return $cwd if $args{'testing'} && $name eq $args{'testing'};

        if ( grep $name eq $_, @plugins ) {
            my $variants = join "(?:|::|-|_)", map "\Q$_\E", split /::/, $name;
            my ($path) = map $ENV{$_}, grep /^CHIMPS_(?:$variants).*_ROOT$/i, keys %ENV;
            return $path if $path;
        }
        return $old_func->(@_);
    };

    RT->Config->Set( Plugins => @plugins );
    RT->InitPluginPaths;

    my $dba_dbh;
    $dba_dbh = _get_dbh(
        RT::Handle->DSN,
        $ENV{RT_DBA_USER}, $ENV{RT_DBA_PASSWORD},
    ) if @plugins;

    require File::Spec;
    foreach my $name ( @plugins ) {
        my $plugin = RT::Plugin->new( name => $name );
        Test::More::diag( "Initializing DB for the $name plugin" )
            if $ENV{'TEST_VERBOSE'};

        my $etc_path = $plugin->Path('etc');
        Test::More::diag( "etc path of the plugin is '$etc_path'" )
            if $ENV{'TEST_VERBOSE'};

        if ( -e $etc_path ) {
            my ($ret, $msg) = $RT::Handle->InsertSchema( $dba_dbh, $etc_path );
            Test::More::ok($ret || $msg =~ /^Couldn't find schema/, "Created schema: ".($msg||''));

            ($ret, $msg) = $RT::Handle->InsertACL( $dba_dbh, $etc_path );
            Test::More::ok($ret || $msg =~ /^Couldn't find ACLs/, "Created ACL: ".($msg||''));

            my $data_file = File::Spec->catfile( $etc_path, 'initialdata' );
            if ( -e $data_file ) {
                ($ret, $msg) = $RT::Handle->InsertData( $data_file );;
                Test::More::ok($ret, "Inserted data".($msg||''));
            } else {
                Test::More::ok(1, "There is no data file" );
            }
        }
        else {
# we can not say if plugin has no data or we screwed with etc path
            Test::More::ok(1, "There is no etc dir: no schema" );
            Test::More::ok(1, "There is no etc dir: no ACLs" );
            Test::More::ok(1, "There is no etc dir: no data" );
        }

        $RT::Handle->Connect; # XXX: strange but mysql can loose connection
    }
    $dba_dbh->disconnect if $dba_dbh;
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

=head1 UTILITIES

=head2 load_or_create_user

=cut

sub load_or_create_user {
    my $self = shift;
    my %args = ( Privileged => 1, Disabled => 0, @_ );
    
    my $MemberOf = delete $args{'MemberOf'};
    $MemberOf = [ $MemberOf ] if defined $MemberOf && !ref $MemberOf;
    $MemberOf ||= [];

    my $obj = RT::User->new( $RT::SystemUser );
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
        my $gms = RT::GroupMembers->new( $RT::SystemUser );
        my $groups_alias = $gms->Join(
            FIELD1 => 'GroupId', TABLE2 => 'Groups', FIELD2 => 'id',
        );
        $gms->Limit( ALIAS => $groups_alias, FIELD => 'Domain', VALUE => 'UserDefined' );
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

=head2 load_or_create_queue

=cut

sub load_or_create_queue {
    my $self = shift;
    my %args = ( Disabled => 0, @_ );
    my $obj = RT::Queue->new( $RT::SystemUser );
    if ( $args{'Name'} ) {
        $obj->LoadByCols( Name => $args{'Name'} );
    } else {
        die "Name is required";
    }
    unless ( $obj->id ) {
        my ($val, $msg) = $obj->Create( %args );
        die "$msg" unless $val;
    } else {
        my @fields = qw(CorrespondAddress CommentAddress);
        foreach my $field ( @fields ) {
            next unless exists $args{ $field };
            next if $args{ $field } eq $obj->$field;
            
            no warnings 'uninitialized';
            my $method = 'Set'. $field;
            my ($val, $msg) = $obj->$method( $args{ $field } );
            die "$msg" unless $val;
        }
    }

    return $obj;
}

=head2 load_or_create_custom_field

=cut

sub load_or_create_custom_field {
    my $self = shift;
    my %args = ( Disabled => 0, @_ );
    my $obj = RT::CustomField->new( $RT::SystemUser );
    if ( $args{'Name'} ) {
        $obj->LoadByName( Name => $args{'Name'}, Queue => $args{'Queue'} );
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
    $current = $current ? RT::CurrentUser->new($current) : $RT::SystemUser;
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
    RT::ACE->new( $RT::SystemUser );
    my @fields = keys %{ RT::ACE->_ClassAccessible };

    require RT::ACL;
    my $acl = RT::ACL->new( $RT::SystemUser );
    $acl->Limit( FIELD => 'RightName', OPERATOR => '!=', VALUE => 'SuperUser' );

    my @res;
    while ( my $ace = $acl->Next ) {
        my $obj = $ace->PrincipalObj->Object;
        if ( $obj->isa('RT::Group') && $obj->Type eq 'UserEquiv' && $obj->Instance == $RT::Nobody->id ) {
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
        my $ace = RT::ACE->new( $RT::SystemUser );
        my ($status, $msg) = $ace->RT::Record::Create( %$entry );
        unless ( $status ) {
            Test::More::diag "couldn't create a record: $msg";
        }
    }
}

sub set_rights {
    my $self = shift;

    require RT::ACL;
    my $acl = RT::ACL->new( $RT::SystemUser );
    $acl->Limit( FIELD => 'RightName', OPERATOR => '!=', VALUE => 'SuperUser' );
    while ( my $ace = $acl->Next ) {
        my $obj = $ace->PrincipalObj->Object;
        if ( $obj->isa('RT::Group') && $obj->Type eq 'UserEquiv' && $obj->Instance == $RT::Nobody->id ) {
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
                $principal = RT::Group->new( $RT::SystemUser );
                $principal->LoadSystemInternalGroup($1);
            } elsif ( $principal =~ /^(Owner|Requestor|(?:Admin)?Cc)$/i ) {
                $principal = RT::Group->new( $RT::SystemUser );
                $principal->LoadByCols(
                    Domain => (ref($e->{'Object'})||'RT::System').'-Role',
                    Type => $1,
                    ref($e->{'Object'})? (Instance => $e->{'Object'}->id): (),
                );
            } else {
                die "principal is not an object, but also is not name of a system group";
            }
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

    while( my ($k,$v) = each %args ) {
        next unless $v;
        $cmd .= " --$k '$v'";
    }
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

sub send_via_mailgate {
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

sub open_mailgate_ok {
    my $class   = shift;
    my $baseurl = shift;
    my $queue   = shift || 'general';
    my $action  = shift || 'correspond';
    Test::More::ok(open(my $mail, '|-', "$RT::BinPath/rt-mailgate --url $baseurl --queue $queue --action $action"), "Opened the mailgate - $!");
    return $mail;
}


sub close_mailgate_ok {
    my $class = shift;
    my $mail  = shift;
    close $mail;
    Test::More::is ($? >> 8, 0, "The mail gateway exited normally. yay");
}

sub mailsent_ok {
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

sub set_mail_catcher {
    my $self = shift;
    return 1;
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

=head2 get_relocatable_dir

Takes a path relative to the location of the test file that is being
run and returns a path that takes the invocation path into account.

e.g. RT::Test::get_relocatable_dir(File::Spec->updir(), 'data', 'emails')

=cut

sub get_relocatable_dir {
    (my $volume, my $directories, my $file) = File::Spec->splitpath($0);
    if (File::Spec->file_name_is_absolute($directories)) {
        return File::Spec->catdir($directories, @_);
    } else {
        return File::Spec->catdir(File::Spec->curdir(), $directories, @_);
    }
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

sub get_abs_relocatable_dir {
    (my $volume, my $directories, my $file) = File::Spec->splitpath($0);
    if (File::Spec->file_name_is_absolute($directories)) {
        return File::Spec->catdir($directories, @_);
    } else {
        return File::Spec->catdir(Cwd->getcwd(), $directories, @_);
    }
}

sub import_gnupg_key {
    my $self = shift;
    my $key  = shift;
    my $type = shift || 'secret';

    $key =~ s/\@/-at-/g;
    $key .= ".$type.key";

    require RT::Crypt::GnuPG;

    # simple strategy find data/gnupg/keys, from the dir where test file lives
    # to updirs, try 3 times in total
    my $path = File::Spec->catfile( 'data', 'gnupg', 'keys' );
    my $abs_path;
    for my $up ( 0 .. 2 ) {
        my $p = get_relocatable_dir($path);
        if ( -e $p ) {
            $abs_path = $p;
            last;
        }
        else {
            $path = File::Spec->catfile( File::Spec->updir(), $path );
        }
    }

    die "can't find the dir where gnupg keys are stored"
      unless $abs_path;

    return RT::Crypt::GnuPG::ImportKey(
        RT::Test->file_content( [ $abs_path, $key ] ) );
}


sub lsign_gnupg_key {
    my $self = shift;
    my $key = shift;

    require RT::Crypt::GnuPG; require GnuPG::Interface;
    my $gnupg = new GnuPG::Interface;
    my %opt = RT->Config->Get('GnuPGOptions');
    $gnupg->options->hash_init(
        RT::Crypt::GnuPG::_PrepareGnuPGOptions( %opt ),
        meta_interactive => 0,
    );

    my %handle; 
    my $handles = GnuPG::Handles->new(
        stdin   => ($handle{'input'}   = new IO::Handle),
        stdout  => ($handle{'output'}  = new IO::Handle),
        stderr  => ($handle{'error'}   = new IO::Handle),
        logger  => ($handle{'logger'}  = new IO::Handle),
        status  => ($handle{'status'}  = new IO::Handle),
        command => ($handle{'command'} = new IO::Handle),
    );

    eval {
        local $SIG{'CHLD'} = 'DEFAULT';
        local @ENV{'LANG', 'LC_ALL'} = ('C', 'C');
        my $pid = $gnupg->wrap_call(
            handles => $handles,
            commands => ['--lsign-key'],
            command_args => [$key],
        );
        close $handle{'input'};
        while ( my $str = readline $handle{'status'} ) {
            if ( $str =~ /^\[GNUPG:\]\s*GET_BOOL sign_uid\..*/ ) {
                print { $handle{'command'} } "y\n";
            }
        }
        waitpid $pid, 0;
    };
    my $err = $@;
    close $handle{'output'};

    my %res;
    $res{'exit_code'} = $?;
    foreach ( qw(error logger status) ) {
        $res{$_} = do { local $/; readline $handle{$_} };
        delete $res{$_} unless $res{$_} && $res{$_} =~ /\S/s;
        close $handle{$_};
    }
    $RT::Logger->debug( $res{'status'} ) if $res{'status'};
    $RT::Logger->warning( $res{'error'} ) if $res{'error'};
    $RT::Logger->error( $res{'logger'} ) if $res{'logger'} && $?;
    if ( $err || $res{'exit_code'} ) {
        $res{'message'} = $err? $err : "gpg exitted with error code ". ($res{'exit_code'} >> 8);
    }
    return %res;
}

sub trust_gnupg_key {
    my $self = shift;
    my $key = shift;

    require RT::Crypt::GnuPG; require GnuPG::Interface;
    my $gnupg = new GnuPG::Interface;
    my %opt = RT->Config->Get('GnuPGOptions');
    $gnupg->options->hash_init(
        RT::Crypt::GnuPG::_PrepareGnuPGOptions( %opt ),
        meta_interactive => 0,
    );

    my %handle; 
    my $handles = GnuPG::Handles->new(
        stdin   => ($handle{'input'}   = new IO::Handle),
        stdout  => ($handle{'output'}  = new IO::Handle),
        stderr  => ($handle{'error'}   = new IO::Handle),
        logger  => ($handle{'logger'}  = new IO::Handle),
        status  => ($handle{'status'}  = new IO::Handle),
        command => ($handle{'command'} = new IO::Handle),
    );

    eval {
        local $SIG{'CHLD'} = 'DEFAULT';
        local @ENV{'LANG', 'LC_ALL'} = ('C', 'C');
        my $pid = $gnupg->wrap_call(
            handles => $handles,
            commands => ['--edit-key'],
            command_args => [$key],
        );
        close $handle{'input'};

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
        waitpid $pid, 0;
    };
    my $err = $@;
    close $handle{'output'};

    my %res;
    $res{'exit_code'} = $?;
    foreach ( qw(error logger status) ) {
        $res{$_} = do { local $/; readline $handle{$_} };
        delete $res{$_} unless $res{$_} && $res{$_} =~ /\S/s;
        close $handle{$_};
    }
    $RT::Logger->debug( $res{'status'} ) if $res{'status'};
    $RT::Logger->warning( $res{'error'} ) if $res{'error'};
    $RT::Logger->error( $res{'logger'} ) if $res{'logger'} && $?;
    if ( $err || $res{'exit_code'} ) {
        $res{'message'} = $err? $err : "gpg exitted with error code ". ($res{'exit_code'} >> 8);
    }
    return %res;
}

sub started_ok {
    my $self = shift;

    require RT::Test::Web;

    my $which = $ENV{'RT_TEST_WEB_HANDLER'} || 'standalone';
    my ($server, $variant) = split /\+/, $which, 2;

    my $function = 'start_'. $server .'_server';
    unless ( $self->can($function) ) {
        die "Don't know how to start server '$server'";
    }
    return $self->$function( $variant, @_ );
}

sub start_standalone_server {
    my $self = shift;


    require RT::Interface::Web::Standalone;

    require Test::HTTP::Server::Simple::StashWarnings;
    unshift @RT::Interface::Web::Standalone::ISA,
        'Test::HTTP::Server::Simple::StashWarnings';
    *RT::Interface::Web::Standalone::test_warning_path = sub {
        "/__test_warnings";
    };

    my $s = RT::Interface::Web::Standalone->new($port);

    my $ret = $s->started_ok;
    push @SERVERS, $s->pids;

    $RT::Handle = new RT::Handle;
    $RT::Handle->dbh( undef );
    RT->ConnectToDatabase;

    return ($ret, RT::Test::Web->new);
}

sub start_apache_server {
    my $self = shift;
    my $variant = shift || 'mod_perl';

    my %info = $self->apache_server_info( variant => $variant );

    Test::More::diag(do {
        open( my $fh, '<', $tmp{'config'}{'RT'} ) or die $!;
        local $/;
        <$fh>
    });

    my $tmpl = File::Spec->rel2abs( File::Spec->catfile(
        't', 'data', 'configs',
        'apache'. $info{'version'} .'+'. $variant .'.conf'
    ) );
    my %opt = (
        listen         => $port,
        server_root    => $info{'HTTPD_ROOT'} || $ENV{'HTTPD_ROOT'}
            || Test::More::BAIL_OUT("Couldn't figure out server root"),
        document_root  => $RT::MasonComponentRoot,
        tmp_dir        => "$tmp{'directory'}",
        rt_bin_path    => $RT::BinPath,
        rt_site_config => $ENV{'RT_SITE_CONFIG'},
    );
    foreach (qw(log pid lock)) {
        $opt{$_ .'_file'} = File::Spec->catfile(
            "$tmp{'directory'}", "apache.$_"
        );
    }
    {
        my $method = 'apache_'.$variant.'_server_options';
        $self->$method( \%info, \%opt );
    }
    $tmp{'config'}{'apache'} = File::Spec->catfile(
        "$tmp{'directory'}", "apache.conf"
    );
    $self->process_in_file(
        in      => $tmpl, 
        out     => $tmp{'config'}{'apache'},
        options => \%opt,
    );

    $self->fork_exec($info{'executable'}, '-f', $tmp{'config'}{'apache'});
    my $pid = do {
        my $tries = 10;
        while ( !-e $opt{'pid_file'} ) {
            $tries--;
            last unless $tries;
            sleep 1;
        }
        Test::More::BAIL_OUT("Couldn't start apache server, no pid file")
            unless -e $opt{'pid_file'};
        open( my $pid_fh, '<', $opt{'pid_file'} )
            or Test::More::BAIL_OUT("Couldn't open pid file: $!");
        my $pid = <$pid_fh>;
        chomp $pid;
        $pid;
    };

    Test::More::ok($pid, "Started apache server #$pid");

    push @SERVERS, $pid;

    return (RT->Config->Get('WebURL'), RT::Test::Web->new);
}

sub apache_server_info {
    my $self = shift;
    my %res = @_;

    my $bin = $res{'executable'} = $ENV{'RT_TEST_APACHE'}
        || $self->find_apache_server
        || Test::More::BAIL_OUT("Couldn't find apache server, use RT_TEST_APACHE");

    Test::More::diag("Using '$bin' apache executable for testing")
        if $ENV{'TEST_VERBOSE'};

    my $info = `$bin -V`;
    ($res{'version'}) = ($info =~ m{Server\s+version:\s+Apache/(\d+\.\d+)\.});
    Test::More::BAIL_OUT(
        "Couldn't figure out version of the server"
    ) unless $res{'version'};

    my %opts = ($info =~ m/^\s*-D\s+([A-Z_]+?)(?:="(.*)")$/mg);
    %res = (%res, %opts);

    $res{'modules'} = [
        map {s/^\s+//; s/\s+$//; $_}
        grep $_ !~ /Compiled in modules/i,
        split /\r*\n/, `$bin -l`
    ];

    return %res;
}

sub apache_mod_perl_server_options {
    my $self = shift;
    my %info = %{ shift() };
    my $current = shift;

    my %required_modules = (
        '2.2' => [qw(authz_host log_config env alias perl)],
    );
    my @mlist = @{ $required_modules{ $info{'version'} } };

    $current->{'load_modules'} = '';
    foreach my $mod ( @mlist ) {
        next if grep $_ =~ /^(mod_|)$mod\.c$/, @{ $info{'modules'} };

        $current->{'load_modules'} .=
            "LoadModule ${mod}_module modules/mod_${mod}.so\n";
    }
    return;
}

sub apache_fastcgi_server_options {
    my $self = shift;
    my %info = %{ shift() };
    my $current = shift;

    my %required_modules = (
        '2.2' => [qw(authz_host log_config env alias mime fastcgi)],
    );
    my @mlist = @{ $required_modules{ $info{'version'} } };

    $current->{'load_modules'} = '';
    foreach my $mod ( @mlist ) {
        next if grep $_ =~ /^(mod_|)$mod\.c$/, @{ $info{'modules'} };

        $current->{'load_modules'} .=
            "LoadModule ${mod}_module modules/mod_${mod}.so\n";
    }
    return;
}

sub find_apache_server {
    my $self = shift;
    return $_ foreach grep defined,
        map $self->find_executable($_),
        qw(httpd apache apache2 apache1);
    return undef;
}

sub stop_server {
    my $self = shift;

    my $sig = 'TERM';
    $sig = 'INT' if !$ENV{'RT_TEST_WEB_HANDLER'}
                    || $ENV{'RT_TEST_WEB_HANDLER'} =~/^standalone(?:\+|\z)/;
    kill $sig, @SERVERS;
    foreach my $pid (@SERVERS) {
        waitpid $pid, 0;
    }
}

sub file_content {
    my $self = shift;
    my $path = shift;
    my %args = @_;

    $path = File::Spec->catfile( @$path ) if ref $path eq 'ARRAY';

    Test::More::diag "reading content of '$path'" if $ENV{'TEST_VERBOSE'};

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
    my $self = shift;
    my $name = shift;

    require File::Spec;
    foreach my $dir ( split /:/, $ENV{'PATH'} ) {
        my $fpath = File::Spec->catpath(
            (File::Spec->splitpath( $dir, 'no file' ))[0..1], $name
        );
        next unless -e $fpath && -r _ && -x _;
        return $fpath;
    }
    return undef;
}

sub fork_exec {
    my $self = shift;

    my $pid = fork;
    unless ( defined $pid ) {
        die "cannot fork: $!";
    } elsif ( !$pid ) {
        exec @_;
        die "can't exec `". join(' ', @_) ."` program: $!";
    } else {
        return $pid;
    }
}

sub process_in_file {
    my $self = shift;
    my %args = ( in => undef, options => undef, @_ );

    my $text = $self->file_content( $args{'in'} );
    while ( my ($opt) = ($text =~ /\%\%(.+?)\%\%/) ) {
        my $value = $args{'options'}{ lc $opt };
        die "no value for $opt" unless defined $value;

        $text =~ s/\%\%\Q$opt\E\%\%/$value/g;
    }

    my ($out_fh, $out_conf);
    unless ( $args{'out'} ) {
        ($out_fh, $out_conf) = tempfile();
    } else {
        $out_conf = $args{'out'};
        open( $out_fh, '>', $out_conf )
            or die "couldn't open '$out_conf': $!";
    }
    print $out_fh $text;
    seek $out_fh, 0, 0;

    return ($out_fh, $out_conf);
}

sub parse_mail {
    my $mail = shift;
    require RT::EmailParser;
    my $parser = RT::EmailParser->new;
    $parser->ParseMIMEEntityFromScalar( $mail );
    return $parser->Entity;
}

END {
    my $Test = RT::Test->builder;
    return if $Test->{Original_Pid} != $$;


    # we are in END block and should protect our exit code
    # so calls below may call system or kill that clobbers $?
    local $?;

    RT::Test->stop_server;

    # not success
    if ( !$Test->summary || grep !$_, $Test->summary ) {
        $tmp{'directory'}->unlink_on_destroy(0);

        Test::More::diag(
            "Some tests failed or we bailed out, tmp directory"
            ." '$tmp{directory}' is not cleaned"
        );
    }

    if ( $ENV{RT_TEST_PARALLEL} && $created_new_db ) {

        # Pg doesn't like if you issue a DROP DATABASE while still connected
        my $dbh = $RT::Handle->dbh;
        $dbh->disconnect if $dbh;

        $dbh = _get_dbh( RT::Handle->SystemDSN, $ENV{RT_DBA_USER}, $ENV{RT_DBA_PASSWORD} );
        RT::Handle->DropDatabase( $dbh, Force => 1 );
        $dbh->disconnect;
    }
}

1;
