#$Header$

package RT::Handle;
use DBIx::SearchBuilder::Handle;

@ISA= qw(DBIx::SearchBuilder::Handle);

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
