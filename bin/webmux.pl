# $Header$
# RT is (c) 1996-2000 Jesse Vincent (jesse@fsck.com);

use strict;
$ENV{'PATH'} = '/bin:/usr/bin';    # or whatever you need
$ENV{'CDPATH'} = '' if defined $ENV{'CDPATH'};
$ENV{'SHELL'} = '/bin/sh' if defined $ENV{'SHELL'};
$ENV{'ENV'} = '' if defined $ENV{'ENV'};
$ENV{'IFS'} = ''          if defined $ENV{'IFS'};


# We really don't want apache to try to eat all vm
# see http://perl.apache.org/guide/control.html#Preventing_mod_perl_Processes_Fr


package RT::FM::Mason;

use CGI qw(-private_tempfiles); #bring this in before mason, to make sure we
				#set private_tempfiles
use HTML::Mason::ApacheHandler (args_method => 'CGI');
use HTML::Mason;  # brings in subpackages: Parser, Interp, etc.

use vars qw($VERSION %session $Nobody $SystemUser $r);

# List of modules that you want to use from components (see Admin
# manual for details)

#Clean up our umask...so that the session files aren't world readable, writable or executable
umask(0077);


	  
$VERSION="!!RT_VERSION!!";

use lib "/home/jesse/projects/fm/lib";
use lib "/home/jesse/projects/fm/etc";

#This drags in  RT's config.pm
use RT::FM::Config;
use RT::FM;
use Carp;

{  
	    package HTML::Mason::Commands;
	    use vars qw(%session);
	  
	    use RT::Framework::Interface::Web;    

	    use RT::FM::Article;
	    use RT::FM::Content;
	    use RT::FM::Delta;
	    use RT::FM::Transaction;
	    use RT::FM::ArticleCollection;
	    use RT::FM::ContentCollection;
	    use RT::FM::DeltaCollection;
	    use RT::FM::TransactionCollection;
	    use RT::FM::CustomFieldValue;
	    use RT::FM::CustomFieldValueCollection;
	    use RT::FM::CustomFieldObjectValue;
	    use RT::FM::CustomFieldObjectValueCollection;
	    use RT::FM::CustomField;
	    use RT::FM::CustomFieldCollection;
	     
	    use MIME::Entity;
	    use Apache::Cookie;
	    use Date::Parse;
	    use HTML::Entities;
	    
	    #TODO: make this use DBI
	    use Apache::Session::File;

	    # Set this page's content type to whatever we are called with
	    sub SetContentType {
		my $type = shift;
		$RT::FM::Mason::r->content_type($type);
	    }

	    sub CGIObject {
		$m->cgi_object();
	    }

	}

my $parser = &RT::Interface::Web::NewParser(allow_globals => [%session]);

my $interp = &RT::Interface::Web::NewInterp
  (
   comp_root => [ [local => $RT::FM::MasonLocalComponentRoot] , 
		  [standard => $RT::FM::MasonComponentRoot] ] , 
   data_dir => "$RT::FM::MasonDataDir",
   parser=>$parser);

my $ah = &RT::Interface::Web::NewApacheHandler($interp);


# Activate the following if running httpd as root (the normal case).
# Resets ownership of all files created by Mason at startup.
#
chown (Apache->server->uid, Apache->server->gid, 
		[$RT::FM::MasonSessionDir]);

chown (Apache->server->uid, Apache->server->gid, 
		$interp->files_written);

# Die if WebSessionDir doesn't exist or we can't write to it

stat ($RT::FM::MasonSessionDir);
die "Can't read and write $RT::FM::MasonSessionDir"
  unless (( -d _ ) and ( -r _ ) and ( -w _ ));


    RT::FM::Init();

sub handler {
    ($r) = @_;
    

 
    # We don't need to handle non-text items
    return -1 if defined($r->content_type) && $r->content_type !~ m|^text/|io;
    
    #This is all largely cut and pasted from mason's session_handler.pl
    
    my %cookies = Apache::Cookie::parse($r->header_in('Cookie'));
    
    eval { 
	tie %HTML::Mason::Commands::session, 'Apache::Session::File',
	  ( $cookies{'RTFM_SID'} ? $cookies{'RTFM_SID'}->value() : undef ), 
	    { Directory => $RT::FM::MasonSessionDir,
	      LockDirectory => $RT::FM::MasonSessionDir,
	    }	;
    };
    
    if ( $@ ) {
	# If the session is invalid, create a new session.
	if ( $@ =~ m#^Object does not exist in the data store# ) {
	     tie %HTML::Mason::Commands::session, 'Apache::Session::File', undef,
	     { Directory => $RT::FM::MasonSessionDir,
	       LockDirectory => $RT::FM::MasonSessionDir,
	     };
	     undef $cookies{'RTFM_SID'};
	}
	  else {
	     die "RT Couldn't write to session directory '$RT::FM::MasonSessionDir'. Check that this directory's permissions are correct.";
	  }
    }
    
    if ( !$cookies{'RTFM_SID'} ) {
	my $cookie = new Apache::Cookie
	  ($r,
	   -name=>'RTFM_SID', 
	   -value=>$HTML::Mason::Commands::session{_session_id}, 
	   -path => '/',);
	$cookie->bake;

    }
    my $status = $ah->handle_request($r);
    untie %HTML::Mason::Commands::session;
    
    return $status;
    
  }
1;

