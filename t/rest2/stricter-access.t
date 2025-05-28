use strict;
use warnings;

use RT::Test::REST2 tests => undef;
use Test::Deep;

my $mech           = RT::Test::REST2->mech;
my $auth           = RT::Test::REST2->authorization_header;
my $rest_base_path = '/REST/2.0';
my $user           = RT::Test::REST2->user;

my ( $ret, $msg ) = $user->PrincipalObj->GrantRight( Right => 'ShowTicket' );
ok( $ret, $msg );

my @tests = (
    map( { {
                request => {
                    method => 'post_json',
                    url    => "/$_",
                    params => [ { field => 'id', value => '0', operator => '>' } ],
                },
                response => {
                    code          => 200,
                    json_response => {
                        'page'     => 1,
                        'total'    => undef,
                        'items'    => [],
                        'pages'    => undef,
                        'count'    => 0,
                        'per_page' => 20,
                        $_ eq 'transactions' ? ( next_page => re(qr{$rest_base_path/transactions\?page=2}) ) : (),
                    },
                },
    } } qw/queues catalogs assets classes articles customfields customroles groups transactions/ ),
    map( { {
                request => {
                    method => 'get',
                    url    => "/$_",
                    params => undef,
                },
                response => {
                    code          => 403,
                    json_response => {
                        message => 'Forbidden',
                    },
                },
    } } qw{queue/1 queue/100 catalog/1 catalog/100 class/1 class/100} ),
    {
        request => {
            method => 'post_json',
            url    => "/tickets",
            params => [ { field => 'id', value => '0', operator => '>' } ],
        },
        response => {
            code          => 200,
            json_response => {
                'page'     => 1,
                'total'    => 0,
                'items'    => [],
                'pages'    => 0,
                'count'    => 0,
                'per_page' => 20,
            },
        },
    },
    {
        request => {
            method => 'post_json',
            url    => "/users",
            params => [ { field => 'id', value => '0', operator => '>' } ],
        },
        response => {
            code          => 200,
            json_response => {
                'page'  => 1,
                'total' => 4,
                'items' => bag(
                    {
                        'type' => 'user',
                        'id'   => 'Nobody',
                        '_url' => re(qr{$rest_base_path/user/Nobody}),
                    },
                    {
                        'type' => 'user',
                        'id'   => 'root',
                        '_url' => re(qr{$rest_base_path/user/root}),
                    },
                    {
                        '_url' => re(qr{$rest_base_path/user/RT_System}),
                        'type' => 'user',
                        'id'   => 'RT_System'
                    },
                    {
                        '_url' => re(qr{$rest_base_path/user/test}),
                        'id'   => 'test',
                        'type' => 'user'
                    }
                ),
                'pages'    => 1,
                'count'    => 4,
                'per_page' => 20,
            },
        },
    },
    {
        request => {
            method => 'get',
            url    => "/rt",
            params => undef,
        },
        response => {
            code          => 200,
            json_response => {
                'Version' => $RT::VERSION,
            },
        },
    },
    sub {
        my $ticket = RT::Test->create_ticket(
            Queue         => 'General',
            Subject       => 'test ticket',
            TimeWorked    => 30,
            TimeEstimated => 100,
            TimeLeft      => 70,
        );
    },
    {
        request => {
            method => 'get',
            url    => "/ticket/1",
            params => undef,
        },
        response => {
            code          => 200,
            json_response => sub {
                my $get = shift;
                is( $get->{TimeWorked},    30 );
                is( $get->{TimeLeft},      70 );
                is( $get->{TimeEstimated}, 100 );
            },
        },
    },
);

for my $type (qw/ticket article asset/) {
    for my $id (qw/1 100/) {
        push @tests,
            {
                request => {
                    method => 'post_json',
                    url    => "/$type",
                    params => {
                          $type eq 'ticket'  ? ( Queue => $id )
                        : $type eq 'article' ? ( Class => $id )
                        :                      ( Catalog => $id )
                    },
                },
                response => {
                    code          => 403,
                    json_response => {
                        message => $type eq 'ticket' ? qq{No permission to create tickets in the queue '$id'}
                        : 'Permission Denied',
                    },
                }
            };
    }
}

push @tests, sub {
    my ( $ret, $msg ) = $user->SetPrivileged(0);
    ok( $ret, $msg );
    },
    {
        request => {
            method => 'post_json',
            url    => "/users",
            params => [ { field => 'id', value => '0', operator => '>' } ],
        },
        response => {
            code          => 403,
            json_response => {
                message => 'Forbidden',
            },
        },
    },
    {
        request => {
            method => 'get',
            url    => "/user/test",
            params => undef,
        },
        response => {
            code => 200,
        },
    },
    {
        request => {
            method => 'get',
            url    => "/user/root",
            params => undef,
        },
        response => {
            code          => 403,
            json_response => {
                message => 'Forbidden',
            },
        },
    },
    {
        request => {
            method => 'get',
            url    => "/ticket/1",
            params => undef,
        },
        response => {
            code          => 200,
            json_response => sub {
                my $get = shift;
                is( $get->{TimeWorked},    30 );
                is( $get->{TimeLeft},      70 );
                is( $get->{TimeEstimated}, 100 );
            },
        },
    },
    sub {
        RT::Test->stop_server;
        RT->Config->Set( HideTimeFieldsFromUnprivilegedUsers => 1 );
        RT::Test->started_ok;
    },
    {
        request => {
            method => 'get',
            url    => "/ticket/1",
            params => undef,
        },
        response => {
            code          => 200,
            json_response => sub {
                my $get = shift;
                ok( !exists $get->{TimeWorked},    'TimeWorked is not returned' );
                ok( !exists $get->{TimeLeft},      'TimeLeft is not returned' );
                ok( !exists $get->{TimeEstimated}, 'TimeEstimated is not returned' );
            },
        },
    };

for my $test (@tests) {
    if ( ref $test eq 'CODE' ) {
        $test->();
    }
    else {
        my $method = $test->{request}{method};
        my $res    = $mech->$method(
            $rest_base_path . $test->{request}{url},
            $test->{request}{params} || (),
            'Authorization' => $auth
        );
        is( $res->code, $test->{response}{code}, "$test->{request}{url} response code" );
        if ( my $response = $test->{response}{json_response} ) {
            if ( ref $response eq 'CODE' ) {
                $response->( $mech->json_response );
            }
            else {
                cmp_deeply(
                    $mech->json_response,
                    $test->{response}{json_response},
                    "$test->{request}{url} response json"
                );
            }
        }
    }
}

done_testing;
