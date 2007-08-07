#!/usr/bin/perl

use strict;
use warnings;

use Test::More qw(no_plan);
BEGIN { require 't/utils.pl' }

use lib "/opt/rt3/lib";
use RT;
RT::LoadConfig;
RT::Init;

use RT::CustomField;
use RT::EmailParser;
use RT::Queue;
use RT::Ticket;
use Test::WWW::Mechanize;
use_ok 'RT::FM::Class';
use_ok 'RT::FM::Topic';
use_ok 'RT::FM::Article';

BEGIN {
$RT::WebPort ||= '80';
$RT::WebPath ||= ''; # Shut up a warning
};
use constant BaseURL => "http://localhost:".$RT::WebPort.$RT::WebPath."/";

# Variables to test return values
my ($ret, $msg);

# Create a test class
my $class = RT::FM::Class->new($RT::SystemUser);
($ret, $msg) = $class->Create('Name' => 'tlaTestClass-'.$$,
			      'Description' => 'A general-purpose test class');
ok($ret, "Test class created");

# Create a hierarchy of test topics
my $topic1 = RT::FM::Topic->new($RT::SystemUser);
my $topic11 = RT::FM::Topic->new($RT::SystemUser);
my $topic12 = RT::FM::Topic->new($RT::SystemUser);
my $topic2 = RT::FM::Topic->new($RT::SystemUser);
($ret, $msg) = $topic1->Create('Parent' => 0,
			      'Name' => 'tlaTestTopic1-'.$$,
			      'ObjectType' => 'RT::FM::Class',
			      'ObjectId' => $class->Id);
ok($ret, "Topic 1 created");
($ret, $msg) = $topic11->Create('Parent' => $topic1->Id,
			       'Name' => 'tlaTestTopic1.1-'.$$,
			       'ObjectType' => 'RT::FM::Class',
			       'ObjectId' => $class->Id);
ok($ret, "Topic 1.1 created");
($ret, $msg) = $topic12->Create('Parent' => $topic1->Id,
			       'Name' => 'tlaTestTopic1.2-'.$$,
			       'ObjectType' => 'RT::FM::Class',
			       'ObjectId' => $class->Id);
ok($ret, "Topic 1.2 created");
($ret, $msg) = $topic2->Create('Parent' => 0,
			      'Name' => 'tlaTestTopic2-'.$$,
			      'ObjectType' => 'RT::FM::Class',
			      'ObjectId' => $class->Id);
ok($ret, "Topic 2 created");

# Create some article custom fields

my $questionCF = RT::CustomField->new($RT::SystemUser);
my $answerCF = RT::CustomField->new($RT::SystemUser);
($ret, $msg) = $questionCF->Create('Name' => 'Question-'.$$,
			   'Type' => 'Text',
			   'MaxValues' => 1,
			   'LookupType' => 'RT::FM::Class-RT::FM::Article',
			   'Description' => 'The question to be answered',
			   'Disabled' => 0);
ok($ret, "Question CF created: $msg");
($ret, $msg) = $answerCF->Create('Name' => 'Answer-'.$$,
			 'Type' => 'Text',
			 'MaxValues' => 1,
			 'LookupType' => 'RT::FM::Class-RT::FM::Article',
			 'Description' => 'The answer to the question',
			 'Disabled' => 0);
ok($ret, "Answer CF created: $msg");

# Attach the custom fields to our class
($ret, $msg) = $questionCF->AddToObject($class);
ok($ret, "Question CF added to class: $msg");
($ret, $msg) = $answerCF->AddToObject($class);
ok($ret, "Answer CF added to class: $msg");
my ($qid, $aid) = ($questionCF->Id, $answerCF->Id);

my %cvals = ('article1q' => 'Some question about swallows',
		'article1a' => 'Some answer about Europe and Africa',
		'article2q' => 'Another question about Monty Python',
		'article2a' => 'Romani ite domum',
		'article3q' => 'Why should I eat my supper?',
		'article3a' => 'There are starving children in Africa',
		'article4q' => 'What did Brian originally write?',
		'article4a' => 'Romanes eunt domus');

# Create an article or two with our custom field values.

