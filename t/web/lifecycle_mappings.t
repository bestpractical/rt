use strict;
use warnings;

BEGIN { require './t/lifecycles/utils.pl' }

my ( $url, $m ) = RT::Test->started_ok;
ok( $m->login(), 'logged in' );

my $sales = RT::Lifecycle->new();
my ( $ret, $msg ) = $sales->Load( Name => 'sales', Type => 'ticket' );
ok $ret, "Loaded lifecycle sales successfully";

my $default = RT::Lifecycle->new();
( $ret, $msg ) = $default->Load( Name => 'default', Type => 'ticket' );
ok $ret, "Loaded lifecycle default successfully";

my $sales_engineering = RT::Lifecycle->new();
( $ret, $msg ) = $sales_engineering->Load( Name => 'sales-engineering', Type => 'ticket' );
ok $ret, "Loaded lifecycle sales_engineering successfully";

diag "Test updating mappings";
{
    $m->get_ok( $url . '/Admin/Lifecycles/Mappings.html?Type=ticket&Name=default' );

    my $form = $m->form_name('ModifyMappings');
    $m->submit_form(
        fields => {
            "map-default--new--sales"      => "initial",
            "map-default--open--sales"     => "active",
            "map-default--resolved--sales" => "inactive",
            "map-sales--initial--default"  => "new",
            "map-sales--active--default"   => "open",
            "map-sales--inactive--default" => "resolved",
            "map-default--deleted--sales"  => "inactive",
            "map-default--rejected--sales" => "inactive",
            "map-default--stalled--sales"  => "active",
            "Name"                         => "default",
            "Type"                         => "ticket",
        },
        button => 'Update'
    );
    $m->content_contains('Lifecycle mappings updated');

    reload_lifecycle();

    my $from = {
        deleted  => "inactive",
        new      => "initial",
        open     => "active",
        rejected => "inactive",
        resolved => "inactive",
        stalled  => "active"
    };

    my $to = {
        active   => "open",
        inactive => "resolved",
        initial  => "new",
    };

    is_deeply( $from, $default->MoveMap($sales), "Move map from default -> sales set correctly" );
    is_deeply( $to,   $sales->MoveMap($default), "Move map from sales -> default set correctly" );

    $from->{'new'} = 'active';

    $m->get_ok( $url . '/Admin/Lifecycles/Mappings.html?Type=ticket&Name=default' );
    $form = $m->form_name('ModifyMappings');
    $m->submit_form(
        fields => {
            "map-default--new--sales"      => "active",
            "map-default--open--sales"     => "active",
            "map-default--resolved--sales" => "inactive",
            "map-sales--initial--default"  => "new",
            "map-sales--active--default"   => "open",
            "map-sales--inactive--default" => "resolved",
            "map-default--deleted--sales"  => "inactive",
            "map-default--rejected--sales" => "inactive",
            "map-default--stalled--sales"  => "active",
            "Name"                         => "default",
            "Type"                         => "ticket",
        },
        button => 'Update'
    );
    $m->content_contains('Lifecycle mappings updated');

    reload_lifecycle();

    is_deeply( $from, $default->MoveMap($sales), "Move map from default -> sales updated correctly" );
}

diag "Confirm the web UI correctly displays mappings";
{
    $m->get_ok( $url . '/Admin/Lifecycles/Mappings.html?Type=ticket&Name=default' );
    my $form = $m->form_name('ModifyMappings');

    my $from = {
        deleted  => "inactive",
        new      => "active",
        open     => "active",
        rejected => "inactive",
        resolved => "inactive",
        stalled  => "active",
    };

    my $to = {
        active   => "open",
        inactive => "resolved",
        initial  => "new",
    };

    my @inputs = $form->inputs;
    foreach my $input (@inputs) {
        my ( $default_from, $default_status, $default_to ) = $input->name =~ /^map-(default)--(.*)--(sales)$/;
        my ( $sales_from,   $sales_status,   $sales_to )   = $input->name =~ /^map-(default)--(.*)--(sales)$/;

        if ($default_from) {
            is( $input->value,
                $from->{$default_status},
                "Mapping set correctly for default -> sales for status: $default_status"
              );
        }
        elsif ($sales_from) {
            is( $input->value, $to->{$sales_status},
                "Mapping set correctly for sales -> default for status: $sales_status" );
        }
    }
}

diag "Test updating sales-engineering mappings";
{
    $m->get_ok( $url . '/Admin/Lifecycles/Mappings.html?Type=ticket&Name=sales-engineering' );

    my $form = $m->form_name('ModifyMappings');
    $m->submit_form(
        fields => {
            "map-sales-engineering--sales--default"       => "new",
            "map-sales-engineering--engineering--default" => "open",
            "map-sales-engineering--rejected--default"    => "rejected",
            "map-sales-engineering--resolved--default"    => "resolved",
            "map-sales-engineering--stalled--default"     => "stalled",
            "map-sales-engineering--deleted--default"     => "deleted",
            "Name"                                        => "sales-engineering",
            "Type"                                        => "ticket",
        },
        button => 'Update'
    );
    $m->content_contains('Lifecycle mappings updated');
    $form = $m->form_name('ModifyMappings');

    my $from = {
        sales       => "new",
        engineering => "open",
        stalled     => "stalled",
        rejected    => "rejected",
        resolved    => "resolved",
        deleted     => "deleted",
    };

    for my $status ( keys %$from ) {
        is( $form->value("map-sales-engineering--$status--default"),
            $from->{$status}, "Mapping set correctly for sales-engineering -> default for status: $status" );
    }

    reload_lifecycle();

    is_deeply(
        $from,
        $sales_engineering->MoveMap($default),
        "Move map from sales_enginnering -> default updated correctly"
    );
}

sub reload_lifecycle {
    # to get rid of the warning of:
    # you're changing config option in a test file when server is active

    RT::Test->stop_server;
    RT->Config->LoadConfigFromDatabase();
    RT::Lifecycle->FillCache();
    ( $url, $m ) = RT::Test->started_ok;
    ok( $m->login(), 'logged in' );
}

done_testing;
