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
use HTML::Mason;  # brings in subpackages: Parser, Interp, etc.
use HTML::Mason::ApacheHandler;

use vars qw($VERSION %session $Nobody $SystemUser);

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
    
    #TODO: make this use DBI
    use Apache::Session::File;
    use FCGI;
}


my ($output);
my $parser = &RT::Interface::Web::NewParser(allow_globals => [%session]);

my $interp = &RT::Interface::Web::NewInterp(parser=>$parser,
					    out_method => \$output);

# Activate the following if running httpd as root (the normal case).
# Resets ownership of all files created by Mason at startup.
#
#chown (Apache->server->uid, Apache->server->gid, 
#		$RT::MasonSessionDir);

#chown (Apache->server->uid, Apache->server->gid, 
#		$interp->files_written);

# Die if WebSessionDir doesn't exist or we can't write to it

stat ($RT::MasonSessionDir);
die "Can't read and write $RT::MasonSessionDir"
  unless (( -d _ ) and ( -r _ ) and ( -w _ ));


# Response loop

while (FCGI::accept >= 0) {
    #undef(%in);
    
        
    RT::Init();
        
    require CGI;
    my $cgi = new CGI;
 
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
    

 #   foreach my $key (keys %ENV) {
#	print STDERR "Env: $key $ENV{$key}\n";
#    }
    my $comp = $ENV{'PATH_INFO'};
    
    
    if ($comp =~ /\/$/) {
	$comp .= "index.html";
    }	
    
    #This is all largely cut and pasted from mason's session_handler.pl
    
    # {{{ Cookies
    my %cookies = fetch CGI::Cookie();
    
    eval { 
	tie %HTML::Mason::Commands::session, 'Apache::Session::File',
	  ( $cookies{'AF_SID'} ? $cookies{'AF_SID'}->value() : undef ), 
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
	      die "RT Couldn't write to session directory '$RT::MasonSessionDir'. Check that this directory's permissions are correct.";
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
    my $status = $interp->exec($comp, %args);
    
    my $content_type =  "text/html";
    
    print "Set-Cookie: $cookie\n\r" if ($cookie);
    print "Content-Type: $content_type\n\r";
    print "\n\r";
    print $output;
    untie %HTML::Mason::Commands::session;
    
}
