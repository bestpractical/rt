# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/copyleft/gpl.html.
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
    $VERSION = do { my @r = ( q$Revision: 1.2.2.1 $ =~ /\d+/g ); sprintf "%d." . "%02d" x $#r, @r }; # must be all one line, for MakeMaker

    @ISA = qw(Exporter);

    # your exported package globals go here,
    # as well as any optionally exported functions
    @EXPORT_OK = qw(&CleanEnv
        &get_current_user &get_message_content &debug &loc);
}

=head1 name

  RT::Interface::CLI - helper functions for creating a commandline RT interface

=head1 SYNOPSIS

  use lib "/path/to/rt/libraries/";

  use RT::Interface::CLI  qw(CleanEnv 
	  		   get_current_user get_message_content loc);

  #Clean out all the nasties from the environment
  CleanEnv();

  #let's talk to RT'
  use RT;

  #Load RT's config file
  RT::load_config();

  # Connect to the database. set up loggign
  RT::Init();

  #Get the current user all loaded
  my $CurrentUser = get_current_user();

  print _('Hello!'); # Synonym of $CuurentUser->loc('Hello!');

=head1 description


=head1 METHODS


=cut

=head2 CleanEnv

Removes some of the nastiest nasties from the user\'s environment.

=cut

sub clean_env {
    $ENV{'PATH'}   = '/bin:/usr/bin';                   # or whatever you need
    $ENV{'CDPATH'} = '' if defined $ENV{'CDPATH'};
    $ENV{'SHELL'}  = '/bin/sh' if defined $ENV{'SHELL'};
    $ENV{'ENV'}    = '' if defined $ENV{'ENV'};
    $ENV{'IFS'}    = '' if defined $ENV{'IFS'};
}

{

    my $CurrentUser;    # shared betwen get_current_user and loc

    # {{{ sub get_current_user

=head2 get_current_user

  Figures out the uid of the current user and returns an RT::CurrentUser object
loaded with that user.  if the current user isn't found, returns a copy of RT::Nobody.

=cut

    sub get_current_user {

        require RT::CurrentUser;

        #Instantiate a user object

        my $gecos
            = ( $^O eq 'MSWin32' ) ? Win32::Loginname() : ( getpwuid($<) )[0];

        #If the current user is 0, then RT will assume that the User object
        #is that of the currentuser.

        $CurrentUser = RT::CurrentUser->new();
        $CurrentUser->load_by_gecos($gecos);

        unless ( $CurrentUser->id ) {
            Jifty->log->debug(
                "No user with a unix login of '$gecos' was found. ");
        }

        return ($CurrentUser);
    }

    # }}}


}

1;
