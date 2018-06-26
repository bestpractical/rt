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

package RT::Test::Web;

use strict;
use warnings;

use base qw(Test::WWW::Mechanize);
use MIME::Base64 qw//;
use Encode 'encode_utf8';
use Storable 'thaw';
use HTTP::Status qw();

BEGIN { require RT::Test; }
require Test::More;

$RT::Test::Web::INSTANCES = undef;

sub new {
    my ($class, @args) = @_;

    push @args, app => $RT::Test::TEST_APP if $RT::Test::TEST_APP;
    my $self = $class->SUPER::new(@args);
    $self->cookie_jar(HTTP::Cookies->new);
    # Clear our caches of anything that the server process may have done
    $self->add_handler(
        response_done => sub {
            RT::Record->FlushCache;
        },
    ) if RT::Record->can( "FlushCache" );

    $RT::Test::Web::INSTANCES++;
    return $self;
}

sub clone {
    my $self = shift;
    $RT::Test::Web::INSTANCES++ if defined $RT::Test::Web::INSTANCES;
    return $self->SUPER::clone();
}

sub get_ok {
    my $self = shift;
    my $url = shift;
    if ( $url =~ s!^/!! ) {
        $url = $self->rt_base_url . $url;
    }

    local $Test::Builder::Level = $Test::Builder::Level + 1;
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

    return 0 unless $self->logged_in_as($user);

    unless ( $self->content =~ m/Logout/i ) {
        Test::More::diag("error: page has no Logout");
        return 0;
    }
    return 1;
}

sub logged_in_as {
    my $self = shift;
    my $user = shift || '';

    unless ( $self->status == HTTP::Status::HTTP_OK ) {
        Test::More::diag( "error: status is ". $self->status );
        return 0;
    }
    RT::Interface::Web::EscapeHTML(\$user);
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
        unless $self->status == HTTP::Status::HTTP_OK;

    if ( $self->content =~ /Logout/i ) {
        $self->follow_link( text => 'Logout' );
        Test::More::diag( "error: status is ". $self->status ." when tried to logout" )
            unless $self->status == HTTP::Status::HTTP_OK;
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
    my $view = shift || 'Display';
    my $status = shift || HTTP::Status::HTTP_OK;
    unless ( $id && int $id ) {
        Test::More::diag( "error: wrong id ". defined $id? $id : '(undef)' );
        return 0;
    }

    my $url = $self->rt_base_url;
    $url .= "Ticket/${ view }.html?id=$id";
    $self->get($url);
    unless ( $self->status == $status ) {
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
        my $queue_obj = RT::Queue->new(RT->SystemUser);
        my ($ok, $msg) = $queue_obj->Load($queue);
        die "Unable to load queue '$queue': $msg" if !$ok;
        $id = $queue_obj->id;
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
    return @{ thaw $clone->content };
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
    $cf_obj->LoadByName(
        Name => $cf_name,
        LookupType => RT::Ticket->CustomFieldLookupType,
        ObjectId => $queue,
    );
    unless ( $cf_obj->id ) {
        Test::More::diag("Can not load custom field '$cf_name' in queue '$queue'");
        return undef;
    }
    my $cf_id = $cf_obj->id;
    
    my ($res) =
        grep /^Object-RT::Ticket-\d*-CustomField(?::\w+)?-$cf_id-Values?$/,
        map $_->name,
        $self->current_form->inputs;
    unless ( $res ) {
        Test::More::diag("Can not find input for custom field '$cf_name' #$cf_id");
        return undef;
    }
    return $res;
}

sub value_name {
    my $self = shift;
    my $field = shift;

    my $input = $self->current_form->find_input( $field )
        or return undef;

    my @names = $input->value_names;
    return $input->value unless @names;

    my @values = $input->possible_values;
    for ( my $i = 0; $i < @values; $i++ ) {
        return $names[ $i ] if $values[ $i ] eq $input->value;
    }
    return undef;
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

sub auth {
    my $self = shift;
    $self->default_header( $self->auth_header(@_) );
}

sub auth_header {
    my $self = shift;
    return Authorization => "Basic " .
        MIME::Base64::encode( join(":", @_) );
}

sub dom {
    my $self = shift;
    Carp::croak("Can not get DOM, not HTML repsone")
        unless $self->is_html;
    require Mojo::DOM;
    return Mojo::DOM->new( $self->content );
}

# override content_* and text_* methods in Test::Mech to dump the content
# on failure, to speed investigation
for my $method_name (qw/
    content_is content_contains content_lacks content_like content_unlike
    text_contains text_lacks text_like text_unlike
/) {
    my $super_method = __PACKAGE__->SUPER::can($method_name);
    my $implementation = sub {
        local $Test::Builder::Level = $Test::Builder::Level + 1;

        my $self = shift;
        my $ok = $self->$super_method(@_);
        if (!$ok) {
            my $dir = RT::Test->temp_directory;
            my ($name) = $self->uri->path =~ m{/([^/]+)$};
            $name ||= 'index.html';

            my $file = $dir . '/' . RT::Test->builder->current_test . '-' . $name;

            open my $handle, '>', $file or die $!;
            print $handle encode_utf8($self->content) or die $!;
            close $handle or die $!;

            Test::More::diag("Dumped failing test page content to $file");
        }
        return $ok;
    };

    no strict 'refs';
    *{$method_name} = $implementation;
}

sub DESTROY {
    my $self = shift;

    if (defined $RT::Test::Web::INSTANCES) {
        $RT::Test::Web::INSTANCES--;
        if ($RT::Test::Web::INSTANCES == 0 ) {
            # Ordering matters -- clean out INSTANCES before we check
            # warnings, so the clone therein sees that we've already begun
            # cleanups.
            undef $RT::Test::Web::INSTANCES;
            $self->no_warnings_ok;
        }
    }
}

END {
    return if RT::Test->builder->{Original_Pid} != $$;
    if (defined $RT::Test::Web::INSTANCES and $RT::Test::Web::INSTANCES == 0 ) {
        # Ordering matters -- clean out INSTANCES after the `new`
        # bumps it up to 1.
        my $cleanup = RT::Test::Web->new;
        undef $RT::Test::Web::INSTANCES;
        $cleanup->no_warnings_ok;
    }
}

1;
