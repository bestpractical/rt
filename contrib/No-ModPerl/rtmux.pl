#!/usr/bin/perl -w

# This is the version of rtmux.pl that I used locally for test purposes at
# 2000-05-23.  It might not be update.  Nag tobix if you want to see newer
# versions

# It really needs to be merged with the official rtmux.pl template,
# but I don't have the time.  Anyone else for it?

# Tobias Brox <tobix@fsck.com>

$ENV{'PATH'} = '/bin:/usr/bin';    # or whatever you need
$ENV{'CDPATH'} = '' if defined $ENV{'CDPATH'};
$ENV{'SHELL'} = '/bin/sh' if defined $ENV{'SHELL'};
$ENV{'ENV'} = '' if defined $ENV{'ENV'};
$ENV{'IFS'} = ''          if defined $ENV{'IFS'};

package RT;
use strict;
use vars qw ($VERSION $Handle $SystemUser);

$VERSION="2.devel";

#this is the RT path

use lib qw(/tmp/FunRT /tmp/DBIx /etc/rt /tmp/M /tmp/rt/contrib);
require "/etc/rt/config.pm";          

# For some strange reason, my perl version used to bark "used only once" warning
# at those variables (yes, I know there are other ways to handle this)

my @stupid=($RT::DatabaseHost,$RT::DatabaseName,$RT::DatabaseUser,
            $RT::DatabasePassword,$RT::DatabaseType);

use Carp;
use DBIx::Handle;

#TODO: need to identify the database user here....
$Handle = new DBIx::Handle;

$Handle->Connect(Host => $RT::DatabaseHost, 
		      Database => $RT::DatabaseName, 
		      User => $RT::DatabaseUser,
		      Password => $RT::DatabasePassword,
		      Driver => $RT::DatabaseType);

#Load up a user object for actions taken by RT itself
use RT::CurrentUser;
#TODO abstract out the ID of the RT SystemUser
$SystemUser = RT::CurrentUser->new(1);

my $program = $0; 
$program =~ s/(.*)\///;
#shift @ARGV;
if ($program eq 'rt') {
  # load rt-cli
  require rt::ui::cli::support;
   require rt::ui::cli::manipulate;

  &rt::ui::cli::manipulate::activate();
}
elsif ($program eq 'rtq') {
  # load rt-query

  require rt::ui::cli::query;
  &rt::ui::cli::query::activate();
  
}
elsif ($program eq 'rtadmin') {
  #load rt_admin
  require rt::support::utils;     
  require rt::ui::cli::support;
  require rt::ui::cli::admin;
  &rt::ui::cli::admin::activate();
}
elsif ($program eq 'rt-mailgate') {
  require RT::Interface::Email;
  &RT::Interface::Email::activate();
}

elsif ($program =~ 'webrt.(f?)cgi') {
    $RT::Logger->log(message=>'WebRT cgi getting up', level=>'info');
    require HTML::Mason;
    {
	package HTML::Mason::Commands;
	use vars qw(%session $r);
    }
    package HTML::Mason;
    use vars qw($VERSION);
    
    my $parser = new HTML::Mason::Parser;
    
    #TODO: Make this draw from the config file
    my $interp = new HTML::Mason::Interp (
					  allow_recursive_autohandlers=>1,
					  parser=>$parser,
					  comp_root=>'/home/web/docroot/WebRT/experimental', 
					  data_dir=>'/home/web/docroot/WebRT/experimental/data');
    chown ( [getpwnam('nobody')]->[2], [getgrnam('nobody')]->[2],
	    $interp->files_written );   # chown nobody
    
    require CGI::Fast;
    require CGI::Cookie;
    require Apache::Session;
    require CGI::ApacheWrapper;
    require ApacheSessionFile;
    while (my $q = new CGI::Fast) {
	$RT::Logger->log(message=>'Inbound WebRT cgi request', level=>'info');
	$HTML::Mason::Commands::r=CGI::ApacheWrapper->new($q);
	
      # This routine comes from ApacheHandler.pm:
      my (%args);
      foreach my $key ( $q->param ) {
	  foreach my $value ( $q->param($key) ) {
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
      my $comp = $ENV{'PATH_TRANSLATED'};
      my $root = $interp->comp_root or die "No component root set";
      $comp =~ s|//|/|g;
      $comp =~ s/^$root//  or die "Component outside comp_root";
  
      my %cookies = CGI::Cookie->fetch;
      $RT::Logger->log(level=>'debug', message=>(exists $cookies{'AF_SID'} ? "Cookie found: $cookies{'AF_SID'}" : "No cookie found :("));
      
      eval {
	  tie %HTML::Mason::Commands::session, 'ApacheSessionFile',
	  ( $cookies{'AF_SID'} ? $cookies{'AF_SID'}->value() : undef );
      };
      
      if ( $@ ) {
	  # If the session is invalid, create a new session.
	  $RT::Logger->log(level=>'debug', message=>"session tie failed: @_");
	  if ( $@ =~ m#^Object does not exist in the data store# ) {
	       tie %HTML::Mason::Commands::session, 'Apache::Session::File', undef;
	       undef $cookies{'AF_SID'};
	   }
      }
      
      if ( !$cookies{'AF_SID'} ) {
	  my $cookie = new CGI::Cookie(-name=>'AF_SID', 
				       -value=>$HTML::Mason::Commands::session{_session_id}, 
				       -path => '/',);
	  
	  $RT::Logger->log(level=>'debug', message=>"New session: $cookie");
	  print "Set-Cookie: $cookie\n";
	  
      } else {
	  $RT::Logger->log(level=>'debug', message=>(exists $HTML::Mason::Commands::session{CurrentUser} ? "Current user:". ($HTML::Mason::Commands::session{CurrentUser} ? $HTML::Mason::Commands::session{CurrentUser}->RealName : "User is undefined :(" ): "No user attached to this session"));
      }
      
      print "Content-type: text/html\n\n";

      $interp->exec($comp, %args);
  }
  $RT::Logger->log(message=>'WebRT cgi shutting down', level=>'info');
  untie %HTML::Mason::Commands::session;
}

else {
  print STDERR "RT Has been launched with an illegal launch program ($program)\n";
  exit(1);
}

$RT::Handle->Disconnect();


1;

