use warnings;
use strict;

package RT::Test::Email;
use Test::More;
use Test::Email;
use Email::Abstract;
use base 'Exporter';
our @EXPORT = qw(mail_ok);

RT::Test->set_mail_catcher;

=head1 NAME

RT::Test::Email - 

=head1 SYNOPSIS

  use RT::Test::Email;

  mail_ok {
    # ... code

  } { from => 'admin@localhost', body => qr('hello') },
    { from => 'admin@localhost', body => qr('hello again') };

  # ... more code

  # XXX: not yet
  mail_sent_ok { from => 'admin@localhost', body => qr('hello') };

  # you should expect all mails by the end of the test


=head1 DESCRIPTION

This is a test helper module for RT, allowing you to expect mail
notification generated during the block or the test.

=cut

sub mail_ok (&@) {
    my $code = shift;

    $code->();
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my @msgs = RT::Test->fetch_caught_mails;
    is(@msgs, @_, "Sent exactly " . @_ . " emails");

    for my $spec (@_) {
        my $msg = shift @msgs
            or ok(0, 'Expecting message but none found.'), next;

        my $te = Email::Abstract->new($msg)->cast('MIME::Entity');
        diag $te->as_string;
        bless $te, 'Test::Email';
        $te->ok($spec, "email matched");
    }
    RT::Test->clean_caught_mails;
}

END {
    my $Test = Test::More->builder;
    # Such a hack -- try to detect if this is a forked copy and don't
    # do cleanup in that case.
    return if $Test->{Original_Pid} != $$;

    if (scalar RT::Test->fetch_caught_mails) {
        diag ((scalar RT::Test->fetch_caught_mails)." uncaught notification email at end of test: ");
        diag "From: @{[ $_->header('From' ) ]}, Subject: @{[ $_->header('Subject') ]}"
            for RT::Test->fetch_caught_mails;
        die;
    }
}

1;

