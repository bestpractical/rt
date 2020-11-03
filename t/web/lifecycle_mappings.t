use strict;
use warnings;

BEGIN {require './t/lifecycles/utils.pl'};

my ( $url, $m ) = RT::Test->started_ok;

diag "Test updating mappings";
{
    ok( $m->login( 'root', 'password' ), 'logged in' );

    $m->get_ok( $url . '/Admin/Lifecycles/Mappings.html?Type=ticket&Name=default' );

    my $form = $m->form_name('ModifyMappings');
    $m->submit_form(
        fields => {
            "map-default--new--foo"      => "initial",
            "map-default--open--foo"     => "active",
            "map-default--resolved--foo" => "inactive",
            "map-foo--initial--default"  => "new",
            "map-foo--active--default"   => "open",
            "map-foo--inactive--default" => "resolved",
            "map-default--deleted--foo"  => "inactive",
            "map-default--rejected--foo" => "inactive",
            "map-default--stalled--foo"  => "active",
            "Name"                       => "default",
            "Type"                       => "ticket",
        },
        button => 'Update'
    );
    $m->content_contains( 'Lifecycle mappings updated' );

    RT::Test->stop_server;
    RT->Config->LoadConfigFromDatabase();
    ( $url, $m ) = RT::Test->started_ok;
    ok( $m->login( 'root', 'password' ), 'logged in' );

    RT::Lifecycle->FillCache();

    my $foo = RT::Lifecycle->new();
    my ($ret, $msg) = $foo->Load( Name => 'foo', Type => 'ticket' );
    ok $ret, "Loaded lifecycle foo successfully";

    my $default = RT::Lifecycle->new();
    ($ret, $msg) = $default->Load( Name => 'default', Type => 'ticket' );
    ok $ret, "Loaded lifecycle default successfully";

    my $from = {
        deleted    => "inactive",
        new        => "initial",
        open       => "active",
        rejected   => "inactive",
        resolved   => "inactive",
        stalled    => "active"
    };

    my $to = {
        active     => "open",
        inactive   => "resolved",
        initial    => "new",
    };

    is_deeply( $from, $default->MoveMap( $foo ), "Move map from default -> foo set correctly" );
    is_deeply( $to, $foo->MoveMap( $default ), "Move map from foo -> default set correctly" );

    $from->{'new'} = 'active';

    $m->get_ok( $url . '/Admin/Lifecycles/Mappings.html?Type=ticket&Name=default' );
    $form = $m->form_name('ModifyMappings');
    $m->submit_form(
        fields => {
            "map-default--new--foo"      => "active",
            "map-default--open--foo"     => "active",
            "map-default--resolved--foo" => "inactive",
            "map-foo--initial--default"  => "new",
            "map-foo--active--default"   => "open",
            "map-foo--inactive--default" => "resolved",
            "map-default--deleted--foo"  => "inactive",
            "map-default--rejected--foo" => "inactive",
            "map-default--stalled--foo"  => "active",
            "Name"                       => "default",
            "Type"                       => "ticket",
        },
        button => 'Update'
    );
    $m->content_contains( 'Lifecycle mappings updated' );

    RT::Test->stop_server;
    RT->Config->LoadConfigFromDatabase();
    ( $url, $m ) = RT::Test->started_ok;
    RT::Lifecycle->FillCache();

    is_deeply( $from, $default->MoveMap( $foo ), "Move map from default -> foo updated correctly" );
}

diag "Confirm the web UI correctly displays mappings";
{
    ok( $m->login( 'root', 'password' ), 'logged in' );

    $m->get_ok( $url . '/Admin/Lifecycles/Mappings.html?Type=ticket&Name=default' );
    my $form = $m->form_name('ModifyMappings');

    my $from = {
        deleted    => "inactive",
        new        => "active",
        open       => "active",
        rejected   => "inactive",
        resolved   => "inactive",
        stalled    => "active"
    };

    my $to = {
        active     => "open",
        inactive   => "resolved",
        initial    => "new",
    };

    my @inputs = $form->inputs;
    foreach my $input ( @inputs ) {
        my ($default_from, $default_status, $default_to) = $input->name =~ /^map-(default)--(.*)--(foo)$/;
        my ($foo_from, $foo_status, $foo_to) = $input->name =~ /^map-(default)--(.*)--(foo)$/;

        if ( $default_from ) {
            is ($input->value, $from->{$default_status}, "Mapping set correctly for default -> foo for status: $default_status" );
        }
        elsif ( $foo_from ) {
            is ( $input->value, $to->{$foo_status}, "Mapping set correctly for foo -> default for status: $foo_status" );
        }
    }
}

diag "Test updating sales-engineering mappings";
{
    ok( $m->login( 'root', 'password' ), 'logged in' );

    $m->get_ok( $url . '/Admin/Lifecycles/Mappings.html?Type=ticket&Name=sales-engineering' );

    my $form = $m->form_name('ModifyMappings');
    $m->submit_form(
        fields => {
            "map-sales-engineering--sales--default"       => "new",
            "map-sales-engineering--engineering--default" => "new", # Mapping we are changing
            "map-sales-engineering--rejected--default"    => "rejected",
            "map-sales-engineering--resolved--default"    => "resolved",
            "map-sales-engineering--stalled--default"     => "stalled",
            "Name"                                        => "sales-engineering",
            "Type"                                        => "ticket",
        },
        button => 'Update'
    );
    $m->content_contains( 'Lifecycle mappings updated' );
    $form = $m->form_name('ModifyMappings');

    my $from = {
        sales        => "new",
        engineering  => "new", # Changed mapping
        stalled      => "stalled",
        rejected     => "rejected",
        resolved     => "resolved",
        deleted      => "deleted",
    };

    # Ensure that the UI correctly reflects the changes we made
    my @inputs = $form->inputs;
    foreach my $input ( @inputs ) {
        my ($sales_engineering, $status, $to) = $input->name =~ /^map-(sales-engineering)--(.*)--(default)$/;
        next unless $from && $status && $to;
        is ($input->value, $from->{$status}, "Mapping set correctly for sales-engineering -> default for status: $status" );
        delete $from->{$status};
    }
    ok scalar keys %{$from} eq 0, "Checked all sales-engineering -> default mappings.";
}

done_testing;
