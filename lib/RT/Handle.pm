#$Header$

=head1 NAME

  RT::Handle - RT's database handle

=head1 SYNOPSIS

  use RT::Handle;

=head1 DESCRIPTION

=begin testing

ok(require RT::Handle);

=end testing

=head1 METHODS

=cut

package RT::Handle;

eval "use DBIx::SearchBuilder::Handle::$RT::DatabaseType;
\@ISA= qw(DBIx::SearchBuilder::Handle::$RT::DatabaseType);";
#TODO check for errors here.

=head2 Connect

Connects to RT's database handle.
Takes nothing. Calls SUPER::Connect with the needed args

=cut

sub Connect {
my $self=shift;

# Unless the database port is a positive integer, we really don't want to pass it.

$self->SUPER::Connect(
			 User => $RT::DatabaseUser,
			 Password => $RT::DatabasePassword,
			);
   
}

=item BuildDSN

Build the DSN for the RT database. doesn't take any parameters, draws all that
from the config file.

=cut


sub BuildDSN {
    my $self = shift;
$RT::DatabasePort = undef unless (defined $RT::DatabasePort && $RT::DatabasePort =~ /^(\d+)$/);
$RT::DatabaseHost = undef unless (defined $RT::DatabaseHost && $RT::DatabaseHost ne '');

    $self->SUPER::BuildDSN(Host => $RT::DatabaseHost, 
			 Database => $RT::DatabaseName, 
			 Port => $RT::DatabasePort,
			 Driver => $RT::DatabaseType,
			 RequireSSL => $RT::DatabaseRequireSSL,
			);
   

}

1;
