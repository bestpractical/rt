use strict;
use warnings;

use RT::Test::Assets;

my $laptops = create_catalog(Name => 'Laptops');
my $servers = create_catalog(Name => 'Servers');
my $keyboards = create_catalog(Name => 'Keyboards');

my $manufacturer = create_cf(Name => 'Manufacturer');
apply_cfs($manufacturer);

my $blank = create_cf(Name => 'Blank');
apply_cfs($blank);

my $shawn = RT::User->new(RT->SystemUser);
my ($ok, $msg) = $shawn->Create(Name => 'shawn', EmailAddress => 'shawn@bestpractical.com');
ok($ok, $msg);

my $rightsless = RT::User->new(RT->SystemUser);
($ok, $msg) = $rightsless->Create(Name => 'rightsless', EmailAddress => 'rightsless@bestpractical.com');
ok($ok, $msg);

my $sysadmins = RT::Group->new( RT->SystemUser );
($ok, $msg) = $sysadmins->CreateUserDefinedGroup( Name => 'Sysadmins' );
ok($ok, $msg);

($ok, $msg) = $sysadmins->AddMember($shawn->PrincipalId);
ok($ok, $msg);

my $memberless = RT::Group->new( RT->SystemUser );
($ok, $msg) = $memberless->CreateUserDefinedGroup( Name => 'Memberless' );
ok($ok, $msg);

ok(RT::Test->add_rights({
    Principal   => 'Privileged',
    Right       => 'ShowCatalog',
}), "Granted ShowCatalog");

ok(RT::Test->add_rights({
    Principal   => 'Owner',
    Right       => 'ShowAsset',
}), "Granted ShowAsset");

my $bloc = create_asset(
    Name                       => 'bloc',
    Description                => "Shawn's BPS office media server",
    Catalog                    => 'Servers',
    Owner                      => $shawn->PrincipalId,
    Contact                    => $shawn->PrincipalId,
    'CustomField-Manufacturer' => 'Raspberry Pi',
);
my $deleted = create_asset(
    Name                       => 'deleted',
    Description                => "for making sure we don't search deleted",
    Catalog                    => 'Servers',
    Owner                      => $shawn->PrincipalId,
    Contact                    => $shawn->PrincipalId,
    'CustomField-Manufacturer' => 'Dell',
);
my $ecaz = create_asset(
    Name                       => 'ecaz',
    Description                => "Shawn's BPS laptop",
    Catalog                    => 'Laptops',
    Owner                      => $shawn->PrincipalId,
    Contact                    => $shawn->PrincipalId,
    'CustomField-Manufacturer' => 'Apple',
);
my $kaitain = create_asset(
    Name                       => 'kaitain',
    Description                => "unused BPS laptop",
    Catalog                    => 'Laptops',
    Owner                      => $shawn->PrincipalId,
    'CustomField-Manufacturer' => 'Apple',
);
my $morelax = create_asset(
    Name                       => 'morelax',
    Description                => "BPS in the data center",
    Catalog                    => 'Servers',
    'CustomField-Manufacturer' => 'Dell',
);
my $stilgar = create_asset(
    Name                       => 'stilgar',
    Description                => "English layout",
    Catalog                    => 'Keyboards',
    Owner                      => $shawn->PrincipalId,
    Contact                    => $shawn->PrincipalId,
    'CustomField-Manufacturer' => 'Apple',
);

($ok, $msg) = $bloc->SetStatus('stolen');
ok($ok, $msg);

($ok, $msg) = $deleted->SetStatus('deleted');
ok($ok, $msg);

($ok, $msg) = $ecaz->SetStatus('in-use');
ok($ok, $msg);

($ok, $msg) = $kaitain->SetStatus('in-use');
ok($ok, $msg);
($ok, $msg) = $kaitain->SetStatus('recycled');
ok($ok, $msg);

($ok, $msg) = $morelax->SetStatus('in-use');
ok($ok, $msg);

($ok, $msg) = $ecaz->AddLink(Type => 'RefersTo', Target => $kaitain->URI);
ok($ok, $msg);

