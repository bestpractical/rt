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
package RT;
use RT::CurrentUser;
use strict;

use vars qw($VERSION $SystemUser $Nobody $Handle $Logger);

$VERSION = '!!RT_VERSION!!';

=head1 NAME

	RT - Request Tracker

=head1 SYNOPSIS

	A fully featured request tracker package

=head1 DESCRIPTION


=cut

=item LoadConfig

Load RT's config file

=cut

sub LoadConfig {
    my $config_file = "!!RT_CONFIG!!";
    # We don't have a configuration file yet. 
    # localizing here would suck.
    #require $config_file || die $self->loc("Couldn't load RT config file '[_1]' [_2]", $config_file, $@);
    require $config_file || die ("Couldn't load RT config file  $config_file $@");
}

=item Init

    Conenct to the database, set up logging.
    
=cut

sub Init {
    require RT::Handle;
    #Get a database connection
    $Handle = RT::Handle->new();
    $Handle->Connect();
    
    
    #RT's system user is a genuine database user. its id lives here
    $SystemUser = new RT::CurrentUser();
    $SystemUser->LoadByName('RT_System');
    
    #RT's "nobody user" is a genuine database user. its ID lives here.
    $Nobody = new RT::CurrentUser();
    $Nobody->LoadByName('Nobody');
   
   InitLogging(); 
}

=head2 InitLogging

Create the RT::Logger object. 

=cut
sub InitLogging {

    # We have to set the record seperator ($, man perlvar)
    # or Log::Dispatch starts getting
    # really pissy, as some other module we use unsets it.

    $, = '';
    use Log::Dispatch 1.6;

    $RT::Logger=Log::Dispatch->new();
    
    if ($RT::LogToFile) {

    unless (-d $RT::LogDir && -w $RT::LogDir) {
        # localizing here would be hard when we don't have a current user yet
        # die $self->loc("Log directory [_1] not found or couldn't be written.\n RT can't run.", $RT::LogDir);
        die ("Log directory $RT::LogDir not found or couldn't be written.\n RT can't run.");
    }

	my $filename = $RT::LogToFileNamed || "$RT::LogDir/rt.log";
    require Log::Dispatch::File;


	  $RT::Logger->add(Log::Dispatch::File->new
		       ( name=>'rtlog',
			 min_level=> $RT::LogToFile,
			 filename=> $filename,
			 mode=>'append',
			 callbacks => sub { my %p = @_;
                                my ($package, $filename, $line) = caller(5);
                                return "[".gmtime(time)."] [".$p{level}."]: $p{message} ($filename:$line)\n"}
             
             
             
		       ));
    }
    if ($RT::LogToScreen) {
	require Log::Dispatch::Screen;
	$RT::Logger->add(Log::Dispatch::Screen->new
		     ( name => 'screen',
		       min_level => $RT::LogToScreen,
			 callbacks => sub { my %p = @_;
                                my ($package, $filename, $line) = caller(5);
                                return "[".gmtime(time)."] [".$p{level}."]: $p{message} ($filename:$line)\n"
				},
             
		       stderr => 1
		     ));
    }
    if ($RT::LogToSyslog) {
	require Log::Dispatch::Syslog;
	$RT::Logger->add(Log::Dispatch::Syslog->new
		     ( name => 'syslog',
		       min_level => $RT::LogToSyslog,
			 callbacks => sub { my %p = @_;
                                my ($package, $filename, $line) = caller(5);
				if ($p{level} eq 'debug') {

                                return "$p{message}\n" }
				else {
                                return "$p{message} ($filename:$line)\n"}
				},
             
		       stderr => 1
		     ));
    }
# {{{ Signal handlers

## This is the default handling of warnings and die'ings in the code
## (including other used modules - maybe except for errors catched by
## Mason).  It will log all problems through the standard logging
## mechanism (see above).

$SIG{__WARN__} = sub {$RT::Logger->warning($_[0])};

#When we call die, trap it and log->crit with the value of the die.

$SIG{__DIE__}  = sub {
    unless ($^S || !defined $^S ) {
        $RT::Logger->crit("$_[0]");
        exit(-1);
    }
    else {
        #Get out of here if we're in an eval
        die $_[0];
    }
};

# }}}

}

# }}}


sub SystemUser {
    return($SystemUser);
}	

sub Nobody {
    return ($Nobody);
}


=head2 DropSetGIDPermissions

Drops setgid permissions.

=cut

sub DropSetGIDPermissions {
    # Now that we got the config read in, we have the database 
    # password and don't need to be setgid
    # make the effective group the real group
    $) = $(;
}


=head1 SYNOPSIS

=head1 BUGS

=head1 SEE ALSO


=begin testing


ok ($RT::Nobody->Name() eq 'Nobody', "Nobody is nobody");
ok ($RT::Nobody->Name() ne 'root', "Nobody isn't named root");
ok ($RT::SystemUser->Name() eq 'RT_System', "The system user is RT_System");
ok ($RT::SystemUser->Name() ne 'noname', "The system user isn't noname");


=end testing

=cut

1;
