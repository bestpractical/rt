# $Header$
# RT is (c) 1996-2001 Jesse Vincent <jesse@fsck.com>

package RT::Interface::Email;

use strict;


BEGIN {
    use Exporter ();
    use vars qw ($VERSION  @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
    
    # set the version for version checking
    $VERSION = do { my @r = (q$Revision$ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker
    
    @ISA         = qw(Exporter);
    
    # your exported package globals go here,
    # as well as any optionally exported functions
    @EXPORT_OK   = qw(&CleanEnv &LoadConfig &DBConnect 
		      &GetCurrentUser &GetMessageContent &debug);
}
=head1 NAME

  RT::Interface::CLI - helper functions for creating a commandline RT interface

=head1 SYNOPSIS

  use lib "!!RT_LIB_PATH!!";
  use lib "!!RT_ETC_PATH!!";

  use RT::Interface::Email  qw(CleanEnv LoadConfig DBConnect 
			      );

  #Clean out all the nasties from the environment
  CleanEnv();

  #Load etc/config.pm and drop privs
  LoadConfig();

  #Connect to the database and get RT::SystemUser and RT::Nobody loaded
  DBConnect();


  #Get the current user all loaded
  my $CurrentUser = GetCurrentUser();

=head1 DESCRIPTION


=head1 METHODS

=cut


=head2 CleanEnv

Removes some of the nastiest nasties from the user\'s environment.

=cut

sub CleanEnv {
    $ENV{'PATH'} = '/bin:/usr/bin';    # or whatever you need
    $ENV{'CDPATH'} = '' if defined $ENV{'CDPATH'};
    $ENV{'SHELL'} = '/bin/sh' if defined $ENV{'SHELL'};
    $ENV{'ENV'} = '' if defined $ENV{'ENV'};
    $ENV{'IFS'} = ''		if defined $ENV{'IFS'};
}



=head2 LoadConfig

Loads RT's config file and then drops setgid privileges.

=cut

sub LoadConfig {
    
    #This drags in  RT's config.pm
    use config;
    
    # Now that we got the config read in, we have the database 
    # password and don't need to be setgid
    # make the effective group the real group
    $) = $(;
}	



=head2 DBConnect

  Calls RT::Init, which creates a database connection and then creates $RT::Nobody
  and $RT::SystemUser

=cut


sub DBConnect {
    use RT;
    RT::Init();
}



# {{{ sub debug

sub debug {
    my $val = shift;
    my ($debug);
    if ($val) {
	$RT::Logger->debug($val."\n");
	if ($debug) {
	    print STDERR "$val\n";
	}
    }
    if ($debug) {
	return(1);
    }	
}

# }}}


1;
