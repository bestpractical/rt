use strict;
use warnings;

use RT::Test tests => undef;
use RT::Test::Email;

my $specs = RT::Test->load_or_create_queue( Name => 'Specs' );

my $engineer = RT::CustomRole->new(RT->SystemUser);
my $sales = RT::CustomRole->new(RT->SystemUser);
my $unapplied = RT::CustomRole->new(RT->SystemUser);

my $linus = RT::Test->load_or_create_user( EmailAddress => 'linus@example.com' );
my $blake = RT::Test->load_or_create_user( EmailAddress => 'blake@example.com' );
my $williamson = RT::Test->load_or_create_user( EmailAddress => 'williamson@example.com' );
my $moss = RT::Test->load_or_create_user( EmailAddress => 'moss@example.com' );
my $ricky = RT::Test->load_or_create_user( EmailAddress => 'ricky.roma@example.com' );

diag 'setup' if $ENV{'TEST_VERBOSE'};
{
    ok( RT::Test->add_rights( { Principal => 'Privileged', Right => [ qw(CreateTicket ShowTicket ModifyTicket OwnTicket SeeQueue) ] } ));

    my ($ok, $msg) = $engineer->Create(
        Name      => 'Engineer',
        MaxValues => 1,
    );
    ok($ok, "created Engineer role: $msg");

    ($ok, $msg) = $sales->Create(
        Name      => 'Sales',
        MaxValues => 0,
    );
    ok($ok, "created Sales role: $msg");

    ($ok, $msg) = $unapplied->Create(
        Name      => 'Unapplied',
        MaxValues => 0,
    );
    ok($ok, "created Unapplied role: $msg");

    ($ok, $msg) = $sales->AddToObject($specs->id);
    ok($ok, "added Sales to Specs: $msg");

    ($ok, $msg) = $engineer->AddToObject($specs->id);
    ok($ok, "added Engineer to Specs: $msg");

}

diag 'create tickets in Specs without scrips' if $ENV{'TEST_VERBOSE'};
{
    mail_ok {
         RT::Test->create_ticket(
             Queue     => $specs,
             Subject   => 'a ticket',
             Owner     => $williamson,
             Requestor => [$blake->EmailAddress],
         );
    } { To => $blake->EmailAddress, Cc => '', Bcc => '' },
      { To => $williamson->EmailAddress, Cc => '', Bcc => '' };

    mail_ok {
         RT::Test->create_ticket(
             Queue     => $specs,
             Subject   => 'another ticket',
             Owner     => $linus,
             Requestor => [$moss->EmailAddress, $williamson->EmailAddress],
             Cc        => [$ricky->EmailAddress],
             AdminCc   => [$blake->EmailAddress],
         );
    } { To => (join ', ', $moss->EmailAddress, $williamson->EmailAddress), Cc => '', Bcc => '' },
      { To => $linus->EmailAddress, Cc => '', Bcc => $blake->EmailAddress },
      { To => '', Cc => $ricky->EmailAddress, Bcc => '' };

    mail_ok {
         RT::Test->create_ticket(
             Queue                => $specs,
             Subject              => 'oops',
             Owner                => $ricky,
             $engineer->GroupType => $linus,
         );
    } { To => $ricky->EmailAddress, Cc => '', Bcc => '' };

    mail_ok {
         RT::Test->create_ticket(
             Queue                => $specs,
             Subject              => 'oops',
             Owner                => $ricky,
             $engineer->GroupType => $linus,
             $sales->GroupType    => [$blake->EmailAddress],
         );
    } { To => $ricky->EmailAddress, Cc => '', Bcc => '' };

    mail_ok {
         RT::Test->create_ticket(
             Queue                => $specs,
             Subject              => 'more',
             Owner                => $ricky,
             Requestor            => [$williamson->EmailAddress],
             Cc                   => [$moss->EmailAddress],
             AdminCc              => [$blake->EmailAddress],
             $engineer->GroupType => $linus,
             $sales->GroupType    => [$blake->EmailAddress, $williamson->EmailAddress],
         );
    } { To => $williamson->EmailAddress, Cc => '', Bcc => '' },
      { To => $ricky->EmailAddress, Cc => '', Bcc => $blake->EmailAddress },
      { To => '', Cc => $moss->EmailAddress, Bcc => '' };

    mail_ok {
         RT::Test->create_ticket(
             Queue                => $specs,
             Subject              => 'more',
             Owner                => $ricky,
             $sales->GroupType    => [$blake->EmailAddress, $williamson->EmailAddress],
         );
    } { To => $ricky->EmailAddress, Cc => '', Bcc => '' };
}

