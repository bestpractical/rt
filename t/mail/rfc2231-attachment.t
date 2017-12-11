use strict;
use warnings;

use RT::Test tests => undef;
my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in as root';

diag "encoded attachment filename with parameter continuations";
{
    my $mail = RT::Test->file_content(
        RT::Test::get_relocatable_file(
            'rfc2231-attachment-filename-continuations',
            (File::Spec->updir(), 'data', 'emails')
        )
    );

    my ( $status, $id ) = RT::Test->send_via_mailgate($mail);
    is( $status >> 8, 0, "The mail gateway exited normally" );
    ok( $id, "Created ticket" );

    $m->get_ok("/Ticket/Display.html?id=$id");
    $m->content_contains(Encode::decode("UTF-8","新しいテキスト ドキュメント.txt"), "found full filename");
}

done_testing;

