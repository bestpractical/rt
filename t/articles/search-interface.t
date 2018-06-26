
use strict;
use warnings;

use RT::Test tests => undef;

use RT::CustomField;
use RT::Queue;
use RT::Ticket;
use_ok 'RT::Class';
use_ok 'RT::Topic';
use_ok 'RT::Article';

my ($url, $m) = RT::Test->started_ok;

# Variables to test return values
my ($ret, $msg);

# Create two classes
my $class = RT::Class->new($RT::SystemUser);
($ret, $msg) = $class->Create('Name' => 'First-class',
                              'Description' => 'A general-purpose test class');
ok($ret, "Test class created");

($ret, $msg) = $class->Create('Name' => 'Second-class',
                              'Description' => 'Another class');
ok($ret, "Test class created");

my $questionCF = RT::CustomField->new($RT::SystemUser);
my $answerCF = RT::CustomField->new($RT::SystemUser);
my $ticketCF = RT::CustomField->new($RT::SystemUser);
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

($ret, $msg) = $ticketCF->Create('Name' => 'Class',
                         'Type' => 'Text',
                         'MaxValues' => 1,
                         'LookupType' => 'RT::Queue-RT::Ticket',
                         'Disabled' => 0);
ok($ret, "Ticket CF 'Class' created: $msg");

# Attach the custom fields to our class
($ret, $msg) = $questionCF->AddToObject($class);
ok($ret, "Question CF added to class: $msg");
($ret, $msg) = $answerCF->AddToObject($class);
ok($ret, "Answer CF added to class: $msg");
my ($qid, $aid) = ($questionCF->Id, $answerCF->Id);

my $global_queue = RT::Queue->new($RT::SystemUser);
($ret, $msg) = $ticketCF->AddToObject($global_queue);
ok($ret, "Ticket CF added globally: $msg");

my %cvals = ('article1q' => 'Some question about swallows',
                'article1a' => 'Some answer about Europe and Africa',
                'article2q' => 'Another question about Monty Python',
                'article2a' => 'Romani ite domum',
                'article3q' => 'Why should I eat my supper?',
                'article3a' => 'There are starving children in Africa',
                'article4q' => 'What did Brian originally write?',
                'article4a' => 'This is an answer that is longer than 255 '
             . 'characters so these tests will be sure to use the LargeContent '
             . 'SQL as well as the normal SQL that would be generated if this '
             . 'was an answer that was shorter than 255 characters. This second '
             . 'sentence has a few extra characters to get this string to go '
             . 'over the 255 character boundary. Lorem ipsum.');

# Create an article or two with our custom field values.

my $article1 = RT::Article->new($RT::SystemUser);
my $article2 = RT::Article->new($RT::SystemUser);
my $article3 = RT::Article->new($RT::SystemUser);
my $article4 = RT::Article->new($RT::SystemUser);
($ret, $msg) = $article1->Create(Name => 'First article '.$$,
                                 Summary => 'blah blah 1',
                                 Class => $class->Id,
                                 "CustomField-$qid" => $cvals{'article1q'},
                                 "CustomField-$aid" => $cvals{'article1a'},
                                 );
ok($ret, "article 1 created");
($ret, $msg) = $article2->Create(Name => 'Second article '.$$,
                                 Summary => 'foo bar 2',
                                 Class => $class->Id,
                                 "CustomField-$qid" => $cvals{'article2q'},
                                 "CustomField-$aid" => $cvals{'article2a'},
                                 );
ok($ret, "article 2 created");
($ret, $msg) = $article3->Create(Name => 'Third article '.$$,
                                 Summary => 'ping pong 3',
                                 Class => $class->Id,
                                 "CustomField-$qid" => $cvals{'article3q'},
                                 "CustomField-$aid" => $cvals{'article3a'},
                                 );
ok($ret, "article 3 created");
($ret, $msg) = $article4->Create(Name => 'Fourth article '.$$,
                                 Summary => 'hoi polloi 4',
                                 Class => $class->Id,
                                 "CustomField-$qid" => $cvals{'article4q'},
                                 "CustomField-$aid" => $cvals{'article4a'},
                                 );
ok($ret, "article 4 created");

isa_ok($m, 'Test::WWW::Mechanize');
ok($m->login, 'logged in');
$m->follow_link_ok( { text => 'Articles', url_regex => qr!^/Articles/! },
    'UI -> Articles' );

# In all of the search results below, the results page should
# have the summary text of the article it occurs in.

# Case sensitive search on small field.
DoArticleSearch($m, $class->Name, 'Africa');
$m->text_contains('Search results'); # Did we do a search?
$m->text_contains('blah blah 1');

# Case insensitive search on small field.
DoArticleSearch($m, $class->Name, 'africa');
$m->text_contains('Search results'); # Did we do a search?
$m->text_contains('blah blah 1');

# Case sensitive search on large field.
DoArticleSearch($m, $class->Name, 'ipsum');
$m->text_contains('Search results'); # Did we do a search?
$m->text_contains('hoi polloi 4');

# Case insensitive search on large field.
DoArticleSearch($m, $class->Name, 'lorem');
$m->text_contains('Search results'); # Did we do a search?
TODO:{
    local $TODO = 'Case insensitive search on LONGBLOB not available in MySQL'
      if RT->Config->Get('DatabaseType') eq 'mysql';
    $m->text_contains('hoi polloi 4');
}

done_testing;

# When you send $m to this sub, it must be on a page with
# a Search link.
sub DoArticleSearch{
  my $m = shift;
  my $class_name = shift;
  my $search_text = shift;

  $m->follow_link_ok( {text => 'Articles'}, 'Articles Search');
  $m->follow_link_ok( {text => 'in class '. $class_name}, 'Articles in class '. $class_name);
  $m->text_contains('First article');

  $m->submit_form_ok( {
            form_number => 2,
            fields      => {
                'Article~' => $search_text
            },
        }, "Search for $search_text"
    );
  return;
}

