# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2017 Best Practical Solutions, LLC
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

package RT::Test::Web;

use strict;
use warnings;

use base qw(Test::WWW::Mechanize);
use Scalar::Util qw(weaken);

BEGIN { require RT::Test; }
require Test::More;

my $instance;

sub new {
    my ($class, @args) = @_;

    push @args, app => $RT::Test::TEST_APP if $RT::Test::TEST_APP;
    my $self = $instance = $class->SUPER::new(@args);
    weaken $instance;
    $self->cookie_jar(HTTP::Cookies->new);

    return $self;
}

sub get_ok {
    my $self = shift;
    my $url = shift;
    if ( $url =~ s!^/!! ) {
        $url = $self->rt_base_url . $url;
    }
    my $rv = $self->SUPER::get_ok($url, @_);
    Test::More::diag( "Couldn't get $url" ) unless $rv;
    return $rv;
}

sub rt_base_url {
    return $RT::Test::existing_server if $RT::Test::existing_server;
    return "http://localhost:" . RT->Config->Get('WebPort') . RT->Config->Get('WebPath') . "/";
}

sub login {
    my $self = shift;
    my $user = shift || 'root';
    my $pass = shift || 'password';
    my %args = @_;
    
    $self->logout if $args{logout};

    my $url = $self->rt_base_url;
    $self->get($url . "?user=$user;pass=$pass");
    unless ( $self->status == 200 ) {
        Test::More::diag( "error: status is ". $self->status );
        return 0;
    }
    unless ( $self->content =~ m/Logout/i ) {
        Test::More::diag("error: page has no Logout");
        return 0;
    }
    RT::Interface::Web::EscapeUTF8(\$user);
    unless ( $self->content =~ m{<span class="current-user">\Q$user\E</span>}i ) {
        Test::More::diag("Page has no user name");
        return 0;
    }
    return 1;
}

sub logout {
    my $self = shift;

    my $url = $self->rt_base_url;
    $self->get($url);
    Test::More::diag( "error: status is ". $self->status )
        unless $self->status == 200;

    if ( $self->content =~ /Logout/i ) {
        $self->follow_link( text => 'Logout' );
        Test::More::diag( "error: status is ". $self->status ." when tried to logout" )
            unless $self->status == 200;
    }
    else {
        return 1;
    }

    $self->get($url);
    if ( $self->content =~ /Logout/i ) {
        Test::More::diag( "error: couldn't logout" );
        return 0;
    }
    return 1;
}

sub goto_ticket {
    my $self = shift;
    my $id   = shift;
    unless ( $id && int $id ) {
        Test::More::diag( "error: wrong id ". defined $id? $id : '(undef)' );
        return 0;
    }

    my $url = $self->rt_base_url;
    $url .= "Ticket/Display.html?id=$id";
    $self->get($url);
    unless ( $self->status == 200 ) {
        Test::More::diag( "error: status is ". $self->status );
        return 0;
    }
    return 1;
}

sub goto_create_ticket {
    my $self = shift;
    my $queue = shift;

    my $id;
    if ( ref $queue ) {
        $id = $queue->id;
    } elsif ( $queue =~ /^\d+$/ ) {
        $id = $queue;
    } else {
        die "not yet implemented";
    }

    $self->get($self->rt_base_url . 'Ticket/Create.html?Queue='.$id);

    return 1;
}

sub get_warnings {
    my $self = shift;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    # We clone here so that when we fetch warnings, we don't disrupt the state
    # of the test's mech. If we reuse the original mech then you can't
    # test warnings immediately after fetching page XYZ, then fill out
    # forms on XYZ. This is because the most recently fetched page has changed
    # from XYZ to /__test_warnings, which has no form.
    my $clone = $self->clone;
    return unless $clone->get_ok('/__test_warnings');

    use Storable 'thaw';

    my @warnings = @{ thaw $clone->content };
    return @warnings;
}

sub warning_like {
    my $self = shift;
    my $re   = shift;
    my $name = shift;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my @warnings = $self->get_warnings;
    if (@warnings == 0) {
        Test::More::fail("no warnings emitted; expected 1");
        return 0;
    }
    elsif (@warnings > 1) {
        Test::More::fail(scalar(@warnings) . " warnings emitted; expected 1");
        for (@warnings) {
            Test::More::diag("got warning: $_");
        }
        return 0;
    }

    return Test::More::like($warnings[0], $re, $name);
}

