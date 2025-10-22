# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2025 Best Practical Solutions, LLC
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
our @EXPORT_OK = qw(GetCurrentUser debug loc Init);

=head1 NAME

RT::Interface::CLI - helper functions for creating a commandline RT interface

=head1 SYNOPSIS

  use lib "/opt/rt6/local/lib", "/opt/rt6/lib";

  use RT::Interface::CLI  qw(GetCurrentUser Init loc);

  # Create a hash to hold parsed values
  my %OPT = (
      "id" => 1,
  );

  # Process command-line arguments, load the configuration, and connect
  # to the database. See below for options provided by default.
  Init(
      \%OPT,
      "id=i",  # Getopt::Long options
  );

  print "Got an id: " . $OPT{'id'};

  # Get the current user all loaded
  my $CurrentUser = GetCurrentUser();

  print loc('Hello!'); # Synonym of $CurrentUser->loc('Hello!');

=head1 DESCRIPTION

This library provides shared functions for bootstrapping RT CLI programs
that provide you with a fully functional environment for running code
against the RT Perl API. When run, a database connection to the RT
database is automatically set up.

=head2 Memory Usage

The CLI interface loads a full RT environment, which is convenient when
creating command-line utilities because you can just start coding.
However, there are parts of RT that are typically not needed in a CLI
context and they contribute to the size of the running CLI process.
You can reduce the size of these processes by disabling some of these
features.

The most effective way to reduce memory usage is to limit the languages
loaded by RT. By default, RT loads all available translation lexicons,
which can consume 40-50MB of memory. If your CLI script only needs English,
you can use:

    --config LexiconLanguages=en

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

C<statement-log> provides a command-line version of the C<$StatementLog>
option in the main RT config file. This allows users to log SQL
for queries run in a CLI script in the same manner as the web UI.
It accepts log levels like C<$StatementLog>:

    --statement-log=debug

C<config> provides a generic way to override any RT configuration option
for the duration of the CLI script. It accepts key=value pairs where the
key is the name of any RT configuration option. You can specify this option
multiple times to set different configuration values.

    --config LogLevel=debug
    --config DisableGraphViz=1
    --config LexiconLanguages=en,fr

For array-valued options, use comma-separated values. For scalar options,
provide the value directly. Hash-valued options are not fully supported yet.

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
            # debug is treated specially later
            push @args, $_ => \($hash->{$1}) unless $1 eq 'debug';
        }
    } else {
        $hash = {};
        while (@_) {
            my $key = shift(@_);
            $exists{$key}++;
            # debug is treated specially later
            if ( $key eq 'debug' ) {
                shift @_;
            }
            else {
                push @args, $key, shift @_;
            }
        }
    }

    push @args, "help|h!" => \($hash->{help})
        unless $exists{help};

    push @args, "verbose|v!" => \($hash->{verbose})
        unless ( $exists{verbose} || $exists{'verbose|v'} );

    push @args, "debug!" => \($hash->{verbose})
        if $exists{debug};

    push @args, "quiet|q!" => \($hash->{quiet})
        unless $exists{quiet};

    push @args, "log=s" => \($hash->{log}) unless $exists{log};

    push @args, "statement-log=s" => \($hash->{'statement-log'})
        unless $exists{'statement-log'};

    push @args, "config=s%" => \($hash->{config}) unless $exists{config};

    my $ok = Getopt::Long::GetOptions( @args );
    Pod::Usage::pod2usage(1) if not $ok and not defined wantarray;

    return unless $ok;

    Pod::Usage::pod2usage({ verbose => 2})
          if not $exists{help} and $hash->{help};

    require RT;
    RT->SetCurrentInterface('CLI');
    RT::LoadConfig();

    if ( $hash->{log} ) {
        RT->Config->Set(LogToSTDERR => $hash->{log});
    } elsif (not $exists{quiet} and $hash->{quiet}) {
        RT->Config->Set(LogToSTDERR => "error");
    } elsif (not $exists{verbose} and $hash->{verbose}) {
        RT->Config->Set(LogToSTDERR => "debug");
    } else {
        RT->Config->Set(LogToSTDERR => "warning");
    }

    if ( $hash->{config} ) {
        while ( my ($option, $value) = each %{$hash->{config}} ) {
            my $meta = RT->Config->Meta($option) || {};
            my $type = $meta->{Type} || 'SCALAR';

            if ( $type eq 'ARRAY' ) {
                # Parse comma-separated values for arrays
                my @values = split /\s*,\s*/, $value;
                RT->Config->Set( $option => @values );
            }
            elsif ( $type eq 'HASH' ) {
                # For now, just warn that hashes aren't fully supported
                RT->Logger->warning(
                    "Hash-valued config option '$option' cannot be set via --config. " .
                    "Use the config file or a specific CLI option instead."
                );
            }
            else {
                # Scalar value
                RT->Config->Set( $option => $value );
            }
        }
    }

    RT->Config->Set( 'StatementLog', $hash->{'statement-log'} ) if defined $hash->{'statement-log'};
    RT::Init();
    $RT::Handle->LogSQLStatements(1) if RT->Config->Get('StatementLog');

    $| = 1;

    return $ok;
}

RT::Base->_ImportOverlays();

END {

    # When pod2usage is called (e.g. with --help), RT.pm won't be
    # required and directly calling RT->Config will error out.
    RT::Interface::Web::LogRecordedSQLStatements( RequestData => { Path => '/' } )
        if RT->can('Config') && RT->Config->Get('StatementLog');
}

1;
