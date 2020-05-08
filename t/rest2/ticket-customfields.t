use strict;
use warnings;
use RT::Test::REST2 tests => undef;
use Test::Deep;

# Test using integer priorities
RT->Config->Set(EnablePriorityAsString => 0);
my $mech = RT::Test::REST2->mech;

my $auth = RT::Test::REST2->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Test::REST2->user;

my $queue = RT::Test->load_or_create_queue( Name => "General" );

my $single_cf = RT::CustomField->new( RT->SystemUser );
my ($ok, $msg) = $single_cf->Create( Name => 'Single', Type => 'FreeformSingle', Queue => $queue->Id );
ok($ok, $msg);
my $single_cf_id = $single_cf->Id;

my $multi_cf = RT::CustomField->new( RT->SystemUser );
($ok, $msg) = $multi_cf->Create( Name => 'Multi', Type => 'FreeformMultiple', Queue => $queue->Id );
ok($ok, $msg);
my $multi_cf_id = $multi_cf->Id;

# Ticket Creation with no ModifyCustomField
my ($ticket_url, $ticket_id);
my ($ticket_url_cf_by_name, $ticket_id_cf_by_name);
{
    my $payload = {
        Subject => 'Ticket creation using REST',
        From    => 'test@bestpractical.com',
        To      => 'rt@localhost',
        Queue   => 'General',
        Content => 'Testing ticket creation using REST API.',
        CustomFields => {
            $single_cf_id => 'Hello world!',
        },
    };

    my $payload_cf_by_name = {
        Subject => 'Ticket creation using REST - CF By Name',
        From    => 'test@bestpractical.com',
        To      => 'rt@localhost',
        Queue   => 'General',
        Content => 'Testing ticket creation using REST API.',
        CustomFields => {
            'Single' => 'Hello world! Again.',
        },
    };

    my $payload_cf_by_name_invalid = {
        Subject => 'Ticket creation using REST - CF By Name (Invalid)',
        From    => 'test@bestpractical.com',
        To      => 'rt@localhost',
        Queue   => 'General',
        Content => 'Testing ticket creation using REST API.',
        CustomFields => {
            'Not Existant CF' => 'Hello world!',
        },
    };


    # 4.2.3 introduced a bug (e092e23) in CFs fixed in 4.2.9 (ab7ea15)
    if (   RT::Handle::cmp_version($RT::VERSION, '4.2.3') >= 0
        && RT::Handle::cmp_version($RT::VERSION, '4.2.8') <= 0) {
        delete $payload->{CustomFields};
        delete $payload_cf_by_name->{CustomFields};
    };

    # Rights Test - No CreateTicket
    my $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 403);

    my @warnings;
    local $SIG{__WARN__} = sub {
        push @warnings, @_;
    };

    # Rights Test - With CreateTicket
    $user->PrincipalObj->GrantRight( Right => 'CreateTicket' );
    $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok($ticket_url = $res->header('location'));
    ok(($ticket_id) = $ticket_url =~ qr[/ticket/(\d+)]);

    # Create CF using name, mising right, how to fail it?
    $res = $mech->post_json("$rest_base_path/ticket",
        $payload_cf_by_name,
        'Authorization' => $auth,
    );
    is($res->code, 201);

    # To be able to lookup a CustomField by name, the user needs to have
    # that right.
    $user->PrincipalObj->GrantRight( Right => 'SeeCustomField');

    # Create CF using name
    $res = $mech->post_json("$rest_base_path/ticket",
        $payload_cf_by_name,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok($ticket_url_cf_by_name = $res->header('location'));
    ok(($ticket_id_cf_by_name) = $ticket_url_cf_by_name =~ qr[/ticket/(\d+)]);

    # Create CF using name (invalid)
    $res = $mech->post_json("$rest_base_path/ticket",
        $payload_cf_by_name_invalid,
        'Authorization' => $auth,
    );
    is($res->code, 201);

   TODO: {
       local $TODO = "this warns due to specifying a CF with no permission to see" if RT::Handle::cmp_version($RT::VERSION, '4.4.0') || RT::Handle::cmp_version($RT::VERSION, '4.4.4') >= 0;
       is(@warnings, 0, "no warnings") or diag(join("\n",'warnings : ', @warnings));
   }

    $user->PrincipalObj->RevokeRight( Right => 'SeeCustomField');
}

# Ticket Display
{
    # Rights Test - No ShowTicket
    my $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 403);
}

# Rights Test - With ShowTicket but no SeeCustomField
{
    $user->PrincipalObj->GrantRight( Right => 'ShowTicket' );

    my $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{id}, $ticket_id);
    is($content->{Type}, 'ticket');
    is($content->{Status}, 'new');
    is($content->{Subject}, 'Ticket creation using REST');
    is_deeply($content->{'CustomFields'}, [], 'Ticket custom field not present');
    is_deeply([grep { $_->{ref} eq 'customfield' } @{ $content->{'_hyperlinks'} }], [], 'No CF hypermedia');
}

my $no_ticket_cf_values = bag(
  { name => 'Single', id => $single_cf_id, type => 'customfield', _url => ignore(), values => [] },
  { name => 'Multi',  id => $multi_cf_id,  type => 'customfield', _url => ignore(), values => [] },
);

