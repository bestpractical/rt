# $Header: /raid/cvsroot/rt/lib/RT/Interface/CLI.pm,v 1.2.2.1 2002/01/28 05:27:14 jesse Exp $
# RT is (c) 1996-2002 Jesse Vincent <jesse@bestpractical.com>

use strict;

use RT;
package RT::Interface::CLI;



BEGIN {
    use Exporter ();
    use vars qw ($VERSION  @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
    
    # set the version for version checking
    $VERSION = do { my @r = (q$Revision: 1.2.2.1 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker
    
    @ISA         = qw(Exporter);
    
    # your exported package globals go here,
    # as well as any optionally exported functions
    @EXPORT_OK   = qw(&CleanEnv 
		      &GetCurrentUser &GetMessageContent &debug &loc);
}

=head1 NAME

  RT::Interface::CLI - helper functions for creating a commandline RT interface

=head1 SYNOPSIS

  use lib "/path/to/rt/libraries/";

  use RT::Interface::CLI  qw(CleanEnv 
	  		   GetCurrentUser GetMessageContent loc);

  #Clean out all the nasties from the environment
  CleanEnv();

  #let's talk to RT'
  use RT;

  #Load RT's config file
  RT::LoadConfig();

  # Connect to the database. set up loggign
  RT::Init();

  #Get the current user all loaded
  my $CurrentUser = GetCurrentUser();

  print loc('Hello!'); # Synonym of $CuurentUser->loc('Hello!');

=head1 DESCRIPTION


=head1 METHODS

=begin testing

ok(require RT::TestHarness);
ok(require RT::Interface::CLI);

=end testing

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




{

    my $CurrentUser; # shared betwen GetCurrentUser and loc

# {{{ sub GetCurrentUser 

=head2 GetCurrentUser

  Figures out the uid of the current user and returns an RT::CurrentUser object
loaded with that user.  if the current user isn't found, returns a copy of RT::Nobody.

=cut

sub GetCurrentUser  {
    
    require RT::CurrentUser;
    
    #Instantiate a user object
    
    my $Gecos=(getpwuid($<))[0];

    #If the current user is 0, then RT will assume that the User object
    #is that of the currentuser.

    $CurrentUser = new RT::CurrentUser();
    $CurrentUser->LoadByGecos($Gecos);
    
    unless ($CurrentUser->Id) {
	$RT::Logger->debug("No user with a unix login of '$Gecos' was found. ");
    }

    return($CurrentUser);
}
# }}}


# {{{ sub loc 

=head2 loc

  Synonym of $CurrentUser->loc().

=cut

sub loc {
    die "No current user yet" unless $CurrentUser;
    return $CurrentUser->loc(@_);
}
# }}}

}


# {{{ sub GetMessageContent

=head2 GetMessageContent

Takes two arguments a source file and a boolean "edit".  If the source file
is undef or "", assumes an empty file.  Returns an edited file as an 
array of lines.

=cut

sub GetMessageContent {
    my %args = (  Source => undef,
		  Content => undef,
		  Edit => undef,
		  CurrentUser => undef,
		 @_);
    my $source = $args{'Source'};

    my $edit = $args{'Edit'};
    
    my $currentuser = $args{'CurrentUser'};
    my @lines;

    use File::Temp qw/ tempfile/;
    
    #Load the sourcefile, if it's been handed to us
    if ($source) {
	open (SOURCE, "<$source");
	@lines = (<SOURCE>);
	close (SOURCE);
    }
    elsif ($args{'Content'}) {
	@lines = split('\n',$args{'Content'});
    }
    #get us a tempfile.
    my ($fh, $filename) = tempfile();
	
    #write to a tmpfile
    for (@lines) {
	print $fh $_;
    }
    close ($fh);
    
    #Edit the file if we need to
    if ($edit) {	

	unless ($ENV{'EDITOR'}) {
	    $RT::Logger->crit('No $EDITOR variable defined'. "\n");
	    return undef;
	}
	system ($ENV{'EDITOR'}, $filename);
    }	
    
    open (READ, "<$filename");
    my @newlines = (<READ>);
    close (READ);

    unlink ($filename) unless (debug());
    return(\@newlines);
    
}

# }}}

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
