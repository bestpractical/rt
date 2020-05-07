use strict;
use warnings;
use lib 't/lib';
use RT::Test::REST2 tests => undef;
use Test::Deep;

my $mech = RT::Test::REST2->mech;

my $auth = RT::Test::REST2->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user = RT::Test::REST2->user;

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
my $freeform_cf = RT::CustomField->new(RT->SystemUser);
$freeform_cf->Create(LookupType => 'RT::Queue-RT::Ticket', Name => 'Text CF', Type => 'Freeform', MaxValues => 1, Queue => 'General');

my $ticket = RT::Ticket->new(RT->SystemUser);
$ticket->Create(Queue => 'General', Subject => 'Test ticket with image cf', "CustomField-" . $freeform_cf->id => 'hello world');
$ticket->AddCustomFieldValue(Field => $image_cf->id, Value => 'image.png', ContentType => 'image/png', LargeContent => $image_content);

my $image_ocfv = $ticket->CustomFieldValues('Image CF')->First;
my $text_ocfv = $ticket->CustomFieldValues('Text CF')->First;

# Rights Test - No SeeCustomField
{
    my $res = $mech->get("$rest_base_path/download/cf/" . $image_ocfv->id,
        'Authorization' => $auth,
    );
    is($res->code, 403);
}

$user->PrincipalObj->GrantRight( Right => 'SeeCustomField' );

# Try undef ObjectCustomFieldValue
{
    my $res = $mech->get("$rest_base_path/download/cf/666",
        'Authorization' => $auth,
    );
    is($res->code, 404);
}

# Download cf text
{
    my $res = $mech->get("$rest_base_path/download/cf/" . $text_ocfv->id,
        'Authorization' => $auth,
    );
    is($res->code, 400);
    is($mech->json_response->{message}, 'Only Image and Binary CustomFields can be downloaded');
}

# Download cf image
{
    $user->PrincipalObj->GrantRight( Right => 'SeeCustomField' );
    my $res = $mech->get("$rest_base_path/download/cf/" . $image_ocfv->id,
        'Authorization' => $auth,
    );
    is($res->code, 200);
    is($res->content, $image_content);
}

done_testing;
