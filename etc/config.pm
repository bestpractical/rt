# $Header$	


# This is where RT's preferences are kept track of

# Most (if not all?) $RT:: global variables should be here.  I'd
# suggest putting session information in another Namespace (main:: or
# RT::main or maybe something like that).

package RT;
use Log::Dispatch;
use Log::Dispatch::File;
#use strict;

#use vars qw/%SitePolicy $dirmode $transactionmode $DatabasePassword $rtname $domain $host $DatabaseHost $DatabaseUser $RT::DatabaseName $DatabaseType $user_passwd_min $MailAlias $WebrtImagePath $web_auth_mechanism $web_auth_cookies_allow_no_path $DefaultLocale $LocalePath $Nobody $Logger/;

# Logging.  The default is to log anything except debugging
# information to a logfile.  Check the Log::Dispatch POD for
# information about how to get things by syslog, mail or anything
# else, get debugging info in the log, etc.

$Logger=Log::Dispatch->new;
$Logger->add(Log::Dispatch::File->new
	     ( name=>'rtlog',
	       min_level=>'info',
	       filename=>'!!RT_LOGFILE!!',
	       mode=>'append'
	      ));

# Different "tunable" configuration options should be in this hash:
%SitePolicy=
    (
     QueueListingCols => 
     # Here you can modify the list view.  Be aware that the web
     # interface might crash if TicketAttribute is wrongly set.
     # Consult the docs (if somebody is going to write them?) your
     # local RT hacker or eventually the rt-users / rt-devel
     # mailinglists
      [
       { Header     => 'Ticket Id',
	 TicketLink => 1,
	 TicketAttribute => 'Id'
	 },

       { Header => 'Queue',
	 TicketAttribute => 'Queue->QueueId'
	 },

       { Header => 'Status',
	 TicketAttribute => 'Status'
	 },

       { Header => 'Told',
	 TicketAttribute => 'ToldAsString'
	 },

       { Header => 'Age',
	 TicketAttribute => 'CreatedAsString'
	 },

       { Header => 'Last',
	 TicketAttribute => 'LastUpdatedAsString'
	 },

       # TODO: It would be nice with a link here to the Owner and all
       # other request owned by this Owner.
       { Header => 'Owner',
	 TicketAttribute => 'Owner->UserId'
       },

       # TODO: We need a link here to a page containing this
       # requestors activity (ticket listing) and notes/similar stored
       # about the requestor
       { Header => 'Requestor(s)',
	 TicketAttribute => 'RequestorsAsString'
	 },

       { Header     => 'Subject',
	 TicketAttribute => 'Subject'
	 }
      ]
     );

# these modes don't do much right now...i had to hard code them in because 
# perl ws being nasty about the leading 0  check RT_Content.pl for hacking
# (Those shouldn't be needed in 2.0?)
$dirmode=0750;
$transactionmode=0640;
umask(0027);	

# rt runs setuid to this user and group to keep its datafile private
# no users should be in the rt group
# if you change these, make sure to edit the makefile and
# to chown the rt directory structure
# (are those needed any more?)
#$rtuser="!!RTUSER!!";
#$rtgroup="!!RTGROUP!!";


# before doing a "make install" in /usr/local/rt/src you NEED to change the 
# password below and change the apropriate line in /usr/local/rt/etc/mysql.acl	
$DatabasePassword="!!DB_RT_PASS!!";


#name of RT installation
#rt will look for this string in the headers of incoming mail
#once you set it, you should NEVER change it.
# (if you do, users will have no end to problems with their old
#tickets getting new requests opened for them)

$rtname="!!RT_MAIL_TAG!!";  

# Domain name and hostname
$domain="!!RT_DOMAIN!!";
$host="!!RT_HOST!!";
 

# host is the fqdn of your Mysql server
# if it's on localhost, leave it blank for enhanced performance
$DatabaseHost="!!DB_HOST!!";

#The name of the database user (inside the database) 
$DatabaseUser="!!DB_RT_USER!!";
    



#$dbname is the name of the RT's database on the Mysql server 
$RT::DatabaseName="!!DB_DATABASE!!";

# $rt_db is the database driver beeing used - i.e. MySQL.
$DatabaseType="!!DB_TYPE!!";


# $passwd_min defines the minimum length for user passwords.
$user_passwd_min = "!!RT_USER_PASSWD_MIN!!";

#$MailAlias is a generic alias to send mail to for any request
#already in a queue because of the nature of RT, mail sent to any
#correspondence address will get put in the right place and mail sent
#to any comment address will also get sent to the right place.  The
#queue_dependent ones are only really important for assigning new
#requests to the correct queue

#This is the default address that will be listed in 
#From: and Reply-To: headers of mail tracked by RT

$MailAlias = "!!RT_MAIL_ALIAS!!";


#TODO: Mail::Internet might need some configuration.


# Define the directory name to be used for images in rt web
# documents.

$WebrtImagePath = "!!WEB_IMAGE_PATH!!";


# WEB_AUTH_MECHANISM defines what sort of authentication you'd like to use
# for the web ui.  Valid choices are: "cookies" and "external".  Cookies
# uses http cookies to keep track of authentication. External means that
# you will have configured your web server to prompt for the user's
# credentials and authenticate them before RT ever sees the request.

$web_auth_mechanism = "!!WEB_AUTH_MECHANISM!!";




# WEB_AUTH_COOKIES_ALLOW_NO_PATH allows RT users to check a box which sends
# their authentication cookies to any CGI on the server.  This could be a
# security hole. You'll _never_ want to enable it, unless you have clients
# with IE4.01sp1..which chokes unless this is enabled.

$web_auth_cookies_allow_no_path = "!!WEB_AUTH_COOKIES_ALLOW_NO_PATH!!";


#  This is the default locale used by RT when deciding what version of the strings
# to show you
$DefaultLocale = "!!DEFAULT_LOCALE!!";

# This is the directory that .po files live in.

$LocalePath = "!!LOCALE_PATH!!";

##### THINGS BELOW SHOULD ONLY BE MODIFIED BY REAL HACKERS! :)

$Nobody=2;
$SIG{__WARN__}=sub {$RT::Logger->log(level=>'warn',message=>$_[0])};
$SIG{__DIE__}= sub {$RT::Logger->log(level=>'crit',message=>$_[0])};


1;






