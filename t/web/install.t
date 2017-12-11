use strict;
use warnings;
use File::Spec;

$ENV{RT_TEST_WEB_HANDLER} = 'plack+rt-server';
use RT::Test
    tests     => undef,
    nodb      => 1,
    server_ok => 1;

my $dbname     = 'rt4test_install_xxx';
my $rtname     = 'rttestname';
my $domain     = 'rttes.com';
my $password   = 'newpass';
my $correspond = 'reply@example.com';
my $comment    = 'comment@example.com';

# use bin/rt to fake sendmail to make sure the file exists
my $sendmail = File::Spec->catfile( $RT::BinPath, 'rt' );
my $owner = 'root@localhost';

unlink File::Spec->catfile( $RT::VarPath, $dbname );

my ( $url, $m ) = RT::Test->started_ok;
$m->warning_like(qr/If this is a new installation of RT/,
                 "Got startup warning");

my ($port) = $url =~ /:(\d+)/;
$m->get_ok($url);

is( $m->uri, $url . '/Install/index.html', 'install page' );
$m->select( 'Lang', 'zh-cn' );
$m->click('ChangeLang');
$m->content_contains( Encode::decode("UTF-8",'语言'), 'select chinese' );

$m->click('Run');
$m->content_contains( Encode::decode("UTF-8",'数据库'), 'select db type in chinese' );

$m->back;
$m->select( 'Lang', 'en' );
$m->click('ChangeLang');
$m->content_contains( 'Select another language', 'back to english' );

$m->click('Run');

is( $m->uri, $url . '/Install/DatabaseType.html', 'db type page' );
my $select_type    = $m->current_form->find_input('DatabaseType');
my @possible_types = $select_type->possible_values;
ok( @possible_types, 'we have at least 1 db type' );

SKIP: {
    skip 'no mysql found', 7 unless grep { /mysql/ } @possible_types;
    $m->select( 'DatabaseType', 'mysql' );
    $m->click;
    for my $field (qw/Name Host Port Admin AdminPassword User Password/) {
        ok( $m->current_form->find_input("Database$field"),
            "db mysql has field Database$field" );
    }
    $m->back;
}

SKIP: {
    skip 'no pg found', 8 unless grep { /Pg/ } @possible_types;
    $m->select( 'DatabaseType', 'Pg' );
    $m->click;
    for my $field (
        qw/Name Host Port Admin AdminPassword User Password/)
    {
        ok( $m->current_form->find_input("Database$field"),
            "db Pg has field Database$field" );
    }
    $m->back;
}

$m->select( 'DatabaseType', 'SQLite' );
$m->click;

is( $m->uri, $url . '/Install/DatabaseDetails.html', 'db details page' );
$m->field( 'DatabaseName' => $dbname );
$m->submit_form( fields => { DatabaseName => $dbname } );
$m->content_contains( 'Connection succeeded', 'succeed msg' );
$m->content_contains(
qq{$dbname already exists, but does not contain RT&#39;s tables or metadata. The &#39;Initialize Database&#39; step later on can insert tables and metadata into this existing database. if this is acceptable, click &#39;Customize Basic&#39; below to continue customizing RT.},
    'more db state msg'
);
$m->click;

is( $m->uri, $url . '/Install/Basics.html', 'basics page' );
$m->click;
$m->content_contains(
    'You must enter an Administrative password',
    "got password can't be empty error"
);

for my $field (qw/rtname WebDomain WebPort Password/) {
    ok( $m->current_form->find_input($field), "has field $field" );
}
is( $m->value('WebPort'), $port, 'default port' );
$m->field( 'rtname'    => $rtname );
$m->field( 'WebDomain' => $domain );
$m->field( 'Password'  => $password );
$m->click;

is( $m->uri, $url . '/Install/Sendmail.html', 'mail page' );
for my $field (qw/SendmailPath OwnerEmail/) {
    ok( $m->current_form->find_input($field), "has field $field" );
}

$m->field( 'OwnerEmail' => '' );
$m->click;
$m->content_contains( "doesn&#39;t look like an email address",
    'got email error' );

$m->field( 'SendmailPath' => '/fake/path/sendmail' );
$m->click;
$m->content_contains( "/fake/path/sendmail doesn&#39;t exist",
    'got sendmail error' );

$m->field( 'SendmailPath' => $sendmail );
$m->field( 'OwnerEmail'   => $owner );
$m->click;

is( $m->uri, $url . '/Install/Global.html', 'global page' );
for my $field (qw/CommentAddress CorrespondAddress/) {
    ok( $m->current_form->find_input($field), "has field $field" );
}

$m->click;
is( $m->uri, $url . '/Install/Initialize.html', 'init db page' );
$m->back;

is( $m->uri, $url . '/Install/Global.html', 'global page' );
$m->field( 'CorrespondAddress' => 'reply' );
$m->click;
$m->content_contains( "doesn&#39;t look like an email address",
    'got email error' );
$m->field( 'CommentAddress' => 'comment' );
$m->click;
$m->content_contains( "doesn&#39;t look like an email address",
    'got email error' );

$m->field( 'CorrespondAddress' => 'reply@example.com' );
$m->field( 'CommentAddress'    => 'comment@example.com' );
$m->click;

is( $m->uri, $url . '/Install/Initialize.html', 'init db page' );
$m->click;

is( $m->uri, $url . '/Install/Finish.html', 'finish page' );
$m->click;

is( $m->uri, $url . '/', 'home page' );
$m->login( 'root', $password );
$m->content_contains( 'RT at a glance', 'logged in with newpass' );

RT->LoadConfig;
my $config = RT->Config;

is( $config->Get('DatabaseType'), 'SQLite',  'DatabaseType in config' );
is( $config->Get('DatabaseName'), $dbname,   'DatabaseName in config' );
is( $config->Get('rtname'),       $rtname,   'rtname in config' );
is( $config->Get('WebDomain'),    $domain,   'WebDomain email in config' );
is( $config->Get('WebPort'),      $port,     'WebPort email in config' );
is( $config->Get('SendmailPath'), $sendmail, 'SendmailPath in config' );
is( $config->Get('OwnerEmail'),   $owner,    'OwnerEmail in config' );
is( $config->Get('CorrespondAddress'),
    $correspond, 'correspond address in config' );
is( $config->Get('CommentAddress'), $comment, 'comment address in config' );

unlink File::Spec->catfile( $RT::VarPath, $dbname );

done_testing;
