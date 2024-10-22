# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2024 Best Practical Solutions, LLC
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

package RT::Test::REST2;

use strict;
use warnings;

use base 'RT::Test';
use Test::WWW::Mechanize::PSGI;
use JSON qw( to_json decode_json);
use URI;
use File::Slurp;
use Try::Tiny;

# Store requests
my @requests_log;

sub import {
    my $class = shift;
    my %args  = @_;

    $class->SUPER::import( %args );
    __PACKAGE__->export_to_level(1);
}

=pod

sub import {
    my $class = shift;
    my %args  = @_;

    $args{'requires'} ||= [];
    if ( $args{'testing'} ) {
        unshift @{ $args{'requires'} }, 'RT::REST2';
    } else {
        $args{'testing'} = 'RT::REST2';
    }

    $class->SUPER::import( %args );
    $class->export_to_level(1);

    require RT::REST2;
}

=cut

sub mech { RT::Test::REST2::Mechanize->new }

{
    my $u;

    sub authorization_header {
        $u = _create_user() unless ($u && $u->id);
        return 'Basic dGVzdDpwYXNzd29yZA==';
    }

    sub user {
        $u = _create_user() unless ($u && $u->id);
        return $u;
    }

    sub _create_user {
        my $u = RT::User->new( RT->SystemUser );
        $u->Create(
            Name => 'test',
            Password => 'password',
            EmailAddress => 'test@rt.example',
            Privileged => 1,
        );
        return $u;
    }

    sub normalize_url {
        my ($url) = @_;

        # Prepend "http://" if no scheme is present
        $url = "http://$url" unless $url =~ m{^https?://};

        my $uri = URI->new($url);

        # Normalize any path segments that contain hard-coded digits
        my $path = $uri->path;

        # Replace any hard-coded digit in the path with {id}
        $path =~ s{(?<=/)\d+(?=/|$)}{\{id\}}g;

        # Return the normalized URL as a string
        return $path;
    }

    # Method to export requests log to OpenAPI YAML format
    sub export_requests_to_yaml {
        require YAML::XS;

        my $log_file = 'requests_log.yaml';    # Path to the request log file
        my %unique_endpoints;

        # Process existing requests from the log file if it exists
        if ( -e $log_file && -s $log_file > 0 ) {
            my $existing_content = read_file($log_file);
            try {
                my $existing_requests = YAML::XS::Load($existing_content);

                # Populate %unique_endpoints with existing requests
                foreach my $endpoint (@$existing_requests) {
                    my $key = $endpoint->{method} . '|' . $endpoint->{url};

                    $unique_endpoints{$key} = {
                        method     => $endpoint->{method},
                        url        => $endpoint->{url},
                        parameters => $endpoint->{parameters},
                        headers    => $endpoint->{headers},
                        query      => $endpoint->{query},
                        responses  => $endpoint->{responses}
                    };
                }
            };

            # Catch and warn about any YAML errors
            if ($@) {
                warn
                    "Warning: Could not decode existing YAML in the log file: $@";
            }
        }

        foreach my $req (@requests_log) {
            my $normalized_endpoint = normalize_url( $req->{url} );
            $req->{url} = $normalized_endpoint;

            # Use the HTTP method and normalized endpoint as a unique key
            my $key = $req->{method} . '|' . $normalized_endpoint;

            # Handle non-GET request parameters (e.g., POST body)
            my $params = try {
                if ( defined $req->{params} && !ref $req->{params} ) {
                    decode_json( $req->{params} );
                } else {
                    $req->{params} || {};
                }
            } catch {
                $req->{params} || {};
            };

            # If the endpoint hasn't been recorded before, initialize it
            if ( !exists $unique_endpoints{$key} ) {
                $unique_endpoints{$key} = {
                    method     => $req->{method},
                    url        => $normalized_endpoint,
                    parameters => $params,
                    query      => $req->{query},
                    headers    => $req->{headers},
                    responses => {}, # Use a hash to store unique status codes
                };
            } else {
                if ( ref $params eq 'HASH' ) {
                    if (  !exists $unique_endpoints{$key}->{parameters}
                        || ref $unique_endpoints{$key}->{parameters} eq
                        'HASH' )
                    {

                        # Merge new parameters with existing ones
                        foreach my $param_key ( keys %{$params} ) {

                            # If the parameter doesn't already exist, add it
                            if ( !exists $unique_endpoints{$key}->{parameters}
                                ->{$param_key} )
                            {
                                $unique_endpoints{$key}->{parameters}
                                    ->{$param_key} = $params->{$param_key};
                            }
                        }
                    }
                }
            }

            # Log the response
            $unique_endpoints{$key}->{responses}->{ $req->{response}->{code} }
                = {
                status  => $req->{response}->{code},
                content => $req->{response}->{content},
                headers => $req->{response}->{headers},
                };
        }

        # Convert the unique endpoints data to YAML using YAML::XS
        my @unique_requests = values %unique_endpoints;
        my $yaml_output     = YAML::XS::Dump( \@unique_requests );

        # Write the updated data back to the log file
        open my $fh, '>', $log_file or die "Could not open '$log_file': $!";
        print $fh $yaml_output;
        close $fh;

        return
            $yaml_output;  # Optionally return the YAML output for further use
    }

}

{

    package RT::Test::REST2::Mechanize;
    use parent 'Test::WWW::Mechanize::PSGI';


=head1 METHODS

=cut

    use JSON;
    my $json = JSON->new->utf8;

    sub new {
        my $class = shift;
        my %args = (
            app => RT::REST2->PSGIWrap(sub { die "Requested non-REST path" }),
            @_,
        );
        return $class->SUPER::new(%args);
    }

    sub hypermedia_ref {
        my ($self, $ref) = @_;

        my $json = $self->json_response;
        my @matches = grep { $_->{ref} eq $ref } @{ $json->{_hyperlinks} };
        Test::More::is(@matches, 1, "got one match for hypermedia with ref '$ref'") or return;
        return $matches[0];

    }

    sub url_for_hypermedia {
        my ($self, $ref) = @_;
        return $self->hypermedia_ref($ref)->{_url};
    }

    sub post_json {
        my ($self, $url, $payload, %headers) = @_;
        $self->post(
            $url,
            Content => $json->encode($payload),
            'Content-Type' => 'application/json; charset=utf-8',
            %headers,
        );
    }

    sub put_json {
        my ($self, $url, $payload, %headers) = @_;
        $self->put(
            $url,
            $payload ? ( Content => $json->encode($payload) ) : (),
            'Content-Type' => 'application/json; charset=utf-8',
            %headers,
        );
    }

    sub json_response {
        local $Test::Builder::Level = $Test::Builder::Level + 1;
        my $self = shift;

        my $res = $self->response;

        local $main::TODO;
        Test::More::like($res->header('content-type'),
            qr{^application/json(?:; charset="?utf-8"?)?$});

        return $json->decode($res->content);
    }


=head2 request_with_logging

This method logs the request and response details for each request made by the
mechanize object. It is used to generate an OpenAPI YAML file that can be used.

=cut

    sub request_with_logging {
        my ( $self, $method, $url, @params ) = @_;

        # Dispatch table to map methods to the corresponding SUPER methods
        my %http_methods = (
            get    => sub { $self->SUPER::get( $url, @params ) },
            post   => sub { $self->SUPER::post( $url, @params ) },
            put    => sub { $self->SUPER::put( $url, @params ) },
            delete => sub { $self->SUPER::delete( $url, @params ) },
        );

        # Extract query parameters if the method is GET
        my %query_params;
        if ( $method eq 'get' ) {
            my $uri = URI->new($url);
            %query_params = $uri->query_form;
        }

        # Perform the request using the appropriate method
        my $response = $http_methods{$method}->();

# Handle different cases where request parameters differ (like POST with Content)
        my $logged_params;
        my %params_hash;

        for ( my $i = 0; $i < @params; $i++ ) {
            my $key = $params[$i];

            if ( ref $key eq 'HASH' ) {

                # If it's a hash reference, store it as-is in the hash
                $params_hash{"Data"} = $key;
            } elsif ( ref $key eq 'ARRAY' ) {

                # If it's an array reference, process it as a special case
                my $sub_array = $params[ $i + 1 ];
                $params_hash{$key} = $sub_array;
                $i++;
            } else {

                # Assume this is a scalar key, so pair it with the next value
                $params_hash{$key} = $params[ $i + 1 ];
                $i++;
            }
        }

        my $content = $params_hash{Content};

        # If we need to remove content
        delete $params_hash{Content};

        # Log both the request and the response details together
        push @requests_log, {
            method  => uc($method),
            url     => $url,
            query   => \%query_params, # Log query parameters for GET requests
            params  => $content,
            headers => \%params_hash,
            response => {
                code    => $response->code,
                content => $response->decoded_content,
                headers => $response
                    ->headers_as_string,
            }
        };

        return $response;    # Return the response after logging
    }

    # Wrapper methods for each HTTP verb
    sub get {
        my ( $self, $url, @params ) = @_;
        if ( $ENV{EXPORT_OPENAPI_YAML} ) {
            return $self->request_with_logging( 'get', $url, @params );
        }
        return $self->SUPER::get( $url, @params );
    }

    sub post {
        my ( $self, $url, @params ) = @_;
        if ( $ENV{EXPORT_OPENAPI_YAML} ) {
            return $self->request_with_logging( 'post', $url, @params );
        }
        return $self->SUPER::post( $url, @params );
    }

    sub put {
        my ( $self, $url, @params ) = @_;
        if ( $ENV{EXPORT_OPENAPI_YAML} ) {
            return $self->request_with_logging( 'put', $url, @params );
        }
        return $self->SUPER::put( $url, @params );
    }

    sub delete {
        my ( $self, $url, @params ) = @_;
        if ( $ENV{EXPORT_OPENAPI_YAML} ) {
            return $self->request_with_logging( 'delete', $url, @params );
        }
        return $self->SUPER::delete( $url, @params );
    }

}

1;
