use lib "/opt/rt2/etc/";

use RT::Interface::CLI  qw(CleanEnv LoadConfig DBConnect 
			   GetCurrentUser GetMessageContent);

#Clean out all the nasties from the environment
CleanEnv();

#Load etc/config.pm and drop privs
LoadConfig();


use RT;
RT::Init;
