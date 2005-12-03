package RT::Interface::Web::Session;

=head1 NAME

RT::Interface::Web::Session - RT web session class

=head1 SYNOPSYS


=head1 DESCRIPTION

RT session class and utilities.

CLASS METHODS can be used without creating object instances,
it's mainly utilities to clean unused session records.

Object is tied hash and can be used to access session data.

=head1 METHODS

=head2 CLASS METHODS

=head3 Class

Returns name of the class that is used as sessions storage.

=cut

sub Class {
    no warnings 'once';
    my $class = $RT::WebSessionClass || $backends{$RT::DatabaseType} || 'Apache::Session::File';
    eval "require $class";
    die $@ if $@;
    return $class;
}

=head3 Backends

Returns hash reference with names of the databases as keys and
sessions class names as values.

=cut

sub Backends {
    return {
        mysql => 'Apache::Session::MySQL',
        Pg    => 'Apache::Session::Postgres',
    };
}

=head3 Attributes

Returns hash reference with attributes that are used to create
new session objects.

=cut

sub Attributes {

    return $_[0]->Backends->{$RT::DatabaseType} ? {
            Handle     => $RT::Handle->dbh,
            LockHandle => $RT::Handle->dbh,
        } : {
            Directory     => $RT::MasonSessionDir,
            LockDirectory => $RT::MasonSessionDir,
        };
}

=head3 Ids

Returns array ref with list of the session IDs.

=cut

sub Ids
{
    my $self = shift || __PACKAGE__;
    my $attributes = $self->Attributes;
    if( $attributes->{Directory} ) {
        return _IdsDir( $attributes->{Directory} );
    } else {
        return _IdsDB( $RT::Handle->dbh );
    }
}

sub _IdsDir
{
    my ($self, $dir) = @_;
    require File::Find;
    my %file;
    File::Find::find(
        sub { return unless /^[a-zA-Z0-9]+$/;
              $file{$_} = (stat($_))[9];
            },
        $dir,
    );

    return [ sort { $file{$a} <=> $file{$b} } keys %file ];
}

sub _IdsDB
{
    my ($self, $dbh) = @_;
    my $ids = $dbh->selectcol_arrayref("SELECT id FROM sessions ORDER BY LastUpdated DESC");
    die "couldn't get ids: ". $dbh->errstr if $dbh->errstr;
    return $ids;
}

=head3 ClearOld

Takes seconds and deletes all sessions that are older.

=cut

sub ClearOld {
    my $class = shift || __PACKAGE__;
    my $attributes = $class->Attributes;
    if( $attributes->{Directory} ) {
        return $class->_CleariOldDir( $attributes->{Directory}, @_ );
    } else {
        return $class->_ClearOldDB( $RT::Handle->dbh, @_ );
    }
}

sub _ClearOldDB
{
    
    my ($self, $dbh, $older_than) = @_;
    my $rows;
    unless( int $older_than ) {
        $rows = $dbh->do("DELETE FROM sessions");
        die "couldn't delete sessions: ". $dbh->errstr unless defined $rows;
    } else {
        require POSIX;
        my $date = POSIX::strftime("%Y-%m-%d %H:%M", localtime( time - int $older_than ) );

        my $sth = $dbh->prepare("DELETE FROM sessions WHERE LastUpdate < ?");
        die "couldn't prepare query: ". $dbh->errstr unless $sth;
        $rows = $sth->execute( $date );
        die "couldn't execute query: ". $dbh->errstr unless defined $rows;
    }

    $RT::Logger->info("successfuly deleted $rows sessions");
    return;
}

sub _ClearOldDir
{
    my ($self, $dir, $older_than) = @_;

    require File::Spec if int $older_than;
    
    my $now = time;
    my $class = $self->Class;
    my $attrs = $self->Attributes;

    foreach my $id( @{ $self->Ids } ) {
        if( int $older_than ) {
            my $ctime = (stat(File::Spec->catfile($dir,$id)))[9];
            if( $ctime > $now - $older_than ) {
                $RT::Logger->debug("skipped session '$id', isn't old");
                next;
            }
        }

        my %session;
        local $@;
        eval { tie %session, $class, $id, $attrs };
        if( $@ ) {
            $RT::Logger->debug("skipped session '$id', couldn't load: $@");
            next;
        }
        tied(%session)->delete;
        $RT::Logger->info("successfuly deleted session '$id'");
    }
    return;
}

=head3 ClearByUser

Checks all sessions and if user has more then one session
then leave only the latest one.

=cut

sub ClearByUser {
    my $self = shift || __PACKAGE__;
    my $class = $self->Class;
    my $attrs = $self->Attributes;

    my %seen = ();
    foreach my $id( @{ $self->Ids } ) {
        my %session;
        local $@;
        eval { tie %session, $class, $id, $attrs };
        if( $@ ) {
            $RT::Logger->debug("skipped session '$id', couldn't load: $@");
            next;
        }
        if( $session{'CurrentUser'} && $session{'CurrentUser'}->id ) {
            unless( $seen{ $session{'CurrentUser'}->id }++ ) {
                $RT::Logger->debug("skipped session '$id', first user's session");
                next;
            }
        }
        tied(%session)->delete;
        $RT::Logger->info("successfuly deleted session '$id'");
    }
}

sub TIEHASH {
    my $self = shift;
    my $id = shift;

    my $class = $self->Class;
    my $attrs = $self->Attributes;

    my %session;

    local $@;
    eval { tie %session, $class, $id, $attrs };
    if( $@ ) {
        if ( $@ =~ /Object does not/i ) {
            tie %session, $class, undef, $attrs;
        } else {
            die loc("RT couldn't store your session.") . "\n"
              . loc("This may mean that that the directory '[_1]' isn't writable or a database table is missing or corrupt.",
                $RT::MasonSessionDir)
              . "\n\n"
              . $@;
        }
    }

    return tied %session;
}

1;