my $article1 = RT::FM::Article->new($RT::SystemUser);
my $article2 = RT::FM::Article->new($RT::SystemUser);
my $article3 = RT::FM::Article->new($RT::SystemUser);
my $article4 = RT::FM::Article->new($RT::SystemUser);
($ret, $msg) = $article1->Create(Name => 'First article '.$$,
				 Summary => 'blah blah 1',
				 Class => $class->Id,
				 Topics => [$topic1->Id],
				 "CustomField-$qid" => $cvals{'article1q'},
				 "CustomField-$aid" => $cvals{'article1a'},
				 );
ok($ret, "article 1 created");
($ret, $msg) = $article2->Create(Name => 'Second article '.$$,
				 Summary => 'foo bar 2',
				 Class => $class->Id,
				 Topics => [$topic11->Id],
				 "CustomField-$qid" => $cvals{'article2q'},
				 "CustomField-$aid" => $cvals{'article2a'},
				 );
ok($ret, "article 2 created");
($ret, $msg) = $article3->Create(Name => 'Third article '.$$,
				 Summary => 'ping pong 3',
				 Class => $class->Id,
				 Topics => [$topic12->Id],
				 "CustomField-$qid" => $cvals{'article3q'},
				 "CustomField-$aid" => $cvals{'article3a'},
				 );
ok($ret, "article 3 created");
($ret, $msg) = $article4->Create(Name => 'Fourth article '.$$,
				 Summary => 'hoi polloi 4',
				 Class => $class->Id,
				 Topics => [$topic2->Id],
				 "CustomField-$qid" => $cvals{'article4q'},
				 "CustomField-$aid" => $cvals{'article4a'},
				 );
ok($ret, "article 4 created");

# Create a ticket.
my $parser = RT::EmailParser->new();
$parser->ParseMIMEEntityFromScalar('From: root@localhost
To: rt@example.com
Subject: test ticket for articles

This is some form of new request.
May as well say something about Africa.');

my $queue = RT::Queue->new($RT::SystemUser);
$queue->Create('ArticleQueue'.$$);
my $ticket = RT::Ticket->new($RT::SystemUser);
my $obj;
($ret, $obj, $msg) = $ticket->Create(Queue => 'General',
			       Subject => 'test ticket for articles '.$$,
			       MIMEObj => $parser->Entity);
ok($ret, "Test ticket for articles created: $msg");


#### Right.  That's our data.  Now begin the real testing.

my $url = BaseURL;
my $m = Test::WWW::Mechanize->new;
isa_ok($m, 'Test::WWW::Mechanize');
ok(1, "Connecting to ".$url);
$m->get( $url."?user=root;pass=password" );
$m->content_like(qr/Logout/, 'we did log in');
$m->follow_link(text => 'RTFM');
$m->content_contains($article3->Name);
$m->follow_link(text => $article3->Name);
$m->title_is("Article #" . $article3->Id . ": " . $article3->Name);
$m->follow_link(text => 'Modify');
$m->content_like(qr/Refers to/, "found links edit box");
my $turi = 't:'.$ticket->Id;
my $a1uri = 'a:'.$article1->Id;
$m->submit_form(form_name => 'EditArticle',
		fields => { $article3->Id.'-RefersTo' => $turi,
			    'RefersTo-'.$article3->Id => $a1uri }
		);
$m->content_like(qr/Link created.*$turi/, "Ticket linkto was created");
$m->content_like(qr/Link created.*$a1uri/, "Article linkfrom was created");

# Now try to extract an article from a link.
$m->get_ok($url."Ticket/Display.html?id=".$ticket->Id, 
	   "Loaded ticket display");
$m->content_like(qr/Extract Article/, "Article extraction link shows up");
$m->follow_link(text => 'Extract Article');
$m->content_contains($class->Name);
$m->follow_link(text => $class->Name);
$m->form_number(2);
$m->set_visible([option => $answerCF->Name]);
$m->click();
$m->title_like(qr/Create a new article/, "got edit page from extraction");
$m->submit_form(form_name => 'EditArticle');
$m->title_like(qr/Modify article/);
$m->follow_link(text => 'Display');
$m->content_like(qr/Africa/, "Article content exist");
$m->content_contains($ticket->Subject,
		     "Article references originating ticket");
