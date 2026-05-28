use strict;
use warnings;

use File::Basename;
use File::Temp;
use MIME::Entity;
use RT::Test tests => undef, playwright => 1;

# Helper used by the widget interactions section below: adds an attachment
# to $ticket via the model.
sub _attach {
    my ( $ticket, $name, $body ) = @_;
    my $mime = MIME::Entity->build( Type => 'text/plain', Filename => $name, Data => [$body] );
    my ($txn_id) = $ticket->AddAttachment( MIMEObj => $mime );
    ok( $txn_id, "added $name" );
}

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

my $widget_ticket
    = RT::Test->create_ticket( Queue => 'General', Subject => 'attachments widget' );
_attach( $widget_ticket, 'alpha.txt', 'alpha body' );
_attach( $widget_ticket, 'beta.txt',  'beta body' );

$p->goto_ticket( $widget_ticket->Id );

diag "Widget renders both attachments";
{
    $p->wait_for_element( '.ticket-info-attachments .attachment-list tr[data-name="alpha.txt"]' );
    $p->wait_for_element( '.ticket-info-attachments .attachment-list tr[data-name="beta.txt"]' );
    $p->text_contains( 'alpha.txt', 'alpha.txt shown in widget' );
    $p->text_contains( 'beta.txt',  'beta.txt shown in widget' );
}

diag "Search box filters the visible rows";
{
    my $search = $p->{page}->locator('.ticket-info-attachments .attachment-search');
    $search->fill('alpha');
    $p->wait_for_element('.attachment-list tr[data-name="beta.txt"]', { state => 'hidden' });
    is( $p->{page}->locator('.attachment-list tr[data-name="alpha.txt"].d-none')->count, 0,
        'alpha.txt stays visible while searching "alpha"' );
    ok( $p->{page}->locator('.attachment-list tr[data-name="beta.txt"].d-none')->count,
        'beta.txt is hidden while searching "alpha"' );

    $search->fill('');
    $p->wait_for_element('.attachment-list tr[data-name="beta.txt"]:not(.d-none)');
    is( $p->{page}->locator('.attachment-list tr[data-name="alpha.txt"].d-none')->count, 0,
        'alpha.txt visible after clearing search' );
    is( $p->{page}->locator('.attachment-list tr[data-name="beta.txt"].d-none')->count, 0,
        'beta.txt visible after clearing search' );
}

diag "Pin alpha.txt — row gets the attachment-pinned class";
{
    my $alpha_row = $p->{page}->locator('.attachment-list tr[data-name="alpha.txt"]');
    $alpha_row->locator('a[data-bs-toggle="dropdown"]')->click;
    $p->wait_for_element( '.attachment-list tr[data-name="alpha.txt"] .dropdown-menu .attachment-pin' );
    $alpha_row->locator('.attachment-pin')->click;

    $p->wait_for_htmx;
    $p->wait_for_element( '.attachment-list tr[data-name="alpha.txt"].attachment-pinned' );
    ok( $p->{page}->locator('.attachment-list tr[data-name="alpha.txt"].attachment-pinned')->count, 'alpha.txt is pinned' );
}

diag "Unpin alpha.txt — pinned class removed";
{
    my $alpha_row = $p->{page}->locator('.attachment-list tr[data-name="alpha.txt"]');
    $alpha_row->locator('a[data-bs-toggle="dropdown"]')->click;
    $p->wait_for_element( '.attachment-list tr[data-name="alpha.txt"] .dropdown-menu .attachment-unpin' );
    $alpha_row->locator('.attachment-unpin')->click;

    $p->wait_for_htmx;
    $p->wait_for_element( '.attachment-list tr[data-name="alpha.txt"]:not(.attachment-pinned)' );
    is( $p->{page}->locator('.attachment-list tr[data-name="alpha.txt"].attachment-pinned')->count, 0,
        'alpha.txt no longer pinned' );
}