# Rights Test - Searching asking for CustomFields without SeeCustomField
{
    my $res = $mech->get("$rest_base_path/tickets?query=id>0&fields=Status,Owner,CustomFields,Subject&fields[Owner]=Name",
        'Authorization' => $auth,
    );
    is($res->code, 200);
    my $content = $mech->json_response;
    is(scalar @{$content->{items}}, 4);

    my $ticket = $content->{items}->[0];

    is($ticket->{Status}, 'new');
    is($ticket->{Owner}{Name}, 'Nobody');
    is_deeply($ticket->{CustomFields}, '', 'Ticket custom field not present');
    is($ticket->{Subject}, 'Ticket creation using REST');
    is(scalar keys %$ticket, 7);
}

# Rights Test - With ShowTicket and SeeCustomField
{
    $user->PrincipalObj->GrantRight( Right => 'SeeCustomField');

    # CustomField by Id
    my $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{id}, $ticket_id);
    is($content->{Type}, 'ticket');
    is($content->{Status}, 'new');
    is($content->{Subject}, 'Ticket creation using REST');
    cmp_deeply($content->{CustomFields}, $no_ticket_cf_values, 'No ticket custom field values');
    cmp_deeply(
        [grep { $_->{ref} eq 'customfield' } @{ $content->{'_hyperlinks'} }],
        [{
            ref => 'customfield',
            id  => $single_cf_id,
            name => 'Single',
            type => 'customfield',
            _url => re(qr[$rest_base_path/customfield/$single_cf_id$]),
        }, {
            ref => 'customfield',
            id  => $multi_cf_id,
            name => 'Multi',
            type => 'customfield',
            _url => re(qr[$rest_base_path/customfield/$multi_cf_id$]),
        }],
        'Two CF hypermedia',
    );

    my ($single_url) = map { $_->{_url} } grep { $_->{ref} eq 'customfield' && $_->{id} == $single_cf_id } @{ $content->{'_hyperlinks'} };
    my ($multi_url) = map { $_->{_url} } grep { $_->{ref} eq 'customfield' && $_->{id} == $multi_cf_id } @{ $content->{'_hyperlinks'} };

    $res = $mech->get($single_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    cmp_deeply($mech->json_response, superhashof({
        id         => $single_cf_id,
        Disabled   => 0,
        LookupType => RT::Ticket->CustomFieldLookupType,
        MaxValues  => 1,
    Name       => 'Single',
    Type       => 'Freeform',
    }), 'single cf');

    $res = $mech->get($multi_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    cmp_deeply($mech->json_response, superhashof({
        id         => $multi_cf_id,
        Disabled   => 0,
        LookupType => RT::Ticket->CustomFieldLookupType,
        MaxValues  => 0,
    Name       => 'Multi',
    Type       => 'Freeform',
    }), 'multi cf');

    # CustomField by Name
    $res = $mech->get($ticket_url_cf_by_name,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    $content = $mech->json_response;
    is($content->{id}, $ticket_id_cf_by_name);
    is($content->{Type}, 'ticket');
    is($content->{Status}, 'new');
    is($content->{Subject}, 'Ticket creation using REST - CF By Name');
    cmp_deeply(
        [grep { $_->{ref} eq 'customfield' } @{ $content->{'_hyperlinks'} }],
        [{
            ref => 'customfield',
            id  => $single_cf_id,
            type => 'customfield',
            _url => re(qr[$rest_base_path/customfield/$single_cf_id$]),
            name => 'Single',
        }, {
            ref => 'customfield',
            id  => $multi_cf_id,
            type => 'customfield',
            _url => re(qr[$rest_base_path/customfield/$multi_cf_id$]),
            name => 'Multi',
        }],
        'Two CF hypermedia',
    );
}

# Ticket Update without ModifyCustomField
{
    my $payload = {
        Subject  => 'Ticket update using REST',
        Priority => 42,
        CustomFields => {
            $single_cf_id => 'Modified CF',
        },
    };

    # Rights Test - No ModifyTicket
    my $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
    );
    TODO: {
        local $TODO = "RT ->Update isn't introspectable";
        is($res->code, 403);
    };
    is_deeply($mech->json_response, ['Ticket 1: Permission Denied', 'Ticket 1: Permission Denied', 'Could not add new custom field value: Permission Denied']);

    $user->PrincipalObj->GrantRight( Right => 'ModifyTicket' );

    $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is_deeply($mech->json_response, ["Ticket 1: Priority changed from (no value) to '42'", "Ticket 1: Subject changed from 'Ticket creation using REST' to 'Ticket update using REST'", 'Could not add new custom field value: Permission Denied']);

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{Subject}, 'Ticket update using REST');
    is($content->{Priority}, 42);
    cmp_deeply($content->{CustomFields}, $no_ticket_cf_values, 'No update to CF');
}

