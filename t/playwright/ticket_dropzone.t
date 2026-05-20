use strict;
use warnings;

use File::Basename;
use File::Temp;
use RT::Test tests => undef, playwright => 1;

my ( $url, $p ) = RT::Test->started_ok;

my $queue2 = RT::Queue->new( RT->SystemUser );
my ( $ok, $msg ) = $queue2->Create( Name => 'DropzoneTest', Lifecycle => 'default' );
ok( $ok, "Created second queue: $msg" );

$p->login();

diag "Upload file via Dropzone, change queue (auto-submits), then create ticket";
{
    $p->goto_create_ticket(1);

    my $tmp_file = File::Temp->new( SUFFIX => '.txt', UNLINK => 1 );
    print $tmp_file "test attachment content\n";
    $tmp_file->flush;
    my $tmp_path = $tmp_file->filename;
    my $tmp_name = File::Basename::basename($tmp_path);

    my $dz_input = $p->{page}->locator('.dz-hidden-input')->first();
    $dz_input->setInputFiles($tmp_path);

    $p->wait_for_element('.dz-preview');
    $p->text_contains( $tmp_name, 'Dropzone shows uploaded filename' );

    my $queue_selector = 'form[name=TicketCreate] [name=Queue]';
    $p->{page}->selectOption( $queue_selector, $queue2->Id . '' );
    $p->wait_for_htmx();

    $p->submit_form_ok(
        {
            form_name => 'TicketCreate',
            fields    => { Subject => 'Test dropzone after queue change' },
            button    => 'SubmitTicket',
        },
        'Create ticket'
    );
    $p->text_like(qr/Ticket \d+ created in queue/);
    $p->wait_for_htmx();
    $p->text_contains( $tmp_name, 'Attachment present in created ticket' );
}

$p->goto_ticket( RT::Test->last_ticket->id );

diag "Upload file via Dropzone and reply to ticket";
{
    my $reply = $p->{page}->locator('a:has-text("Reply")')->first();
    my $href  = $reply->getAttribute('href');
    $p->get_ok($href);

    my $tmp_file = File::Temp->new( SUFFIX => '.txt', UNLINK => 1 );
    print $tmp_file "test attachment content\n";
    $tmp_file->flush;
    my $tmp_path = $tmp_file->filename;
    my $tmp_name = File::Basename::basename($tmp_path);

    my $dz_input = $p->{page}->locator('.dz-hidden-input')->first();
    $dz_input->setInputFiles($tmp_path);

    $p->wait_for_element('.dz-preview');
    $p->text_contains( $tmp_name, 'Dropzone shows uploaded filename' );

    $p->submit_form_ok(
        {
            form_name => 'TicketUpdate',
            fields    => { UpdateContent => 'reply with attachment' },
            button    => 'SubmitTicket',
        },
        'Submit reply with attachment'
    );
    $p->text_contains('Correspondence added');
    $p->wait_for_htmx();
    $p->text_contains( $tmp_name, 'Attachment present in transaction' );
}

diag "Upload file via Dropzone, remove it manually, verify no attachment on ticket";
{
    $p->goto_create_ticket(1);

    my $tmp_file = File::Temp->new( SUFFIX => '.txt', UNLINK => 1 );
    print $tmp_file "test attachment content\n";
    $tmp_file->flush;
    my $tmp_path = $tmp_file->filename;
    my $tmp_name = File::Basename::basename($tmp_path);

    my $dz_input = $p->{page}->locator('.dz-hidden-input')->first();
    $dz_input->setInputFiles($tmp_path);

    $p->wait_for_element('.dz-preview');
    $p->text_contains( $tmp_name, 'Dropzone shows uploaded filename' );

    $p->{page}->locator('.dz-remove-mark')->first()->click();
    $p->wait_for_element( '.dz-preview', { state => 'hidden' } );

    $p->submit_form_ok(
        {
            form_name => 'TicketCreate',
            fields    => { Subject => 'Test manual file removal' },
            button    => 'SubmitTicket',
        },
        'Create ticket after manual file removal'
    );
    $p->text_like(qr/Ticket \d+ created in queue/);
    $p->wait_for_htmx();
    $p->text_lacks( $tmp_name, 'No attachment on ticket after manual removal' );
}

$p->logout;

done_testing;
