# $Header$	

package RT;

# {{{ Base Configuration

# $rtname the string that RT will look for in mail messages to
# figure out what ticket a new piece of mail belongs to

# Your domain name is recommended, so as not to pollute the namespace.
# once you start using a given tag, you should probably never change it. 
# (otherwise, mail for existing tickets won't get put in the right place

$rtname="example.com";  

# You should set this to your organization's DNS domain. For example,
# fsck.com or asylum.arkham.ma.us. It's used by the linking interface to 
# guarantee that ticket URIs are unique and easy to construct.

$Organization = "example.com";

# $user_passwd_min defines the minimum length for user passwords. Setting
# it to 0 disables this check
$MinimumPasswordLength = "5";

# $Timezone is used to convert times entered by users into GMT and back again
# It should be set to a timezone recognized by your local unix box.
$Timezone =  'US/Eastern'; 

# RootDir is the root of the RT installation
$LogDir = "!!RT_LOG_PATH!!";

# }}}

# {{{ Database Configuration

# Database driver beeing used - i.e. MySQL.
$DatabaseType="!!DB_TYPE!!";

# host is the domain name of your database server
# if it's on localhost, leave it blank for enhanced performance
$DatabaseHost="!!DB_HOST!!";

#The name of the database user (inside the database) 
$DatabaseUser="!!DB_RT_USER!!";

# Password the DatabaseUser should use to access the database
$DatabasePassword="!!DB_RT_PASS!!";


# The name of the RT's database on your database server
$DatabaseName="!!DB_DATABASE!!";

# }}}

# {{{ Incoming mail gateway configuration


# If $LoopsToRTOwner is defined, RT will send mail that it believes 
# might be a loop to $RT::OwnerEmail 

$LoopsToRTOwner = 1;

# If $StoreLoopss is defined, RT will record messages that it believes 
# to be part of mail loops.
# As it does this, it will try to be careful not to send mail to the 
# sender of these messages 

$StoreLoops = undef;


# $MaxAttachmentSize sets the maximum size (in bytes) of attachments stored
# in the database. 

# For mysql and oracle, we set this size at 10 megabytes.
# If you're running a postgres version earlier than 7.1, you will need
# to drop this to 8192. (8k)

$MaxAttachmentSize = 10000000;  

# $TruncateLongAttachments: if this is set to a non-undef value,
# RT will truncate attachments longer than MaxAttachmentLength. 

$TruncateLongAttachments = undef;


# $DropLongAttachments: if this is set to a non-undef value,
# RT will silently drop attachments longer than MaxAttachmentLength. 

$DropLongAttachments = undef;

# CanonicalizeAddress converts email addresses into canonical form.
# it takes one email address in and returns the proper canonical
# form. You can dump whatever your proper local config is in here

sub CanonicalizeAddress {
    my $email = shift;
    # Example: the following rule would treat all email
    # coming from a subdomain as coming from second level domain
    # foo.com
    #$email =~ s/\@(.*).foo.com/\@foo.com/;
    return ($email)
}

# }}}

# {{{ Outgoing mail configuration

#$MailAlias is a generic alias to send mail to for any request
#already in a queue.  

#RT is designed such that any mail which already has a ticket-id associated
#with it will get to the right place automatically.

#This is the default address that will be listed in 
#From: and Reply-To: headers of mail tracked by RT unless overridden
#by a queue specific address

$CorrespondAddress="RT::CorrespondAddress.not.set";

$CommentAddress="RT::CommentAddress.not.set";


#Sendmail Configuration

# $MailCommand defines which method RT will use to try to send mail
$MailCommand = 'sendmail', 

#$SendmailArguments defines what flags to pass to $Sendmail
# (assuming you picked 'sendmail' as the $MailCommand above)

#These options are good for most sendmail wrappers and workalikes
$SendmailArguments="-oi";

#These arguments are good for sendmail brand sendmail 8 and newer
#$SendmailArguments="-oi -ODeliveryMode=b -OErrorMode=m";

# }}}

# {{{ Logging

