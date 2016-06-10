use utf8;
use warnings;
use strict;

use RT::Test tests => undef;

my $t = RT::Test->create_ticket( Subject => 'test canonicalize values', Queue => 'General' );

{
    diag "testing invalid canonicalizer";
    my $invalid = RT::CustomField->new(RT->SystemUser);
    my ($ok, $msg) = $invalid->Create(
        Name              => 'uppercase',
        Type              => 'FreeformSingle',
        Queue             => 0,
        CanonicalizeClass => 'RT::CustomFieldValues::Canonicalizer::NonExistent',
    );
    ok(!$ok, "Didn't create CF");
    like($msg, qr/Invalid custom field values canonicalizer/);
}

{
    diag "testing uppercase canonicalizer";
    my $uppercase = RT::Test->load_or_create_custom_field(
        Name              => 'uppercase',
        Type              => 'FreeformSingle',
        Queue             => 0,
        CanonicalizeClass => 'RT::CustomFieldValues::Canonicalizer::Uppercase',
    );
    is($uppercase->CanonicalizeClass, 'RT::CustomFieldValues::Canonicalizer::Uppercase', 'CanonicalizeClass');

    my @tests = (
        'hello world'          => 'HELLO WORLD',
        'Hello World'          => 'HELLO WORLD',
        'ABC 123 xyz !@#'      => 'ABC 123 XYZ !@#',
        'Unicode aware: "ω Ω"' => 'UNICODE AWARE: "Ω Ω"',
        'てすとテスト'         => 'てすとテスト',
    );

    while (my ($input, $expected) = splice @tests, 0, 2) {
        my ($ok, $msg) = $t->AddCustomFieldValue(
            Field => $uppercase,
            Value => $input,
        );
        ok( $ok, $msg );
        is( $t->FirstCustomFieldValue($uppercase), $expected, 'canonicalized to uppercase' );
     }
}

{
    diag "testing lowercase canonicalizer";
    my $lowercase = RT::Test->load_or_create_custom_field(
        Name              => 'lowercase',
        Type              => 'FreeformSingle',
        Queue             => 0,
        CanonicalizeClass => 'RT::CustomFieldValues::Canonicalizer::Lowercase',
    );
    is($lowercase->CanonicalizeClass, 'RT::CustomFieldValues::Canonicalizer::Lowercase', 'CanonicalizeClass');

    my @tests = (
        'hello world'          => 'hello world',
        'Hello World'          => 'hello world',
        'ABC 123 xyz !@#'      => 'abc 123 xyz !@#',
        'Unicode aware: "ω Ω"' => 'unicode aware: "ω ω"',
        'てすとテスト'         => 'てすとテスト',
    );

    while (my ($input, $expected) = splice @tests, 0, 2) {
        my ($ok, $msg) = $t->AddCustomFieldValue(
            Field => $lowercase,
            Value => $input,
        );
        ok( $ok, $msg );
        is( $t->FirstCustomFieldValue($lowercase), $expected, 'canonicalized to lowercase' );
     }
}

{
    diag "testing asset canonicalizer";

    my $assetcf = RT::Test->load_or_create_custom_field(
        Name              => 'assetcf',
        Type              => 'FreeformSingle',
        LookupType        => RT::Asset->CustomFieldLookupType,
        CanonicalizeClass => 'RT::CustomFieldValues::Canonicalizer::Uppercase',
    );
    $assetcf->AddToObject(RT::Catalog->new(RT->SystemUser));
    is($assetcf->CanonicalizeClass, 'RT::CustomFieldValues::Canonicalizer::Uppercase', 'CanonicalizeClass');

    my $asset = RT::Asset->new(RT->SystemUser);
    my ($ok, $msg) = $asset->Create(Subject => 'test canonicalizers', Catalog => 'General assets');
    ok($ok, $msg);

    my @tests = (
        'hello world'          => 'HELLO WORLD',
        'Hello World'          => 'HELLO WORLD',
        'ABC 123 xyz !@#'      => 'ABC 123 XYZ !@#',
        'Unicode aware: "ω Ω"' => 'UNICODE AWARE: "Ω Ω"',
        'てすとテスト'         => 'てすとテスト',
    );

    while (my ($input, $expected) = splice @tests, 0, 2) {
        my ($ok, $msg) = $asset->AddCustomFieldValue(
            Field => $assetcf,
            Value => $input,
        );
        ok( $ok, $msg );
        is( $asset->FirstCustomFieldValue($assetcf), $expected, 'canonicalized to uppercase' );
     }
}

done_testing;

