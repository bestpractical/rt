use strict;
use warnings;

use RT::Test
    tests  => undef,
    config => qq{Set(\$EmailDashboardIncludeCharts, 1);
Set(\@ChromeLaunchArguments, '--no-sandbox');
Set(\$ChromePath, '@{[$ENV{RT_TEST_CHROME_PATH} // '']}');
};

plan skip_all => 'Need WWW::Mechanize::Chrome and a chrome-based browser'
    unless RT::StaticUtil::RequireModule("WWW::Mechanize::Chrome")
    && ( $ENV{RT_TEST_CHROME_PATH} || WWW::Mechanize::Chrome->find_executable('chromium') );

my $root = RT::Test->load_or_create_user( Name => 'root' );

my ( $baseurl, $m ) = RT::Test->started_ok;
ok( $m->login, 'logged in' );
my $ticket = RT::Test->create_ticket(
    Queue   => 'General',
    Subject => 'Test JSChart',
);

$m->get_ok(q{/Search/Chart.html?Query=Subject LIKE 'test JSChart'});
$m->submit_form(
    form_name => 'SaveSearch',
    fields    => {
        SavedSearchName        => 'chart foo',
        SavedSearchDescription => 'chart foo',
        SavedSearchOwner       => $root->id,
        ChartStyle             => 'bar',
    },
    button => 'SavedSearchSave',
);
my $search_id = ($m->form_number(4)->find_input('SavedSearchLoad')->possible_values)[1];

# first, create and populate a dashboard
$m->get_ok('/Dashboards/Modify.html?Create=1');
$m->form_name('ModifyDashboard');
$m->field( 'Name' => 'dashboard foo' );
$m->click_button( value => 'Create' );

my ($dashboard_id) = ( $m->uri =~ /id=(\d+)/ );
ok( $dashboard_id, "Got an ID for the dashboard, $dashboard_id" );

my $content = [
    {
        Layout   => 'col-md-8, col-md-4',
        Elements => [
            [
                {
                    portlet_type => 'search',
                    id           => $search_id,
                    description  => "Transaction: first txn search",
                }
            ],
            [],
        ],
    }
];

my $res = $m->post(
    $baseurl . "/Dashboards/Queries.html?id=$dashboard_id",
    { Update => 1, Content => JSON::encode_json($content) },
);

$m->content_contains('Dashboard updated', "Added 'chart foo' to dashboard" );

$m->follow_link_ok( { text => 'Subscription' } );
$m->form_name('SubscribeDashboard');
$m->field( 'Frequency' => 'daily' );
$m->field( 'Hour'      => '06:00' );
$m->click_button( name => 'Save' );
$m->content_contains('Subscribed to dashboard dashboard foo');

RT::Test->run_and_capture(
    command => $RT::SbinPath . '/rt-email-dashboards',
    all     => 1,
);

my @mails = RT::Test->fetch_caught_mails;
is @mails, 1, "Got a dashboard mail";


# can't use parse_mail here is because it deletes all attachments
# before we can call bodyhandle :/
use RT::EmailParser;
my $parser = RT::EmailParser->new;
my $mail   = $parser->ParseMIMEEntityFromScalar( $mails[0] );
like( $mail->head->get('Subject'), qr/Daily Dashboard: dashboard foo/, 'Mail subject' );

my ($mail_image) = grep { $_->mime_type eq 'image/png' } $mail->parts;
ok( $mail_image, 'Mail contains image attachment' );
require Imager;                                    # Imager is a dependency of WWW::Mechanize::Chrome
my $imager = Imager->new();
$imager->open( data => $mail_image->bodyhandle->as_string, type => 'png' );
is( $imager->bits, 8, 'Image bit depth is 8' );


# The first bar's color is #a6cee3, which is (166, 206, 227),
# on Apple Display preset, it's converted to (174, 205, 225).
# Here we test if each channel is in range
my $bar_color  = $imager->getpixel( x => 300, y => 200 );

ok( $bar_color->red >= 150   && $bar_color->red <= 180,   'Image bar red channel is in range' );
ok( $bar_color->green >= 190 && $bar_color->green <= 220, 'Image bar green channel is in range' );
ok( $bar_color->blue >= 210  && $bar_color->blue <= 240,  'Image bar blue channel is in range' );

done_testing;