diag 'create scrips' if $ENV{'TEST_VERBOSE'};
{
    my $a1 = RT::ScripAction->new(RT->SystemUser);
    my ($val, $msg) = $a1->Create(
        Name       => 'Notify Engineer as Cc',
        ExecModule => 'Notify',
        Argument   => 'Engineer',
    );
    ok($val, $msg);

    my $s1 = RT::Scrip->new(RT->SystemUser);
    ($val, $msg) = $s1->Create(
        Queue          => 'Specs',
        ScripCondition => 'On Create',
        ScripAction    => 'Notify Engineer as Cc',
        Template       => 'Correspondence',
    );
    ok($val, $msg);

    my $a2 = RT::ScripAction->new(RT->SystemUser);
    ($val, $msg) = $a2->Create(
        Name       => 'Notify Sales as To',
        ExecModule => 'Notify',
        Argument   => 'RT::CustomRole-2/To',
    );
    ok($val, $msg);

    my $s2 = RT::Scrip->new(RT->SystemUser);
    ($val, $msg) = $s2->Create(
        Queue          => 'Specs',
        ScripCondition => 'On Create',
        ScripAction    => 'Notify Sales as To',
        Template       => 'Admin Correspondence',
    );
    ok($val, $msg);

    my $a3 = RT::ScripAction->new(RT->SystemUser);
    ($val, $msg) = $a2->Create(
        Name       => 'Notify Unapplied as Bcc',
        ExecModule => 'Notify',
        Argument   => 'Unapplied/Bcc',
    );
    ok($val, $msg);

    my $s3 = RT::Scrip->new(RT->SystemUser);
    ($val, $msg) = $s2->Create(
        Queue          => 'Specs',
        ScripCondition => 'On Create',
        ScripAction    => 'Notify Unapplied as Bcc',
        Template       => 'Admin Correspondence',
    );
    ok($val, $msg);
}

diag 'create tickets in Specs with scrips' if $ENV{'TEST_VERBOSE'};
{
    mail_ok {
         RT::Test->create_ticket(
             Queue     => $specs,
             Subject   => 'a ticket',
             Owner     => $williamson,
             Requestor => [$blake->EmailAddress],
         );
    } { To => $blake->EmailAddress, Cc => '', Bcc => '' },
      { To => $williamson->EmailAddress, Cc => '', Bcc => '' };

    mail_ok {
         RT::Test->create_ticket(
             Queue     => $specs,
             Subject   => 'another ticket',
             Owner     => $linus,
             Requestor => [$moss->EmailAddress, $williamson->EmailAddress],
             Cc        => [$ricky->EmailAddress],
             AdminCc   => [$blake->EmailAddress],
         );
    } { To => (join ', ', $moss->EmailAddress, $williamson->EmailAddress), Cc => '', Bcc => '' },
      { To => $linus->EmailAddress, Cc => '', Bcc => $blake->EmailAddress },
      { To => '', Cc => $ricky->EmailAddress, Bcc => '' };

    mail_ok {
         RT::Test->create_ticket(
             Queue                => $specs,
             Subject              => 'oops',
             Owner                => $ricky,
             $engineer->GroupType => $linus,
         );
    } { To => $ricky->EmailAddress, Cc => '', Bcc => '' },
      { To => '', Cc => $linus->EmailAddress, Bcc => '' };

    mail_ok {
         RT::Test->create_ticket(
             Queue                => $specs,
             Subject              => 'oops',
             Owner                => $ricky,
             $engineer->GroupType => $linus,
             $sales->GroupType    => [$blake->EmailAddress],
         );
    } { To => $ricky->EmailAddress, Cc => '', Bcc => '' },
      { To => '', Cc => $linus->EmailAddress, Bcc => '' },
      { To => $blake->EmailAddress, Cc => '', Bcc => '' };

    mail_ok {
         RT::Test->create_ticket(
             Queue                => $specs,
             Subject              => 'more',
             Owner                => $ricky,
             Requestor            => [$williamson->EmailAddress],
             Cc                   => [$moss->EmailAddress],
             AdminCc              => [$blake->EmailAddress],
             $engineer->GroupType => $linus,
             $sales->GroupType    => [$blake->EmailAddress, $williamson->EmailAddress],
         );
    } { To => $williamson->EmailAddress, Cc => '', Bcc => '' },
      { To => $ricky->EmailAddress, Cc => '', Bcc => $blake->EmailAddress },
      { To => '', Cc => $moss->EmailAddress, Bcc => '' },
      { To => '', Cc => $linus->EmailAddress, Bcc => '' },
      { To => (join ', ', $blake->EmailAddress, $williamson->EmailAddress), Cc => '', Bcc => '' };

    mail_ok {
         RT::Test->create_ticket(
             Queue                => $specs,
             Subject              => 'more',
             Owner                => $ricky,
             $sales->GroupType    => [$blake->EmailAddress, $williamson->EmailAddress],
         );
    } { To => $ricky->EmailAddress, Cc => '', Bcc => '' },
      { To => (join ', ', $blake->EmailAddress, $williamson->EmailAddress), Cc => '', Bcc => '' };
}

done_testing;

