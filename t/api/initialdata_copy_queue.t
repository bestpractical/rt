use warnings;
use strict;

use RT::Test tests => undef;
RT->Config->Set( 'InitialdataFormatHandlers' => [ 'perl', 'RT::Initialdata::JSON' ] );

my $general = RT::Test->load_or_create_queue( Name => 'General' );
my $queue   = RT::Test->load_or_create_queue( Name => 'Test' );

my $user     = RT::Test->load_or_create_user( Name => 'alice' );
my $group    = RT::Test->load_or_create_group('Duty');
my $engineer = RT::CustomRole->new( RT->SystemUser );
ok(
    $engineer->Create(
        Name      => 'Engineer',
        MaxValues => 0,
    )
);
ok( $engineer->AddToObject( $_->id ) ) for $general, $queue;
my $class = RT::Class->new( RT->SystemUser );
ok( $class->Create( Name => 'FAQ' ) );
ok( $class->AddToObject($_) ) for $general, $queue;

ok( $queue->AddWatcher(Type => 'AdminCc', PrincipalId => $user->Id ) );
ok( $queue->AddWatcher(Type => 'Cc', PrincipalId => $group->Id ) );

my $scrip = RT::Scrip->new( RT->SystemUser );
ok(
    $scrip->Create(
        Description    => 'On Comment Notify Owner',
        ScripCondition => 'On Comment',
        ScripAction    => 'Notify Owner',
        Template       => 'Blank',
    )
);

ok( $scrip->AddToObject( $_->id ) ) for $general, $queue;

my $template = RT::Template->new( RT->SystemUser );
ok( $template->Create( Name => 'Foo', Description => 'Foo Description', Queue => $queue->Id, Content => q{Foo} ) );

my $custom_field = RT::Test->load_or_create_custom_field(
    Name  => 'Action',
    Type  => 'FreeformSingle',
    Queue => $queue->Id,
);
ok( $custom_field->SetDefaultValues( Object => $queue, Values => 'review, merge' ) );


RT::Test->add_rights(
    { Principal => 'Everyone',           Right => 'SeeQueue',     Object => RT->System },
    { Principal => 'Requestor',          Right => 'ShowTicket',   Object => $general },
    { Principal => $group,               Right => 'TakeTicket',   Object => RT->System },
    { Principal => $user,                Right => 'StealTicket',  Object => $general },
    { Principal => $engineer->GroupType, Right => 'CreateTicket', Object => RT->System },

    { Principal => 'Privileged',         Right => 'ReplyToTicket',   Object => $queue },
    { Principal => 'AdminCc',            Right => 'CommentOnTicket', Object => $queue },
    { Principal => $user,                Right => 'SeeCustomField',  Object => $queue },
    { Principal => $group,               Right => 'ModifyTicket',    Object => $queue },
    { Principal => $engineer->GroupType, Right => 'OwnTicket',       Object => $queue },
);

my $parent_dir = RT->Config->Get('LogDir');
my $global_dir = File::Spec->catdir( $parent_dir, 'global' );
my $queue_dir  = File::Spec->catdir( $parent_dir, 'queue' );

diag "Export queue Test";

ok(
    RT::Test->run_singleton_command(
        'sbin/rt-dump-initialdata', '--quiet', '--dir', $global_dir, '--sync', '--no-queues',
    ),
    'Dump global initialdata'
);

ok(
    RT::Test->run_singleton_command(
        'sbin/rt-dump-initialdata', '--quiet', '--dir', $queue_dir, '--sync', '--limit-queues', 'Test', '--base',
        File::Spec->catfile( $global_dir, 'initialdata.json' ),
    ),
    'Dump Test queue changes'
);

my $changes;
{
    open my $fh, "<" . File::Spec->catfile( $queue_dir, 'changes.json' ) or die "Can't load changes.json";
    local $/;
    $changes = <$fh>;
}

