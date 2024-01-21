use strict;
use warnings;

use RT::Test
    tests  => undef,
    config => qq{Set(\$EmailDashboardJSChartImages, 1);
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
        SavedSearchDescription => 'chart foo',
        SavedSearchOwner       => 'RT::User-' . $root->id,
        ChartStyle             => 'bar',
    },
    button => 'SavedSearchSave',
);

# first, create and populate a dashboard
$m->get_ok('/Dashboards/Modify.html?Create=1');
$m->form_name('ModifyDashboard');
$m->field( 'Name' => 'dashboard foo' );
$m->click_button( value => 'Create' );

my ($dashboard_id) = ( $m->uri =~ /id=(\d+)/ );
ok( $dashboard_id, "Got an ID for the dashboard, $dashboard_id" );

$m->follow_link_ok( { text => 'Content' } );

# add content, Chart: chart foo, to dashboard body
# we need to get the saved search id from the content before submitting the form.
my $regex = qr/data-type="(\w+)" data-name="RT::User-/ . $root->id . qr/-SavedSearch-(\d+)"/;
my ( $saved_search_type, $saved_search_id ) = $m->content =~ /$regex/;
ok( $saved_search_type, "Got a type for the saved search, $saved_search_type" );
ok( $saved_search_id,   "Got an ID for the saved search, $saved_search_id" );

$m->submit_form_ok(
    {
        form_name => 'UpdateSearches',
        fields    => {
            dashboard_id => $dashboard_id,
            body         => $saved_search_type . "-" . "RT::User-" . $root->id . "-SavedSearch-" . $saved_search_id,
        },
        button => 'UpdateSearches',
    },
    "Add content 'Chart: chart foo' to dashboard body"
);

like( $m->uri, qr/results=[A-Za-z0-9]{32}/, 'URL redirected for results' );
$m->content_contains('Dashboard updated');

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
is( $imager->bits, 8, 'Image bit depth is 8' );    # Images created by GD::Graph have 4-bit color depth


# The first bar's color is #a6cee3, which is (166, 206, 227),
# on Apple Display preset, it's converted to (174, 205, 225).
my $bar_color  = $imager->getpixel( x => 300, y => 200 );
my $srgb_color = Imager::Color->new( 166, 206, 227 );
my $p3_color   = Imager::Color->new( 174, 205, 225 );
ok( $bar_color->equals( other => $srgb_color ) || $bar_color->equals( other => $p3_color ),
    'Image bar color is #a6cee3' );

done_testing;