# Logging.  The default is to log anything except debugging
# information to a logfile.  Check the Log::Dispatch POD for
# information about how to get things by syslog, mail or anything
# else, get debugging info in the log, etc. 

#  It might generally make
# sense to send error and higher by email to some administrator. 
# If you do this, be careful that this email isn't sent to this RT instance.


#  Mail loops will generate a critical log message.

$LogToScreen = 'error';
$LogToFile = 'debug';
$LogToFileNamed = "$LogDir/rt.log.".$$.".".$<; #log to rt.log.<pid>.<user>



# Define the directory name to be used for images in rt web
# documents.

#If you're putting the web ui somewhere other than at / on a server
$WebPath = "";

#Scheme, server and port for constructing urls to webrt

$WebBaseURL = "http://RT::WebBaseURL.not.configured:80/";

$WebURL = $WebBaseURL . $WebPath. "/";


# $MasonComponentRoot is where your rt instance keeps its mason html files
# (this should be autoconfigured during 'make install' or 'make upgrade')

$MasonComponentRoot = "!!MASON_HTML_PATH!!";

# $MasonDataDir Where mason keeps its datafiles
# (this should be autoconfigured during 'make install' or 'make upgrade')

$MasonDataDir = "!!MASON_DATA_PATH!!";


#This is from tobias' prototype web search UI. it may stay and it may go.
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
       { Header     => 'Id',
	 TicketLink => 1,
	 TicketAttribute => 'Id'
	 },

      { Header     => 'Subject',
	 TicketAttribute => 'Subject'
	 },
       { Header => 'Requestor(s)',
	 TicketAttribute => 'RequestorsAsString'
	 },
       { Header => 'Status',
	 TicketAttribute => 'Status'
	 },


       { Header => 'Queue',
	 TicketAttribute => 'QueueObj->Name'
	 },



       { Header => 'Told',
	 TicketAttribute => 'LongSinceToldAsString'
	 },

       { Header => 'Age',
	 TicketAttribute => 'AgeAsString'
	 },

       { Header => 'Last',
	 TicketAttribute => 'LongSinceUpdateAsString'
	 },

       # TODO: It would be nice with a link here to the Owner and all
       # other request owned by this Owner.
       { Header => 'Owner',
	 TicketAttribute => 'OwnerObj->Name'
       },
   
 
       { Header     => 'Take',
	 TicketLink => 1,
	 Constant   => 'Take',
	 ExtraLinks => '&Action=Take'
	 },

      ]
     );

# }}}

# {{{ RT Linking Interface

# $TicketBaseURI is the Base path of the URI for local tickets

# You shouldn't need to touch this. it's used to link tickets both locally
# and remotely

$TicketBaseURI = "fsck.com-rt://$Organization/$rtname/ticket/";

# A hash table of conversion subs to be used for transforming RT Link
# URIs to URLs in the web interface.  If you want to use RT towards
# locally installed databases, this is the right place to configure it.

%URI2HTTP=
    (
      'http' => sub {return @_;},
      'https' => sub {return @_;},
      'ftp' => sub {return @_;},
     'fsck.com-rt' => sub {warn "stub!";},
     'mozilla.org-bugzilla' => sub {warn "stub!"},
     'fsck.com-kb' => sub {warn "stub!"}
     );


# A hash table of subs for fetching content from an URI
%ContentFromURI=   
    (
     'fsck.com-rt' => sub {warn "stub!";},
     'mozilla.org-bugzilla' => sub {warn "stub!"},
     'fsck.com-kb' => sub {warn "stub!"}
     );

# }}}

# {{{  No User servicable parts inside 

############################################
############################################
############################################
#
#  Don't edit anything below this line unless you really know
#  what you're doing
#
#
############################################
############################################

# TODO: get this stuff out of the config file and into RT.pm

#Set up us the timezone
$ENV{'TZ'} = $Timezone; #TODO: Bogus hack to deal with Date::Manip whining

# Configure sendmail if we're using Entity->send('sendmail')
if ($MailCommand eq 'sendmail') {
    $MailParams = $SendmailArguments;
}



# }}}


1;
