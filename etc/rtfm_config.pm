# $Header$	

package RT::FM;

# Database driver beeing used - i.e. MySQL.
$DatabaseType="mysql";

# The domain name of your database server
# If you're running mysql and it's on localhost,
# leave it blank for enhanced performance
$DatabaseHost="localhost";

# The port that your database server is running on.  Ignored unless it's 
# a positive integer. It's usually safe to leave this blank
$DatabasePort = undef ;


#The name of the database user (inside the database) 
$DatabaseUser="root";

# Password the DatabaseUser should use to access the database
$DatabasePassword="";


# The name of the RT's database on your database server
$DatabaseName="rtfm";

# where RTFM's session files live
$MasonSessionDir = "/var/run/rtfm";

# Where mason stores its cruft
$MasonDataDir = "/var/run/rtfm/mason";

$WebPath = "/fm";

# Where mason looks for local components
$MasonLocalComponentRoot = "/home/jesse/projects/fm/local/html";

# Where mason looks for components
$MasonComponentRoot = "/home/jesse/projects/fm/html";

$LogToApacheLog = 'debug';

1;
