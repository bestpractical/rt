#!!!PERL!!
# $Header$
# RT is (c) 1996-2001 Jesse Vincent (jesse@fsck.com);

use strict;
$ENV{'PATH'} = '/bin:/usr/bin';    # or whatever you need
$ENV{'CDPATH'} = '' if defined $ENV{'CDPATH'};
$ENV{'SHELL'} = '/bin/sh' if defined $ENV{'SHELL'};
$ENV{'ENV'} = '' if defined $ENV{'ENV'};
$ENV{'IFS'} = ''          if defined $ENV{'IFS'};


# We really don't want apache to try to eat all vm
# see http://perl.apache.org/guide/control.html#Preventing_mod_perl_Processes_Fr


package RT::Mason;
#use CGI qw(-private_tempfiles);   # pull in CGI with the private tempfiles
				  #option predefined
use HTML::Mason;  # brings in subpackages: Parser, Interp, etc.
use HTML::Mason::ApacheHandler;

use vars qw($VERSION %session $Nobody $SystemUser $cgi);

# List of modules that you want to use from components (see Admin
# manual for details)

#Clean up our umask...so that the session files aren't world readable, writable or executable
umask(0077);


  
$VERSION="!!RT_VERSION!!";

use lib "!!RT_LIB_PATH!!";
use lib "!!RT_ETC_PATH!!";

#This drags in  RT's config.pm
use config;
use Carp;

{  
    package HTML::Mason::Commands;
    use vars qw(%session);
    
    use RT; 
    use RT::Ticket;
    use RT::Tickets;
    use RT::Transaction;
    use RT::Transactions;
    use RT::User;
    use RT::Users;
    use RT::CurrentUser;
    use RT::Template;
    use RT::Templates;
    use RT::Queue;
    use RT::Queues;
    use RT::ScripAction;
    use RT::ScripActions;
    use RT::ScripCondition;
    use RT::ScripConditions;
    use RT::Scrip;
    use RT::Scrips;
    use RT::Group;
    use RT::Groups;
    use RT::Keyword;
    use RT::Keywords;
    use RT::ObjectKeyword;
    use RT::ObjectKeywords;
    use RT::KeywordSelect;
    use RT::KeywordSelects;
    use RT::GroupMember;
    use RT::GroupMembers;
    use RT::Watcher;
    use RT::Watchers;
    use RT::Handle;
    use RT::Interface::Web;    
    use MIME::Entity;
    use CGI::Cookie;
    use Date::Parse;
    use HTML::Entities;
    use Text::Wrapper;
 
    #TODO: make this use DBI
    use Apache::Session::File;
    use CGI::Fast;

    # set the page's content type.
    # In this case, just save it to a variable that we can pull later;
    my $ContentType;
    sub SetContentType {
	$ContentType = shift;
    }
    sub CGIObject {
	return $RT::Mason::cgi;
    }
}


my ($output);
my $parser = &RT::Interface::Web::NewParser(allow_globals => [%session]);

my $interp = &RT::Interface::Web::NewInterp(parser=>$parser,
					    out_method => \$output);

# Die if WebSessionDir doesn't exist or we can't write to it

stat ($RT::MasonSessionDir);
die "Can't read and write $RT::MasonSessionDir"
  unless (( -d _ ) and ( -r _ ) and ( -w _ ));


RT::Init();

# Response loop
while ($RT::Mason::cgi = new CGI::Fast) {
    
    $HTML::Mason::Commands::ContentType = 'text/html';
        
    # This routine comes from ApacheHandler.pm:
    my (%args, $cookie);
    foreach my $key ( $cgi->param ) {
	foreach my $value ( $cgi->param($key) ) {
	    if (exists($args{$key})) {
		if (ref($args{$key})) {
		    $args{$key} = [@{$args{$key}}, $value];
		} else {
		    $args{$key} = [$args{$key}, $value];
		}
	    } else {
		$args{$key} = $value;
	    }

	}
	
    }
    

    my $comp = $ENV{'PATH_INFO'};
    
    if ($comp =~ /^(.*)$/) {  # untaint the path info. apache should
			      # never hand us a bogus path. 
			      # We should be more careful here.
	$comp = $1;
    }    
    
    if ($comp =~ /\/$/) {
	$comp .= "index.html";
    }	
    
    #This is all largely cut and pasted from mason's session_handler.pl
    
    # {{{ Cookies
    my %cookies = fetch CGI::Cookie();
    
    eval {
	my $session_id = undef;

	#Get the session id and untaint it
	if ($cookies{'AF_SID'} && $cookies{'AF_SID'}->value() =~ /^(.*)$/) {
		$session_id = $1;
	}
 
	tie %HTML::Mason::Commands::session, 'Apache::Session::File',
	  	$session_id, 
	    { Directory => $RT::MasonSessionDir,
	      LockDirectory => $RT::MasonSessionDir,
	    }	;
    };
    
    if ( $@ ) {
	# If the session is invalid, create a new session.
	if ( $@ =~ m#^Object does not exist in the data store# ) {
	     tie %HTML::Mason::Commands::session, 'Apache::Session::File', undef,
	     { Directory => $RT::MasonSessionDir,
	       LockDirectory => $RT::MasonSessionDir,
	     };
	     undef $cookies{'AF_SID'};
	}
	  else {
	      die "$@ \nProbably means that RT Couldn't write to session directory '$RT::MasonSessionDir'. Check that this directory's permissions are correct.";
	  }
    }
    
    if ( !$cookies{'AF_SID'} ) {
	$cookie = new CGI::Cookie
	  (-name=>'AF_SID', 
	   -value=>$HTML::Mason::Commands::session{_session_id}, 
	   -path => '/',);
	
    } else {
	$cookie = undef;
    }
    
    # }}}
    
    $output = '';
    eval {
	    my $status = $interp->exec($comp, %args);
    };
 
    if ($@) {
	$output = "<PRE>$@</PRE>";
    }
 
    print "Content-Type: $HTML::Mason::Commands::ContentType\r\n";
    print "Set-Cookie: $cookie\r\n" if ($cookie);
    print "\r\n";
    print $output;
    untie %HTML::Mason::Commands::session;
    
}
