package RT;
use RT::Handle;
use RT::CurrentUser;
use strict;

use vars qw($VERSION $SystemUser $Nobody $Handle);

$VERSION = '!!RT_VERSION!!';


sub Init {
    #Get a database connection
    $Handle = new RT::Handle($RT::DatabaseType);
    $Handle->Connect();
    
    
    #RT's system user is a genuine database user. its id lives here
    $SystemUser = new RT::CurrentUser();
    $SystemUser->LoadByName('RT_System');
    
    #RT's "nobody user" is a genuine database user. its ID lives here.
    $Nobody = new RT::CurrentUser();
    $Nobody->LoadByName('Nobody');
    
}


sub SystemUser {
    return($SystemUser);
}	

sub Nobody {
    return ($Nobody);
}

=head1 NAME

RT - Request Tracker

=head1 SYNOPSIS

=head1 BUGS

=head1 SEE ALSO

=cut

1;
