# $Header$	

# This is where RT's base configuration is stored.

package RT;

#use vars qw/%SitePolicy $dirmode $transactionmode $DatabasePassword 
# $rtname $domain $host $DatabaseHost $DatabaseUser $RT::DatabaseName 
# $DatabaseType $user_passwd_min $MailAlias $WebrtImagePath 
# $web_auth_mechanism $web_auth_cookies_allow_no_path $DefaultLocale 
# $LocalePath $Nobody $Logger/;

# {{{ Logging
# Logging.  The default is to log anything except debugging
# information to a logfile.  Check the Log::Dispatch POD for
# information about how to get things by syslog, mail or anything
# else, get debugging info in the log, etc.  It might generally make
# sense to send error and higher by email to some administrator.  For
# heavens sake; be sure that the email goes directly to a mailbox, and
# not via RT :)  Mail loops will generate a critical log message.

# I'm running this stuff to SysLog myself, but that's a bit more
# complex - actually I had to fight a bit with Sys::Syslog and h2ph to
# get it working.  I really don't want RT to break on such a stupid
# thing as logging, so I'll leave logging to file as the default.

# I'm using a hacked version of Log::Dispatch::File here which trails
# the messages with a newline.  For newer versions of Log::Dispatch, a
# callback should be used.  I will eventually look more into this
# later.

use Log::Dispatch;
use Log::Dispatch::File;

$Logger=Log::Dispatch->new;
$Logger->add(Log::Dispatch::File->new
	     ( name=>'rtlog',
	       min_level=>'info',
	       filename=>'!!RT_LOGFILE!!',
	       mode=>'append'
	      ));

# }}}

# {{{ Options for the webui
%WebOptions=
    (
     # This is for putting in more user-actions at the Transaction
     # bar.  I will typically add "Enter bug in Bugzilla" here.:
     ExtraTransactionActions => sub { return ""; },

     # Here you can modify the list view.  Be aware that the web
     # interface might crash if TicketAttribute is wrongly set.
     # Consult the docs (if somebody is going to write them?) your
     # local RT hacker or eventually the rt-users / rt-devel
     # mailinglists
     QueueListingCols => 
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

# }}}

# {{{ RT Linking Interface
# A hash table of convertion subs to be used for transforming RT Link
# URIs to URLs in the web interface.  If you want to use RT towards
# locally installed databases, this is the right place to configure it.
# (TODO!)
my %URI2HTTP=
    (
     'fsck.com-rt' => sub {warn "stub!";},
     'mozilla.org-bugzilla' => sub {warn "stub!";},
     'fsck.com-kb' => sub {warn "stub!"}
     );
    

# }}}

# {{{ Base Configuration (everything below should be set by the Makefile)

# name of RT installation
# Use a smart name, it's not smart changing this, unless you know
# exactly what you're doing.
$rtname="!!RT_MAIL_TAG!!";  

# Domain name and hostname
$domain="!!RT_DOMAIN!!";
$host="!!RT_HOST!!";
 
# $passwd_min defines the minimum length for user passwords.
$user_passwd_min = "!!RT_USER_PASSWD_MIN!!";

# }}}

# {{{ Database Configuration

# before doing a "make install" in /usr/local/rt/src you NEED to change the 
# password below and change the apropriate line in /usr/local/rt/etc/mysql.acl	
$DatabasePassword="!!DB_RT_PASS!!";

# host is the fqdn of your Mysql server
# if it's on localhost, leave it blank for enhanced performance
$DatabaseHost="!!DB_HOST!!";

#The name of the database user (inside the database) 
$DatabaseUser="!!DB_RT_USER!!";
    

#$dbname is the name of the RT's database on the Mysql server 
$RT::DatabaseName="!!DB_DATABASE!!";

# $rt_db is the database driver beeing used - i.e. MySQL.
$DatabaseType="!!DB_TYPE!!";

# }}}

# {{{ Mail configuration

#$MailAlias is a generic alias to send mail to for any request
#already in a queue because of the nature of RT, mail sent to any
#correspondence address will get put in the right place and mail sent
#to any comment address will also get sent to the right place.  The
#queue_dependent ones are only really important for assigning new
#requests to the correct queue

#This is the default address that will be listed in 
#From: and Reply-To: headers of mail tracked by RT

$MailAlias = "!!RT_MAIL_ALIAS!!";
$CorrespondAddress=$MailAlias;
$CommentAddress="!!RT_COMMENT_MAIL_ALIAS!!";


#TODO: Mail::Internet might need some configuration.

# }}}

# {{{ WebRT Configuration
# Define the directory name to be used for images in rt web
# documents.

$WebrtImagePath = "!!WEB_IMAGE_PATH!!";
$WebPath = "!!WEB_PATH!!";
$WebURL = "http://$host\.$domain/$WebPath/";


# WEB_AUTH_MECHANISM defines what sort of authentication you'd like to use
# for the web ui.  Valid choices are: "cookies" and "external".  Cookies
# uses http cookies to keep track of authentication. External means that
# you will have configured your web server to prompt for the user's
# credentials and authenticate them before RT ever sees the request.

$web_auth_mechanism = "!!WEB_AUTH_MECHANISM!!";

# }}}

# {{{ Localization configuration

#  This is the default locale used by RT when deciding what version of the strings
# to show you
$DefaultLocale = "!!DEFAULT_LOCALE!!";

# This is the directory that .po files live in.

$LocalePath = "!!LOCALE_PATH!!";

# }}}

# {{{  No User servicable parts inside 
#

$Nobody=2;
$SIG{__WARN__} = sub {$RT::Logger->log(level=>'warning',message=>$_[0])};
$SIG{__DIE__}  = sub {
    die @_ if $^S;
    $RT::Logger->log(level=>'crit',message=>$_[0]); 
    exit(-1);
};

# }}}

1;






