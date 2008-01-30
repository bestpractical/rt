
use warnings;
use strict;

package RT::Bootstrap;
use base qw/Jifty::Bootstrap/;

sub run {
    my $self = shift;
    $self->insert_initial_data();
    $self->insert_data( $RT::EtcPath . "/initialdata" );
}

=head1 METHODS


use File::Spec;

=head2 Database maintanance

=head2 create_database $DBH

Creates a new database. This method can be used as class method.

Takes DBI handle. Many database systems require special handle to
allow you to create a new database, so you have to use L<system_dsn>
method during connection.

Fetches type and name of the DB from the config.

=cut

sub create_database {
    my $self    = shift;
    my $dbh     = shift || die "No DBI handle provided";
    my $db_type = RT->config->get('DatabaseType');
    my $db_name = RT->config->get('Databasename');

    #print "Creating $db_type database $db_name.\n";
    if ( $db_type eq 'SQLite' ) {
        return;
    } elsif ( $db_type eq 'Pg' ) {

       # XXX: as we get external DBH we don't know if RaiseError or PrintError
       # are enabled, so we have to setup it here and restore them back
        $dbh->do("CREATE DATABASE $db_name WITH ENCODING='UNICODE'");
        if ($DBI::errstr) {
            $dbh->do("CREATE DATABASE $db_name") || die $DBI::errstr;
        }
    } elsif ( $db_type eq 'Informix' ) {
        local $ENV{'DB_LOCALE'} = 'en_us.utf8';
        $dbh->do("CREATE DATABASE $db_name WITH BUFFERED LOG");
    } else {
        $dbh->do("CREATE DATABASE $db_name") or die $DBI::errstr;
    }
}

=head3 drop_database $DBH [Force => 0]

Drops RT's database. This method can be used as class method.

Takes DBI handle as first argument. Many database systems require
special handle to allow you to create a new database, so you have
to use L<system_dsn> method during connection.

Takes as well optional named argument C<Force>, if it's true than
no questions would be asked.

Fetches type and name of the DB from the config.

=cut

sub drop_database {
    my $self = shift;
    my $dbh  = shift || die "No DBI handle provided";
    my %args = ( Force => 0, @_ );

    my $db_type = RT->config->get('DatabaseType');
    my $db_name = RT->config->get('Databasename');
    my $db_host = RT->config->get('DatabaseHost');

    if ( $db_type eq 'Oracle' ) {
        print <<END;

To delete the tables and sequences of the RT Oracle database by running
    \@etc/drop.Oracle
through SQLPlus.

END
        return;
    }
    unless ( $args{'Force'} ) {
        print <<END;

About to drop $db_type database $db_name on $db_host.
WARNING: This will erase all data in $db_name.

END
        return unless _yesno();

    }

    #print "Dropping $db_type database $db_name.\n";

    if ( $db_type eq 'SQLite' ) {
        my $path = $db_name;
        $path = "$RT::VarPath/$path" unless substr( $path, 0, 1 ) eq '/';
        unlink $path or warn $!;
        return;
    }
    $dbh->do( "DROP DATABASE " . $db_name ) or warn $DBI::errstr;
}

sub _yesno {

    #print "Proceed [y/N]:";
    my $x = scalar(<STDIN>);
    $x =~ /^y/i;
}

sub insert_acl { }

=head2 insert_schema

=cut

sub insert_schema {
    my $self      = shift;
    my $dbh       = shift || $self->dbh;
    my $base_path = ( shift || $RT::EtcPath );
    my $db_type   = RT->config->get('DatabaseType');

    my $file = get_version_file( $base_path . "/schema." . $db_type );
    unless ($file) {
        die "Couldn't find schema file in '$base_path' dir";
    }
    unless ( -f $file || -r $file ) {
        die "File '$file' doesn't exist or couldn't be read";
    }

    my (@schema);

    #print "Creating database schema.\n";

    open my $fh_schema, "<$file";

    my $has_local = 0;
    open my $fh_schema_local,
        "<" . get_version_file( $RT::LocalEtcPath . "/schema." . $db_type )
        and $has_local = 1;

    my $statement = "";
    foreach my $line ( <$fh_schema>, ( $_ = ';;' ),
        $has_local ? <$fh_schema_local> : () )
    {
        $line =~ s/\#.*//g;
        $line =~ s/--.*//g;
        $statement .= $line;
        if ( $line =~ /;(\s*)$/ ) {
            $statement =~ s/;(\s*)$//g;
            push @schema, $statement;
            $statement = "";
        }
    }
    close $fh_schema;
    close $fh_schema_local;

    local $SIG{__WARN__} = sub { };
    my $is_local = 0;    # local/etc/schema needs to be nonfatal.
    $dbh->begin_work or die $dbh->errstr;
    foreach my $statement (@schema) {
        if ( $statement =~ /^\s*;$/ ) { $is_local = 1; next; }

     #        #print "Executing SQL:\n$statement\n" if defined $args{'debug'};
        my $sth = $dbh->prepare($statement) or die $dbh->errstr;
        unless ( $sth->execute or $is_local ) {
            die "Problem with statement:\n$statement\n" . $sth->errstr;
        }
    }
    $dbh->commit or die $dbh->errstr;

    #print "Done setting up database schema.\n";
}