($ok, $msg) = $stilgar->AddLink(Type => 'MemberOf', Target => $ecaz->URI);
ok($ok, $msg);

my $ticket = RT::Ticket->new(RT->SystemUser);
($ok, $msg) = $ticket->Create(Queue => 'General', Subject => "reboot the server please");

($ok, $msg) = $morelax->AddLink(Type => 'RefersTo', Target => $ticket->URI);
ok($ok, $msg);

my $bloc_id = $bloc->id;
my $ecaz_id = $ecaz->id;
my $kaitain_id = $kaitain->id;
my $morelax_id = $morelax->id;
my $stilgar_id = $stilgar->id;
my $ticket_id = $ticket->id;

my $shawn_cu = RT::CurrentUser->new($shawn);
my $rightsless_cu = RT::CurrentUser->new($rightsless);

my $assetsql_shawn = sub {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my ($sql, @expected) = @_;
    assetsql({
        sql => $sql,
        CurrentUser => $shawn_cu,
    }, @expected);
};

my $assetsql_rightsless = sub {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my ($sql, @expected) = @_;
    assetsql({
        sql => $sql,
        CurrentUser => $rightsless_cu,
    }, @expected);
};

$assetsql_shawn->("id = 1" => $bloc);
$assetsql_shawn->("id != 1" => $ecaz, $kaitain, $stilgar);
$assetsql_shawn->("id = 2" => ()); # deleted
$assetsql_shawn->("id = 5" => ()); # morelax
$assetsql_shawn->("id < 3" => $bloc);
$assetsql_shawn->("id >= 3" => $ecaz, $kaitain, $stilgar);

$assetsql_shawn->("Name = 'ecaz'" => $ecaz);
$assetsql_shawn->("Name != 'ecaz'" => $bloc, $kaitain, $stilgar);
$assetsql_shawn->("Name = 'no match'" => ());
$assetsql_shawn->("Name != 'no match'" => $bloc, $ecaz, $kaitain, $stilgar);

$assetsql_shawn->("Status = 'new'" => $stilgar);
$assetsql_shawn->("Status = 'allocated'" => ());
$assetsql_shawn->("Status = 'in-use'" => $ecaz);
$assetsql_shawn->("Status = 'recycled'" => $kaitain);
$assetsql_shawn->("Status = 'stolen'" => $bloc);
$assetsql_shawn->("Status = 'deleted'" => ());

$assetsql_shawn->("Status = '__Active__'" => $ecaz, $stilgar);
$assetsql_shawn->("Status != '__Inactive__'" => $ecaz, $stilgar);
$assetsql_shawn->("Status = '__Inactive__'" => $bloc, $kaitain);
$assetsql_shawn->("Status != '__Active__'" => $bloc, $kaitain);

$assetsql_shawn->("Catalog = 'Laptops'" => $ecaz, $kaitain);
$assetsql_shawn->("Catalog = 'Servers'" => $bloc);
$assetsql_shawn->("Catalog = 'Keyboards'" => $stilgar);
$assetsql_shawn->("Catalog != 'Servers'" => $ecaz, $kaitain, $stilgar);
$assetsql_shawn->("Catalog != 'Laptops'" => $bloc, $stilgar);
$assetsql_shawn->("Catalog != 'Keyboards'" => $bloc, $ecaz, $kaitain);

$assetsql_shawn->("Description LIKE 'data center'" => ());
$assetsql_shawn->("Description LIKE 'Shawn'" => $bloc, $ecaz);
$assetsql_shawn->("Description LIKE 'media'" => $bloc);
$assetsql_shawn->("Description NOT LIKE 'laptop'" => $bloc, $stilgar);
$assetsql_shawn->("Description LIKE 'deleted'" => ());
$assetsql_shawn->("Description LIKE 'BPS'" => $bloc, $ecaz, $kaitain);

$assetsql_shawn->("Lifecycle = 'assets'" => $bloc, $ecaz, $kaitain, $stilgar);
$assetsql_shawn->("Lifecycle != 'assets'" => ());
$assetsql_shawn->("Lifecycle = 'default'" => ());
$assetsql_shawn->("Lifecycle != 'default'" => $bloc, $ecaz, $kaitain, $stilgar);

