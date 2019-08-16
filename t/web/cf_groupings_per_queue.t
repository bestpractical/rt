use strict;
use warnings;

use RT::Test tests => undef;

my @groupings = qw/Basics Dates People Links More/;
RT->Config->Set( 'CustomFieldGroupings',
    'RT::Ticket' => {
        'General' => {
            map { +($_ => ["Test$_"]) } @groupings,
        },
        'Default' => {
            map { +($_ => ["Test$_"]) } grep { $_ ne 'More' } @groupings,
        },
    },
);
RT->Config->PostLoadCheck;

my $general = RT::Test->load_or_create_queue( Name => 'General' );
my $foo = RT::Test->load_or_create_queue( Name => 'Foo' );

my ( $baseurl, $m ) = RT::Test->started_ok;
ok $m->login, 'logged in as root';

my %CF;
for my $grouping (@groupings) {
    my $name = "Test$grouping";
    my $cf = RT::CustomField->new( RT->SystemUser );
    my ($id, $msg) = $cf->Create(
        Name => $name,
        Queue => '0',
        Description => 'A Testing custom field',
        Type => 'FreeformSingle',
        Pattern => '^(?!bad value).*$',
    );
    ok $id, "custom field '$name' correctly created";
    $CF{$grouping} = $id;
}

for my $queue ( $general, $foo ) {

    my %location = (
        Basics => ".ticket-info-basics",
        Dates  => ".ticket-info-dates",
        People => "#ticket-create-message",
        Links  => ".ticket-info-links",
        More   => ".ticket-info-cfs",
    );

    {
        diag "testing Create";
        $m->goto_create_ticket($queue);

        my $prefix = 'Object-RT::Ticket--CustomField:';
        my $dom    = $m->dom;
        $m->form_name('TicketCreate');
        $m->field( "Subject", "CF grouping test" );

        for my $grouping (@groupings) {
            my $input_name = $prefix . "$grouping-$CF{$grouping}-Value";
            if ( $grouping eq 'More' && $queue == $foo ) {
                $input_name =~ s!:More!!;
            }
            is $dom->find(qq{input[name="$input_name"]})->size, 1, "only one CF input on the page";
            ok $dom->at(qq{$location{$grouping} input[name="$input_name"]}), "CF is in the right place";
            $m->field( $input_name, "Test" . $grouping . "Value" );
        }
        $m->submit;
    }

    my $id = $m->get_ticket_id;
    {
        diag "testing Display";
        ok $id, "created a ticket";
        my $dom = $m->dom;

        $location{People} = ".ticket-info-people";
        foreach my $grouping (@groupings) {
            my $row_id = "CF-$CF{$grouping}-ShowRow";
            is $dom->find(qq{#$row_id})->size, 1, "CF on the page";
            like $dom->at(qq{#$row_id})->all_text, qr/Test$grouping:\s*Test${grouping}Value/, "value is set";
            ok $dom->at(qq{$location{$grouping} #$row_id}), "CF is in the right place";
        }
        if ( $queue == $general ) {
            ok( !$m->find_link( url_regex => qr/#ticket-info-cfs$/, text => 'Custom Fields' ),
                'no "Custom Fields" widget' );
            ok( $m->find_link( url_regex => qr/#ticket-info-cfs-More$/, text => 'More' ), 'has "More" widget' );
        }
        else {
            ok( $m->find_link( url_regex => qr/#ticket-info-cfs$/, text => 'Custom Fields' ),
                'has "Custom Fields" widget' );
            ok( !$m->find_link( url_regex => qr/#ticket-info-cfs-More$/, text => 'More' ), 'no "More" widget' );
        }
    }
}

done_testing;