=head1 get_version_file

Takes base name of the file as argument, scans for <base name>-<version> named
files and returns file name with closest version to the version of the RT DB.

=cut

sub get_version_file {
    my $base_name = shift;

    require File::Glob;
    my @files = File::Glob::bsd_glob("$base_name*");
    return '' unless @files;

    my %version = map { $_ =~ /\.\w+-([-\w\.]+)$/; ( $1 || 0 ) => $_ } @files;
    my $db_version = Jifty->handle->database_version;

    #print "Server version $db_version\n";
    my $version;
    foreach ( reverse sort cmp_version keys %version ) {
        if ( cmp_version( $db_version, $_ ) >= 0 ) {
            $version = $_;
            last;
        }
    }

    return defined $version ? $version{$version} : undef;
}

sub cmp_version($$) {
    my ( $a, $b ) = (@_);
    my @a = split /[^0-9]+/, $a;
    my @b = split /[^0-9]+/, $b;
    for ( my $i = 0; $i < @a; $i++ ) {
        return 1 unless defined $b[$i];
        return $a[$i] <=> $b[$i] if $a[$i] <=> $b[$i];
    }
    return 0 if @a == @b;
    return -1;
}

=head2 insert_initial_data

=cut

sub insert_initial_data {
    my $self    = shift;
    my $db_type = RT->config->get('DatabaseType');

    #Put together a current user object so we can create a User object
    require RT::CurrentUser;
    my $bootstrap_user = RT::CurrentUser->new( _bootstrap => 1 );

    #print "Checking for existing system user...";
    my $test_user = RT::Model::User->new( current_user => $bootstrap_user );
    $test_user->load('RT_System');
    if ( $test_user->id ) {

        #print "found!\n\nYou appear to have a functional RT database.\n"
        #. "Exiting, so as not to clobber your existing data.\n";

    } else {

        #print "not found.  This appears to be a new installation.\n";
    }

    #print "Creating system user...";
    my $RT_System = RT::Model::User->new( current_user => $bootstrap_user );

    my ( $val, $msg ) = $RT_System->_bootstrap_create(
        name      => 'RT_System',
        real_name => 'The RT System itself',
        comments  => 'Do not delete or modify this user. '
            . 'It is integral to RT\'s internal database structures',
    );

    unless ($val) {

        #print "$msg\n";
        exit(-1);
    }
    Jifty::DBI::Record::Cachable->flush_cache;

    #print "done.\n";

    #print "Creating system user's ACL...";

    my $current_user = RT::CurrentUser->new( name => 'RT_System' );
    unless ( $current_user->id ) {

        #print "Couldn't load system user\n";
        exit(-1);
    }

    my $superuser_ace = RT::Model::ACE->new( current_user => $current_user );
    $superuser_ace->_bootstrap_create(
        principal_id   => acl_equiv_group_id( $current_user->id ),
        principal_type => 'Group',
        right_name     => 'SuperUser',
        object_type    => 'RT::System',
        object_id      => 1,
    );

    #print "done.\n";
}

=head insert_data

=cut

