# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2005 Best Practical Solutions, LLC 
#                                          <jesse@bestpractical.com>
# 
# (Except where explicitly superseded by other copyright notices)
# 
# 
# LICENSE:
# 
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
# 
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
# 
# 
# CONTRIBUTION SUBMISSION POLICY:
# 
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
# 
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
# 
# END BPS TAGGED BLOCK }}}
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
    
    my $Gecos= ($^O eq 'MSWin32') ? Win32::LoginName() : (getpwuid($<))[0];

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
    die "No current user yet" unless $CurrentUser ||= RT::CurrentUser->new;
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


eval "require RT::Interface::CLI_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Interface/CLI_Vendor.pm});
eval "require RT::Interface::CLI_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Interface/CLI_Local.pm});

1;
