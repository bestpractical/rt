#$Header$

=head1 NAME

  RT::FM::Handle - RT's database handle

=head1 SYNOPSIS

  use RT::FM::Handle;

=head1 DESCRIPTION


=head1 METHODS

=cut

package RT::FM::Handle;

eval "use DBIx::SearchBuilder::Handle::$RT::FM::DatabaseType;

\@ISA= qw(DBIx::SearchBuilder::Handle::$RT::FM::DatabaseType);";

#TODO check for errors here.

=head2 Connect

Takes nothing. Calls SUPER::Connect with the needed args

=cut

sub Connect {
my $self=shift;

# Unless the database port is a positive integer, we really don't want to pass it.
$RT::FM::DatabasePort = undef unless (defined $RT::FM::DatabasePort && $RT::FM::DatabasePort =~ /^(\d+)$/);

$self->SUPER::Connect(Host => $RT::FM::DatabaseHost, 
			 Database => $RT::FM::DatabaseName, 
			 User => $RT::FM::DatabaseUser,
			 Password => $RT::FM::DatabasePassword,
			 Port => $RT::FM::DatabasePort,
			 Driver => $RT::FM::DatabaseType);
   
}

=item BeginTransaction

Turn off autocommit and start a transaction

=cut

sub BeginTransaction {
	my $self = shift;
	$self->AutoCommit(0);

}

=item CommitTransaction

Commit the current transaction and then turn autocommit back on

=cut

sub CommitTransaction {
	my $self = shift;
	$self->dbh->commit();	
	$self->AutoCommit(1);
	
}


=item RollbackTransaction

Roll the current transaction back and then turn autocommit back on

=cut

sub RollbackTransaction {
	my $self = shift;
	$self->dbh->rollback();	
	$self->AutoCommit(1);
}

1;
