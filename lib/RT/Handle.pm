#$Header$

package RT::Handle;

eval "use DBIx::SearchBuilder::Handle::$RT::DatabaseType;

\@ISA= qw(DBIx::SearchBuilder::Handle::$RT::DatabaseType);";

#TODO check for errors here.

=head2 Connect

Takes nothing. Calls SUPER::Connect with the needed args

=cut

sub Connect {
my $self=shift;
$self->SUPER::Connect(Host => $RT::DatabaseHost, 
			 Database => $RT::DatabaseName, 
			 User => $RT::DatabaseUser,
			 Password => $RT::DatabasePassword,
			 Driver => $RT::DatabaseType);
   
}
1;
