
use strict;
use warnings;

use RT::Test tests => 53;

use RT::CustomField;
use RT::EmailParser;
use RT::Queue;
use RT::Ticket;
use_ok 'RT::Class';
use_ok 'RT::Topic';
use_ok 'RT::Article';

my ($url, $m) = RT::Test->started_ok;

# Variables to test return values
my ($ret, $msg);

# Create a test class
my $class = RT::Class->new($RT::SystemUser);
($ret, $msg) = $class->Create('Name' => 'tlaTestClass-'.$$,
                              'Description' => 'A general-purpose test class');
ok($ret, "Test class created");
my $class2 = RT::Class->new($RT::SystemUser);
($ret, $msg) = $class2->Create('Name' => 'tlaTestClass2-'.$$,
                              'Description' => 'Another general-purpose test class');
ok($ret, "Test class 2 created");


# Create a hierarchy of test topics
my $topic1 = RT::Topic->new($RT::SystemUser);
my $topic11 = RT::Topic->new($RT::SystemUser);
my $topic12 = RT::Topic->new($RT::SystemUser);
my $topic2 = RT::Topic->new($RT::SystemUser);
my $topic_class2= RT::Topic->new($RT::SystemUser);
my $gtopic = RT::Topic->new($RT::SystemUser);
($ret, $msg) = $topic1->Create('Parent' => 0,
                               'Name' => 'tlaTestTopic1-'.$$,
                               'ObjectType' => 'RT::Class',
                               'ObjectId' => $class->Id);
ok($ret, "Topic 1 created");
($ret, $msg) = $topic11->Create('Parent' => $topic1->Id,
                                'Name' => 'tlaTestTopic1.1-'.$$,
                                'ObjectType' => 'RT::Class',
                                'ObjectId' => $class->Id);
ok($ret, "Topic 1.1 created");
($ret, $msg) = $topic12->Create('Parent' => $topic1->Id,
                                'Name' => 'tlaTestTopic1.2-'.$$,
                                'ObjectType' => 'RT::Class',
                                'ObjectId' => $class->Id);
ok($ret, "Topic 1.2 created");
($ret, $msg) = $topic2->Create('Parent' => 0,
                               'Name' => 'tlaTestTopic2-'.$$,
                               'ObjectType' => 'RT::Class',
                               'ObjectId' => $class->Id);
ok($ret, "Topic 2 created");
($ret, $msg) = $topic_class2->Create('Parent' => 0,
                                     'Name' => 'tlaTestTopicClass2-'.$$,
                                     'ObjectType' => 'RT::Class',
                                     'ObjectId' => $class2->Id);
ok($ret, "Topic Class2 created");
($ret, $msg) = $gtopic->Create('Parent' => 0,
                               'Name' => 'tlaTestTopicGlobal-'.$$,
                               'ObjectType' => 'RT::System',
                               'ObjectId' => $RT::System->Id );
ok($ret, "Global Topic created");

# Create some article custom fields

my $questionCF = RT::CustomField->new($RT::SystemUser);
my $answerCF = RT::CustomField->new($RT::SystemUser);
($ret, $msg) = $questionCF->Create('Name' => 'Question-'.$$,
                                   'Type' => 'Text',
                                   'MaxValues' => 1,
                                   'LookupType' => 'RT::Class-RT::Article',
                                   'Description' => 'The question to be answered',
                                   'Disabled' => 0);
ok($ret, "Question CF created: $msg");
($ret, $msg) = $answerCF->Create('Name' => 'Answer-'.$$,
                                 'Type' => 'Text',
                                 'MaxValues' => 1,
                                 'LookupType' => 'RT::Class-RT::Article',
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

my $article1 = RT::Article->new($RT::SystemUser);
my $article2 = RT::Article->new($RT::SystemUser);
my $article3 = RT::Article->new($RT::SystemUser);
my $article4 = RT::Article->new($RT::SystemUser);
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

my $ticket = RT::Ticket->new($RT::SystemUser);
my $obj;
($ret, $obj, $msg) = $ticket->Create(Queue => 'General',
                                     Subject => 'test ticket for articles '.$$,
                                     MIMEObj => $parser->Entity);
ok($ret, "Test ticket for articles created: $msg");


#### Right.  That's our data.  Now begin the real testing.

isa_ok($m, 'Test::WWW::Mechanize');
ok($m->login, 'logged in');
$m->follow_link_ok( { text => 'Articles', url_regex => qr!^/Articles/index.html! },
    'UI -> Articles' );

$m->content_contains($article3->Name);
$m->follow_link_ok( {text => $article3->Name}, 'Articles -> '. $article3->Name );
$m->title_is("Article #" . $article3->Id . ": " . $article3->Name);
$m->follow_link_ok( { text => 'Modify'}, 'Article -> Modify' );

{
$m->content_like(qr/Refers to/, "found links edit box");
my $ticket_id = $ticket->Id;
my $turi = "t:$ticket_id";
my $a1uri = 'a:'.$article1->Id;
$m->submit_form(form_name => 'EditArticle',
                fields => { $article3->Id.'-RefersTo' => $turi,
                            'RefersTo-'.$article3->Id => $a1uri }
                );

$m->content_like(qr/Ticket.*$ticket_id/, "Ticket linkto was created");
$m->content_like(qr/URI.*$a1uri/, "Article linkfrom was created");
}

# Now try to extract an article from a link.
$m->get_ok($url."/Ticket/Display.html?id=".$ticket->Id, 
           "Loaded ticket display");
$m->content_like(qr/Extract Article/, "Article extraction link shows up");
$m->follow_link_ok( { text => 'Extract Article' }, '-> Extract Article' );
$m->content_contains($class->Name);
$m->follow_link_ok( { text => $class->Name }, 'Extract Article -> '. $class->Name );
$m->content_like(qr/Select topics for this article/i, 'selecting topic');
$m->form_number(2);
$m->set_visible([option => $topic1->Name]);
$m->submit;
$m->form_number(2);
$m->set_visible([option => $answerCF->Name]);
$m->click();
$m->title_like(qr/Create a new article/, "got edit page from extraction");
$m->submit_form(form_name => 'EditArticle');
$m->title_like(qr/Modify article/);
$m->follow_link_ok( { text => 'Display' }, '-> Display' );
$m->content_like(qr/Africa/, "Article content exist");
$m->content_contains($ticket->Subject,
                     "Article references originating ticket");

diag("Test creating a ticket in Class2 and make sure we don't see Class1 Topics") if $ENV{TEST_VERBOSE};
{
$m->follow_link_ok( { text => 'Articles', url_regex => qr!^/Articles/! },
    'UI -> Articles' );
$m->follow_link_ok( {text => 'New Article' }, 'Articles -> New Article' );
$m->follow_link_ok( {text => 'in class '.$class2->Name }, 'New Article -> in class '.$class2->Name );
$m->content_lacks( $topic1->Name, "Topic1 from Class1 isn't shown" );
$m->content_lacks( $topic11->Name, "Topic11 from Class1 isn't shown" );
$m->content_lacks( $topic12->Name, "Topic12 from Class1 isn't shown" );
$m->content_lacks( $topic2->Name, "Topic2 from Class1 isn't shown" );
$m->content_contains( $gtopic->Name, "Global Topic is shown" );
$m->content_contains( $topic_class2->Name, "Class2 topic is shown" );
}