$assetsql_shawn->("Linked IS NOT NULL" => $ecaz, $kaitain, $stilgar);
$assetsql_shawn->("Linked IS NULL" => $bloc);
$assetsql_shawn->("RefersTo = 'asset:$kaitain_id'" => $ecaz);
$assetsql_shawn->("RefersTo = $ticket_id" => ());
$assetsql_shawn->("HasMember = 'asset:$stilgar_id'" => $ecaz);
$assetsql_shawn->("MemberOf = 'asset:$stilgar_id'" => ());

$assetsql_shawn->("Owner.Name = 'shawn'" => $bloc, $ecaz, $kaitain, $stilgar);
$assetsql_shawn->("Owner.EmailAddress LIKE 'bestpractical'" => $bloc, $ecaz, $kaitain, $stilgar);
$assetsql_shawn->("Owner.Name = 'Nobody'" => ());
$assetsql_shawn->("Owner = '__CurrentUser__'" => $bloc, $ecaz, $kaitain, $stilgar);
$assetsql_shawn->("Owner != '__CurrentUser__'" => ());
$assetsql_shawn->("OwnerGroup = 'Sysadmins'" => $bloc, $ecaz, $kaitain, $stilgar);
$assetsql_shawn->("OwnerGroup = 'Memberless'" => ());

$assetsql_shawn->("Contact.Name = 'shawn'" => $bloc, $ecaz, $stilgar);
$assetsql_shawn->("Contact = '__CurrentUser__'" => $bloc, $ecaz, $stilgar);
$assetsql_shawn->("Contact != '__CurrentUser__'" => $kaitain);
$assetsql_shawn->("ContactGroup = 'Sysadmins'" => $bloc, $ecaz, $stilgar);
$assetsql_shawn->("ContactGroup = 'Memberless'" => ());

$assetsql_shawn->("CustomField.{Manufacturer} = 'Apple'" => $ecaz, $kaitain, $stilgar);
$assetsql_shawn->("CF.{Manufacturer} != 'Apple'" => $bloc);
$assetsql_shawn->("CustomFieldValue.{Manufacturer} = 'Raspberry Pi'" => $bloc);
$assetsql_shawn->("CF.{Manufacturer} IS NULL" => ());

$assetsql_shawn->("CF.{Blank} IS NULL" => $bloc, $ecaz, $kaitain, $stilgar);
$assetsql_shawn->("CF.{Blank} IS NOT NULL" => ());

$assetsql_shawn->("Status = '__Active__' AND Catalog = 'Servers'" => ());
$assetsql_shawn->("Status = 'in-use' AND Catalog = 'Laptops'" => $ecaz);
$assetsql_shawn->("Catalog != 'Servers' AND Catalog != 'Laptops'" => $stilgar);
$assetsql_shawn->("Description LIKE 'BPS' AND Contact.Name IS NULL" => $kaitain);
$assetsql_shawn->("CF.{Manufacturer} = 'Apple' AND Catalog = 'Laptops'" => $ecaz, $kaitain);
$assetsql_shawn->("Catalog = 'Servers' AND Linked IS NULL" => $bloc);
$assetsql_shawn->("Catalog = 'Servers' OR Linked IS NULL" => $bloc);
$assetsql_shawn->("(Catalog = 'Keyboards' AND CF.{Manufacturer} = 'Apple') OR (Catalog = 'Servers' AND CF.{Manufacturer} = 'Raspberry Pi')" => $bloc, $stilgar);

$assetsql_rightsless->("id = 1");
$assetsql_rightsless->("id != 1");
$assetsql_rightsless->("id = 2");
$assetsql_rightsless->("id < 3");
$assetsql_rightsless->("id >= 3");

$assetsql_rightsless->("Name = 'ecaz'");
$assetsql_rightsless->("Name != 'ecaz'");
$assetsql_rightsless->("Name = 'no match'");
$assetsql_rightsless->("Name != 'no match'");

$assetsql_rightsless->("Status = 'new'");
$assetsql_rightsless->("Status = 'allocated'");
$assetsql_rightsless->("Status = 'in-use'");
$assetsql_rightsless->("Status = 'recycled'");
$assetsql_rightsless->("Status = 'stolen'");
$assetsql_rightsless->("Status = 'deleted'");

