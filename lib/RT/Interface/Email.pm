# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2002 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
# 
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org
# 
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# 
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK
use RT;
package RT::Interface::Email;

use strict;
use Mail::Address;
use MIME::Entity;

BEGIN {
    use Exporter();
    use vars qw ($VERSION  @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

    # set the version for version checking
    $VERSION = do { my @r = (q$Revision: 1.3.2.1 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r }; # must be all one line, for MakeMaker

    @ISA = qw(Exporter);

    # your exported package globals go here,
    # as well as any optionally exported functions
    @EXPORT_OK = qw(&CleanEnv
      &MailError
      &debug);
}

=head1 NAME

  RT::Interface::CLI - helper functions for creating a commandline RT interface

=head1 SYNOPSIS

  use lib "!!RT_LIB_PATH!!";
  use lib "!!RT_ETC_PATH!!";

  use RT;
  use RT::Interface::Email  qw(CleanEnv 
			      );

  #Clean out all the nasties from the environment
  CleanEnv();

  # Load RT's config file

  RT::LoadConfig();
 #  connect to the database
  RT::Init();

=head1 DESCRIPTION


=begin testing

ok(require RT::Interface::Email);

=end testing


=head1 METHODS

=cut

=head2 CleanEnv

Removes some of the nastiest nasties from the user\'s environment.

=cut

sub CleanEnv {
    $ENV{'PATH'}   = '/bin:/usr/bin';                     # or whatever you need
    $ENV{'CDPATH'} = '' if defined $ENV{'CDPATH'};
    $ENV{'SHELL'}  = '/bin/sh' if defined $ENV{'SHELL'};
    $ENV{'ENV'}    = '' if defined $ENV{'ENV'};
    $ENV{'IFS'}    = '' if defined $ENV{'IFS'};
}


# {{{ sub debug

sub debug {
    my $val = shift;
    my ($debug);
    if ($val) {
        $RT::Logger->debug( $val . "\n" );
        if ($debug) {
            print STDERR "$val\n";
        }
    }
    if ($debug) {
        return (1);
    }
}

# }}}

# {{{ sub MailError 
sub MailError {
    my %args = (
        To          => $RT::OwnerEmail,
        Bcc         => undef,
        From        => $RT::CorrespondAddress,
        Subject     => 'There has been an error',
        Explanation => 'Unexplained error',
        MIMEObj     => undef,
        LogLevel    => 'crit',
        @_
    );

    $RT::Logger->log(
        level   => $args{'LogLevel'},
        message => $args{'Explanation'}
    );
    my $entity = MIME::Entity->build(
        Type                   => "multipart/mixed",
        From                   => $args{'From'},
        Bcc                    => $args{'Bcc'},
        To                     => $args{'To'},
        Subject                => $args{'Subject'},
        'X-RT-Loop-Prevention' => $RT::rtname,
    );

    $entity->attach( Data => $args{'Explanation'} . "\n" );

    my $mimeobj = $args{'MIMEObj'};
    $mimeobj->sync_headers();
    $entity->add_part($mimeobj);

    if ( $RT::MailCommand eq 'sendmailpipe' ) {
        open( MAIL, "|$RT::SendmailPath $RT::SendmailArguments" ) || return (0);
        print MAIL $entity->as_string;
        close(MAIL);
    }
    else {
        $entity->send( $RT::MailCommand, $RT::MailParams );
    }
}

# }}}


1;
