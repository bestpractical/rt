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
use strict;
use warnings;

package RT::Test;
use base qw/Jifty::Test/;
use Test::More;
use File::Temp;
use File::Spec;
my $config;
our ( $existing_server, $port );
my $mailsent;

my @server;

=head1 NAME

RT::Test - RT Testing

=head1 NOTES

=head2 COVERAGE

To run the rt test suite with coverage support, install L<Devel::Cover> and run:

  make test RT_DBA_USER=.. RT_DBA_PASSWORD=.. HARNESS_PERL_SWITCHES=-MDevel::Cover
 cover -ignore_re 'var/mason/.*'

The coverage tests have DevelMode turned off, and have C<named_component_subs> enabled for L<HTML::Mason> to avoid an optimizer problem in Perl that hides the top-level optree from L<Devel::Cover>.

=cut

sub setup {
    my $self = shift;
    my $args = shift;

    # Make sure to call the super-class version
    $self->SUPER::setup($args);

    $self->_setup_config(@$args);
    RT::init_system_objects();
}

sub _setup_config {
    my $class = shift;
    my %args  = (@_);

    require RT;
    RT->load_config();
    my $port = 999;
    $config = File::Temp->new;
    print $config qq{
set( \$WebPort , $port);
set( \$WebbaseURL , "http://localhost:\$WebPort");
set( \$LogToScreen , "debug");
set( \$LogStackTraces , "warning");
};
    print $config $args{'config'} if $args{'config'};
    print $config "\n1;\n";
    $ENV{'RT_SITE_CONFIG'} = $config->filename;
    close $config;

    if ( RT->config->get('DevelMode') ) { require Module::Refresh; }

    # make it another function
    $mailsent = 0;
    my $mailfunc = sub {
        my $Entity = shift;
        $mailsent++;
        return 1;
    };
    RT->config->set( 'MailCommand' => $mailfunc );
}
our $server_url;

sub started_ok {
    require RT::Test::Web;
    if ($existing_server) {
        ok( 1, "using existing server $existing_server" );
        Jifty->log->warn($existing_server);
        return ( $existing_server, RT::Test::Web->new );
    }
    my $server = Jifty::Test->make_server;
    $RT::Test::server_url = $server->started_ok . "/";

    return ( $RT::Test::server_url, RT::Test::Web->new );
}

sub open_mailgate_ok {
    my $class   = shift;
    my $baseurl = shift;
    my $queue   = shift || 'general';
    my $action  = shift || 'correspond';
    ok( open( my $mail, "|$RT::BinPath/rt-mailgate --url $baseurl --queue $queue --action $action" ), "Opened the mailgate - $!" );
    return $mail;
}
    RT->config->set( DevelMode => '0' ) if $INC{'Devel/Cover.pm'};


sub close_mailgate_ok {
    my $class = shift;
    my $mail  = shift;
    close $mail;
    is( $? >> 8, 0, "The mail gateway exited normally. yay" );
}

sub mailsent_ok {
    my $class    = shift;
    my $expected = shift;
    is( $mailsent, $expected, "The number of mail sent ($expected) matches. yay" );
}

=head1 UTILITIES

=head2 load_or_create_user

=cut

sub load_or_create_user {
    my $self = shift;
    my %args = ( privileged => 1, disabled => 0, @_ );

    my $MemberOf = delete $args{'member_of'};
    $MemberOf = [$MemberOf] if defined $MemberOf && !ref $MemberOf;
    $MemberOf ||= [];

    my $obj = RT::Model::User->new( current_user => RT->system_user );
    if ( $args{'name'} ) {
        $obj->load_by_cols( name => $args{'name'} );
    } elsif ( $args{'email'} ) {
        $obj->load_by_cols( email => $args{'email'} );
    } else {
        die "name or email is required";
    }
    if ( $obj->id ) {

        # cool
        $obj->set_privileged( $args{'privileged'} || 0 )
            if ( $args{'privileged'} || 0 ) != ( $obj->privileged || 0 );
        $obj->set_disabled( $args{'disabled'} || 0 )
            if ( $args{'disabled'} || 0 ) != ( $obj->disabled || 0 );
    } else {
        my ( $val, $msg ) = $obj->create(%args);
        die "$msg" unless $val;
    }

    # clean group membership
    {
        require RT::Model::GroupMemberCollection;
        my $gms = RT::Model::GroupMemberCollection->new( current_user => RT->system_user );
        my $groups_alias = $gms->join(
            column1 => 'group_id',
            table2  => 'Groups',
            column2 => 'id',
        );
        $gms->limit(
            alias  => $groups_alias,
            column => 'domain',
            value  => 'UserDefined'
        );
        $gms->limit( column => 'member_id', value => $obj->id );
        while ( my $group_member_record = $gms->next ) {
            $group_member_record->delete;
        }
    }

    # add new user to groups
    foreach (@$MemberOf) {
        my $group = RT::Model::Group->new( current_user => RT::system_user() );
        $group->load_user_defined_group($_);
        die "couldn't load group '$_'" unless $group->id;
        $group->add_member( $obj->id );
    }

    return $obj;
}

