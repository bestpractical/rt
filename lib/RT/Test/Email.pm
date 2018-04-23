# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2018 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
#
# (Except where explicitly superseded by other copyright notices)
#
#
# LICENSE:
#
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
#
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
#
#
# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# END BPS TAGGED BLOCK }}}

use warnings;
use strict;

package RT::Test::Email;
use Test::More;
use Test::Email;
use Email::Abstract;
use base 'Exporter';
our @EXPORT = qw(mail_ok);

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
            for map { Email::Abstract->new($_)->cast('Email::Simple') } @mail;

        die;
    }
}

1;

