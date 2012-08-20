
use warnings;
use strict;

use RT;
use RT::Test tests => 10;

my $queue = RT::Test->load_or_create_queue( Name => 'Templates' );
ok $queue && $queue->id, "loaded or created a queue";

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
