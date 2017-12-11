use strict;
use warnings;

use RT::Test tests => undef;

plan skip_all => 'GD required'
    unless GD->require;

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

$m->follow_link_ok( { text => 'Content' } );
my $form  = $m->form_name('Dashboard-Searches-body');
my @input = $form->find_input('Searches-body-Available');
my ($dashboards_component) =
  map { ( $_->possible_values )[1] }
  grep { ( $_->value_names )[1] =~ /^Chart/ } @input;
$form->value( 'Searches-body-Available' => $dashboards_component );
$m->click_button( name => 'add' );
$m->content_contains('Dashboard updated');

$m->follow_link_ok( { text => 'Subscription' } );
$m->form_name('SubscribeDashboard');
$m->field( 'Frequency' => 'daily' );
$m->field( 'Hour'      => '06:00' );
$m->click_button( name => 'Save' );
$m->content_contains('Subscribed to dashboard dashboard foo');

my $c     = $m->get(Encode::decode("UTF-8",q{/Search/Chart?Query=Subject LIKE 'test äöü'}));
my $image = $c->content;
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

my ($mail_image) = grep { $_->mime_type eq 'image/png' } $mail->parts;
ok( $mail_image, 'mail contains image attachment' );

my $handle = $mail_image->bodyhandle;

my $mail_image_data = '';
if ( my $io = $handle->open('r') ) {
    while ( defined( $_ = $io->getline ) ) { $mail_image_data .= $_ }
    $io->close;
}
is( $mail_image_data, $image, 'image in mail is the same one in web' );

done_testing;
