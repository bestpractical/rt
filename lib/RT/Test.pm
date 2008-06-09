# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2008 Best Practical Solutions, LLC 
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

use Test::More;
use Socket;
use File::Temp;
my $config;
our ($existing_server, $port, $dbname);
my $mailsent;

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
    if ( my $test_server = $ENV{'RT_TEST_SERVER'} ) {
        my ($host, $test_port) = split(':', $test_server, 2);
        $port = $test_port || 80;
        $existing_server = "http://$host:$port";

        # we can't parallel test with $existing_server
        undef $ENV{RT_TEST_PARALLEL};
    }
    if ( $ENV{RT_TEST_PARALLEL} ) {
        $port   = generate_port();
        $dbname = "rt3test_$port";    #yes, dbname also makes use of $port
    }
    else {
        $dbname = "rt3test";
    }

    $port = generate_port() unless $port;

};

use RT::Interface::Web::Standalone;
use Test::HTTP::Server::Simple;
use Test::WWW::Mechanize;

unshift @RT::Interface::Web::Standalone::ISA, 'Test::HTTP::Server::Simple';

my @server;

sub import {
    my $class = shift;
    my %args = @_;

    $config = File::Temp->new;
    print $config qq{
Set( \$WebPort , $port);
Set( \$WebBaseURL , "http://localhost:\$WebPort");
Set( \$DatabaseName , $dbname);
Set( \$LogToSyslog , undef);
Set( \$LogToScreen , "warning");
};
    print $config $args{'config'} if $args{'config'};
    print $config "\n1;\n";
    $ENV{'RT_SITE_CONFIG'} = $config->filename;
    close $config;

    use RT;
    RT::LoadConfig;
    if (RT->Config->Get('DevelMode')) { require Module::Refresh; }

    # make it another function
    $mailsent = 0;
    my $mailfunc = sub { 
        my $Entity = shift;
        $mailsent++;
        return 1;
    };
    RT::Config->Set( 'MailCommand' => $mailfunc);

    require RT::Handle;
    unless ( $existing_server ) {
        $class->bootstrap_db( %args );
    }

    RT->Init;

    my $screen_logger = $RT::Logger->remove( 'screen' );
    require Log::Dispatch::Perl;
    $RT::Logger->add( Log::Dispatch::Perl->new
                      ( name      => 'rttest',
                        min_level => $screen_logger->min_level,
                        action => { error     => 'warn',
                                    critical  => 'warn' } ) );
}

my $created_new_db;    # have we created new db? mainly for parallel testing

sub bootstrap_db {
    my $self = shift;
    my %args = @_;

   unless (defined $ENV{'RT_DBA_USER'} && defined $ENV{'RT_DBA_PASSWORD'}) {
	BAIL_OUT("RT_DBA_USER and RT_DBA_PASSWORD environment variables need to be set in order to run 'make test'");
   }
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

sub started_ok {
    require RT::Test::Web;
    if ( $existing_server ) {
        ok(1, "using existing server $existing_server");
        RT::Logger->warning( $existing_server);
        return ($existing_server, RT::Test::Web->new);
    }
    my $s = RT::Interface::Web::Standalone->new($port);
    push @server, $s;
    my $ret = $s->started_ok;
    $RT::Handle = new RT::Handle;
    $RT::Handle->dbh( undef );
    RT->ConnectToDatabase;
    return ($ret, RT::Test::Web->new);
}

sub _get_dbh {
    my ($dsn, $user, $pass) = @_;
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

sub open_mailgate_ok {
    my $class   = shift;
    my $baseurl = shift;
    my $queue   = shift || 'general';
    my $action  = shift || 'correspond';
    ok(open(my $mail, "|$RT::BinPath/rt-mailgate --url $baseurl --queue $queue --action $action"), "Opened the mailgate - $!");
    return $mail;
}


sub close_mailgate_ok {
    my $class = shift;
    my $mail  = shift;
    close $mail;
    is ($? >> 8, 0, "The mail gateway exited normally. yay");
}

sub mailsent_ok {
    my $class = shift;
    my $expected  = shift;
    is ($mailsent, $expected, "The number of mail sent ($expected) matches. yay");
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
            diag "couldn't create a record: $msg";
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
        @_
    );
    my $message = delete $args{'message'};

    my $cmd = $RT::BinPath .'/rt-mailgate';
    die "Couldn't find mailgate ($cmd) command" unless -f $cmd;

    $cmd .= ' --debug';
    while( my ($k,$v) = each %args ) {
        next unless $v;
        $cmd .= " --$k '$v'";
    }
    $cmd .= ' 2>&1';

    DBIx::SearchBuilder::Record::Cachable->FlushCache;

    require IPC::Open2;
    my ($child_out, $child_in);
    my $pid = IPC::Open2::open2($child_out, $child_in, $cmd);

    if ( UNIVERSAL::isa($message, 'MIME::Entity') ) {
        $message->print( $child_in );
    } else {
        print $child_in $message;
    }
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

    my ($status, $gate_result) = $self->run_mailgate( message => $message, %args );

    my $id;
    unless ( $status >> 8 ) {
        ($id) = ($gate_result =~ /Ticket:\s*(\d+)/i);
        unless ( $id ) {
            diag "Couldn't find ticket id in text:\n$gate_result" if $ENV{'TEST_VERBOSE'};
        }
    } else {
        diag "Mailgate output:\n$gate_result" if $ENV{'TEST_VERBOSE'};
    }
    return ($status, $id);
}

sub set_mail_catcher {
    my $self = shift;
    my $catcher = sub {
        my $MIME = shift;

        open my $handle, '>>', 't/mailbox'
            or die "Unable to open t/mailbox for appending: $!";

        $MIME->print($handle);
        print $handle "%% split me! %%\n";
        close $handle;
    };
    RT->Config->Set( MailCommand => $catcher );
}

sub fetch_caught_mails {
    my $self = shift;
    return grep /\S/, split /%% split me! %%/,
        RT::Test->file_content( 't/mailbox', 'unlink' => 1, noexist => 1 );
}

sub file_content {
    my $self = shift;
    my $path = shift;
    my %args = @_;

    $path = File::Spec->catfile( @$path ) if ref $path;

    diag "reading content of '$path'" if $ENV{'TEST_VERBOSE'};

    open my $fh, "<:raw", $path
        or do { warn "couldn't open file '$path': $!" unless $args{noexist}; return '' };
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
        my $fpath = File::Spec->catpath( (File::Spec->splitpath( $dir, 'no file' ))[0..1], $name );
        next unless -e $fpath && -r _ && -x _;
        return $fpath;
    }
    return undef;
}

sub import_gnupg_key {
    my $self = shift;
    my $key = shift;
    my $type = shift || 'secret';

    $key =~ s/\@/-at-/g;
    $key .= ".$type.key";
    require RT::Crypt::GnuPG;
    return RT::Crypt::GnuPG::ImportKey(
        RT::Test->file_content([qw(t data gnupg keys), $key])
    );
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

END {
    if ( $ENV{RT_TEST_PARALLEL} && $created_new_db ) {
        my $dbh =
          _get_dbh( RT::Handle->DSN, $ENV{RT_DBA_USER}, $ENV{RT_DBA_PASSWORD} );
        RT::Handle->DropDatabase( $dbh, Force => 1 );
        $dbh->disconnect;
    }
}

1;
