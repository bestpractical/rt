#!!!PERL!! -w
# $Header$
# RT is (c) 1996-2000 Jesse Vincent (jesse@fsck.com);

use strict;
$ENV{'PATH'} = '/bin:/usr/bin';    # or whatever you need
$ENV{'CDPATH'} = '' if defined $ENV{'CDPATH'};
$ENV{'SHELL'} = '/bin/sh' if defined $ENV{'SHELL'};
$ENV{'ENV'} = '' if defined $ENV{'ENV'};
$ENV{'IFS'} = ''          if defined $ENV{'IFS'};

package RT::Mason;
use HTML::Mason;  # brings in subpackages: Parser, Interp, etc.
use vars qw($VERSION %session $Nobody $SystemUser);

# List of modules that you want to use from components (see Admin
# manual for details)

  
$VERSION="1.3.16";

use lib "/opt/rt-1.3/lib";
use lib "/opt/rt-1.3/etc";

#This drags in  RT's config.pm
use config;
use Carp;
use DBIx::SearchBuilder::Handle;

{  
    package HTML::Mason::Commands;
    use vars qw(%session);
   
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
    use RT::Interface::Web;    
    use MIME::Entity;
    use CGI::Cookie;
    use Date::Parse;
    use HTML::Entities;
    use Apache::Session::File;
    use FCGI;
    
}

#TODO: need to identify the database user here....


my $parser = &RT::Interface::Web::NewParser();

my $interp = &RT::Interface::Web::NewInterp($parser);

# Response loop

while (FCGI::accept >= 0) {
    #undef(%in);
    my $url="index.html";
    print "Content-type: text/html\r\n\r\n";

  require CGI;
  my $q = new CGI;

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

  my $key;
  foreach $key (keys %ENV) {
  	print STDERR "Env: $key $ENV{$key}\n";
	}
  my $comp = $ENV{'PATH_INFO'};
  my $root = $interp->comp_root;

  $interp->exec("/".$comp, %args);
}
