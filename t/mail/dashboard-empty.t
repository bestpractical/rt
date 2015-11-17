use strict;
use warnings;

use RT::Test tests => undef;
use RT::Dashboard::Mailer;

my $root = RT::Test->load_or_create_user( Name => 'root' );

my ( $baseurl, $m ) = RT::Test->started_ok;
ok( $m->login, 'logged in' );

sub create_dashboard {
    my ($name, $suppress_if_empty) = @_;

    # first, create and populate a "suppress if empty" dashboard
    $m->get_ok('/Dashboards/Modify.html?Create=1');
    $m->form_name('ModifyDashboard');
    $m->field( 'Name' => $name );
    $m->click_button( value => 'Create' );
    
    $m->follow_link_ok( { text => 'Content' } );
    my $form  = $m->form_name('Dashboard-Searches-body');
    my @input = $form->find_input('Searches-body-Available');
    
    my ($dashboards_component) =
      map { ( $_->possible_values )[1] }
      grep { ( $_->value_names )[1] =~ /My Tickets/ } @input;
    $form->value( 'Searches-body-Available' => $dashboards_component );
    $m->click_button( name => 'add' );
    $m->content_contains('Dashboard updated');
    
    $m->follow_link_ok( { text => 'Subscription' } );
    $m->form_name('SubscribeDashboard');
    $m->field( 'Frequency' => 'daily' );
    $m->field( 'Hour'      => '06:00' );

    $m->field( 'SuppressIfEmpty' => 1 ) if $suppress_if_empty;

    $m->click_button( name => 'Save' );
    $m->content_contains("Subscribed to dashboard $name");
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
    like($content, qr/highest priority tickets I own/);
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
        like($content, qr/highest priority tickets I own/);
        like($content, qr/a search result!/);
    }
}

undef $m;
done_testing;

