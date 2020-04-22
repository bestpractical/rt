use strict;
use warnings;

use RT::Test tests => undef;
use RT::Dashboard::Mailer;

my $root = RT::Test->load_or_create_user( Name => 'root' );

my ( $baseurl, $m ) = RT::Test->started_ok;
ok( $m->login, 'logged in' );

sub create_dashboard {
    my ($dashboard_name, $suppress_if_empty, $assets) = @_;

    # first, create and populate a "suppress if empty" dashboard
    $m->get_ok('/Dashboards/Modify.html?Create=1');
    $m->form_name('ModifyDashboard');
    $m->field( 'Name' => $dashboard_name );
    $m->click_button( value => 'Create' );

    my ( $dashboard_id ) = ( $m->uri =~ /id=(\d+)/ );
    ok( $dashboard_id, "got a dashboard ID, $dashboard_id" );

    $m->follow_link_ok( { text => 'Content' } );

    my $add_component = sub {
        my $component_name = shift;

        my $payload = {
            "dashboard_id" => $dashboard_id,
            "panes"        => {
                "body" => [
                ],
                "sidebar" => [
                ],
            },
        };

        my $component = {
            "description" => "",
            "name" => "",
            "searchId" => "",
            "searchType" => "",
            "type" => "",
        };

        if ( $component_name eq 'My Tickets' ) {
            my ( $search_id ) = $m->content =~ /data-search-id="(\d+)" data-description="My Tickets"/;
            ok( $search_id, "got an ID for the search, $search_id");

            $component->{type}        = 'system';
            $component->{description} = 'My Tickets';
            $component->{searchId}    = $search_id;
            $component->{name}        = 'My Tickets';
        }
        else {  # component_name is 'My Assets'
            $component->{type}        = 'component';
            $component->{description} = 'MyAssets';
            $component->{name}        = 'MyAssets';
        }

        push @{$payload->{panes}->{body}}, $component;

        my $json = JSON::to_json( $payload );
        my $res  = $m->post(
            $baseurl . '/Helpers/UpdateDashboard',
            [ content => $json ],
        );
        is( $res->code, 200, "added '$component_name' to dashboard '$dashboard_name'" );
    };

    $add_component->('My Tickets') unless $assets;
    $add_component->('MyAssets') if $assets;

    $m->get_ok('/Dashboards/Queries.html?id=' . $dashboard_id);
    $m->follow_link_ok( { text => 'Subscription' } );
    $m->form_name('SubscribeDashboard');
    $m->field( 'Frequency' => 'daily' );
    $m->field( 'Hour'      => '06:00' );

    $m->field( 'SuppressIfEmpty' => 1 ) if $suppress_if_empty;

    $m->click_button( name => 'Save' );
    $m->content_contains("Subscribed to dashboard $dashboard_name");
}

create_dashboard('Suppress if empty', 1);

diag 'no mail since the dashboard is suppressed if empty' if $ENV{'TEST_VERBOSE'};
{
    RT::Dashboard::Mailer->MailDashboards(All => 1);

    my @mails = RT::Test->fetch_caught_mails;
    is @mails, 0, "got no dashboard mail because the dashboard is empty";
}

create_dashboard('Always send', 0);

diag 'one mail since one of two dashboards is suppressed if empty' if $ENV{'TEST_VERBOSE'};
{
    RT::Dashboard::Mailer->MailDashboards(All => 1);

    my @mails = RT::Test->fetch_caught_mails;
    is @mails, 1, "got a dashboard mail from the always-send dashboard";
    my $content = parse_mail( $mails[0] )->bodyhandle->as_string;
    ok($content =~ qr/highest priority tickets I own/);
}

RT::Test->create_ticket(
    Queue     => 'General',
    Subject   => 'a search result!',
    Owner     => $root,
);
RT::Test->fetch_caught_mails; # dump ticket notifications

diag 'two mails since both dashboards now have results' if $ENV{'TEST_VERBOSE'};
{
    RT::Dashboard::Mailer->MailDashboards(All => 1);

    my @mails = RT::Test->fetch_caught_mails;
    is @mails, 2, "got a dashboard mail from the always-send dashboard";

    for my $mail (@mails) {
        my $content = parse_mail( $mail )->bodyhandle->as_string;
        ok($content =~ qr/highest priority tickets I own/);
        ok($content =~ qr/a search result!/);
    }
}

create_dashboard('My Assets', 1, 1);

diag 'two mails since no asset yet' if $ENV{'TEST_VERBOSE'};
{
    RT::Dashboard::Mailer->MailDashboards(All => 1);

    my @mails = RT::Test->fetch_caught_mails;
    is @mails, 2, "got 2 dashboard mails";

    for my $mail (@mails) {
        my $content = parse_mail( $mail )->bodyhandle->as_string;
        ok($content =~ qr/highest priority tickets I own/);
        ok($content =~ qr/a search result!/);
    }
}

my $asset = RT::Asset->new( RT->SystemUser );
my ($ok, $msg) = $asset->Create(
    Catalog     => 'General assets',
    HeldBy      => 'root@localhost',
    Description => 'a computer asset',
);
ok($ok, $msg);

{
    RT::Dashboard::Mailer->MailDashboards(All => 1);

    my @mails = RT::Test->fetch_caught_mails;
    is @mails, 3, "got 3 dashboard mails";
    my @contents = map { parse_mail( $_ )->bodyhandle->as_string } @mails;

    ok($contents[0] =~ qr/highest priority tickets I own/);
    ok($contents[0] =~ qr/a search result!/);
    ok($contents[1] =~ qr/highest priority tickets I own/);
    ok($contents[1] =~ qr/a search result!/);
    ok($contents[2] =~ qr/a computer asset/);
}

done_testing;

