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


use strict;

use vars qw($mode $module @modules);

$mode = shift || &print_help;

@modules = qw(DBI HTML::Mason MIME::Entity Mail::Mailer CGI::Cookie 
		Log::Dispatch
	        DBIx::Record DBIx::EasySearch Apache::Session DBIx::Handle);
use CPAN;


foreach $module (@modules) {
	eval "require $module" || &resolve_dependency($module);
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
	CPAN::install($module) if ($mode eq '-fix');
	print "$module not installed.\n" if ($mode eq '-warn');
	exit(1) if ($mode eq '-quiet');
}	
	
