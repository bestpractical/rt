use strict;
use warnings;

use RT::Test tests => undef, config => 'Set($DevelMode, 0);';
use JSON;
use File::Temp;
use File::Path 'make_path';
use File::Spec;
my $dir            = File::Temp::tempdir( CLEANUP => 1 );
my $column_map_dir = File::Spec->catdir( $dir, qw/Callbacks MasonCache Elements RT__Ticket ColumnMap/ );
make_path($column_map_dir);

my $once  = File::Spec->catfile( $column_map_dir, 'Once' );
my $hello = File::Spec->catfile( $dir,            'Hello.html' );

update_mason( $once, <<'EOF' );
<%INIT>
$ARGS{COLUMN_MAP}{IDAndSubject} = {
    title => 'ID-Subject',
    value => sub { join '-', $_[0]->id, $_[0]->Subject },
};
</%INIT>
EOF

update_mason( $hello, 'Hello world!' );

$RT::MasonLocalComponentRoot = $dir;

my ( $baseurl, $m ) = RT::Test->started_ok;
my $ticket = RT::Test->create_ticket( Queue => 'General', Subject => 'test mason cache' );

$m->login;

sleep 1;    # Cache updates at most once per second.
$m->post_ok( $baseurl . '/Admin/Helpers/ClearMasonCache' );
is_deeply( from_json( $m->content ), { status => 1, message => 'Cache cleared' }, 'Cache cleared' );

# Test multiple times to make sure once callback always takes effect.
for ( 1 .. 3 ) {
    $m->get_ok('/Search/Results.html?Query=id>0&Format=__IDAndSubject__');
    $m->text_contains( 'ID-Subject',                               'Column title' );
    $m->text_contains( join( '-', $ticket->id, $ticket->Subject ), 'Column value' );
}

$m->get_ok('/Hello.html');
$m->text_contains( 'Hello world!', 'Mason content' );

update_mason( $once, <<'EOF' );
<%INIT>
$ARGS{COLUMN_MAP}{SubjectAndID} = {
    title => 'Subject-ID',
    value => sub { join '-', $_[0]->Subject, $_[0]->id },
};
</%INIT>
EOF

update_mason( $hello, 'Howdy world!' );

# Test multiple times to make sure once callback always takes effect.
for ( 1 .. 3 ) {
    $m->get_ok('/Search/Results.html?Query=id>0&Format=__IDAndSubject__');
    $m->text_contains( 'ID-Subject',                               'Old Column title is still valid' );
    $m->text_contains( join( '-', $ticket->id, $ticket->Subject ), 'Old Column value is still valid' );

    $m->get_ok('/Search/Results.html?Query=id>0&Format=__SubjectAndID__');
    $m->text_lacks( 'Subject-ID',                               'New Column title is not yet' );
    $m->text_lacks( join( '-', $ticket->Subject, $ticket->id ), 'New Column value is not yet' );
}
$m->get_ok('/Hello.html');
$m->text_contains( 'Hello world!', 'Old mason content' );

sleep 1;    # Cache updates at most once per second.
$m->post_ok( $baseurl . '/Admin/Helpers/ClearMasonCache' );
is_deeply( from_json( $m->content ), { status => 1, message => 'Cache cleared' }, 'Cache cleared' );

# Test multiple times to make sure once callback always takes effect.
for ( 1 .. 3 ) {
    $m->get_ok('/Search/Results.html?Query=id>0&Format=__IDAndSubject__');
    $m->text_lacks( 'ID-Subject',                               'Old Column title is gone' );
    $m->text_lacks( join( '-', $ticket->id, $ticket->Subject ), 'Old Column value is gone' );

    $m->get_ok('/Search/Results.html?Query=id>0&Format=__SubjectAndID__');
    $m->text_contains( 'Subject-ID',                               'New Column title is valid' );
    $m->text_contains( join( '-', $ticket->Subject, $ticket->id ), 'New Column value is valid' );
}

$m->get_ok('/Hello.html');
$m->text_contains( 'Howdy world!', 'New mason content' );

done_testing();

sub update_mason {
    my $path    = shift;
    my $content = shift;
    open my $fh, '>', $path or die $!;
    print $fh $content;
    close $fh;
}
