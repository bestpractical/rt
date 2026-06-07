use strict;
use warnings;
use RT::Test::Assets tests => undef, playwright => 1;

my ( $url, $p ) = RT::Test->started_ok;
$p->login();

my $ta = RT::Test->create_ticket( Queue => 'General', Subject => 'rows target a' );
my $tb = RT::Test->create_ticket( Queue => 'General', Subject => 'rows target b' );

my $catalog   = create_catalog( Name => 'Rows Catalog' );
my $asset     = create_asset( Name => 'rows target asset', Catalog => $catalog->id );
my $link_user = RT::Test->load_or_create_user( Name => 'rows-link-user', Privileged => 1 );
ok( $link_user->id, 'created a user to link by name' );

my $link_group = RT::Group->new( RT->SystemUser );
$link_group->CreateUserDefinedGroup( Name => 'rows link group' );
ok( $link_group->id, 'created a group (name has a space) to link by name' );

$p->goto_create_ticket('General');

$p->wait_for_element('div.ticket-info-links .add-links-section .add-link-row');
$p->content_unlike( qr/Separate multiple entries with spaces/, 'inline hint text is gone (moved to the modal)' );

$p->{handle}->await(
    $p->{page}->waitForFunction(
        'document.querySelector("div.ticket-info-links .add-link-row .link-value.tomselected") !== null')
);

my $ta_id = '' . $ta->id;
my $tb_id = '' . $tb->id;

my $row1_ts = 'div.ticket-info-links .add-link-row:first-child .link-value + .ts-wrapper .ts-control input';
$p->{page}->locator($row1_ts)->click();
$p->{page}->locator($row1_ts)->fill($ta_id);
$p->{page}->evaluate(
    'document.querySelector("div.ticket-info-links .add-link-row:first-child .link-value + .ts-wrapper .ts-control input").blur()'
);

my $row2_ts = 'div.ticket-info-links .add-link-row:nth-child(2) .link-value + .ts-wrapper .ts-control input';
$p->{page}->locator($row2_ts)->click();
$p->{page}->locator($row2_ts)->fill($tb_id);
$p->{page}->evaluate(
    'document.querySelector("div.ticket-info-links .add-link-row:nth-child(2) .link-value + .ts-wrapper .ts-control input").blur()'
);

$p->wait_for_element('div.ticket-info-links .add-link-row:nth-child(3)');

my $row1_val = $p->{page}
    ->evaluate('return document.querySelector("div.ticket-info-links .add-link-row:first-child .link-value").value');
my $row2_val = $p->{page}
    ->evaluate('return document.querySelector("div.ticket-info-links .add-link-row:nth-child(2) .link-value").value');
is( $row1_val, $ta_id, "row 1 link-value contains ticket $ta_id" );
is( $row2_val, $tb_id, "row 2 link-value contains ticket $tb_id" );

my $row1_hidden = $p->{page}->evaluate(
    'return document.querySelector("div.ticket-info-links .add-link-row:first-child .link-value-submit").value');
my $row1_name = $p->{page}->evaluate(
    'return document.querySelector("div.ticket-info-links .add-link-row:first-child .link-value-submit").name');
is( $row1_hidden, $ta_id,         "row 1 hidden submit value is the bare ticket id" );
is( $row1_name,   'new-RefersTo', "row 1 hidden submit field is named for the relationship" );

my $set_row = sub {
    my ( $nth, $type, $value, $id ) = @_;
    my $row = "div.ticket-info-links .add-link-row:nth-child($nth)";
    $p->{page}->evaluate(qq{document.querySelector("$row .link-object-type-select").tomselect.setValue("$type")});

    $p->{handle}->await(
        $p->{page}->waitForFunction(
            qq{document.querySelector("$row .link-value") && document.querySelector("$row .link-value").tomselect != null}
        )
    );

    my $opt
        = defined $id
        ? qq{{value:"$value", text:"$value", label:"$value", id:$id}}
        : qq{{value:"$value", text:"$value"}};
    $p->{page}->evaluate(
        qq{const ts = document.querySelector("$row .link-value").tomselect; ts.addOption($opt); ts.addItem("$value");});
};

my $asset_id = '' . $asset->id;
$set_row->( 3, 'asset', $asset_id );
$p->wait_for_element('div.ticket-info-links .add-link-row:nth-child(4)');
my $row3_visible = $p->{page}
    ->evaluate('return document.querySelector("div.ticket-info-links .add-link-row:nth-child(3) .link-value").value');