$assetsql_rightsless->("Status = '__Active__'");
$assetsql_rightsless->("Status != '__Inactive__'");
$assetsql_rightsless->("Status = '__Inactive__'");
$assetsql_rightsless->("Status != '__Active__'");

$assetsql_rightsless->("Catalog = 'Laptops'");
$assetsql_rightsless->("Catalog = 'Servers'");
$assetsql_rightsless->("Catalog = 'Keyboards'");
$assetsql_rightsless->("Catalog != 'Servers'");
$assetsql_rightsless->("Catalog != 'Laptops'");
$assetsql_rightsless->("Catalog != 'Keyboards'");

$assetsql_rightsless->("Description LIKE 'data center'");
$assetsql_rightsless->("Description LIKE 'Shawn'");
$assetsql_rightsless->("Description LIKE 'media'");
$assetsql_rightsless->("Description NOT LIKE 'laptop'");
$assetsql_rightsless->("Description LIKE 'deleted'");
$assetsql_rightsless->("Description LIKE 'BPS'");

$assetsql_rightsless->("Lifecycle = 'assets'");
$assetsql_rightsless->("Lifecycle != 'assets'");
$assetsql_rightsless->("Lifecycle = 'default'");
$assetsql_rightsless->("Lifecycle != 'default'");

$assetsql_rightsless->("Linked IS NOT NULL");
$assetsql_rightsless->("Linked IS NULL");
$assetsql_rightsless->("RefersTo = 'asset:$kaitain_id'");
$assetsql_rightsless->("RefersTo = $ticket_id");
$assetsql_rightsless->("HasMember = 'asset:$stilgar_id'");
$assetsql_rightsless->("MemberOf = 'asset:$stilgar_id'");

$assetsql_rightsless->("Owner.Name = 'shawn'");
$assetsql_rightsless->("Owner.EmailAddress LIKE 'bestpractical'");
$assetsql_rightsless->("Owner.Name = 'Nobody'");
$assetsql_rightsless->("Owner = '__CurrentUser__'");
$assetsql_rightsless->("Owner != '__CurrentUser__'");
$assetsql_rightsless->("OwnerGroup = 'Sysadmins'");
$assetsql_rightsless->("OwnerGroup = 'Memberless'");

$assetsql_rightsless->("Contact.Name = 'shawn'");
$assetsql_rightsless->("Contact = '__CurrentUser__'");
$assetsql_rightsless->("Contact != '__CurrentUser__'");
$assetsql_rightsless->("ContactGroup = 'Sysadmins'");
$assetsql_rightsless->("ContactGroup = 'Memberless'");

$assetsql_rightsless->("CustomField.{Manufacturer} = 'Apple'");
$assetsql_rightsless->("CF.{Manufacturer} != 'Apple'");
$assetsql_rightsless->("CustomFieldValue.{Manufacturer} = 'Raspberry Pi'");
$assetsql_rightsless->("CF.{Manufacturer} IS NULL");

$assetsql_rightsless->("CF.{Blank} IS NULL");
$assetsql_rightsless->("CF.{Blank} IS NOT NULL");

$assetsql_rightsless->("Status = '__Active__' AND Catalog = 'Servers'");
$assetsql_rightsless->("Status = 'in-use' AND Catalog = 'Laptops'");
$assetsql_rightsless->("Catalog != 'Servers' AND Catalog != 'Laptops'");
$assetsql_rightsless->("Description LIKE 'BPS' AND Contact.Name IS NULL");
$assetsql_rightsless->("CF.{Manufacturer} = 'Apple' AND Catalog = 'Laptops'");
$assetsql_rightsless->("Catalog = 'Servers' AND Linked IS NULL");
$assetsql_rightsless->("Catalog = 'Servers' OR Linked IS NULL");
$assetsql_rightsless->("(Catalog = 'Keyboards' AND CF.{Manufacturer} = 'Apple') OR (Catalog = 'Servers' AND CF.{Manufacturer} = 'Raspberry Pi')");