diag "Rename beta.txt -> gamma.txt via the per-row Rename action";
{
    my $beta_row = $p->{page}->locator('.attachment-list tr[data-name="beta.txt"]');
    $beta_row->locator('a[data-bs-toggle="dropdown"]')->click;
    $p->wait_for_element( '.attachment-list tr[data-name="beta.txt"] .dropdown-menu .attachment-rename' );
    $beta_row->locator('.attachment-rename')->click;

    # Editing slides the inline form into view; fill it and submit.
    my $editor_input
        = $p->{page}->locator('.attachment-list tr[data-name="beta.txt"] form.editor input[name^="RenameAttachment-"]');
    $p->wait_for_element( '.attachment-list tr[data-name="beta.txt"] form.editor input[name^="RenameAttachment-"]' );
    $editor_input->fill('gamma.txt');
    $p->{page}->locator('.attachment-list tr[data-name="beta.txt"] form.editor .submit')->click;

    $p->wait_for_htmx;
    $p->wait_for_element( '.attachment-list tr[data-name="gamma.txt"]' );
    $p->text_contains( 'gamma.txt', 'beta.txt was renamed to gamma.txt' );
    is( $p->{page}->locator('.attachment-list tr[data-name="beta.txt"]')->count, 0, 'old name gone from list' );
}

diag "Delete gamma.txt via the per-row Delete action (with confirmation)";
{
    my $gamma_row = $p->{page}->locator('.attachment-list tr[data-name="gamma.txt"]');
    $gamma_row->locator('a[data-bs-toggle="dropdown"]')->click;
    $p->wait_for_element( '.attachment-list tr[data-name="gamma.txt"] .dropdown-menu .attachment-delete' );
    $gamma_row->locator('.attachment-delete')->click;

    # The delete now opens a confirmation modal listing the file; confirm it.
    $p->wait_for_element( '.attachment-delete-confirm-modal .attachment-delete-confirm', { state => 'visible' } );
    ok(
        $p->{page}->locator('.attachment-delete-confirm-modal .attachment-delete-list li:has-text("gamma.txt")')->count,
        'confirmation modal lists gamma.txt'
    );
    $p->{page}->locator('.attachment-delete-confirm-modal .attachment-delete-confirm')->click;

    $p->wait_for_htmx;
    $p->wait_for_element( '.attachment-list tr[data-name="gamma.txt"]', { state => 'hidden' } );
    is( $p->{page}->locator('.attachment-list tr[data-name="gamma.txt"]')->count, 0, 'gamma.txt row removed' );
}

diag "Bulk mode toggle reveals the bulk action bar and per-row checkboxes";
{
    my $widget = $p->{page}->locator('.ticket-info-attachments');

    # Before toggling, the row checkbox column is hidden via CSS (`.bulk-only` inside `:not(.bulk)`).
    ok( $widget->locator('.attachment-bulk-toggle.bulk:not(.hidden)')->count, 'bulk toggle shown initially' );

    $widget->locator('.attachment-bulk-toggle.bulk')->click;
    $p->wait_for_element( '.ticket-info-attachments.bulk' );

    # In bulk mode, the bulk action bar is visible and starts disabled.
    ok( $widget->locator('.attachment-bulk-download.disabled')->count, 'Download Selected starts disabled' );
    ok( $widget->locator('.attachment-bulk-delete.disabled')->count,   'Delete Selected starts disabled' );

    # Check alpha.txt — the bulk buttons should enable.
    $widget->locator('.attachment-list tr[data-name="alpha.txt"] input.attachment-select')->check;
    $p->wait_for_element( '.attachment-bulk-download:not(.disabled)' );
    ok( !$widget->locator('.attachment-bulk-delete.disabled')->count, 'Delete Selected enabled after a row is checked' );

    # Cancel bulk mode.
    $widget->locator('.attachment-bulk-toggle.cancel')->click;
    $p->wait_for_element( '.ticket-info-attachments:not(.bulk)' );
}

$p->logout;

done_testing;
