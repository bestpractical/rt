#!/usr/bin/perl -w

# $Header$

# Copyright 2000 Jesse Vincent <jesse@fsck.com>
# Distributed under the GNU General Public License
# 

#
# This is just a basic script that checks to make sure that all
# the modules needed by RT before you can install it.
#

# TODO Polish this a whole lot
#
# in a MakeMaker-based install, you can do:
#
#    'PREREQ_PM' => {
#                     'DBI'                 => 1.13,
#                     'HTML::Mason'         => 0.89,
#                     'Date::Manip'         => 0,
#                     'Date::Format'        => 0,
#                     'MIME::Entity'        => 5.108,
#                     'Mail::Mailer'        => 1.20,
#                     'CGI::Cookie'         => 1.06,
#                     'Log::Dispatch'       => 1.6,
#                     'HTML::Entities'      => 0,
#                     'Text::Wrapper'       => 0,
#                     'Text::Template'      => 0,
#                     'DBIx::SearchBuilder' => 0,
#                     'Apache::Session'     => 1.03,
#                     'DBIx::DataSource'    => 0.03,
#                     'DBIx::DBSchema'      => 0.13,
#                   },

use strict;

use vars qw($mode $module @modules);

$mode = shift || &print_help;

@modules = qw(
DBI 1.13
HTML::Mason 0.89
Date::Manip
Date::Format
MIME::Entity 5.108
Mail::Mailer 1.20
CGI::Cookie 1.06
Log::Dispatch 1.6
HTML::Entities 
Text::Wrapper
Text::Template
DBIx::DataSource
DBIx::DBSchema 0.14
DBIx::SearchBuilder 0.13
Apache::Session 1.03
);
use CPAN;

while ($module= shift @modules) {
	my $version = "";
	$version = " ". shift (@modules) . " " if ($modules[0] =~ /^([\d\.]*)$/);
	print "Checking for $module$version";
	eval "use $module$version" ;
	if ($@) {
	&resolve_dependency($module, $version) 
	}
	else {
	print "...found\n";
	}
}

sub print_help {
print <<EOF;

$0 is a tool for RT that will tell you if you've got all
the modules RT depends on properly installed.

Flags: (only one flag is valid for a given run)

-quiet will check to see if we've got everything we need
	and will exit with a return code of (1) if we don't.

-warn will tell you what isn't properly installed

-fix will use CPAN to magically make everything better

EOF
}

sub resolve_dependency {
	my $module = shift;
	my $version = shift;
        print "....$module$version not installed.";
    if ($mode =~ /-f/) {
        print "Installing with CPAN...";
        CPAN::install($module);
     }
     print "\n";
	exit(1) if ($mode =~ /-q/);
}	
	
