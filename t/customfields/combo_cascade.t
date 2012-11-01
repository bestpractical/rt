use warnings;
use strict;

use RT::Test nodata => 1, tests => 11;

my $q = RT::Queue->new($RT::SystemUser);
works($q->Create(Name => "CF-Pattern-".$$));

my $cf = RT::CustomField->new($RT::SystemUser);
my @cf_args = (Name => $q->Name, Type => 'Combobox', Queue => $q->id);

works($cf->Create(@cf_args));

# Set some CFVs with Category markers

my $t = RT::Ticket->new($RT::SystemUser);
my ($id,undef,$msg) = $t->Create(Queue => $q->id, Subject => 'CF Test');
works($id,$msg);

sub add_works {
    works(
        $cf->AddValue(Name => $_[0], Description => $_[0], Category => $_[1])
    );
};

add_works('value1', '1. Category A');
add_works('value2');
add_works('value3', '1.1. A-sub one');
add_works('value4', '1.2. A-sub two');
add_works('value5', '');

my $cfv = $cf->Values->First;
is($cfv->Category, '1. Category A');
works($cfv->SetCategory('1. Category AAA'));
is($cfv->Category, '1. Category AAA');