my $expected_changes = JSON::decode_json(<<'EOF');
{
   "ACL" : [
      {
         "GroupDomain" : "SystemInternal",
         "GroupType" : "Privileged",
         "ObjectId" : "Test",
         "ObjectType" : "RT::Queue",
         "RightName" : "ReplyToTicket"
      },
      {
         "GroupDomain" : "RT::Queue-Role",
         "GroupType" : "AdminCc",
         "ObjectId" : "Test",
         "ObjectType" : "RT::Queue",
         "RightName" : "CommentOnTicket"
      },
      {
         "ObjectId" : "Test",
         "ObjectType" : "RT::Queue",
         "RightName" : "SeeCustomField",
         "UserId" : "alice"
      },
      {
         "GroupDomain" : "UserDefined",
         "GroupId" : "Duty",
         "ObjectId" : "Test",
         "ObjectType" : "RT::Queue",
         "RightName" : "ModifyTicket"
      },
      {
         "GroupDomain" : "RT::Queue-Role",
         "GroupType" : "RT::CustomRole-Engineer",
         "ObjectId" : "Test",
         "ObjectType" : "RT::Queue",
         "RightName" : "OwnTicket"
      }
   ],
   "Attributes" : [
      {
         "Content" : {
            "Action" : "review, merge"
         },
         "ContentType" : "storable",
         "Name" : "CustomFieldDefaultValues",
         "Object" : "Test",
         "ObjectType" : "RT::Queue"
      }
   ],
   "Classes" : [
      {
         "ApplyTo" : [
            "Test"
         ],
         "_Original" : {
            "ApplyTo" : [],
            "Description" : "",
            "Name" : "FAQ",
            "SortOrder" : 0
         },
         "_Updated" : 1
      }
   ],
   "CustomFields" : [
      {
         "ApplyTo" : [
            "Test"
         ],
         "_Original" : {
            "ApplyTo" : [],
            "Description" : "",
            "EntryHint" : "Enter one value",
            "LookupType" : "RT::Queue-RT::Ticket",
            "MaxValues" : 1,
            "Name" : "Action",
            "SortOrder" : 0,
            "Type" : "Freeform"
         },
         "_Updated" : 1
      }
   ],
   "CustomRoles" : [
      {
         "ApplyTo" : [
            "Test"
         ],
         "_Original" : {
            "Description" : "",
            "EntryHint" : "",
            "MaxValues" : 0,
            "LookupType" : "RT::Queue-RT::Ticket",
            "Name" : "Engineer"
         },
         "_Updated" : 1
      }
   ],
   "Members" : [
      {
         "Class" : "RT::User",
         "Group" : "AdminCc",
         "GroupDomain" : "RT::Queue-Role",
         "GroupInstance" : "Test",
         "Name" : "alice"
      },
      {
         "Class" : "RT::Group",
         "Group" : "Cc",
         "GroupDomain" : "RT::Queue-Role",
         "GroupInstance" : "Test",
         "Name" : "Duty"
      }
   ],
   "Queues" : [
      {
         "CommentAddress" : "",
         "CorrespondAddress" : "",
         "Description" : "",
         "Lifecycle" : "default",
         "Name" : "Test",
         "SLADisabled" : 1,
         "SortOrder" : 0
      }
   ],
   "Templates" : [
      {
         "Content" : "Foo",
         "Description" : "Foo Description",
         "Name" : "Foo",
         "LookupType" : "RT::Queue-RT::Ticket",
         "ObjectId": "Test",
         "Type" : "Perl"
      }
   ]
}
EOF

# Remove empty strings as they are stored as NULL in Oracle and thus not dumped
if ( RT->Config->Get('DatabaseType') eq 'Oracle' ) {
    for my $type ( keys %$expected_changes ) {
        for my $item ( @{ $expected_changes->{$type} } ) {
            for my $field ( keys %$item ) {
                if ( $field eq '_Original' ) {
                    for my $orig_field ( keys %{ $item->{$field} } ) {
                        delete $item->{$field}{$orig_field} if $item->{$field}{$orig_field} eq '';
                    }
                }
                elsif ( $item->{$field} eq '' ) {
                    delete $item->{$field};
                }
            }
        }
    }
}

is_deeply( JSON::decode_json($changes), $expected_changes, 'Generated changes look good' );

diag "Import queue Test with a new name";
$changes =~ s/"Test"/"Test2"/g;

open my $fh, '>', File::Spec->catdir( $parent_dir, 'queue_changes.json' );
print $fh $changes;
close $fh;

ok(
    RT->DatabaseHandle->InsertData(
        File::Spec->catdir( $parent_dir, 'queue_changes.json' ),
        undef, disconnect_after => 0
    )
);

$queue_dir = File::Spec->catdir( $parent_dir, 'queue2' );

ok(
    RT::Test->run_singleton_command(
        'sbin/rt-dump-initialdata', '--quiet', '--dir', $queue_dir, '--sync', '--limit-queues', 'Test2', '--base',
        File::Spec->catfile( $global_dir, 'initialdata.json' ),
    ),
    'Dump Test2 queue changes'
);

my $new_changes;
{
    open my $fh, "<" . File::Spec->catfile( $queue_dir, 'changes.json' ) or die "Can't load changes.json";
    local $/;
    $new_changes = <$fh>;
}

is_deeply( JSON::decode_json($new_changes), JSON::decode_json($changes), 'Generated changes look good' );

done_testing;
