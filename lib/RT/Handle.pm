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

Takes nothing. Calls SUPER::Connect with the needed args

=cut

sub Connect {
my $self=shift;

# Unless the database port is a positive integer, we really don't want to pass it.
$RT::DatabasePort = undef unless (defined $RT::DatabasePort && $RT::DatabasePort =~ /^(\d+)$/);

$self->SUPER::Connect(Host => $RT::DatabaseHost, 
			 Database => $RT::DatabaseName, 
			 User => $RT::DatabaseUser,
			 Password => $RT::DatabasePassword,
			 Port => $RT::DatabasePort,
			 Driver => $RT::DatabaseType);
   
}
1;
