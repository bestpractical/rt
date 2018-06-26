# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2018 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
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
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
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

package RT::Interface::CLI;
use strict;
use warnings;

use RT::Base;

use base 'Exporter';
our @EXPORT_OK = qw(CleanEnv GetCurrentUser debug loc Init);

=head1 NAME

  RT::Interface::CLI - helper functions for creating a commandline RT interface

=head1 SYNOPSIS

  use lib "/opt/rt4/local/lib", "/opt/rt4/lib";

  use RT::Interface::CLI  qw(GetCurrentUser Init loc);

  # Process command-line arguments, load the configuration, and connect
  # to the database
  Init();

  # Get the current user all loaded
  my $CurrentUser = GetCurrentUser();

  print loc('Hello!'); # Synonym of $CurrentUser->loc('Hello!');

=head1 DESCRIPTION


=head1 METHODS


=cut

{

    my $CurrentUser; # shared betwen GetCurrentUser and loc


=head2 GetCurrentUser

  Figures out the uid of the current user and returns an RT::CurrentUser object
loaded with that user.  if the current user isn't found, returns a copy of RT::Nobody.

=cut

sub GetCurrentUser  {

    require RT::CurrentUser;

    #Instantiate a user object

    my $Gecos= (getpwuid($<))[0];

    #If the current user is 0, then RT will assume that the User object
    #is that of the currentuser.

    $CurrentUser = RT::CurrentUser->new();
    $CurrentUser->LoadByGecos($Gecos);

    unless ($CurrentUser->Id) {
        $RT::Logger->error("No user with a GECOS (unix login) of '$Gecos' was found.");
    }

    return($CurrentUser);
}

=head2 loc

  Synonym of $CurrentUser->loc().

=cut

sub loc {
    die "No current user yet" unless $CurrentUser ||= RT::CurrentUser->new;
    return $CurrentUser->loc(@_);
}

}

sub ShowHelp {
    my $self = shift;
    my %args = @_;
    require Pod::Usage;
    Pod::Usage::pod2usage(
        -message => $args{'Message'},
        -exitval => $args{'ExitValue'} || 0, 
        -verbose => 99,
        -sections => $args{'Sections'} || ($args{'ExitValue'}
            ? 'NAME|USAGE'
            : 'NAME|USAGE|OPTIONS|DESCRIPTION'
        ),
    );
}

=head2 Init

A shim for L<Getopt::Long/GetOptions> which automatically adds a
C<--help> option if it is not supplied.  It then calls L<RT/LoadConfig>
and L<RT/Init>.

It sets the C<LogToSTDERR> setting to C<warning>, to ensure that the
user sees all relevant warnings.  It also adds C<--quiet> and
C<--verbose> options, which adjust the C<LogToSTDERR> value to C<error>
or C<debug>, respectively.

If C<debug> is provided as a parameter, it added as an alias for
C<--verbose>.

=cut

sub Init {
    require Getopt::Long;
    require Pod::Usage;

    my %exists;
    my @args;
    my $hash;
    if (ref $_[0]) {
        $hash = shift(@_);
        for (@_) {
            m/^([a-zA-Z0-9-]+)/;
            $exists{$1}++;
            push @args, $_ => \($hash->{$1});
        }
    } else {
        $hash = {};
        @args = @_;
        while (@_) {
            my $key = shift(@_);
            $exists{$key}++;
            shift(@_);
        }
    }

    push @args, "help|h!" => \($hash->{help})
        unless $exists{help};

    push @args, "verbose|v!" => \($hash->{verbose})
        unless $exists{verbose};

    push @args, "debug!" => \($hash->{verbose})
        if $exists{debug};

    push @args, "quiet|q!" => \($hash->{quiet})
        unless $exists{quiet};

    my $ok = Getopt::Long::GetOptions( @args );
    Pod::Usage::pod2usage(1) if not $ok and not defined wantarray;

    return unless $ok;

    Pod::Usage::pod2usage({ verbose => 2})
          if not $exists{help} and $hash->{help};

    require RT;
    RT::LoadConfig();

    if (not $exists{quiet} and $hash->{quiet}) {
        RT->Config->Set(LogToSTDERR => "error");
    } elsif (not $exists{verbose} and $hash->{verbose}) {
        RT->Config->Set(LogToSTDERR => "debug");
    } else {
        RT->Config->Set(LogToSTDERR => "warning");
    }

    RT::Init();

    $| = 1;

    return $ok;
}

RT::Base->_ImportOverlays();

1;
