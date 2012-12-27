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

    # random stuff
    "http://$ORG"                       => "http://$ORG",
    "mailto:foo\@example.com"           => "mailto:foo\@example.com",
    "invalid"                           => "invalid",   # doesn't trigger die
);
for my $uri (sort keys %expected) {
    is $URI->CanonicalizeURI($uri), $expected{$uri}, "canonicalized as expected";
}

is_deeply \@warnings, [
    "Could not determine a URI scheme for invalid\n",
], "expected warnings";

done_testing;