# load some sort of data into the database
sub insert_data {
    my $self     = shift;
    my $datafile = shift;

 # Slurp in stuff to insert from the datafile. Possible things to go in here:-
    our (
        @Groups,       @Users,           @ACL,       @Queues,
        @scrip_actions, @scrip_conditions, @Templates, @CustomFields,
        @Scrips,       @Attributes,      @Initial,   @Final
    );
    local (
        @Groups,       @Users,           @ACL,       @Queues,
        @scrip_actions, @scrip_conditions, @Templates, @CustomFields,
        @Scrips,       @Attributes,      @Initial,   @Final
    );

    require $datafile
        || die "Couldn't find initial data for import\n" . $@;

    if (@Initial) {

        #print "Running initial actions...\n";
        # Don't trap errors here, as they *should* be fatal
        $_->() for @Initial;
    }
    if (@Groups) {

        #print "Creating groups...";
        #print "My systemuser is ".RT->system_user ."\n";
        $RT::system_user = RT::CurrentUser->new( name => 'RT_System' );
        foreach my $item (@Groups) {
            my $new_entry
                = RT::Model::Group->new( current_user => RT->system_user );
            my $member_of = delete $item->{'member_of'};
            my ( $return, $msg ) = $new_entry->_create(%$item);

            #print "(Error: $msg)" unless $return;
            #print $return. ".";
            if ($member_of) {
                $member_of = [$member_of] unless ref $member_of eq 'ARRAY';
                foreach (@$member_of) {
                    my $parent = RT::Model::Group->new(
                        current_user => RT->system_user );
                    if ( ref $_ eq 'HASH' ) {
                        $parent->load_by_cols(%$_);
                    } elsif ( !ref $_ ) {
                        $parent->load_user_defined_group($_);
                    } else {
                        print "(Error: wrong format of member_of field."
                            . " Should be name of user defined group or"
                            . " hash reference with 'column => value' pairs."
                            . " Use array reference to add to multiple groups)";
                        next;
                    }
                    unless ( $parent->id ) {
                        print "(Error: couldn't load group to add member)";
                        next;
                    }
                    my ( $return, $msg )
                        = $parent->add_member( $new_entry->id );

                    #print "(Error: $msg)" unless ($return);
                    #print $return. ".";
                }
            }
        }

        #print "done.\n";
    }
    if (@Users) {

        #print "Creating users...";
        foreach my $item (@Users) {
            my $new_entry
                = RT::Model::User->new( current_user => RT->system_user );
            my ( $return, $msg ) = $new_entry->create(%$item);
            print "(Error: $msg)" unless $return;

            #print $return. ".";
        }

        #print "done.\n";
    }
    if (@Queues) {

        #print "Creating queues...";
        for my $item (@Queues) {
            my $new_entry
                = RT::Model::Queue->new( current_user => RT->system_user );
            my ( $return, $msg ) = $new_entry->create(%$item);

            #print "(Error: $msg)" unless $return;
            #print $return. ".";
        }

        #print "done.\n";
    }
    if (@CustomFields) {

        #print "Creating custom fields...";
        for my $item (@CustomFields) {
            my $new_entry = RT::Model::CustomField->new(
                current_user => RT->system_user );
            my $values = delete $item->{'Values'};

            my @queues;

            # if ref then it's list of queues, so we do things ourself
            if ( exists $item->{'queue'} && ref $item->{'queue'} ) {
                $item->{'lookup_type'} = 'RT::Model::Queue-RT::Model::Ticket';
                @queues = @{ delete $item->{'queue'} };
            }

            my ( $return, $msg ) = $new_entry->create(%$item);
            unless ($return) {

                #print "(Error: $msg)\n";
                next;
            }

            foreach my $value ( @{$values} ) {
                my ( $return, $msg ) = $new_entry->add_value(%$value);

                #print "(Error: $msg)\n" unless $return;
            }

            # apply by default
            if ( !@queues && !exists $item->{'queue'} && $item->{lookup_type} )
            {
                my $ocf = RT::Model::ObjectCustomField->new(
                    current_user => RT->system_user );
                $ocf->create( custom_field => $new_entry->id );
            }

            for my $q (@queues) {
                my $q_obj = RT::Model::Queue->new(
                    current_user => RT->system_user );
                $q_obj->load($q);
                unless ( $q_obj->id ) {

                    #print "(Error: Could not find queue " . $q . ")\n";
                    next;
                }
                my $OCF = RT::Model::ObjectCustomField->new(
                    current_user => RT->system_user );
                ( $return, $msg ) = $OCF->create(
                    custom_field => $new_entry->id,
                    object_id   => $q_obj->id,
                );

                #print "(Error: $msg)\n" unless $return and $OCF->id;
            }

            #print $new_entry->id. ".";
        }

        #print "done.\n";
    }
    if (@ACL) {
        #print "Creating ACL...";
        for my $item (@ACL) {
            my ( $princ, $object );

            # Global rights or queue rights?
            if ( $item->{'CF'} ) {
                $object = RT::Model::CustomField->new(
                    current_user => RT->system_user );
                my @columns = ( name => $item->{'CF'} );
                push @columns, queue => $item->{'queue'}
                    if $item->{'queue'} and not ref $item->{'queue'};
                $object->load_by_name(@columns);
            } elsif ( $item->{'queue'} ) {
                $object = RT::Model::Queue->new(
                    current_user => RT->system_user );
                $object->load( $item->{'queue'} );
            } else {
                $object = RT->system;
            }

        #print "Couldn't load object" and next unless $object and $object->id;

            # Group rights or user rights?
            if ( $item->{'GroupDomain'} ) {
                $princ = RT::Model::Group->new(
                    current_user => RT->system_user );
                if ( $item->{'GroupDomain'} eq 'UserDefined' ) {
                    $princ->load_user_defined_group( $item->{'group_id'} );
                } elsif ( $item->{'GroupDomain'} eq 'SystemInternal' ) {
                    $princ->load_system_internal_group(
                        $item->{'GroupType'} );
                } elsif ( $item->{'GroupDomain'} eq 'RT::System-Role' ) {
                    $princ->load_system_role_group( $item->{'GroupType'} );
                } elsif ( $item->{'GroupDomain'} eq 'RT::Model::Queue-Role'
                    && $item->{'queue'} )
                {
                    $princ->load_queue_role_group(
                        type  => $item->{'GroupType'},
                        queue => $object->id
                    );
                } else {
                    $princ->load( $item->{'group_id'} );
                }
            } else {
                $princ
                    = RT::Model::User->new( current_user => RT->system_user );
                $princ->load( $item->{'user_id'} );
            }

            unless ( $princ->id ) {
                Carp::confess(
                    "Could not create principal! - " . YAML::Dump($item) );
            }

            # Grant it
            my ( $return, $msg ) = $princ->principal_object->grant_right(
                right  => $item->{'right'},
                object => $object
            );

            if ($return) {

                #warn $return. ".";
            } else {

                #warn $msg . ".";

            }

        }

        #print "done.\n";
    }

    if (@scrip_actions) {

        #print "Creating scrip_actions...";

        for my $item (@scrip_actions) {
            my $new_entry = RT::Model::ScripAction->new(
                current_user => RT->system_user );
            my $return = $new_entry->create(%$item);

            #print $return. ".";
        }

        #print "done.\n";
    }

    if (@scrip_conditions) {

        #print "Creating scrip_conditions...";

        for my $item (@scrip_conditions) {
            my $new_entry = RT::Model::ScripCondition->new(
                current_user => RT->system_user );
            my $return = $new_entry->create(%$item);

            #print $return. ".";
        }

        #print "done.\n";
    }

    if (@Templates) {

        #print "Creating templates...";

        for my $item (@Templates) {
            my $new_entry
                = RT::Model::Template->new( current_user => RT->system_user );
            my $return = $new_entry->create(%$item);

            #print $return. ".";
        }

        #print "done.\n";
    }
    if (@Scrips) {

        #print "Creating scrips...";

        for my $item (@Scrips) {
            my $new_entry
                = RT::Model::Scrip->new( current_user => RT->system_user );

            my @queues
                = ref $item->{'queue'} eq 'ARRAY'
                ? @{ $item->{'queue'} }
                : $item->{'queue'} || 0;
            push @queues, 0 unless @queues;    # add global queue at least

            foreach my $q (@queues) {
                my ( $return, $msg )
                    = $new_entry->create( %$item, queue => $q );
                if ($return) {

                    #print $return. ".";
                } else {

                    #print "(Error: $msg)\n";
                }
            }
        }

        #print "done.\n";
    }

    if (@Attributes) {

        #print "Creating predefined searches...";

        use RT::System;
        my $sys = RT::System->new( current_user => RT->system_user );
        for my $item (@Attributes) {
            my $obj
                = delete $item->{object};  # XXX: make this something loadable
            $obj ||= $sys;
            my ( $return, $msg ) = $obj->add_attribute(%$item);
            if ($return) {

                #print $return. ".";
            } else {

                #print "(Error: $msg)\n";
            }
        }

        #print "done.\n";
    }
    if (@Final) {

        #print "Running final actions...\n";
        for (@Final) {
            eval { $_->(); };
            print "(Error: $@)\n" if $@;
        }
    }

    my $db_type = RT->config->get('DatabaseType');

    #print "Done setting up database content.\n";
}

=head2 acl_equiv_group_id

Given a userid, return that user's acl equivalence group

=cut

sub acl_equiv_group_id {
    my $username = shift;
    my $user = RT::Model::User->new( current_user => RT->system_user );
    $user->load($username);
    my $equiv_group
        = RT::Model::Group->new( current_user => RT->system_user );
    $equiv_group->load_acl_equivalence_group($user);
    return ( $equiv_group->id );
}

1;
