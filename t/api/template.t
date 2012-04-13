
use warnings;
use strict;

use RT::Test tests => 12;

my $queue = RT::Test->load_or_create_queue( Name => 'Templates' );
ok $queue && $queue->id, "loaded or created a queue";

use_ok('RT::Template');

{
    my $template = RT::Template->new( RT->SystemUser );
    isa_ok($template, 'RT::Template');
    my ($val,$msg) = $template->Create(
        Queue => $queue->id,
        Name => 'InsertTest',
        Content => 'This is template content'
    );
    ok $val, "created a template" or diag "error: $msg";
    ok my $id = $template->id, "id is defined";
    is $template->Name, 'InsertTest';
    is $template->Content, 'This is template content', "We created the object right";

    ($val, $msg) = $template->SetContent( 'This is new template content');
    ok $val, "changed content" or diag "error: $msg";

    is $template->Content, 'This is new template content', "We managed to _Set_ the content";

    ($val, $msg) = $template->Delete;
    ok $val, "deleted template";

    $template->Load($id);
    ok !$template->id, "can not load template after deletion";
}

{
    my $t = RT::Template->new(RT->SystemUser);
    $t->Create(Name => "Foo", Queue => $queue->id);
    my $t2 = RT::Template->new(RT->Nobody);
    $t2->Load($t->Id);
    ok($t2->QueueObj->id, "Got the template's queue objet");
}
