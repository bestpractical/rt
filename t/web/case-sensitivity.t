use strict;
use warnings;

use RT::Test tests => 18;

my $q = RT::Test->load_or_create_queue( Name => 'General' );
ok $q && $q->id, 'loaded or created queue';

my ($root, $root_id);
{
    $root = RT::User->new( RT->SystemUser );
    $root->Load('root');
    ok $root_id = $root->id, 'found root';
}

my ($baseurl, $m) = RT::Test->started_ok;
$m->login;

# test users auto completer
{
    $m->get_ok('/Helpers/Autocomplete/Users?term=eNo');
    require JSON;
    is_deeply(
        JSON::from_json( $m->content ),
        [{id => 14, "value" =>  "root\@localhost","label" => "root (Enoch Root)"}]
    );
}

# test ticket's People page
{
    my $ticket = RT::Test->create_ticket( Queue => $q->id );
    ok $ticket && $ticket->id, "created ticket";

    $m->goto_ticket( $ticket->id );
    $m->follow_link_ok( {text => 'People'} );
    $m->form_number(3);
    $m->select( UserField => 'RealName' );
    $m->field( UserString => 'eNo' );
    $m->click('OnlySearchForPeople');

    my $form = $m->form_number(3);
    my $input = $form->find_input('Ticket-AddWatcher-Principal-'. $root->id );
    ok $input, 'input is there';
}

# test users' admin UI
{
    $m->get_ok('/Admin/Users/');

    $m->form_number(4);
    $m->select( UserField => 'RealName' );
    $m->field( UserString => 'eNo' );
    $m->submit;

    like $m->uri, qr{\QAdmin/Users/Modify.html?id=$root_id\E};
}

# create a cf for testing
my $cf;
{
    $cf = RT::CustomField->new(RT->SystemUser);
    my ($id,$msg) = $cf->Create(
        Name => 'Test',
        Type => 'Select',
        MaxValues => '1',
        Queue => $q->id,
    );
    ok($id,$msg);

    ($id,$msg) = $cf->AddValue(Name => 'Enoch', Description => 'Root');
    ok($id,$msg);
}

# test custom field values auto completer
{
    $m->get_ok('/Helpers/Autocomplete/CustomFieldValues?term=eNo&Object-RT::Ticket--CustomField-'. $cf->id .'-Value&ContextId=1&ContextType=RT::Queue');
    require JSON;
    is_deeply(
        JSON::from_json( $m->content ),
        [{"value" =>  "Enoch","label" => "Enoch (Root)"}]
    );
}

