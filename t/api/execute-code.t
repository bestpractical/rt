use strict;
use warnings;
use RT::Test tests => 17;

my $ticket = RT::Ticket->new(RT->SystemUser);
ok(
    $ticket->Create(
        Subject => 'blue lines',
        Queue   => 'General',
    )
);

my $attacker = RT::User->new(RT->SystemUser);
ok(
    $attacker->Create(
        Name       => 'attacker',
        Password   => 'foobar',
        Privileged => 1,
    )
);

my $template_as_attacker = RT::Template->new($attacker);

# can't create templates without ModifyTemplate
my ($ok, $msg) = $template_as_attacker->Create(
    Name    => 'Harmless, honest!',
    Content => "\nhello ;)",
    Type    => 'Perl',
);
ok(!$ok, 'permission to create denied');


# permit modifying templates but they must be simple
$attacker->PrincipalObj->GrantRight(Right => 'ShowTemplate', Object => $RT::System);
$attacker->PrincipalObj->GrantRight(Right => 'ModifyTemplate', Object => $RT::System);

($ok, $msg) = $template_as_attacker->Create(
    Name    => 'Harmless, honest!',
    Content => "\nhello ;)",
    Type    => 'Perl',
);
ok(!$ok, 'permission to create denied');


($ok, $msg) = $template_as_attacker->Create(
    Name    => 'Harmless, honest!',
    Content => "\nhello ;)",
    Type    => 'Simple',
);
ok($ok, 'created template now that we have ModifyTemplate');

($ok, $msg) = $template_as_attacker->SetType('Perl');
ok(!$ok, 'permission to update type to Perl denied');

my $template_as_root = RT::Template->new(RT->SystemUser);
$template_as_root->Load('Harmless, honest!');
is($template_as_root->Content, "\nhello ;)");
is($template_as_root->Type, 'Simple');

$template_as_root->Parse(TicketObj => $ticket);
is($template_as_root->MIMEObj->stringify_body, "hello ;)");


# update the content to include code (even though Simple won't parse it)

($ok, $msg) = $template_as_attacker->SetContent("\nYou are { (my \$message = 'bjarq') =~ tr/a-z/n-za-m/; \$message }!");
ok($ok, 'updating Content permitted since the template is Simple');

$template_as_root = RT::Template->new(RT->SystemUser);
$template_as_root->Load('Harmless, honest!');

is($template_as_root->Content, "\nYou are { (my \$message = 'bjarq') =~ tr/a-z/n-za-m/; \$message }!");
is($template_as_root->Type, 'Simple');

$template_as_root->Parse(TicketObj => $ticket);
is($template_as_root->MIMEObj->stringify_body, "You are { (my \$message = 'bjarq') =~ tr/a-z/n-za-m/; \$message }!");


# try again, why not
($ok, $msg) = $template_as_attacker->SetType('Perl');
ok(!$ok, 'permission to update type to Perl denied');


# now root will change the template to genuine code
$template_as_root = RT::Template->new(RT->SystemUser);
$template_as_root->Load('Harmless, honest!');
$template_as_root->SetType('Perl');
$template_as_root->SetContent("\n{ scalar reverse \$Ticket->Subject }");

$template_as_root->Parse(TicketObj => $ticket);
is($template_as_root->MIMEObj->stringify_body, "senil eulb");


# see if we can update anything
$template_as_attacker = RT::Template->new($attacker);
$template_as_attacker->Load('Harmless, honest!');

($ok, $msg) = $template_as_attacker->SetContent("\nYou are { (my \$message = 'bjarq') =~ tr/a-z/n-za-m/; \$message }!");
ok(!$ok, 'updating Content forbidden since the template is Perl');

# try again just to be absolutely sure it doesn't work
$template_as_root = RT::Template->new(RT->SystemUser);
$template_as_root->Load('Harmless, honest!');
$template_as_root->SetType('Perl');
$template_as_root->SetContent("\n{ scalar reverse \$Ticket->Subject }");

$template_as_root->Parse(TicketObj => $ticket);
is($template_as_root->MIMEObj->stringify_body, "senil eulb");
