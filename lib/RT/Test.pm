
use strict;
use warnings;

package RT::Test;
use base qw/Jifty::Test/;
use Test::More;
use File::Temp;
my $config;
our ($existing_server, $port);
my $mailsent;

my @server;

sub import {
    my $class = shift;
    my %args = @_;
    $class->_setup_config(%args);
    $class->SUPER::import(@_);
    RT::InitSystemObjects();
}

sub _setup_config   {
    my $class = shift;
    my %args = (@_);

    require RT;
    RT->load_config();
    my $port = 999;
    $config = File::Temp->new;
    print $config qq{
set( \$WebPort , $port);
set( \$WebBaseURL , "http://localhost:\$WebPort");
set( \$LogToScreen , "debug");
};
    print $config $args{'config'} if $args{'config'};
    print $config "\n1;\n";
    $ENV{'RT_SITE_CONFIG'} = $config->filename;
    close $config;

    if (RT->Config->Get('DevelMode')) { require Module::Refresh; }

    # make it another function
    $mailsent = 0;
    my $mailfunc = sub { 
        my $Entity = shift;
        $mailsent++;
        return 1;
    };
    RT::Config->set( 'MailCommand' => $mailfunc);
}
our $server_url;
sub started_ok {
    require RT::Test::Web;
    if ( $existing_server ) {
        ok(1, "using existing server $existing_server");
        warn $existing_server;
        return ($existing_server, RT::Test::Web->new);
    }
        my $server = Jifty::Test->make_server;
             $RT::Test::server_url = $server->started_ok."/";

    return ($RT::Test::server_url, RT::Test::Web->new);
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

    my $obj = RT::Model::User->new( $RT::SystemUser );
    if ( $args{'Name'} ) {
        $obj->load_by_cols( Name => $args{'Name'} );
    } elsif ( $args{'EmailAddress'} ) {
        $obj->load_by_cols( EmailAddress => $args{'EmailAddress'} );
    } else {
        die "Name or EmailAddress is required";
    }
    if ( $obj->id ) {
        # cool
        $obj->set_Privileged( $args{'Privileged'} || 0 )
            if ($args{'Privileged'}||0) != ($obj->Privileged||0);
        $obj->set_Disabled( $args{'Disabled'} || 0 )
            if ($args{'Disabled'}||0) != ($obj->Disabled||0);
    } else {
        my ($val, $msg) = $obj->create( %args );
        die "$msg" unless $val;
    }

    # clean group membership
    {
        require RT::Model::GroupMemberCollection;
        my $gms = RT::Model::GroupMemberCollection->new( $RT::SystemUser );
        my $groups_alias = $gms->join(
            column1 => 'GroupId', table2 => 'Groups', column2 => 'id',
        );
        $gms->limit( alias => $groups_alias, column => 'Domain', value => 'UserDefined' );
        $gms->limit( column => 'MemberId', value => $obj->id );
        while ( my $group_member_record = $gms->next ) {
            $group_member_record->Delete;
        }
    }

    # add new user to groups
    foreach ( @$MemberOf ) {
        my $group = RT::Model::Group->new( RT::SystemUser() );
        $group->loadUserDefinedGroup( $_ );
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
    my $obj = RT::Model::Queue->new( $RT::SystemUser );
    if ( $args{'Name'} ) {
        $obj->load_by_cols( Name => $args{'Name'} );
    } else {
        die "Name is required";
    }
    unless ( $obj->id ) {
        my ($val, $msg) = $obj->create( %args );
        die "$msg" unless $val;
    } else {
        my @fields = qw(CorrespondAddress CommentAddress);
        foreach my $field ( @fields ) {
            next unless exists $args{ $field };
            next if $args{ $field } eq $obj->$field;
            
            no warnings 'uninitialized';
            my $method = 'set_'. $field;
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
    $acl->limit( column => 'RightName', operator => '!=', value => 'SuperUser' );

    my @res;
    while ( my $ace = $acl->next ) {
        my $obj = $ace->PrincipalObj->Object;
        if ( $obj->isa('RT::Model::Group') && $obj->Type eq 'UserEquiv' && $obj->Instance == $RT::Nobody->id ) {
            next;
        }

        my %tmp = ();
        foreach my $field( @fields ) {
            $tmp{ $field } = $ace->__value( $field );
        }
        push @res, \%tmp;
    }
    return @res;
}

sub restore_rights {
    my $self = shift;
    my @entries = @_;
    foreach my $entry ( @entries ) {
        my $ace = RT::Model::ACE->new( $RT::SystemUser );
        my ($status, $msg) = $ace->RT::Record::create( %$entry );
        unless ( $status ) {
            diag "couldn't create a record: $msg";
        }
    }
}

sub set_rights {
    my $self = shift;
    my @list = ref $_[0]? @_: @_? { @_ }: ();

    require RT::Model::ACECollection;
    my $acl = RT::Model::ACECollection->new( $RT::SystemUser );
    $acl->limit( column => 'RightName', operator => '!=', value => 'SuperUser' );
    while ( my $ace = $acl->next ) {
        my $obj = $ace->PrincipalObj->Object;
        if ( $obj->isa('RT::Model::Group') && $obj->Type eq 'UserEquiv' && $obj->Instance == $RT::Nobody->id ) {
            next;
        }
        $ace->delete;
    }

    foreach my $e (@list) {
        my $principal = delete $e->{'Principal'};
        unless ( ref $principal ) {
            if ( $principal =~ /^(everyone|(?:un)?privileged)$/i ) {
                $principal = RT::Model::Group->new( $RT::SystemUser );
                $principal->load_system_internal_group($1);
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
            warn "$msg" unless $status;
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

    Jifty::DBI::Record::Cachable->flush_cache;

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
    RT->Config->set( MailCommand => $catcher );
}

sub fetch_caught_mails {
    my $self = shift;
    return grep /\S/, split /%% split me! %%/,
        RT::Test->file_content( 't/mailbox', 'unlink' => 1 );
}

sub file_content {
    my $self = shift;
    my $path = shift;
    my %args = @_;

    $path = File::Spec->catfile( @$path ) if ref $path;

    diag "reading content of '$path'" if $ENV{'TEST_VERBOSE'};

    open my $fh, "<:raw", $path
        or die "couldn't open file '$path': $!";
    my $content = do { local $/; <$fh> };
    close $fh;

    unlink $path if $args{'unlink'};

    return $content;
}

1;
