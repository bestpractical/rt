#!/usr/bin/perl

use strict;
use warnings;

use RT;
RT::LoadConfig();
RT->Config->Set('LogToScreen' => 'debug');
RT::Init();

$| = 1;

$RT::Handle->BeginTransaction();

use RT::CustomFields;
my $CFs = RT::CustomFields->new( $RT::SystemUser );
$CFs->UnLimit;
$CFs->Limit( FIELD => 'Type', VALUE => 'Select' );

while (my $cf  = $CFs->Next ) {
    next if $cf->BasedOnObj->Id;
    my @categories;
    my %mapping;
    my $values = $cf->Values;
    while (my $value = $values->Next) {
        next unless defined $value->Category and length $value->Category;
        push @categories, $value->Category unless grep {$_ eq $value->Category} @categories;
        $mapping{$value->Name} = $value->Category;
    }
    next unless @categories;

    print "Found CF '@{[$cf->Name]}' with categories:\n";
    print "  $_\n" for @categories;

    print "Enter name of CF to create as category ('@{[$cf->Name]} category'): ";
    my $newname = <>;
    chomp $newname;
    $newname = $cf->Name . " category" unless length $newname;

    # bump the CF's sort oder up by one
    $cf->SetSortOrder( ($cf->SortOrder || 0) + 1 );

    # ..and add a new CF before it
    my $new = RT::CustomField->new( $RT::SystemUser );
    my ($id, $msg) = $new->Create(
        Name => $newname,
        Type => 'Select',
        MaxValues => 1,
        LookupType => $cf->LookupType,
        SortOrder => $cf->SortOrder - 1,
    );
    die "Can't create custom field '$newname': $msg" unless $id;

    # Set the CF to be based on what we just made
    $cf->SetBasedOn( $new->Id );

    # Apply it to all of the same things
    {
        my $ocfs = RT::ObjectCustomFields->new( $RT::SystemUser );
        $ocfs->LimitToCustomField( $cf->Id );
        while (my $ocf = $ocfs->Next) {
            my $newocf = RT::ObjectCustomField->new( $RT::SystemUser );
            ($id, $msg) = $newocf->Create(
                SortOrder => $ocf->SortOrder,
                CustomField => $new->Id,
                ObjectId => $ocf->ObjectId,
            );
            die "Can't create ObjectCustomField: $msg" unless $id;
        }
    }

    # Copy over all of the rights
    {
        my $acl = RT::ACL->new( $RT::SystemUser );
        $acl->LimitToObject( $cf );
        while (my $ace = $acl->Next) {
            my $newace = RT::ACE->new( $RT::SystemUser );
            ($id, $msg) = $newace->Create(
                PrincipalId => $ace->PrincipalId,
                PrincipalType => $ace->PrincipalType,
                RightName => $ace->RightName,
                Object => $new,
            );
            die "Can't assign rights: $msg" unless $id;
        }
    }

    # Add values for all of the categories
    for my $i (0..$#categories) {
        ($id, $msg) = $new->AddValue(
            Name => $categories[$i],
            SortOrder => $i + 1,
        );
        die "Can't create custom field value: $msg" unless $id;
    }

    # Grovel through all ObjectCustomFieldValues, and add the
    # appropriate category
    {
        my $ocfvs = RT::ObjectCustomFieldValues->new( $RT::SystemUser );
        $ocfvs->LimitToCustomField( $cf->Id );
        while (my $ocfv = $ocfvs->Next) {
            next unless exists $mapping{$ocfv->Content};
            my $newocfv = RT::ObjectCustomFieldValue->new( $RT::SystemUser );
            ($id, $msg) = $newocfv->Create(
                CustomField => $new->Id,
                ObjectType => $ocfv->ObjectType,
                ObjectId   => $ocfv->ObjectId,
                Content    => $mapping{$ocfv->Content},
            );
        }
    }
}

$RT::Handle->Commit;
