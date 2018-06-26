use strict;
use warnings;

use RT::Test tests => undef;

use RT::CustomField;
use RT::EmailParser;
use RT::Queue;
use RT::Ticket;
use_ok 'RT::Class';
use_ok 'RT::Topic';
use_ok 'RT::Article';

# Variables to test return values
my ($ret, $msg);

# Create a test class
my $class = RT::Class->new($RT::SystemUser);
($ret, $msg) = $class->Create('Name' => 'TestClass-'.$$,
                              'Description' => 'A general-purpose test class');
ok($ret, "Test class created: $msg");
# because id 0 represents global, it uses an empty Queue object...
($ret, $msg) = $class->AddToObject(RT::Queue->new($RT::SystemUser));
ok($ret, "Applied Class globally: $msg");

# Create some article custom fields
my $bodyCF    = RT::CustomField->new($RT::SystemUser);
my $subjectCF = RT::CustomField->new($RT::SystemUser);
($ret, $msg) = $subjectCF->Create('Name' => 'Subject-'.$$,
                           'Type' => 'Text',
                           'MaxValues' => 1,
                           'LookupType' => 'RT::Class-RT::Article',
                           'Description' => 'The subject to be answered',
                           'Disabled' => 0);
ok($ret, "Question CF created: $msg");
($ret, $msg) = $bodyCF->Create('Name' => 'Body-'.$$,
                         'Type' => 'Text',
                         'MaxValues' => 1,
                         'LookupType' => 'RT::Class-RT::Article',
                         'Description' => 'The body to the subject',
                         'Disabled' => 0);
ok($ret, "Answer CF created: $msg");
my ($sid, $bid) = ($subjectCF->Id, $bodyCF->Id);

# Attach the custom fields to our class
($ret, $msg) = $subjectCF->AddToObject($class);
ok($ret, "Subject CF added to class: $msg");
($ret, $msg) = $bodyCF->AddToObject($class);
ok($ret, "Body CF added to class: $msg");

my $article = RT::Article->new($RT::SystemUser);
($ret, $msg) = $article->Create(Name => 'First article '.$$,
                                Summary => 'blah blah 1',
                                Class => $class->Id,
                                "CustomField-$bid" => 'This goes in the body', 
                                "CustomField-$sid" => 'This clobbers your subject',
                            );
ok($ret, "article 1 created: $msg");

# Create a ticket.
my $parser = RT::EmailParser->new();
$parser->ParseMIMEEntityFromScalar('From: root@localhost
To: rt@example.com
Subject: test ticket for articles

This is some form of new request.
May as well say something about Africa.');

my $ticket = RT::Ticket->new($RT::SystemUser);
my $obj;
($ret, $obj, $msg) = $ticket->Create(Queue => 'General',
                                     Subject => 'test ticket for articles '.$$,
                                     MIMEObj => $parser->Entity);
ok($ret, "Test ticket for articles created: $msg");


#### Right.  That's our data.  Now begin the real testing.

my ($url, $m) = RT::Test->started_ok;
ok($m->login, 'logged in');

$m->get_ok( '/Ticket/Update.html?Action=Comment&id=' . $ticket->id,
    'ticket update page' );
is($m->form_number(3)->find_input('UpdateSubject')->value,$ticket->Subject,'Ticket Subject Found');
$m->submit_form(
    form_number => 3,
    fields      => { 'Articles-Include-Article-Named' => $article->Id },
    button      => 'Go',
);
is($m->form_number(3)->find_input('UpdateSubject')->value,$ticket->Subject,'Ticket Subject Not Clobbered');

$m->get_ok("$url/Admin/Articles/Classes/");
$m->follow_link_ok( { text => 'TestClass-'.$$ } );
$m->submit_form_ok({
    form_number => 3,
    fields => { SubjectOverride => $sid },
});
$m->content_contains("Added Subject Override: Subject-$$");

$m->get_ok( '/Ticket/Update.html?Action=Comment&id=' . $ticket->id,
    'ticket update page' );
is($m->form_number(3)->find_input('UpdateSubject')->value,$ticket->Subject,'Ticket Subject Found');
$m->submit_form(
    form_number => 3,
    fields      => { 'Articles-Include-Article-Named' => $article->Name },
    button      => 'Go',
);
is($m->form_number(3)->find_input('UpdateSubject')->value,$article->FirstCustomFieldValue("Subject-$$"),'Ticket Subject Clobbered');

done_testing;
