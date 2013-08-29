
use warnings;
use strict;

use RT::Test tests => 37;

use_ok('RT::Template');

my $queue = RT::Test->load_or_create_queue( Name => 'Templates' );
ok $queue && $queue->id, "loaded or created a queue";

my $alt_queue = RT::Test->load_or_create_queue( Name => 'Alternative' );
ok $alt_queue && $alt_queue->id, 'loaded or created queue';

{
    my $template = RT::Template->new(RT->SystemUser);
    isa_ok($template, 'RT::Template');
}

{
    my $template = RT::Template->new( RT->SystemUser );
    my ($val,$msg) = $template->Create(
        Queue => $queue->id,
        Name => 'Test',
        Content => 'This is template content'
    );
    ok $val, "created a template" or diag "error: $msg";
    ok my $id = $template->id, "id is defined";
    is $template->Name, 'Test';
    is $template->Content, 'This is template content', "We created the object right";

    ($val, $msg) = $template->SetContent( 'This is new template content');
    ok $val, "changed content" or diag "error: $msg";

    is $template->Content, 'This is new template content', "We managed to _Set_ the content";

    ($val, $msg) = $template->Delete;
    ok $val, "deleted template";

    $template->Load($id);
    ok !$template->id, "can not load template after deletion";
}

note "can not create template w/o Name";
{
    clean_templates( Queue => $queue->id );
    my $template = RT::Template->new( RT->SystemUser );
    my ($val,$msg) = $template->Create( Queue => $queue->id );
    ok(!$val,$msg);
}

note "can not create template with duplicate name";
{
    clean_templates( Queue => $queue->id );
    my $template = RT::Template->new( RT->SystemUser );
    my ($val,$msg) = $template->Create( Queue => $queue->id, Name => 'Test' );
    ok($val,$msg);

    ($val,$msg) = $template->Create( Queue => $queue->id, Name => 'Test' );
    ok(!$val,$msg);
}

note "change template's name";
{
    clean_templates( Queue => $queue->id );
    my $template = RT::Template->new( RT->SystemUser );
    my ($val,$msg) = $template->Create( Queue => $queue->id, Name => 'Test' );
    ok($val,$msg);

    ($val,$msg) = $template->SetName( 'Some' );
    ok($val,$msg);
    is $template->Name, 'Some';
}

note "can not change name to empty";
{
    clean_templates( Queue => $queue->id );
    my $template = RT::Template->new( RT->SystemUser );
    my ($val,$msg) = $template->Create( Queue => $queue->id, Name => 'Test' );
    ok($val,$msg);

    ($val,$msg) = $template->Create( Queue => $queue->id, Name => '' );
    ok(!$val,$msg);
    ($val,$msg) = $template->Create( Queue => $queue->id, Name => undef );
    ok(!$val,$msg);
}

note "can not change name to duplicate";
{
    clean_templates( Queue => $queue->id );
    my $template = RT::Template->new( RT->SystemUser );
    my ($val,$msg) = $template->Create( Queue => $queue->id, Name => 'Test' );
    ok($val,$msg);

    ($val,$msg) = $template->Create( Queue => $queue->id, Name => 'Some' );
    ok($val,$msg);
}

note "changing queue of template is not implemented";
{
    clean_templates( Queue => $queue->id );
    my $template = RT::Template->new( RT->SystemUser );
    my ($val,$msg) = $template->Create( Queue => $queue->id, Name => 'Test' );
    ok($val,$msg);

    ($val,$msg) = $template->SetQueue( $alt_queue->id );
    ok(!$val,$msg);
}

note "make sure template can not be deleted if it has scrips";
{
    clean_templates( Queue => $queue->id );
    my $template = RT::Template->new( RT->SystemUser );
    my ($val,$msg) = $template->Create( Queue => $queue->id, Name => 'Test' );
    ok($val,$msg);

    my $scrip = RT::Scrip->new( RT->SystemUser );
    ($val,$msg) = $scrip->Create(
        Queue => $queue->id,
        ScripCondition => "On Create",
        ScripAction => 'Autoreply To Requestors',
        Template => $template->Name,
    );
    ok($val, $msg);

    ($val, $msg) = $template->Delete;
    ok(!$val,$msg);
}

note "make sure template can be deleted if it's an override";
{
    clean_templates( Queue => $queue->id );
    my $template = RT::Template->new( RT->SystemUser );
    my ($val,$msg) = $template->Create( Queue => $queue->id, Name => 'Overrided' );
    ok($val,$msg);

    $template = RT::Template->new( RT->SystemUser );
    ($val,$msg) = $template->Create( Queue => 0, Name => 'Overrided' );
    ok($val,$msg);

    my $scrip = RT::Scrip->new( RT->SystemUser );
    ($val,$msg) = $scrip->Create(
        Queue => $queue->id,
        ScripCondition => "On Create",
        ScripAction => 'Autoreply To Requestors',
        Template => $template->Name,
    );
    ok($val, $msg);

    ($val, $msg) = $template->Delete;
    ok($val,$msg);
}

note "make sure template can be deleted if it has an override";
{
    clean_templates( Queue => $queue->id );
    my $template = RT::Template->new( RT->SystemUser );
    my ($val,$msg) = $template->Create( Queue => 0, Name => 'Overrided' );
    ok($val,$msg);

    $template = RT::Template->new( RT->SystemUser );
    ($val,$msg) = $template->Create( Queue => $queue->id, Name => 'Overrided' );
    ok($val,$msg);

    my $scrip = RT::Scrip->new( RT->SystemUser );
    ($val,$msg) = $scrip->Create(
        Queue => $queue->id,
        ScripCondition => "On Create",
        ScripAction => 'Autoreply To Requestors',
        Template => $template->Name,
    );
    ok($val, $msg);

    ($val, $msg) = $template->Delete;
    ok($val,$msg);
}


{
    my $t = RT::Template->new(RT->SystemUser);
    $t->Create(Name => "Foo", Queue => $queue->id);
    my $t2 = RT::Template->new(RT->Nobody);
    $t2->Load($t->Id);
    ok($t2->QueueObj->id, "Got the template's queue objet");
}

sub clean_templates {
    my %args = (@_);

    my $templates = RT::Templates->new( RT->SystemUser );
    $templates->Limit( FIELD => 'Queue', VALUE => $args{'Queue'} )
        if defined $args{'Queue'};
    $templates->Limit( FIELD => 'Name', VALUE => $_ )
        foreach ref $args{'Name'}? @{$args{'Name'}} : ($args{'Name'}||());
    while ( my $t = $templates->Next ) {
        my ($status) = $t->Delete;
        unless ( $status ) {
            $_->Delete foreach @{ $t->UsedBy->ItemsArrayRef };
            $t->Delete;
        }
    }
}