# Ticket Update with ModifyCustomField
{
    $user->PrincipalObj->GrantRight( Right => 'ModifyCustomField' );
    my $payload = {
        Subject  => 'More updates using REST',
        Priority => 43,
        CustomFields => {
            $single_cf_id => 'Modified CF',
        },
    };
    my $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is_deeply($mech->json_response, ["Ticket 1: Priority changed from '42' to '43'", "Ticket 1: Subject changed from 'Ticket update using REST' to 'More updates using REST'", 'Single Modified CF added']);

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $modified_single_cf_value = bag(
        { name => 'Single', id => $single_cf_id, type => 'customfield', _url => ignore(), values => ['Modified CF'] },
        { name => 'Multi',  id => $multi_cf_id,  type => 'customfield', _url => ignore(), values => [] },
    );

    my $content = $mech->json_response;
    is($content->{Subject}, 'More updates using REST');
    is($content->{Priority}, 43);
    cmp_deeply($content->{CustomFields}, $modified_single_cf_value, 'New CF value');

    # make sure changing the CF doesn't add a second OCFV
    $payload->{CustomFields}{$single_cf_id} = 'Modified Again';
    $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is_deeply($mech->json_response, ['Single Modified CF changed to Modified Again']);

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $modified_again_single_cf_value = bag(
        { name => 'Single', id => $single_cf_id, type => 'customfield', _url => ignore(), values => ['Modified Again'] },
        { name => 'Multi',  id => $multi_cf_id,  type => 'customfield', _url => ignore(), values => [] },
    );

    $content = $mech->json_response;
    cmp_deeply($content->{CustomFields}, $modified_again_single_cf_value, 'New CF value');

    # stop changing the CF, change something else, make sure CF sticks around
    delete $payload->{CustomFields}{$single_cf_id};
    $payload->{Subject} = 'No CF change';
    $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is_deeply($mech->json_response, ["Ticket 1: Subject changed from 'More updates using REST' to 'No CF change'"]);

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    $content = $mech->json_response;
    cmp_deeply($content->{CustomFields}, $modified_again_single_cf_value, 'Same CF value');

    # fail to delete the CF if mandatory
    $single_cf->SetPattern('(?#Mandatory).');
    $payload->{Subject} = 'Cannot delete mandatory CF';
    $payload->{CustomFields}{$single_cf_id} = undef;
    $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is_deeply($mech->json_response, ["Ticket 1: Subject changed from 'No CF change' to 'Cannot delete mandatory CF'", "Input must match [Mandatory]"]);

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    $content = $mech->json_response;
    cmp_deeply($content->{CustomFields}, $modified_again_single_cf_value, 'Still same CF value');

    # delete the CF
    $single_cf->SetPattern();
    $payload->{Subject} = 'Delete CF';
    $payload->{CustomFields}{$single_cf_id} = undef;
    $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    cmp_deeply($mech->json_response, ["Ticket 1: Subject changed from 'Cannot delete mandatory CF' to 'Delete CF'", 'Modified Again is no longer a value for custom field Single']);

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    $modified_again_single_cf_value = bag(
        { name => 'Single', id => $single_cf_id, type => 'customfield', _url => ignore(), values => [] },
        { name => 'Multi',  id => $multi_cf_id,  type => 'customfield', _url => ignore(), values => [] },
    );
    $content = $mech->json_response;
    cmp_deeply($content->{CustomFields}, $modified_again_single_cf_value, 'No more CF value');
}