sub next_warning_like {
    my $self = shift;
    my $re   = shift;
    my $name = shift;

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    if (@{ $self->{stashed_server_warnings} || [] } == 0) {
        my @warnings = $self->get_warnings;
        if (@warnings == 0) {
            Test::More::fail("no warnings emitted; expected 1");
            return 0;
        }
        $self->{stashed_server_warnings} = \@warnings;
    }

    my $warning = shift @{ $self->{stashed_server_warnings} };
    return Test::More::like($warning, $re, $name);
}

sub no_warnings_ok {
    my $self = shift;
    my $name = shift || "no warnings emitted";

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my @warnings = $self->get_warnings;

    Test::More::is(@warnings, 0, $name);
    for (@warnings) {
        Test::More::diag("got warning: $_");
    }

    return @warnings == 0 ? 1 : 0;
}

sub no_leftover_warnings_ok {
    my $self = shift;

    my $name = shift || "no leftover warnings";

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    # we clear the warnings because we don't want to break later tests
    # in case there *are* leftover warnings
    my @warnings = splice @{ $self->{stashed_server_warnings} || [] };

    Test::More::is(@warnings, 0, $name);
    for (@warnings) {
        Test::More::diag("leftover warning: $_");
    }

    return @warnings == 0 ? 1 : 0;
}

sub ticket_status {
    my $self = shift;
    my $id = shift;
    
    $self->display_ticket( $id);
    my ($got) = ($self->content =~ m{Status:\s*</td>\s*<td[^>]*?class="value"[^>]*?>\s*([\w ]+?)\s*</td>}ism);
    unless ( $got ) {
        Test::More::diag("Error: couldn't find status value on the page, may be regexp problem");
    }
    return $got;
}

sub ticket_status_is {
    my $self = shift;
    my $id = shift;
    my $status = shift;
    my $desc = shift || "Status of the ticket #$id is '$status'";
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    return Test::More::is($self->ticket_status( $id), $status, $desc);
}

sub get_ticket_id {
    my $self = shift;
    my $content = $self->content;
    my $id = 0;
    if ($content =~ /.*Ticket (\d+) created.*/g) {
        $id = $1;
    }
    elsif ($content =~ /.*No permission to view newly created ticket #(\d+).*/g) {
        Test::More::diag("\nNo permissions to view the ticket.\n") if($ENV{'TEST_VERBOSE'});
        $id = $1;
    }
    return $id;
}

sub set_custom_field {
    my $self   = shift;
    my $queue   = shift;
    my $cf_name = shift;
    my $val     = shift;
    
    my $field_name = $self->custom_field_input( $queue, $cf_name )
        or return 0;

    $self->field($field_name, $val);
    return 1;
}

sub custom_field_input {
    my $self   = shift;
    my $queue   = shift;
    my $cf_name = shift;

    my $cf_obj = RT::CustomField->new( $RT::SystemUser );
    $cf_obj->LoadByName( Queue => $queue, Name => $cf_name );
    unless ( $cf_obj->id ) {
        Test::More::diag("Can not load custom field '$cf_name' in queue '$queue'");
        return undef;
    }
    my $cf_id = $cf_obj->id;
    
    my ($res) =
        grep /^Object-RT::Ticket-\d*-CustomField-$cf_id-Values?$/,
        map $_->name,
        $self->current_form->inputs;
    unless ( $res ) {
        Test::More::diag("Can not find input for custom field '$cf_name' #$cf_id");
        return undef;
    }
    return $res;
}

sub check_links {
    my $self = shift;
    my %args = @_;

    my %has = map {$_ => 1} @{ $args{'has'} };
    my %has_no = map {$_ => 1} @{ $args{'has_no'} };

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my @found;

    my @links = $self->followable_links;
    foreach my $text ( grep defined && length, map $_->text, @links ) {
        push @found, $text if $has_no{ $text };
        delete $has{ $text };
    }
    if ( @found || keys %has ) {
        Test::More::ok( 0, "expected links" );
        Test::More::diag( "didn't expect, but found: ". join ', ', map "'$_'", @found )
            if @found;
        Test::More::diag( "didn't find, but expected: ". join ', ', map "'$_'", keys %has )
            if keys %has;
        return 0;
    }
    return Test::More::ok( 1, "expected links" );
}

sub DESTROY {
    my $self = shift;
    if ( !$RT::Test::Web::DESTROY++ ) {
        $self->no_warnings_ok;
    }
}

END {
    return unless $instance;
    return if RT::Test->builder->{Original_Pid} != $$;
    $instance->no_warnings_ok if !$RT::Test::Web::DESTROY++;
}

1;
