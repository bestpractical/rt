# $Header$	


# This is where RT's preferences are kept track of

package RT;

# Different "tunable" configuration options should be in this hash:
%SitePolicy=();

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

# Hackers only:

$Nobody=2;

1;






