#!/usr/bin/perl -w -d:DProf
#
# $Header$
# RT is (c) 1996-2000 Jesse Vincent (jesse@fsck.com);

=head1 Stress Test for RT2

This test stresses the rt core with 1000 ticket creates,
1000 ticket takes, 1000 responses and 1000 resolves

so far, the first thing is all it does.

=cut

package RT;
use strict;
use vars qw($VERSION $Handle $SystemUser);

$VERSION="1.3.3";

use lib "/opt/rt-1.3/lib";
use lib "/opt/rt-1.3/etc";

#This drags in  RT's config.pm
use config;
use Carp;
use DBIx::Handle;


$Handle = new DBIx::Handle;

$Handle->Connect(Host => $RT::DatabaseHost, 
		     Database => $RT::DatabaseName, 
		     User => $RT::DatabaseUser,
		     Password => $RT::DatabasePassword,
		     Driver => $RT::DatabaseType);


#Load up a user object for actions taken by RT itself
use RT::CurrentUser;
#TODO abstract out the ID of the RT SystemUser
$SystemUser = RT::CurrentUser->new(1);

use MIME::Entity;
my  $Message = MIME::Entity->build ( Subject => "This is a subject",
				     From => "jesse\@fsck.com",
				     Data => "This is a simple little bit of data which isn't meant to exercise MIME::Entity and database storage.");


use RT::Ticket;
for (my $i = 0; $i < 1000; $i++) {
	my $ticket = RT::Ticket->new($SystemUser);
	$ticket->Create(QueueTag => 'general',
		Subject => "This is a subject",
		Status => "Open",
		MIMEEntity => $Message);

}
$RT::Handle->Disconnect();


1;

