
use Test::More  tests => '6';
use RT;
RT::LoadConfig();
RT::Init();

# when you try to merge duplicate links on postgres, eveyrything goes to hell due to referential integrity constraints.


my $t = RT::Ticket->new($RT::SystemUser);
$t->Create(Subject => 'Main', Queue => 'general');

ok ($t->id);
my $t2 = RT::Ticket->new($RT::SystemUser);
$t2->Create(Subject => 'Second', Queue => 'general');
ok ($t2->id);

my $t3 = RT::Ticket->new($RT::SystemUser);
$t3->Create(Subject => 'Third', Queue => 'general');

ok ($t3->id);

my ($id,$val);
($id,$val) = $t->AddLink(Type => 'DependsOn', Target => $t3->id);
ok($id,$val);
($id,$val) = $t2->AddLink(Type => 'DependsOn', Target => $t3->id);
ok($id,$val);


($id,$val) = $t->MergeInto($t2->id);
ok($id,$val);
