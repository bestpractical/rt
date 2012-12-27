use strict;
use warnings;

use RT::Test::GnuPG tests => 22, gnupg_options => { passphrase => 'rt-test' };

use RT::Action::SendEmail;

RT::Test->import_gnupg_key('rt-recipient@example.com');
RT::Test->import_gnupg_key('rt-test@example.com', 'public');

my $queue = RT::Test->load_or_create_queue(
    Name              => 'Regression',
    CorrespondAddress => 'rt-recipient@example.com',
    CommentAddress    => 'rt-recipient@example.com',
);
ok $queue && $queue->id, 'loaded or created queue';

my ($baseurl, $m) = RT::Test->started_ok;
ok $m->login, 'logged in';

my @variants = (
    {},
    { Sign => 1 },
    { Encrypt => 1 },
    { Sign => 1, Encrypt => 1 },
);

# collect emails
my %mail = (
    plain            => [],
    signed           => [],
    encrypted        => [],
    signed_encrypted => [],
);

diag "check in read-only mode that queue's props influence create/update ticket pages";
{
    foreach my $variant ( @variants ) {
        set_queue_crypt_options( $queue =>  %$variant );
        $m->goto_create_ticket( $queue );
        $m->form_name('TicketCreate');
        if ( $variant->{'Encrypt'} ) {
            ok $m->value('Encrypt', 2), "encrypt tick box is checked";
        } else {
            ok !$m->value('Encrypt', 2), "encrypt tick box is unchecked";
        }
        if ( $variant->{'Sign'} ) {
            ok $m->value('Sign', 2), "sign tick box is checked";
        } else {
            ok !$m->value('Sign', 2), "sign tick box is unchecked";
        }
    }

    # to avoid encryption/signing during create
    set_queue_crypt_options($queue);

    my $ticket = RT::Ticket->new( RT->SystemUser );
    my ($id) = $ticket->Create(
        Subject   => 'test',
        Queue     => $queue->id,
        Requestor => 'rt-test@example.com',
    );
    ok $id, 'ticket created';

    foreach my $variant ( @variants ) {
        set_queue_crypt_options( $queue => %$variant );
        $m->get( $m->rt_base_url . "/Ticket/Update.html?Action=Respond&id=$id" );
        $m->form_name('TicketUpdate');
        if ( $variant->{'Encrypt'} ) {
            ok $m->value('Encrypt', 2), "encrypt tick box is checked";
        } else {
            ok !$m->value('Encrypt', 2), "encrypt tick box is unchecked";
        }
        if ( $variant->{'Sign'} ) {
            ok $m->value('Sign', 2), "sign tick box is checked";
        } else {
            ok !$m->value('Sign', 2), "sign tick box is unchecked";
        }
    }
}