# Ticket Comment with custom field
{
    my $payload = {
        Content     => 'This is some content for a comment',
        ContentType => 'text/plain',
        Subject     => 'This is a subject',
        CustomFields => {
            $single_cf_id => 'Yet another modified CF',
        },
    };

    $user->PrincipalObj->GrantRight( Right => 'CommentOnTicket' );

    my $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    my $content = $mech->json_response;

    my ($hypermedia) = grep { $_->{ref} eq 'comment' } @{ $content->{_hyperlinks} };
    ok($hypermedia, 'got comment hypermedia');
    like($hypermedia->{_url}, qr[$rest_base_path/ticket/$ticket_id/comment$]);

    $res = $mech->post_json($mech->url_for_hypermedia('comment'),
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    cmp_deeply($mech->json_response, [re(qr/Comments added|Message recorded/), "Single Yet another modified CF added"]);
}

# Ticket Creation with ModifyCustomField
{
    my $payload = {
        Subject => 'Ticket creation using REST',
        From    => 'test@bestpractical.com',
        To      => 'rt@localhost',
        Queue   => 'General',
        Content => 'Testing ticket creation using REST API.',
        CustomFields => {
            $single_cf_id => 'Hello world!',
        },
    };

    my $payload_cf_by_name = {
        Subject => 'Ticket creation using REST - CF By Name',
        From    => 'test@bestpractical.com',
        To      => 'rt@localhost',
        Queue   => 'General',
        Content => 'Testing ticket creation using REST API.',
        CustomFields => {
            'Single' => 'Hello world! Again.',
        },
    };

    my $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok($ticket_url = $res->header('location'));
    ok(($ticket_id) = $ticket_url =~ qr[/ticket/(\d+)]);

    $res = $mech->post_json("$rest_base_path/ticket",
        $payload_cf_by_name,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok($ticket_url_cf_by_name = $res->header('location'));
    ok(($ticket_id_cf_by_name) = $ticket_url_cf_by_name =~ qr[/ticket/(\d+)]);
}

# Rights Test - With ShowTicket and SeeCustomField
{
    # CustomField by Id
    my $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $ticket_cf_value = bag(
        { name => 'Single', id => $single_cf_id, type => 'customfield', _url => ignore(), values => ['Hello world!'] },
        { name => 'Multi',  id => $multi_cf_id,  type => 'customfield', _url => ignore(), values => [] },
    );

    my $content = $mech->json_response;
    is($content->{id}, $ticket_id);
    is($content->{Type}, 'ticket');
    is($content->{Status}, 'new');
    is($content->{Subject}, 'Ticket creation using REST');
    cmp_deeply($content->{CustomFields}, $ticket_cf_value, 'Ticket custom field');

    # CustomField by Name
    $res = $mech->get($ticket_url_cf_by_name,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    $content = $mech->json_response;
    is($content->{id}, $ticket_id_cf_by_name);
    is($content->{Type}, 'ticket');
    is($content->{Status}, 'new');
    is($content->{Subject}, 'Ticket creation using REST - CF By Name');
}

# Ticket Creation for multi-value CF
for my $value (
    'scalar',
    ['array reference'],
    ['multiple', 'values'],
) {
    my $payload = {
        Subject => 'Multi-value CF',
        Queue   => 'General',
        CustomFields => {
            $multi_cf_id => $value,
        },
    };

    my $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok($ticket_url = $res->header('location'));
    ok(($ticket_id) = $ticket_url =~ qr[/ticket/(\d+)]);

    $res = $mech->get($ticket_url,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $content = $mech->json_response;
    is($content->{id}, $ticket_id);
    is($content->{Type}, 'ticket');
    is($content->{Status}, 'new');
    is($content->{Subject}, 'Multi-value CF');

    my $output = ref($value) ? $value : [$value]; # scalar input comes out as array reference
    my $ticket_cf_value = bag(
        { name => 'Single', id => $single_cf_id, type => 'customfield', _url => ignore(), values => [] },
        { name => 'Multi',  id => $multi_cf_id,  type => 'customfield', _url => ignore(), values => $output },
    );
    cmp_deeply($content->{'CustomFields'}, $ticket_cf_value, 'Ticket custom field');

    # Ticket Show - Fields, custom fields
    {
        $res = $mech->get("$rest_base_path/tickets?query=id>0&fields=Status,Owner,CustomFields,Subject&fields[Owner]=Name",
            'Authorization' => $auth,
        );
        is($res->code, 200);
        my $content = $mech->json_response;

        # Just look at the last one.
        my $ticket = $content->{items}->[-1];

        is($ticket->{Status}, 'new');
        is($ticket->{id}, $ticket_id);
        is($ticket->{Subject}, 'Multi-value CF');
        cmp_deeply($ticket->{'CustomFields'}, $ticket_cf_value, 'Ticket custom field');
    }
}

{
    sub modify_multi_ok {
        local $Test::Builder::Level = $Test::Builder::Level + 1;
        my $input = shift;
        my $messages = shift;
        my $output = shift;
        my $name = shift;

        my $payload = {
            CustomFields => {
                $multi_cf_id => $input,
            },
        };
        my $res = $mech->put_json($ticket_url,
            $payload,
            'Authorization' => $auth,
        );
        is($res->code, 200);
        is_deeply($mech->json_response, $messages);

        $res = $mech->get($ticket_url,
            'Authorization' => $auth,
        );
        is($res->code, 200);

        my $ticket_cf_value = bag(
            { name => 'Single', id => $single_cf_id, type => 'customfield', _url => ignore(), values => [] },
            { name => 'Multi',  id => $multi_cf_id,  type => 'customfield', _url => ignore(), values => bag(@$output) },
        );

        my $content = $mech->json_response;
        cmp_deeply($content->{'CustomFields'}, $ticket_cf_value, $name || 'New CF value');
    }

    # starting point: ['multiple', 'values'],
    modify_multi_ok(['multiple', 'values'], [], ['multiple', 'values'], 'no change');
    modify_multi_ok(['multiple', 'values', 'new'], ['new added as a value for Multi'], ['multiple', 'new', 'values'], 'added "new"');
    modify_multi_ok(['multiple', 'new'], ['values is no longer a value for custom field Multi'], ['multiple', 'new'], 'removed "values"');
    modify_multi_ok('replace all', ['replace all added as a value for Multi', 'multiple is no longer a value for custom field Multi', 'new is no longer a value for custom field Multi'], ['replace all'], 'replaced all values');
    modify_multi_ok([], ['replace all is no longer a value for custom field Multi'], [], 'removed all values');

    if (RT::Handle::cmp_version($RT::VERSION, '4.2.5') >= 0) {
        modify_multi_ok(['foo', 'foo', 'bar'], ['foo added as a value for Multi', undef, 'bar added as a value for Multi'], ['bar', 'foo'], 'multiple values with the same name');
        modify_multi_ok(['foo', 'bar'], [], ['bar', 'foo'], 'multiple values with the same name');
        modify_multi_ok(['bar'], ['foo is no longer a value for custom field Multi'], ['bar'], 'multiple values with the same name');
        modify_multi_ok(['bar', 'bar', 'bar'], [undef, undef], ['bar'], 'multiple values with the same name');
    } else {
        modify_multi_ok(['foo', 'foo', 'bar'], ['foo added as a value for Multi', 'foo added as a value for Multi', 'bar added as a value for Multi'], ['bar', 'foo', 'foo'], 'multiple values with the same name');
        modify_multi_ok(['foo', 'bar'], ['foo is no longer a value for custom field Multi'], ['bar', 'foo'], 'multiple values with the same name');
        modify_multi_ok(['bar'], ['foo is no longer a value for custom field Multi'], ['bar'], 'multiple values with the same name');
        modify_multi_ok(['bar', 'bar', 'bar'], ['bar added as a value for Multi', 'bar added as a value for Multi'], ['bar', 'bar', 'bar'], 'multiple values with the same name');
    }
}

# Ticket Creation with image CF through JSON Base64
my $image_name = 'image.png';
my $image_path = RT::Test::get_relocatable_file($image_name, 'data');
my $image_content;
open my $fh, '<', $image_path or die "Cannot read $image_path: $!\n";
{
    local $/;
    $image_content = <$fh>;
}
close $fh;
my $image_cf = RT::CustomField->new(RT->SystemUser);
$image_cf->Create(LookupType => 'RT::Queue-RT::Ticket', Name => 'Image CF', Type => 'Image', MaxValues => 1, Queue => 'General');
my $image_cf_id = $image_cf->id;
{
    my $payload = {
        Subject => 'Ticket creation with image CF',
        From    => 'test@bestpractical.com',
        To      => 'rt@localhost',
        Queue   => 'General',
        Content => 'Testing ticket creation with Base64 encoded Image Custom Field using REST API.',
        CustomFields => {
            $image_cf_id => {
                FileName => $image_name,
                FileType => 'image/png',
                FileContent => MIME::Base64::encode_base64($image_content),
            },
        },
    };

    my $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok($ticket_url = $res->header('location'));
    ok(($ticket_id) = $ticket_url =~ qr[/ticket/(\d+)]);

    my $ticket = RT::Ticket->new($user);
    $ticket->Load($ticket_id);
    my $image_ocfv = $ticket->CustomFieldValues('Image CF')->First;
    is($image_ocfv->Content, $image_name);
    is($image_ocfv->ContentType, 'image/png');
    is($image_ocfv->LargeContent, $image_content);
}

# Ticket Update with image CF through JSON Base64
{
    # Ticket update to delete image CF
    my $payload = {
        CustomFields => {
            $image_cf_id => undef,
        },
    };

    my $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    my $ticket = RT::Ticket->new($user);
    $ticket->Load($ticket_id);
    my $image_ocfv = $ticket->CustomFieldValues('Image CF')->First;
    is($image_ocfv, undef);

    # Ticket update with a value for image CF
    $payload = {
        Subject => 'Ticket with image CF',
        CustomFields => {
            $image_cf_id => {
                FileName => $image_name,
                FileType => 'image/png',
                FileContent => MIME::Base64::encode_base64($image_content),
            },
        },
    };

    $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is_deeply($mech->json_response, ["Ticket $ticket_id: Subject changed from 'Ticket creation with image CF' to 'Ticket with image CF'", "Image CF $image_name added"]);

    $ticket = RT::Ticket->new($user);
    $ticket->Load($ticket_id);
    $image_ocfv = $ticket->CustomFieldValues('Image CF')->First;
    is($image_ocfv->Content, $image_name);
    is($image_ocfv->ContentType, 'image/png');
    is($image_ocfv->LargeContent, $image_content);
}

# Ticket Creation with multi-value image CF through JSON Base64
my $multi_image_cf = RT::CustomField->new(RT->SystemUser);
$multi_image_cf->Create(LookupType => 'RT::Queue-RT::Ticket', Name => 'Multi Image CF', Type => 'Image', MaxValues => 0, Queue => 'General');
my $multi_image_cf_id = $multi_image_cf->id;
{
    my $payload = {
        Subject => 'Ticket creation with multi-value image CF',
        From    => 'test@bestpractical.com',
        To      => 'rt@localhost',
        Queue   => 'General',
        Content => 'Testing ticket creation with Base64 encoded Multi-Value Image Custom Field using REST API.',
        CustomFields => {
            $multi_image_cf_id => [
                {
                    FileName => $image_name,
                    FileType => 'image/png',
                    FileContent => MIME::Base64::encode_base64($image_content),
                },
                {
                    FileName => 'Duplicate',
                    FileType => 'image/png',
                    FileContent => MIME::Base64::encode_base64($image_content),
                },
            ],
        },
    };

    my $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok($ticket_url = $res->header('location'));
    ok(($ticket_id) = $ticket_url =~ qr[/ticket/(\d+)]);

    my $ticket = RT::Ticket->new($user);
    $ticket->Load($ticket_id);
    my @multi_image_ocfvs = @{$ticket->CustomFieldValues('Multi Image CF')->ItemsArrayRef};
    is(scalar(@multi_image_ocfvs), 2);
    is($multi_image_ocfvs[0]->Content, $image_name);
    is($multi_image_ocfvs[0]->ContentType, 'image/png');
    is($multi_image_ocfvs[0]->LargeContent, $image_content);
    is($multi_image_ocfvs[1]->Content, 'Duplicate');
    is($multi_image_ocfvs[1]->ContentType, 'image/png');
    is($multi_image_ocfvs[1]->LargeContent, $image_content);
}

# Ticket Update with multi-value image CF through JSON Base64
{
    # Ticket Creation with empty multi-value image CF
    my $payload = {
        Subject => 'Ticket creation with empty multi-value image CF',
        From    => 'test@bestpractical.com',
        To      => 'rt@localhost',
        Queue   => 'General',
        Content => 'Testing ticket creation with Base64 encoded Multi-Value Image Custom Field using REST API.',
    };

    my $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok($ticket_url = $res->header('location'));
    ok(($ticket_id) = $ticket_url =~ qr[/ticket/(\d+)]);

    my $ticket = RT::Ticket->new($user);
    $ticket->Load($ticket_id);
    my $multi_image_ocfvs = $ticket->CustomFieldValues('Multi Image CF');
    is($multi_image_ocfvs->Count, 0);

    # Ticket update with two values for multi-value image CF
    $payload = {
        Subject => 'Ticket with multi-value image CF',
        CustomFields => {
            $multi_image_cf_id => [
                {
                    FileName => $image_name,
                    FileType => 'image/png',
                    FileContent => MIME::Base64::encode_base64($image_content),
                },
                {
                    FileName => 'Duplicate',
                    FileType => 'image/png',
                    FileContent => MIME::Base64::encode_base64($image_content),
                },
            ],
        },
    };

    $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is_deeply($mech->json_response, ["Ticket $ticket_id: Subject changed from 'Ticket creation with empty multi-value image CF' to 'Ticket with multi-value image CF'", "$image_name added as a value for Multi Image CF", "Duplicate added as a value for Multi Image CF"]);

    $ticket = RT::Ticket->new($user);
    $ticket->Load($ticket_id);
    my @multi_image_ocfvs = @{$ticket->CustomFieldValues('Multi Image CF')->ItemsArrayRef};
    is(scalar(@multi_image_ocfvs), 2);
    is($multi_image_ocfvs[0]->Content, $image_name);
    is($multi_image_ocfvs[0]->ContentType, 'image/png');
    is($multi_image_ocfvs[0]->LargeContent, $image_content);
    is($multi_image_ocfvs[1]->Content, 'Duplicate');
    is($multi_image_ocfvs[1]->ContentType, 'image/png');
    is($multi_image_ocfvs[1]->LargeContent, $image_content);

    # Ticket update with deletion of one value for multi-value image CF
    $payload = {
        Subject => 'Ticket with deletion of one value for multi-value image CF',
        CustomFields => {
            $multi_image_cf_id => [ $image_name ],
        },
    };

    $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is_deeply($mech->json_response, ["Ticket $ticket_id: Subject changed from 'Ticket with multi-value image CF' to 'Ticket with deletion of one value for multi-value image CF'", "Duplicate is no longer a value for custom field Multi Image CF"]);

    $ticket = RT::Ticket->new($user);
    $ticket->Load($ticket_id);
    @multi_image_ocfvs = @{$ticket->CustomFieldValues('Multi Image CF')->ItemsArrayRef};
    is(scalar(@multi_image_ocfvs), 1);
    is($multi_image_ocfvs[0]->Content, $image_name);
    is($multi_image_ocfvs[0]->ContentType, 'image/png');
    is($multi_image_ocfvs[0]->LargeContent, $image_content);

    # Ticket update with non-unique values for multi-value image CF
    $payload = {
        Subject => 'Ticket with non-unique values for multi-value image CF',
        CustomFields => {
            $multi_image_cf_id => [
                {
                    FileName => $image_name,
                    FileType => 'image/png',
                    FileContent => MIME::Base64::encode_base64($image_content),
                },
                $image_name,
                {
                    FileName => 'Duplicate',
                    FileType => 'image/png',
                    FileContent => MIME::Base64::encode_base64($image_content),
                },
            ],
        },
    };

    $res = $mech->put_json($ticket_url,
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 200);

    $ticket = RT::Ticket->new($user);
    $ticket->Load($ticket_id);
    @multi_image_ocfvs = @{$ticket->CustomFieldValues('Multi Image CF')->ItemsArrayRef};

    if (RT::Handle::cmp_version($RT::VERSION, '4.2.5') >= 0) {
        is_deeply($mech->json_response, ["Ticket $ticket_id: Subject changed from 'Ticket with deletion of one value for multi-value image CF' to 'Ticket with non-unique values for multi-value image CF'", undef, "Duplicate added as a value for Multi Image CF"]);
        is(scalar(@multi_image_ocfvs), 2);
        is($multi_image_ocfvs[0]->Content, $image_name);
        is($multi_image_ocfvs[0]->ContentType, 'image/png');
        is($multi_image_ocfvs[0]->LargeContent, $image_content);
        is($multi_image_ocfvs[1]->Content, 'Duplicate');
        is($multi_image_ocfvs[1]->ContentType, 'image/png');
        is($multi_image_ocfvs[1]->LargeContent, $image_content);
    } else {
        is_deeply($mech->json_response, ["Ticket $ticket_id: Subject changed from 'Ticket with deletion of one value for multi-value image CF' to 'Ticket with non-unique values for multi-value image CF'", "$image_name added as a value for Multi Image CF", "Duplicate added as a value for Multi Image CF"]);
        is(scalar(@multi_image_ocfvs), 3);
        is($multi_image_ocfvs[0]->Content, $image_name);
        is($multi_image_ocfvs[0]->ContentType, 'image/png');
        is($multi_image_ocfvs[0]->LargeContent, $image_content);
        is($multi_image_ocfvs[1]->Content, $image_name);
        is($multi_image_ocfvs[1]->ContentType, 'image/png');
        is($multi_image_ocfvs[1]->LargeContent, $image_content);
        is($multi_image_ocfvs[2]->Content, 'Duplicate');
        is($multi_image_ocfvs[2]->ContentType, 'image/png');
        is($multi_image_ocfvs[2]->LargeContent, $image_content);
    }
}

# Ticket Creation with image CF through multipart/form-data
my $json = JSON->new->utf8;
{
    my $payload = {
        Subject => 'Ticket creation with image CF',
        From    => 'test@bestpractical.com',
        To      => 'rt@localhost',
        Queue   => 'General',
        Content => 'Testing ticket creation with multipart/form-data Image Custom Field using REST API.',
        CustomFields => {
            $image_cf_id => { UploadField => 'IMAGE' },
        },
    };
    no warnings 'once';
    $HTTP::Request::Common::DYNAMIC_FILE_UPLOAD = 1;

    my $res = $mech->post("$rest_base_path/ticket",
        'Authorization' => $auth,
        'Content_Type'  => 'form-data',
        'Content'       => [
            'JSON'  => $json->encode($payload),
            'IMAGE' => [$image_path, $image_name, 'Content-Type' => 'image/png'],
        ]
    );
    is($res->code, 201);
    ok($ticket_url = $res->header('location'));
    ok(($ticket_id) = $ticket_url =~ qr[/ticket/(\d+)]);

    my $ticket = RT::Ticket->new($user);
    $ticket->Load($ticket_id);
    my $image_ocfv = $ticket->CustomFieldValues('Image CF')->First;
    is($image_ocfv->Content, $image_name);
    is($image_ocfv->ContentType, 'image/png');
    is($image_ocfv->LargeContent, $image_content);
}

# Ticket Update with image CF through multipart/form-data
{
    # Ticket Creation with empty image CF
    my $payload = {
        Subject => 'Ticket creation with empty image CF',
        From    => 'test@bestpractical.com',
        To      => 'rt@localhost',
        Queue   => 'General',
        Content => 'Testing ticket update with multipart/form-data Image Custom Field using REST API.',
    };

    my $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok($ticket_url = $res->header('location'));
    ok(($ticket_id) = $ticket_url =~ qr[/ticket/(\d+)]);

    my $ticket = RT::Ticket->new($user);
    $ticket->Load($ticket_id);
    my $image_ocfv = $ticket->CustomFieldValues('Image CF')->First;
    is($image_ocfv, undef);

    # Ticket update with a value for image CF
    $payload = {
        Subject => 'Ticket with image CF',
        CustomFields => {
            $image_cf_id => { UploadField => 'IMAGE' },
        },
    };
    no warnings 'once';
    $HTTP::Request::Common::DYNAMIC_FILE_UPLOAD = 1;

    $res = $mech->put("$ticket_url",
        'Authorization' => $auth,
        'Content_Type'  => 'form-data',
        'Content'       => [
            'JSON'  => $json->encode($payload),
            'IMAGE' => [$image_path, $image_name, 'Content-Type' => 'image/png'],
        ]
    );

    is($res->code, 200);
    is_deeply($mech->json_response, ["Ticket $ticket_id: Subject changed from 'Ticket creation with empty image CF' to 'Ticket with image CF'", "Image CF $image_name added"]);

    $ticket = RT::Ticket->new($user);
    $ticket->Load($ticket_id);
    $image_ocfv = $ticket->CustomFieldValues('Image CF')->First;
    is($image_ocfv->Content, $image_name);
    is($image_ocfv->ContentType, 'image/png');
    is($image_ocfv->LargeContent, $image_content);
}

# Ticket Creation with multi-value image CF through multipart/form-data
{
    my $payload = {
        Subject => 'Ticket creation with multi-value image CF',
        From    => 'test@bestpractical.com',
        To      => 'rt@localhost',
        Queue   => 'General',
        Content => 'Testing ticket creation with multipart/form-data Multi-Value Image Custom Field using REST API.',
        CustomFields => {
            $multi_image_cf_id => [ { UploadField => 'IMAGE_1' }, { UploadField => 'IMAGE_2' } ],
        },
    };

    my $res = $mech->post("$rest_base_path/ticket",
        'Authorization' => $auth,
        'Content_Type'  => 'form-data',
        'Content'       => [
            'JSON'  => $json->encode($payload),
            'IMAGE_1' => [$image_path, $image_name, 'Content-Type' => 'image/png'],
            'IMAGE_2' => [$image_path, 'Duplicate', 'Content-Type' => 'image/png'],
        ]
    );
    is($res->code, 201);
    ok($ticket_url = $res->header('location'));
    ok(($ticket_id) = $ticket_url =~ qr[/ticket/(\d+)]);

    my $ticket = RT::Ticket->new($user);
    $ticket->Load($ticket_id);
    my @multi_image_ocfvs = @{$ticket->CustomFieldValues('Multi Image CF')->ItemsArrayRef};
    is(scalar(@multi_image_ocfvs), 2);
    is($multi_image_ocfvs[0]->Content, $image_name);
    is($multi_image_ocfvs[0]->ContentType, 'image/png');
    is($multi_image_ocfvs[0]->LargeContent, $image_content);
    is($multi_image_ocfvs[1]->Content, 'Duplicate');
    is($multi_image_ocfvs[1]->ContentType, 'image/png');
    is($multi_image_ocfvs[1]->LargeContent, $image_content);
}

# Ticket Update with multi-value image CF through multipart/form-data
{
    # Ticket Creation with empty multi-value image CF
    my $payload = {
        Subject => 'Ticket creation with empty multi-value image CF',
        From    => 'test@bestpractical.com',
        To      => 'rt@localhost',
        Queue   => 'General',
        Content => 'Testing ticket creation with multipart/form-data Multi-Value Image Custom Field using REST API.',
    };

    my $res = $mech->post_json("$rest_base_path/ticket",
        $payload,
        'Authorization' => $auth,
    );
    is($res->code, 201);
    ok($ticket_url = $res->header('location'));
    ok(($ticket_id) = $ticket_url =~ qr[/ticket/(\d+)]);

    my $ticket = RT::Ticket->new($user);
    $ticket->Load($ticket_id);
    my $multi_image_ocfvs = $ticket->CustomFieldValues('Multi Image CF');
    is($multi_image_ocfvs->Count, 0);

    # Ticket update with two values for multi-value image CF
    $payload = {
        Subject => 'Ticket with multi-value image CF',
        CustomFields => {
            $multi_image_cf_id => [ { UploadField => 'IMAGE_1' }, { UploadField => 'IMAGE_2' } ],
        },
    };

    $res = $mech->put($ticket_url,
        'Authorization' => $auth,
        'Content_Type'  => 'form-data',
        'Content'       => [
            'JSON'  => $json->encode($payload),
            'IMAGE_1' => [$image_path, $image_name, 'Content-Type' => 'image/png'],
            'IMAGE_2' => [$image_path, 'Duplicate', 'Content-Type' => 'image/png'],
        ]
    );
    is($res->code, 200);
    is_deeply($mech->json_response, ["Ticket $ticket_id: Subject changed from 'Ticket creation with empty multi-value image CF' to 'Ticket with multi-value image CF'", "$image_name added as a value for Multi Image CF", "Duplicate added as a value for Multi Image CF"]);

    $ticket = RT::Ticket->new($user);
    $ticket->Load($ticket_id);
    my @multi_image_ocfvs = @{$ticket->CustomFieldValues('Multi Image CF')->ItemsArrayRef};
    is(scalar(@multi_image_ocfvs), 2);
    is($multi_image_ocfvs[0]->Content, $image_name);
    is($multi_image_ocfvs[0]->ContentType, 'image/png');
    is($multi_image_ocfvs[0]->LargeContent, $image_content);
    is($multi_image_ocfvs[1]->Content, 'Duplicate');
    is($multi_image_ocfvs[1]->ContentType, 'image/png');
    is($multi_image_ocfvs[1]->LargeContent, $image_content);

    # Ticket update with deletion of one value for multi-value image CF
    $payload = {
        Subject => 'Ticket with deletion of one value for multi-value image CF',
        CustomFields => {
            $multi_image_cf_id => [ $image_name ],
        },
    };

    $res = $mech->put($ticket_url,
        'Authorization' => $auth,
        'Content_Type'  => 'form-data',
        'Content'       => [
            'JSON'  => $json->encode($payload),
        ]
    );
    is($res->code, 200);
    is_deeply($mech->json_response, ["Ticket $ticket_id: Subject changed from 'Ticket with multi-value image CF' to 'Ticket with deletion of one value for multi-value image CF'", "Duplicate is no longer a value for custom field Multi Image CF"]);

    $ticket = RT::Ticket->new($user);
    $ticket->Load($ticket_id);
    @multi_image_ocfvs = @{$ticket->CustomFieldValues('Multi Image CF')->ItemsArrayRef};
    is(scalar(@multi_image_ocfvs), 1);
    is($multi_image_ocfvs[0]->Content, $image_name);
    is($multi_image_ocfvs[0]->ContentType, 'image/png');
    is($multi_image_ocfvs[0]->LargeContent, $image_content);

    # Ticket update with non-unique values for multi-value image CF
    $payload = {
        Subject => 'Ticket with non-unique values for multi-value image CF',
        CustomFields => {
            $multi_image_cf_id => [ { UploadField => 'IMAGE_1' }, $image_name, { UploadField => 'IMAGE_2' } ],
        },
    };

    $res = $mech->put($ticket_url,
        'Authorization' => $auth,
        'Content_Type'  => 'form-data',
        'Content'       => [
            'JSON'  => $json->encode($payload),
            'IMAGE_1' => [$image_path, $image_name, 'Content-Type' => 'image/png'],
            'IMAGE_2' => [$image_path, 'Duplicate', 'Content-Type' => 'image/png'],
        ]
    );
    is($res->code, 200);

    $ticket = RT::Ticket->new($user);
    $ticket->Load($ticket_id);
    @multi_image_ocfvs = @{$ticket->CustomFieldValues('Multi Image CF')->ItemsArrayRef};

    if (RT::Handle::cmp_version($RT::VERSION, '4.2.5') >= 0) {
        is_deeply($mech->json_response, ["Ticket $ticket_id: Subject changed from 'Ticket with deletion of one value for multi-value image CF' to 'Ticket with non-unique values for multi-value image CF'", undef, "Duplicate added as a value for Multi Image CF"]);
        is(scalar(@multi_image_ocfvs), 2);
        is($multi_image_ocfvs[0]->Content, $image_name);
        is($multi_image_ocfvs[0]->ContentType, 'image/png');
        is($multi_image_ocfvs[0]->LargeContent, $image_content);
        is($multi_image_ocfvs[1]->Content, 'Duplicate');
        is($multi_image_ocfvs[1]->ContentType, 'image/png');
        is($multi_image_ocfvs[1]->LargeContent, $image_content);
    } else {
        is_deeply($mech->json_response, ["Ticket $ticket_id: Subject changed from 'Ticket with deletion of one value for multi-value image CF' to 'Ticket with non-unique values for multi-value image CF'", "$image_name added as a value for Multi Image CF", "Duplicate added as a value for Multi Image CF"]);
        is(scalar(@multi_image_ocfvs), 3);
        is($multi_image_ocfvs[0]->Content, $image_name);
        is($multi_image_ocfvs[0]->ContentType, 'image/png');
        is($multi_image_ocfvs[0]->LargeContent, $image_content);
        is($multi_image_ocfvs[1]->Content, $image_name);
        is($multi_image_ocfvs[1]->ContentType, 'image/png');
        is($multi_image_ocfvs[1]->LargeContent, $image_content);
        is($multi_image_ocfvs[2]->Content, 'Duplicate');
        is($multi_image_ocfvs[2]->ContentType, 'image/png');
        is($multi_image_ocfvs[2]->LargeContent, $image_content);
    }
}

done_testing;