my $row3_hidden = $p->{page}->evaluate(
    'return document.querySelector("div.ticket-info-links .add-link-row:nth-child(3) .link-value-submit").value');
is( $row3_visible, $asset_id,            "asset row shows the bare asset id" );
is( $row3_hidden,  'asset:' . $asset_id, "asset row hidden submit value carries the asset: prefix" );

my $user_name = $link_user->Name;
$set_row->( 4, 'user', $user_name, $link_user->id );
$p->wait_for_element('div.ticket-info-links .add-link-row:nth-child(5)');
my $row4_visible = $p->{page}
    ->evaluate('return document.querySelector("div.ticket-info-links .add-link-row:nth-child(4) .link-value").value');
my $row4_hidden = $p->{page}->evaluate(
    'return document.querySelector("div.ticket-info-links .add-link-row:nth-child(4) .link-value-submit").value');
is( $row4_visible, $user_name,               "user row shows the bare user name" );
is( $row4_hidden,  'user:' . $link_user->id, "user row hidden submit value is user:<id>, not the name" );

my $group_name = $link_group->Name;
$set_row->( 5, 'group', $group_name, $link_group->id );
$p->wait_for_element('div.ticket-info-links .add-link-row:nth-child(6)');
my $row5_visible = $p->{page}
    ->evaluate('return document.querySelector("div.ticket-info-links .add-link-row:nth-child(5) .link-value").value');
my $row5_hidden = $p->{page}->evaluate(
    'return document.querySelector("div.ticket-info-links .add-link-row:nth-child(5) .link-value-submit").value');
is( $row5_visible, $group_name,                "group row shows the spaced group name" );
is( $row5_hidden,  'group:' . $link_group->id, "group row hidden submit value is group:<id>, not the spaced name" );
unlike( $row5_hidden, qr/\s/, "group row hidden submit value has no whitespace" );

$p->submit_form_ok(
    {   form_name => 'TicketCreate',
        fields    => { Subject => 'created via link rows' },
        button    => 'SubmitTicket',
    },
    'Submit create form with link rows filled'
);

$p->text_like( qr/Ticket \d+ created in queue/, 'landed on ticket display page after create' );

my $tickets = RT::Tickets->new( RT->SystemUser );
$tickets->Limit( FIELD => 'Subject', VALUE => 'created via link rows' );
my $new = $tickets->First;
ok( $new, 'ticket was created' );

SKIP: {
    skip 'ticket not created', 5 unless $new;
    my @refers     = @{ $new->RefersTo->ItemsArrayRef };
    my %target_ids = map { $_->TargetObj->id => 1 } @refers;
    ok( $target_ids{ $ta->id }, 'new ticket refers to target a (row 1)' );
    ok( $target_ids{ $tb->id }, 'new ticket refers to target b (row 2)' );

    my %target_uris = map { $_->TargetURI->URI => 1 } @refers;
    ok( $target_uris{ $asset->URI },      'new ticket refers to the asset (row 3, asset:<id>)' );
    ok( $target_uris{ $link_user->URI },  'new ticket refers to the user (row 4, user:<id>)' );
    ok( $target_uris{ $link_group->URI }, 'new ticket refers to the group (row 5, group:<id> from a spaced name)' );
}

$p->goto_create_ticket('General');
$p->{handle}->await(
    $p->{page}->waitForFunction(
        'document.querySelector("div.ticket-info-links .add-link-row .link-value.tomselected") !== null')
);

my $ctrl      = 'div.ticket-info-links .add-link-row:first-child .link-value + .ts-wrapper .ts-control input';
my $otype_sel = 'div.ticket-info-links .add-link-row:first-child .link-object-type-select';

my $otype_before = $p->{page}->evaluate(qq{return document.querySelector("$otype_sel").value});
is( $otype_before, 'ticket', 'fresh row defaults to the Ticket object type' );

$p->{page}->locator($ctrl)->click();
$p->{page}->locator($ctrl)->fill('user:');
$p->{handle}->await( $p->{page}->waitForFunction(qq{document.querySelector("$otype_sel").value === "user"}) );
pass('typing "user:" switched the row to the User object type');

$p->{page}->locator($ctrl)->fill($user_name);
$p->{page}->evaluate(qq{document.querySelector("$ctrl").blur()});
my $prefix_hidden = $p->{page}->evaluate(
    'return document.querySelector("div.ticket-info-links .add-link-row:first-child .link-value-submit").value');
is( $prefix_hidden, 'user:' . $user_name, 'committed value composes user:<name> after the prefix switch' );

done_testing;
