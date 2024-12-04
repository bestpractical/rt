use strict;
use warnings;

use RT::Test tests => undef;
use JSON;

my $root = RT::Test->load_or_create_user( Name => 'root' );

my ( $baseurl, $m ) = RT::Test->started_ok;
ok( $m->login, 'logged in' );
my $ticket = RT::Ticket->new( $RT::SystemUser );
$ticket->Create(
    Queue   => 'General',
    Subject => Encode::decode("UTF-8",'test äöü'),
);
ok( $ticket->id, 'created ticket' );

$m->get_ok(Encode::decode("UTF-8", q{/Search/Chart.html?Query=Subject LIKE 'test äöü'}));
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

my $saved_search_id = ($m->form_number(4)->find_input('SavedSearchLoad')->possible_values)[1];

# first, create and populate a dashboard
$m->get_ok('/Dashboards/Modify.html?Create=1');
$m->form_name('ModifyDashboard');
$m->field( 'Name' => 'dashboard foo' );
$m->click_button( value => 'Create' );

my ( $dashboard_id ) = ( $m->uri =~ /id=(\d+)/ );
ok( $dashboard_id, "got an ID for the dashboard, $dashboard_id" );

$m->follow_link_ok( { text => 'Content' } );

$m->submit_form_ok(
    {
        form_id => 'pagelayout-form-modify',
        fields  => {
            id      => $dashboard_id,
            Content => JSON::encode_json(
                [
                    {
                        Layout   => 'col-md-8, col-md-4',
                        Elements => [
                            [
                                {
                                    portlet_type => 'search',
                                    id           => $saved_search_id,
                                    description  => 'Chart: chart foo',
                                }
                            ],
                            [],
                        ],
                    }
                ]
            ),
        },
        button => 'Update',
    },
    "add content 'Chart: chart foo' to dashboard"
);

like( $m->uri, qr/results=[A-Za-z0-9]{32}/, 'URL redirected for results' );
$m->content_contains( 'Dashboard updated' );

$m->follow_link_ok( { text => 'Subscription' } );
$m->form_name('SubscribeDashboard');
$m->field( 'Frequency' => 'daily' );
$m->field( 'Hour'      => '06:00' );
$m->click_button( name => 'Save' );
$m->content_contains('Subscribed to dashboard dashboard foo');

RT::Test->run_and_capture(
    command => $RT::SbinPath . '/rt-email-dashboards', all => 1
);

my @mails = RT::Test->fetch_caught_mails;
is @mails, 1, "got a dashboard mail";

# can't use parse_mail here is because it deletes all attachments
# before we can call bodyhandle :/
use RT::EmailParser;
my $parser = RT::EmailParser->new;
my $mail = $parser->ParseMIMEEntityFromScalar( $mails[0] );
like(
    $mail->head->get('Subject'),
    qr/Daily Dashboard: dashboard foo/,
    'mail subject'
);

like( $mail->bodyhandle->as_string, qr/Chart is not available in emails, click title to get the live version/, 'chart hint' );

done_testing;
