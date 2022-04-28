use strict;
use warnings;

use RT::Test tests => undef;

my ( $url, $m ) = RT::Test->started_ok;
ok( $m->login(), 'logged in' );

my $cf = RT::Test->load_or_create_custom_field(
    Name       => 'Notes',
    LookupType => RT::Ticket->CustomFieldLookupType,
    Type       => 'FreeformSingle',
    Queue      => 0,
);
my $txn_cf = RT::Test->load_or_create_custom_field(
    Name       => 'Actor',
    LookupType => RT::Transaction->CustomFieldLookupType,
    Type       => 'FreeformSingle',
    ObjectId   => 0,
);
my ( $ret, $msg ) = $txn_cf->AddToObject( RT::Queue->new( RT->SystemUser ) );
ok( $ret, 'Added txn cf Actor globally' );

my %default_values = (
    InitialPriority                                                       => 50,
    FinalPriority                                                         => 100,
    Starts                                                                => '2022-02-01 12:00:00',
    Due                                                                   => '2022-02-14 12:00:00',
    RT::Interface::Web::GetCustomFieldInputName( CustomField => $cf )     => 'default notes',
    RT::Interface::Web::GetCustomFieldInputName( CustomField => $txn_cf ) => 'default actor',
);

$m->get_ok( $url . '/Admin/Queues/DefaultValues.html?id=1' );
$m->submit_form_ok(
    {
        form_name => 'ModifyDefaultValues',
        fields    => \%default_values,
        button    => 'Update',
    }
);

for my $msg (
    'Default value of InitialPriority changed from (no value) to 50',
    'Default value of FinalPriority changed from (no value) to 100',
    'Default value of Starts changed from (no value) to 2022-02-01 12:00:00',
    'Default value of Due changed from (no value) to 2022-02-14 12:00:00',
    'Default values changed from (no value) to default notes',
    'Default values changed from (no value) to default actor',
    )
{
    $m->text_contains($msg);
}

my $form = $m->form_name('ModifyDefaultValues');
for my $field ( sort keys %default_values ) {
    is( $form->find_input($field)->value, $default_values{$field}, "$field value on default values page" );
}

$m->goto_create_ticket(1);
$form = $m->form_name('TicketCreate');
for my $field ( sort keys %default_values ) {
    is( $form->find_input($field)->value, $default_values{$field}, "$field value on create page" );
}

done_testing;
