use strict;
use warnings;
use RT::Test tests => undef;

my @warnings;
local $SIG{__WARN__} = sub {
    push @warnings, "@_";
};

# Create ticket
my $ticket = RT::Test->create_ticket( Queue => 1, Subject => 'test ticket' );
ok $ticket->id, 'created ticket';

# Create article class
my $class = RT::Class->new( $RT::SystemUser );
$class->Create( Name => 'URItest - '. $$ );
ok $class->id, 'created a class';

# Create article
my $article = RT::Article->new( $RT::SystemUser );
$article->Create(
    Name    => 'Testing URI parsing - '. $$,
    Summary => 'In which this should load',
    Class   => $class->Id
);
ok $article->id, 'create article';

# Create a user and a user-defined group so the user:/group: shorthands can be
# resolved by Name (names are unique), not just by numeric id.
my $user = RT::User->new( $RT::SystemUser );
$user->Create( Name => 'uri-canon-user-'. $$, Privileged => 1 );
ok $user->id, 'created a user';

my $group = RT::Group->new( $RT::SystemUser );
$group->CreateUserDefinedGroup( Name => 'uri-canon-group-'. $$ );
ok $group->id, 'created a user-defined group';

# Test permutations of URIs
my $ORG = RT->Config->Get('Organization');
my $URI = RT::URI->new( RT->SystemUser );
my %expected = (
    # tickets
    "1"                                 => "fsck.com-rt://$ORG/ticket/1",
    "t:1"                               => "fsck.com-rt://$ORG/ticket/1",
    "fsck.com-rt://$ORG/ticket/1"       => "fsck.com-rt://$ORG/ticket/1",

    # articles
    "a:1"                               => "fsck.com-article://$ORG/article/1",
    "fsck.com-article://$ORG/article/1" => "fsck.com-article://$ORG/article/1",

    # users -- by id and by (unique) Name
    "user:@{[$user->id]}"               => "user://$ORG/@{[$user->id]}",
    "user:@{[$user->Name]}"             => "user://$ORG/@{[$user->id]}",
    "user://$ORG/@{[$user->id]}"        => "user://$ORG/@{[$user->id]}",

    # groups -- by id and by (unique) Name
    "group:@{[$group->id]}"             => "group://$ORG/@{[$group->id]}",
    "group:@{[$group->Name]}"           => "group://$ORG/@{[$group->id]}",
    "group://$ORG/@{[$group->id]}"      => "group://$ORG/@{[$group->id]}",

    # random stuff
    "http://$ORG"                       => "http://$ORG",
    "mailto:foo\@example.com"           => "mailto:foo\@example.com",
    "invalid"                           => "invalid",   # doesn't trigger die
);
for my $uri (sort keys %expected) {
    is $URI->CanonicalizeURI($uri), $expected{$uri}, "canonicalized as expected";
}

# RT::URI->ParseObjectURI is the lightweight (no-load) classifier the Links display uses to
# bucket links by object type: it returns (Class, id) for a local RT object URI and an empty
# list for external, remote, or unparseable URIs, without resolving the object.
my %parse_expected = (
    "fsck.com-rt://$ORG/ticket/42"          => [ 'RT::Ticket',      42 ],
    "fsck.com-article://$ORG/article/7"     => [ 'RT::Article',     7 ],
    "asset://$ORG/5"                        => [ 'RT::Asset',       5 ],
    "user://$ORG/3"                         => [ 'RT::User',        3 ],
    "group://$ORG/9"                        => [ 'RT::Group',       9 ],
    "transaction://$ORG/100"                => [ 'RT::Transaction', 100 ],
    "FSCK.COM-RT://$ORG/ticket/1"           => [ 'RT::Ticket',      1 ],   # scheme is case-insensitive
    "https://example.org/foo"               => [],                        # external URL
    "mailto:foo\@example.com"               => [],                        # not an object URI
    "http://$ORG/123"                       => [],                        # unknown scheme
    "fsck.com-rt://other.example/ticket/1"  => [],                        # remote organization
    "fsck.com-rt://$ORG/ticket/"            => [],                        # missing id
);
for my $uri ( sort keys %parse_expected ) {
    is_deeply [ RT::URI->ParseObjectURI($uri) ], $parse_expected{$uri}, "ParseObjectURI: $uri";
}
is_deeply [ RT::URI->ParseObjectURI(undef) ], [], 'ParseObjectURI: undef';
is_deeply [ RT::URI->ParseObjectURI('') ],    [], 'ParseObjectURI: empty string';

is_deeply \@warnings, [
    "Could not determine a URI scheme for invalid\n",
], "expected warnings";

done_testing;
