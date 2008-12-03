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

        $msg =~ s/^\s*//gs; # XXX: for some reasons, message from template has leading newline
        # XXX: use Test::Email directly?
        my $te = Email::Abstract->new($msg)->cast('MIME::Entity');
        bless $te, 'Test::Email';
        $te->ok($spec, "email matched");
        my $Test = Test::More->builder;
        if (!($Test->summary)[$Test->current_test-1]) {
            diag $te->as_string;
        }
    }
    RT::Test->clean_caught_mails;
}

END {
    my $Test = Test::More->builder;
    # Such a hack -- try to detect if this is a forked copy and don't
    # do cleanup in that case.
    return if $Test->{Original_Pid} != $$;

    my @mail = RT::Test->fetch_caught_mails;
    if (scalar @mail) {
        diag ((scalar @mail)." uncaught notification email at end of test: ");
        diag "From: @{[ $_->header('From' ) ]}, Subject: @{[ $_->header('Subject') ]}"
            for @mail;
        die;
    }
}

1;