=head2 load_or_create_queue

=cut

sub load_or_create_queue {
    my $self = shift;
    my %args = ( disabled => 0, @_ );
    my $obj  = RT::Model::Queue->new( current_user => RT->system_user );
    if ( $args{'name'} ) {
        $obj->load_by_cols( name => $args{'name'} );
    } else {
        die "name is required";
    }
    unless ( $obj->id ) {
        my ( $val, $msg ) = $obj->create(%args);
        die "$msg" unless $val;
    } else {
        my @fields = qw(correspond_address comment_address);
        foreach my $field (@fields) {
            next unless exists $args{$field};
            next if $args{$field} eq $obj->$field;

            no warnings 'uninitialized';
            my $method = 'set_' . $field;
            my ( $val, $msg ) = $obj->$method( $args{$field} );
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
    my $obj  = RT::Model::CustomField->new(RT->system_user);
    if ( $args{'name'} ) {
        $obj->load_by_name( name => $args{'name'}, queue => $args{'queue'} );
    }
    else {
        die "Name is required";
    }
    unless ( $obj->id ) {
        my ( $val, $msg ) = $obj->create(%args);
        die "$msg" unless $val;
    }

    return $obj;
}

sub store_rights {
    my $self = shift;

    require RT::ACE;

    # fake construction
    RT::ACE->new( current_user => RT->system_user );
    my @fields = keys %{ RT::ACE->_class_accessible };

    require RT::ACL;
    my $acl = RT::ACL->new( current_user => RT->system_user );
    $acl->limit(
        column   => 'right_name',
        operator => '!=',
        value    => 'SuperUser'
    );

    my @res;
    while ( my $ace = $acl->next ) {
        my $obj = $ace->principal_object->object;
        if (   $obj->isa('RT::Model::Group')
            && $obj->type eq 'UserEquiv'
            && $obj->instance == RT->nobody->id )
        {
            next;
        }

        my %tmp = ();
        foreach my $field (@fields) {
            $tmp{$field} = $ace->__value($field);
        }
        push @res, \%tmp;
    }
    return @res;
}

sub restore_rights {
    my $self    = shift;
    my @entries = @_;
    foreach my $entry (@entries) {
        my $ace = RT::Model::ACE->new( current_user => RT->system_user );
        my ( $status, $msg ) = $ace->RT::Record::create(%$entry);
        unless ($status) {
            diag "couldn't create a record: $msg";
        }
    }
}

sub set_rights {
    my $self = shift;

    require RT::Model::ACECollection;
    my $acl = RT::Model::ACECollection->new( current_user => RT->system_user );
    $acl->limit(
        column   => 'right_name',
        operator => '!=',
        value    => 'SuperUser'
    );
    while ( my $ace = $acl->next ) {
        my $obj = $ace->principal_object->object;
        if (   $obj->isa('RT::Model::Group')
            && $obj->type eq 'UserEquiv'
            && $obj->instance == RT->nobody->id )
        {
            next;
        }
        $ace->delete;
    }
    return $self->add_rights(@_);
}

sub add_rights {
    my $self = shift;
    my @list = ref $_[0] ? @_ : @_ ? {@_} : ();

    require RT::Model::ACECollection;
    foreach my $e (@list) {
        my $principal = delete $e->{'principal'};
        unless ( ref $principal ) {
            if ( $principal =~ /^(everyone|(?:un)?privileged)$/i ) {
                $principal = RT::Model::Group->new( current_user => RT->system_user );
                $principal->load_system_internal_group($1);
            } else {
                die "principal is not an object, but also is not name of a system group";
            }
        }
        unless ( $principal->isa('RT::Model::Principal') ) {
            if ( $principal->can('principal_object') ) {
                $principal = $principal->principal_object;
            }
        }
        my @Rights = ref $e->{'right'} ? @{ $e->{'right'} } : ( $e->{'right'} );
        foreach my $right (@Rights) {
            my ( $status, $msg ) = $principal->grant_right( %$e, right => $right );
            Jifty->log->warn($msg) unless $status;
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

    my $cmd = $RT::BinPath . '/rt-mailgate';
    die "Couldn't find mailgate ($cmd) command" unless -f $cmd;

    $cmd = $^X . " " . $cmd . ' --debug';
    while ( my ( $k, $v ) = each %args ) {
        next unless $v;
        $cmd .= " --$k '$v'";
    }
    $cmd .= ' 2>&1';

    Jifty::DBI::Record::Cachable->flush_cache;

    require IPC::Open2;
    my ( $child_out, $child_in );
    my $pid = IPC::Open2::open2( $child_out, $child_in, $cmd );

    if ( UNIVERSAL::isa( $message, 'MIME::Entity' ) ) {
        $message->print($child_in);
    } else {
        print $child_in $message;
    }
    close $child_in;

    my $result = do { local $/; <$child_out> };
    close $child_out;
    waitpid $pid, 0;
    return ( $?, $result );
}

sub send_via_mailgate {
    my $self    = shift;
    my $message = shift;
    my %args    = (@_);

    my ( $status, $gate_result ) = $self->run_mailgate( message => $message, %args );

    my $id;
    unless ( $status >> 8 ) {
        ($id) = ( $gate_result =~ /Ticket:\s*(\d+)/i );
        unless ($id) {
            diag "Couldn't find ticket id in text:\n$gate_result"
                if $ENV{'TEST_VERBOSE'};
        }
    } else {
        diag "Mailgate output:\n$gate_result" if $ENV{'TEST_VERBOSE'};
    }
    return ( $status, $id );
}

sub import_gnupg_key {
    my $self = shift;
    my $key  = shift;
    my $type = shift || 'secret';

    $key =~ s/\@/-at-/g;
    $key .= ".$type.key";

    require RT::Crypt::GnuPG;
    ( my $volume, my $directories, my $file ) = File::Spec->splitpath($0);
    my $keys_dir = File::Spec->catdir(
        File::Spec->curdir(), $directories,
        File::Spec->updir(),  qw(data gnupg keys)
    );

    # this is a bit hackish; calling it from somewhere that's not a subdir
    # of t/ will fail
    return RT::Crypt::GnuPG::ImportKey(
        RT::Test->file_content(
            [
                get_relocatable_dir(
                    File::Spec->updir(), 'data', 'gnupg', 'keys'
                ),
                $key
            ]
        )
    );
}

my $mailbox_catcher = File::Temp->new( OPEN => 0, CLEANUP => 0 )->filename;

sub set_mail_catcher {
    my $self    = shift;
    my $catcher = sub {
        my $MIME = shift;

        open my $handle, '>>', $mailbox_catcher
          or die "Unable to open $mailbox_catcher for appending: $!";

        $MIME->print($handle);
        print $handle "%% split me! %%\n";
        close $handle;
    };
    RT->config->set( MailCommand => $catcher );
}

sub db_requires_no_dba {
    my $self    = shift;
    my $db_type = RT->config->get('DatabaseType');
    return 1 if $db_type eq 'SQLite';
}


sub fetch_caught_mails {
    my $self = shift;
    return grep /\S/, split /%% split me! %%/,
       RT::Test->file_content( $mailbox_catcher, 'unlink' => 1, noexist => 1 );
}

sub clean_caught_mails {
    unlink $mailbox_catcher;
}

sub file_content {
    my $self = shift;
    my $path = shift;
    my %args = @_;

    $path = File::Spec->catfile(@$path) if ref $path eq 'ARRAY';

    diag "reading content of '$path'" if $ENV{'TEST_VERBOSE'};
    my $content = '';
    if ( -f $path ) {
        open my $fh, "<:raw", $path
          or do {
            warn "couldn't open file '$path': $!" unless $args{noexist};
            return '';
          };
        $content = do { local $/; <$fh> };
        close $fh;

        unlink $path if $args{'unlink'};
    }

    return $content;
}
sub find_executable {
    my $self = shift;
    my $name = shift;

    require File::Spec;
    foreach my $dir ( split /:/, $ENV{'PATH'} ) {
        my $fpath = File::Spec->catpath(
            ( File::Spec->splitpath( $dir, 'no file' ) )[ 0 .. 1 ], $name );
        next unless -e $fpath && -r _ && -x _;
        return $fpath;
    }
    return undef;
}

=head2 get_relocatable_dir

Takes a path relative to the location of the test file that is being
run and returns a path that takes the invocation path into account.

e.g. RT::Test::get_relocatable_dir(File::Spec->updir(), 'data', 'emails')

=cut

sub get_relocatable_dir {
    ( my $volume, my $directories, my $file ) = File::Spec->splitpath($0);
    if ( File::Spec->file_name_is_absolute($directories) ) {
        return File::Spec->catdir( $directories, @_ );
    }
    else {
        return File::Spec->catdir( File::Spec->curdir(), $directories, @_ );
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
    return File::Spec->catfile( get_relocatable_dir(@_), $file );
}

sub get_abs_relocatable_dir {
    ( my $volume, my $directories, my $file ) = File::Spec->splitpath($0);
    if ( File::Spec->file_name_is_absolute($directories) ) {
        return File::Spec->catdir( $directories, @_ );
    }
    else {
        return File::Spec->catdir( Cwd->getcwd(), $directories, @_ );
    }
}


sub lsign_gnupg_key {
    my $self = shift;
    my $key  = shift;

    require RT::Crypt::GnuPG;
    require GnuPG::Interface;
    my $gnupg = new GnuPG::Interface;
    my %opt   = RT->config->get('GnuPGOptions');
    $gnupg->options->hash_init( RT::Crypt::GnuPG::_prepare_gnupg_options(%opt), meta_interactive => 0, );

    my %handle;
    my $handles = GnuPG::Handles->new(
        stdin   => ( $handle{'input'}   = new IO::Handle ),
        stdout  => ( $handle{'output'}  = new IO::Handle ),
        stderr  => ( $handle{'error'}   = new IO::Handle ),
        logger  => ( $handle{'logger'}  = new IO::Handle ),
        status  => ( $handle{'status'}  = new IO::Handle ),
        command => ( $handle{'command'} = new IO::Handle ),
    );

    eval {
        local $SIG{'CHLD'} = 'DEFAULT';
        local @ENV{ 'LANG', 'LC_ALL' } = ( 'C', 'C' );
        my $pid = $gnupg->wrap_call(
            handles      => $handles,
            commands     => ['--lsign-key'],
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
    foreach (qw(error logger status)) {
        $res{$_} = do { local $/; readline $handle{$_} };
        delete $res{$_} unless $res{$_} && $res{$_} =~ /\S/s;
        close $handle{$_};
    }
    Jifty->log->debug( $res{'status'} ) if $res{'status'};
    Jifty->log->warn( $res{'error'} )   if $res{'error'};
    Jifty->log->error( $res{'logger'} ) if $res{'logger'} && $?;
    if ( $err || $res{'exit_code'} ) {
        $res{'message'}
            = $err
            ? $err
            : "gpg exitted with error code " . ( $res{'exit_code'} >> 8 );
    }
    return %res;
}

sub trust_gnupg_key {
    my $self = shift;
    my $key  = shift;

    require RT::Crypt::GnuPG;
    require GnuPG::Interface;
    my $gnupg = new GnuPG::Interface;
    my %opt   = RT->config->get('GnuPGOptions');
    $gnupg->options->hash_init( RT::Crypt::GnuPG::_prepare_gnupg_options(%opt), meta_interactive => 0, );

    my %handle;
    my $handles = GnuPG::Handles->new(
        stdin   => ( $handle{'input'}   = new IO::Handle ),
        stdout  => ( $handle{'output'}  = new IO::Handle ),
        stderr  => ( $handle{'error'}   = new IO::Handle ),
        logger  => ( $handle{'logger'}  = new IO::Handle ),
        status  => ( $handle{'status'}  = new IO::Handle ),
        command => ( $handle{'command'} = new IO::Handle ),
    );

    eval {
        local $SIG{'CHLD'} = 'DEFAULT';
        local @ENV{ 'LANG', 'LC_ALL' } = ( 'C', 'C' );
        my $pid = $gnupg->wrap_call(
            handles      => $handles,
            commands     => ['--edit-key'],
            command_args => [$key],
        );
        close $handle{'input'};

        my $done = 0;
        while ( my $str = readline $handle{'status'} ) {
            if ( $str =~ /^\[GNUPG:\]\s*\QGET_LINE keyedit.prompt/ ) {
                if ($done) {
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
    foreach (qw(error logger status)) {
        $res{$_} = do { local $/; readline $handle{$_} };
        delete $res{$_} unless $res{$_} && $res{$_} =~ /\S/s;
        close $handle{$_};
    }
    Jifty->log->debug( $res{'status'} ) if $res{'status'};
    Jifty->log->warn( $res{'error'} )   if $res{'error'};
    Jifty->log->error( $res{'logger'} ) if $res{'logger'} && $?;
    if ( $err || $res{'exit_code'} ) {
        $res{'message'}
            = $err
            ? $err
            : "gpg exitted with error code " . ( $res{'exit_code'} >> 8 );
    }
    return %res;
}

1;
