package RT::FM;
use strict;

use vars qw($VERSION $SystemUser $Nobody $Handle $Logger);



$VERSION = '!!RT_VERSION!!';


sub Init {
    my $configfile = shift;
    
    # read the config file
    require "$configfile";

    #Get a database connection
    # We require rather than use, because we need to delay this until after
    # we read the config file
    require RT::FM::Handle;
    $Handle = new RT::FM::Handle($RT::FM::DatabaseType);
    $Handle->Connect();
    
    
    #RT's system user is a genuine database user. its id lives here
    $SystemUser = new RT::FM::CurrentUser();
    $SystemUser->LoadByName('RT_System');
    
    #RT's "nobody user" is a genuine database user. its ID lives here.
    $Nobody = new RT::FM::CurrentUser();
    $Nobody->LoadByName('Nobody');
   
    InitLogging(); 
}

=head2 InitLogging

Create the RT::FM::Logger object. 

=cut
sub InitLogging {

    # We have to set the record seperator ($, man perlvar)
    # or Log::Dispatch starts getting
    # really pissy, as some other module we use unsets it.

    $, = '';
    use Log::Dispatch 1.6;
    use Log::Dispatch::File;
    use Log::Dispatch::Screen;

    $Logger=Log::Dispatch->new();
    
    if ($RT::FM::LogToScreen) {
	$Logger->add(Log::Dispatch::Screen->new
		     ( name => 'screen',
		       min_level => $RT::FM::LogToScreen,
		       stderr => 1
		     ));
    }
# {{{ Signal handlers

## This is the default handling of warnings and die'ings in the code
## (including other used modules - maybe except for errors catched by
## Mason).  It will log all problems through the standard logging
## mechanism (see above).

$SIG{__WARN__} = sub {$RT::FM::Logger->warning($_[0])};

#When we call die, trap it and log->crit with the value of the die.

$SIG{__DIE__}  = sub {
    unless ($^S || !defined $^S ) {
        $RT::FM::Logger->crit("$_[0]");
        exit(-1);
    }
    else {
        #Get out of here if we're in an eval
        die $_[0];
    }
};

# }}}

}

# }}}


sub SystemUser {
    return($SystemUser);
}	

sub Nobody {
    return ($Nobody);
}


=head2 DropSetGIDPermissions

Drops setgid permissions.

=cut

sub DropSetGIDPermissions {
    # Now that we got the config read in, we have the database 
    # password and don't need to be setgid
    # make the effective group the real group
    $) = $(;
}


=head1 NAME

RT - Request Tracker

=head1 SYNOPSIS

=head1 BUGS

=head1 SEE ALSO

=cut

1;
