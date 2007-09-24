use RT::Bootstrap;
use base qw/Jifty::Bootstrap/;

sub run {
    my $self = shift;
    RT::connect_to_database();
        RT::InitLogging();
        RT::InitSystemObjects();
 
    RT::Handle->InsertInitialData();

}

1;
