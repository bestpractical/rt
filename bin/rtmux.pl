#!/usr/bin/perl -w
#
# $Header$
# RT is (c) 1996-2000 Jesse Vincent (jesse@fsck.com);


$ENV{'PATH'} = '/bin:/usr/bin';    # or whatever you need
$ENV{'CDPATH'} = '' if defined $ENV{'CDPATH'};
$ENV{'SHELL'} = '/bin/sh' if defined $ENV{'SHELL'};
$ENV{'ENV'} = '' if defined $ENV{'ENV'};
$ENV{'IFS'} = ''          if defined $ENV{'IFS'};

package RT;
use strict;
use vars qw($VERSION $Handle $Nobody $SystemUser);

$VERSION="!!RT_VERSION!!";

use lib "!!RT_LIB_PATH!!";
use lib "!!RT_ETC_PATH!!";

#This drags in  RT's config.pm
use config;
use Carp;
use DBIx::SearchBuilder::Handle;


# {{{  Lets load up the Locale managment stuff
#TODO get a few files to try some translations
#use Locale::PGetText;

#Locale::PGetText::setLocaleDir("$RT::LocalePath");
#Locale::PGetText::setLanguage("$RT::DefaultLocale");

# }}}

#TODO: need to identify the database user here....
$Handle = new DBIx::SearchBuilder::Handle;

{
# I did get a stupid "Variable Used Only Once" message here.
# Well, this ought to fix it.
#no warnings;
$Handle->Connect(Host => $RT::DatabaseHost, 
		     Database => $RT::DatabaseName, 
		     User => $RT::DatabaseUser,
		     Password => $RT::DatabasePassword,
		     Driver => $RT::DatabaseType);
}


use RT::CurrentUser;
#RT's system user is a genuine database user. its id lives here

$SystemUser = new RT::CurrentUser(1);

#RT's "nobody user" is a genuine database user. its ID lives here.
$Nobody = new RT::CurrentUser(2);



my $program = $0; 

$program =~ s/(.*)\///;


if ($program eq '!!RT_ACTION_BIN!!') {
  # load rt-cli
  require rt::ui::cli::support;
  require rt::ui::cli::manipulate;
  
  &rt::ui::cli::manipulate::activate();
}
elsif ($program eq '!!RT_QUERY_BIN!!') {
  # load rt-query
  
  require rt::ui::cli::query;
  &rt::ui::cli::query::activate();
  
}

elsif ($program eq '!!RT_ADMIN_BIN!!') {
  #load rt_admin
  require rt::support::utils;     
  require rt::ui::cli::support;
  require rt::ui::cli::admin;
  &rt::ui::cli::admin::activate();
}

elsif ($program eq '!!RT_MAILGATE_BIN!!') {
  require RT::Interface::Email;
  &RT::Interface::Email::activate();
}

elsif ($program eq '!!RT_CGI_BIN!!') {
  die "This doesn't work - use the mod_perl version (webmux.pl) or mail tobix\@fsck.com for updates about the work on a CGI version";
  require HTML::Mason;
  package HTML::Mason;
  my $parser = new HTML::Mason::Parser;
  
  #TODO: Make this draw from the config file
  my $interp = new HTML::Mason::Interp (
					parser=>$parser,
					comp_root=>'!!WEBRT_HTML_PATH!!',
					data_dir=>'!!WEBRT_DATA_PATH!!');
  chown ( [getpwnam('nobody')]->[2], [getgrnam('nobody')]->[2],
	  $interp->files_written );   # chown nobody
  
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
  my $comp = $ENV{'PATH_TRANSLATED'};
  my $root = $interp->comp_root;
  $comp =~ s/^$root//  or die "Component outside comp_root";
  
  $interp->exec($comp, %args);
}

else {
  $RT::Logger->crit( "RT Has been launched with an illegal launch program ($program)");
  exit(1);
}

$RT::Handle->Disconnect();


1;

