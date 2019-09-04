package RT::RightsInspector;
use strict;
use warnings;

# glossary:
#     inner role - being granted a right by way of ticket role membership
#                  which is treated in a special way in RT. this is because
#                  members of ticket AdminCc group are neither members of
#                  the queue AdminCc group nor the system AdminCc group.
#                  this means we have to do a really gnarly joins to recover
#                  such ACLs. to improve comprehensibility we keep track
#                  of such inner roles then massage the serialized data
#                  afterwards to reference these implicit relationships
#     principal  - the recipient of a privilege; e.g. user or group
#     object     - the scope of the privilege; e.g. queue or system
#     record     - generalization of principal and object since rendering
#                  and whatnot can share code

my $PageLimit = 100;

$RT::Interface::Web::WHITELISTED_COMPONENT_ARGS{'/Admin/RightsInspector/index.html'} = ['Principal', 'Object', 'Right'];

sub CurrentUser {
    return $HTML::Mason::Commands::session{CurrentUser};
}

sub _EscapeHTML {
    my $s = shift;
    RT::Interface::Web::EscapeHTML(\$s);
    return $s;
}

sub _EscapeURI {
    my $s = shift;
    RT::Interface::Web::EscapeURI(\$s);
    return $s;
}

# used to convert a search term (e.g. "root") into a regex for highlighting
# in the UI. potentially useful hook point for implementing say, "ro*t"
sub RegexifyTermForHighlight {
    my $self = shift;
    my $term = shift || '';
    return qr/\Q$term\E/i;
}

# takes a text label and returns escaped html, highlighted using the search
# term(s)
sub HighlightTextForSearch {
    my $self = shift;
    my $text = shift;
    my $term = shift;

    my $re = ref($term) eq 'ARRAY'
           ? join '|', map { $self->RegexifyTermForHighlight($_) } @$term
           : $self->RegexifyTermForHighlight($term);

    # if $term is an arrayref, make sure we qr-ify it
    # without this, then if $term has no elements, we interpolate $re
    # as an empty string which causes the regex engine to fall into
    # an infinite loop
    $re = qr/$re/ unless ref($re);

    $text =~ s{
        \G         # where we left off the previous iteration thanks to /g
        (.*?)      # non-matching text before the match
        ($re|$)    # matching text, or the end of the line (to escape any
                   # text after the last match)
    }{
      _EscapeHTML($1) .
      (length $2 ? '<span class="match">' . _EscapeHTML($2) . '</span>' : '')
    }xeg;

    return $text; # now escaped as html
}

# takes a serialized result and highlights its labels according to the search
# terms
sub HighlightSerializedForSearch {
    my $self         = shift;
    my $serialized   = shift;
    my $args         = shift;
    my $regex_search = shift;

    # highlight matching terms
    $serialized->{right_highlighted} = $self->HighlightTextForSearch($serialized->{right}, [split ' ', $args->{right} || '']);

    for my $key (qw/principal object/) {
        for my $record ($serialized->{$key}, $serialized->{$key}->{primary_record}) {
            next if !$record;

            # if we used a regex search for this record, then highlight the
            # text that the regex matched
            if ($regex_search->{$key}) {
                for my $column (qw/label detail/) {
                    $record->{$column . '_highlighted'} = $self->HighlightTextForSearch($record->{$column}, $args->{$key});
                }
            }
            # otherwise we used a search like user:root and so we should
            # highlight just that user completely (but not its parent group)
            else {
                $record->{'highlight'} = $record->{primary_record} ? 0 : 1;
                for my $column (qw/label detail/) {
                    $record->{$column . '_highlighted'} = _EscapeHTML($record->{$column});
                }
            }
        }
    }

    return;
}

# takes "u:root" "group:37" style specs and returns the RT::Principal
sub PrincipalForSpec {
    my $self       = shift;
    my $type       = shift;
    my $identifier = shift;

    if ($type =~ /^(g|group)$/i) {
        my $group = RT::Group->new($self->CurrentUser);
        if ( $identifier =~ /^\d+$/ ) {
            $group->LoadByCols(
                id => $identifier,
            );
        } else {
            $group->LoadByCols(
                Domain => 'UserDefined',
                Name   => $identifier,
            );
        }

        return $group->PrincipalObj if $group->Id;
        return (0, "Unable to load group $identifier");
    }
    elsif ($type =~ /^(u|user)$/i) {
        my $user = RT::User->new($self->CurrentUser);
        my ($ok, $msg) = $user->Load($identifier);
        return $user->PrincipalObj if $user->Id;
        return (0, "Unable to load user $identifier");
    }
    else {
        RT->Logger->debug("Unexpected type '$type'");
    }

    return undef;
}

# takes "t#1" "queue:General", "asset:37" style specs and returns that object
# limited to thinks you can grant rights on
sub ObjectForSpec {
    my $self       = shift;
    my $type       = shift;
    my $identifier = shift;

    my $record;

    if ($type =~ /^(t|ticket)$/i) {
        $record = RT::Ticket->new($self->CurrentUser);
    }
    elsif ($type =~ /^(q|queue)$/i) {
        $record = RT::Queue->new($self->CurrentUser);
    }
    elsif ($type =~ /^asset$/i) {
        $record = RT::Asset->new($self->CurrentUser);
    }
    elsif ($type =~ /^catalog$/i) {
        $record = RT::Catalog->new($self->CurrentUser);
    }
    elsif ($type =~ /^(a|article)$/i) {
        $record = RT::Article->new($self->CurrentUser);
    }
    elsif ($type =~ /^class$/i) {
        $record = RT::Class->new($self->CurrentUser);
    }
    elsif ($type =~ /^cf|customfield$/i) {
        $record = RT::CustomField->new($self->CurrentUser);
    }
    elsif ($type =~ /^(g|group)$/i) {
        return $self->PrincipalForSpec($type, $identifier);
    }
    else {
        RT->Logger->debug("Unexpected type '$type'");
        return undef;
    }

    $record->Load($identifier);
    return $record if $record->Id;
    my $class = ref($record); $class =~ s/^RT:://;
    return (0, "Unable to load $class '$identifier'");

    return undef;
}

our %ParentMap = (
    'RT::Ticket' => [Queue => 'RT::Queue'],
    'RT::Asset' => [Catalog => 'RT::Catalog'],
);

# see inner role glossary entry
# this has three modes, depending on which parameters are passed
# - principal_id but no inner_id: find tickets/assets this principal
#   has permissions for
# - inner_id but no principal_id: find the queue/system permissions that affect
#   this ticket
# - principal and inner_id: find all permissions this principal has on
#   this "inner" object
# there's no analagous query in the RT codebase because it uses a caching approach;
# see RT::Tickets::_RolesCanSee
sub InnerRoleQuery {
    my $self = shift;
    my %args = (
        inner_class  => '', # RT::Ticket, RT::Asset
        principal_id => undef,
        inner_id     => undef,
        right_search => undef,
        @_,
    );

    my $inner_class  = $args{inner_class};
    my $principal_id = $args{principal_id};
    my $inner_id     = $args{inner_id};
    my $inner_table  = $inner_class->Table;

    my ($parent_column, $parent_class) = @{ $ParentMap{$inner_class} || [] }
        or die "No parent mapping specified for $inner_class";
    my $parent_table = $parent_class->Table;

    my @query = qq[
        SELECT main.id,
               MIN(InnerRecords.id) AS example_record,
               COUNT(InnerRecords.id)-1 AS other_count
        FROM ACL main
        JOIN Groups ParentRoles
             ON main.PrincipalId = ParentRoles.id
        JOIN $inner_table InnerRecords
             ON   (ParentRoles.Domain = '$parent_class-Role' AND InnerRecords.$parent_column = ParentRoles.Instance)
                OR ParentRoles.Domain = 'RT::System-Role'
        JOIN Groups InnerRoles
             ON  InnerRoles.Instance = InnerRecords.Id
             AND InnerRoles.Name = main.PrincipalType
    ];
    if ($principal_id) {
        push @query, qq[
            JOIN CachedGroupMembers CGM
                 ON CGM.GroupId = InnerRoles.id
        ];
    }

    push @query, qq[ WHERE ];

    if ($args{right_search}) {
        my $LIKE = RT->Config->Get('DatabaseType') eq 'Pg' ? 'ILIKE' : 'LIKE';

        push @query, qq[ ( ];
        for my $term (split ' ', $args{right_search}) {
            my $quoted = $RT::Handle->Quote('%' . $term . '%');
            push @query, qq[
                main.RightName $LIKE $quoted OR
            ],
        }
        push @query, qq[main.RightName $LIKE 'SuperUser'];
        push @query, qq[ ) AND ];
    }

    if ($principal_id) {
        push @query, qq[
             CGM.MemberId = $principal_id AND
             CGM.Disabled = 0 AND
        ];
    }
    else {
        #push @query, qq[
        #         CGM.MemberId = $principal_id AND
        #];
    }

    push @query, qq[
             InnerRecords.id = $inner_id AND
    ] if $inner_id;

    push @query, qq[
             InnerRoles.Domain = '$inner_class-Role'
        GROUP BY main.id
    ];

    return join "\n", @query;
}

# key entry point into this extension; takes a query (principal, object, right)
# and produces a list of highlighted results
sub Search {
    my $self = shift;
    my %args = (
        principal => '',
        object    => '',
        right     => '',
        @_,
    );

    my @results;

    my $ACL = RT::ACL->new($self->CurrentUser);

    my $has_search = 0;
    my %use_regex_search_for = (
        principal => 1,
        object    => 1,
    );
    my %primary_records = (
        principal => undef,
        object    => undef,
    );
    my %filter_out;
    my %inner_role;

    if ($args{right}) {
        $has_search = 1;

        push @{ $filter_out{right} }, $2
            while $args{right} =~ s/( |^)!(\S+)/$1/;

        for my $term (split ' ', $args{right}) {
            $ACL->Limit(
                FIELD           => 'RightName',
                OPERATOR        => 'LIKE',
                VALUE           => $term,
                CASESENSITIVE   => 0,
                ENTRYAGGREGATOR => 'OR',
            );
        }
        $ACL->Limit(
            FIELD           => 'RightName',
            OPERATOR        => '=',
            VALUE           => 'SuperUser',
            ENTRYAGGREGATOR => 'OR',
        );
    }

    if ($args{object}) {
        push @{ $filter_out{object} }, $2
            while $args{object} =~ s/( |^)!(\S+)/$1/;

        if (my ($type, $identifier) = $args{object} =~ m{
            ^
                \s*
                (t|ticket|q|queue|asset|catalog|a|article|class|g|group|cf|customfield)
                \s*
                [:#]
                \s*
                (.+?)
                \s*
            $
        }xi) {
            my ($record, $msg) = $self->ObjectForSpec($type, $identifier);
            if (!$record) {
                return { error => $msg || 'Unable to find row' };
            }

            $has_search = 1;
            $use_regex_search_for{object} = 0;

            $primary_records{object} = $record;

            for my $obj ($record, $record->ACLEquivalenceObjects, RT->System) {
                $ACL->_OpenParen('object');
                $ACL->Limit(
                    SUBCLAUSE          => 'object',
                    FIELD           => 'ObjectType',
                    OPERATOR        => '=',
                    VALUE           => ref($obj),
                    ENTRYAGGREGATOR => 'OR',
                );
                $ACL->Limit(
                    SUBCLAUSE          => 'object',
                    FIELD           => 'ObjectId',
                    OPERATOR        => '=',
                    VALUE           => $obj->Id,
                    QUOTEVALUE      => 0,
                    ENTRYAGGREGATOR => 'AND',
                );
                $ACL->_CloseParen('object');
            }
        }
    }

    my $principal_paren = 0;

    if ($args{principal}) {
        push @{ $filter_out{principal} }, $2
            while $args{principal} =~ s/( |^)!(\S+)/$1/;

        if (my ($type, $identifier) = $args{principal} =~ m{
            ^
                \s*
                (u|user|g|group)
                \s*
                [:#]
                \s*
                (.+?)
                \s*
            $
        }xi) {
            my ($principal, $msg) = $self->PrincipalForSpec($type, $identifier);
            if (!$principal) {
                return { error => $msg || 'Unable to find row' };
            }

            $has_search = 1;
            $use_regex_search_for{principal} = 0;

            $primary_records{principal} = $principal;

            my $principal_alias = $ACL->Join(
                ALIAS1 => 'main',
                FIELD1 => 'PrincipalId',
                TABLE2 => 'Principals',
                FIELD2 => 'id',
            );

            my $cgm_alias = $ACL->Join(
                ALIAS1 => 'main',
                FIELD1 => 'PrincipalId',
                TABLE2 => 'CachedGroupMembers',
                FIELD2 => 'GroupId',
            );
            $ACL->_OpenParen('principal');
            $principal_paren = 1;
            $ACL->Limit(
                ALIAS => $cgm_alias,
                SUBCLAUSE => 'principal',
                FIELD => 'Disabled',
                QUOTEVALUE => 0,
                VALUE => 0,
                ENTRYAGGREGATOR => 'AND',
            );
            $ACL->Limit(
                ALIAS => $cgm_alias,
                SUBCLAUSE => 'principal',
                FIELD => 'MemberId',
                VALUE => $principal->Id,
                QUOTEVALUE => 0,
                ENTRYAGGREGATOR => 'AND',
            );
        }
    }

    # now we need to address the unfortunate fact that ticket role
    # members are not listed as queue role members. the way we do this
    # is with a many-join query to map queue roles to ticket roles
    if ($primary_records{principal} || $primary_records{object}) {
        for my $inner_class (keys %ParentMap) {
            next if $primary_records{object}
                 && !$primary_records{object}->isa($inner_class);

            my $query = $self->InnerRoleQuery(
                inner_class  => $inner_class,
                principal_id => ($primary_records{principal} ? $primary_records{principal}->Id : undef),
                inner_id     => ($primary_records{object} ? $primary_records{object}->Id : undef),
                right_search => $args{right},
            );
            my $sth = $ACL->_Handle->SimpleQuery($query);
            my @acl_ids;
            while (my ($acl_id, $record_id, $other_count) = $sth->fetchrow_array) {
                push @acl_ids, $acl_id;
                $inner_role{$acl_id} = [$inner_class, $record_id, $other_count];
            }
            if (@acl_ids) {
                if (!$principal_paren) {
                    $ACL->_OpenParen('principal');
                    $principal_paren = 1;
                }

                $ACL->Limit(
                    SUBCLAUSE => 'principal',
                    FIELD     => 'id',
                    OPERATOR  => 'IN',
                    VALUE     => \@acl_ids,
                    ENTRYAGGREGATOR => 'OR',
                );
            }
        }
    }

    $ACL->_CloseParen('principal') if $principal_paren;

    if ($args{continueAfter}) {
        $has_search = 1;
        $ACL->Limit(
            FIELD     => 'id',
            OPERATOR  => '>',
            VALUE     => int($args{continueAfter}),
            QUOTEVALUE => 0,
        );
    }

    $ACL->OrderBy(
        ALIAS => 'main',
        FIELD => 'id',
        ORDER => 'ASC',
    );

    $ACL->UnLimit unless $has_search;

    $ACL->RowsPerPage($PageLimit);

    my $continueAfter;

    ACE: while (my $ACE = $ACL->Next) {
        $continueAfter = $ACE->Id;
        my $serialized = $self->SerializeACE($ACE, \%primary_records, \%inner_role);

        for my $key (keys %filter_out) {
            for my $term (@{ $filter_out{$key} }) {
                my $re = qr/\Q$term\E/i;
                if ($key eq 'right') {
                    next ACE if $serialized->{right} =~ $re;
                }
                else {
                    my $record = $serialized->{$key};
                    next ACE if $record->{class}  =~ $re
                             || $record->{id}     =~ $re
                             || $record->{label}  =~ $re
                             || $record->{detail} =~ $re;
                }
            }
        }

        KEY: for my $key (qw/principal object/) {
	    # filtering on the serialized record is hacky, but doing the
	    # searching in SQL is absolutely a nonstarter
            next KEY unless $use_regex_search_for{$key};

            if (my $term = $args{$key}) {
                my $record = $serialized->{$key};
                $term =~ s/^\s+//;
                $term =~ s/\s+$//;
                my $re = qr/\Q$term\E/i;
                next KEY if $record->{class}  =~ $re
                         || $record->{id}     =~ $re
                         || $record->{label}  =~ $re
                         || $record->{detail} =~ $re;

                # no matches
                next ACE;
            }
        }

        $self->HighlightSerializedForSearch($serialized, \%args, \%use_regex_search_for);

        push @results, $serialized;
    }

    return {
        results => \@results,
        continueAfter => $continueAfter,
    };
}

# takes an ACE (singular version of ACL) and produces a JSON-serializable
# dictionary for transmitting over the wire
sub SerializeACE {
    my $self = shift;
    my $ACE = shift;
    my $primary_records = shift;
    my $inner_role = shift;

    my $serialized = {
        principal      => $self->SerializeRecord($ACE->PrincipalObj, $primary_records->{principal}),
        object         => $self->SerializeRecord($ACE->Object, $primary_records->{object}),
        right          => $ACE->RightName,
        ace            => { id => $ACE->Id },
        disable_revoke => $self->DisableRevoke($ACE),
    };

    if ($inner_role->{$ACE->Id}) {
        $self->InjectSerializedWithInnerRoleDetails($serialized, $ACE, $inner_role->{$ACE->Id}, $primary_records);
    }

    return $serialized;
}

# should the "Revoke" button be disabled? by default it is for the two required
# system privileges; if such privileges needed to be revoked they can be done
# through the ordinary ACL management UI
sub DisableRevoke {
    my $self = shift;
    my $ACE = shift;
    my $Principal = $ACE->PrincipalObj;
    my $Object    = $ACE->Object;
    my $Right     = $ACE->RightName;

    if ($Principal->Object->Domain eq 'ACLEquivalence') {
        my $User = $Principal->Object->InstanceObj;
        if ($User->Id == RT->SystemUser->Id && $Object->isa('RT::System') && $Right eq 'SuperUser') {
            return 1;
        }
        if ($User->Id == RT->Nobody->Id && $Object->isa('RT::System') && $Right eq 'OwnTicket') {
            return 1;
        }
    }

    return 0;
}

# convert principal to its user/group, custom role group to its custom role, etc
sub CanonicalizeRecord {
    my $self = shift;
    my $record = shift;

    return undef unless $record;

    if ($record->isa('RT::Principal')) {
        $record = $record->Object;
    }

    if ($record->isa('RT::Group')) {
        if ($record->Domain eq 'ACLEquivalence') {
            my $principal = RT::Principal->new($record->CurrentUser);
            $principal->Load($record->Instance);
            $record = $principal->Object;
        }
        elsif ($record->Domain =~ /-Role$/) {
            my ($id) = $record->Name =~ /^RT::CustomRole-(\d+)$/;
            if ($id) {
                my $role = RT::CustomRole->new($record->CurrentUser);
                $role->Load($id);
                $record = $role;
            }
        }
    }

    return $record;
}

# takes a user, group, ticket, queue, etc and produces a JSON-serializable
# dictionary
sub SerializeRecord {
    my $self = shift;
    my $record = shift;
    my $primary_record = shift;

    return undef unless $record;

    $record = $self->CanonicalizeRecord($record);
    $primary_record = $self->CanonicalizeRecord($primary_record);

    undef $primary_record if $primary_record
                          && ref($record) eq ref($primary_record)
                          && $record->Id == $primary_record->Id;

    my $serialized = {
        class           => ref($record),
        id              => $record->id,
        label           => $self->LabelForRecord($record),
        detail          => $self->DetailForRecord($record),
        url             => $self->URLForRecord($record),
        disabled        => $self->DisabledForRecord($record) ? JSON::true : JSON::false,
        primary_record  => $self->SerializeRecord($primary_record),
    };

    return $serialized;
}

sub InjectSerializedWithInnerRoleDetails {
    my $self = shift;
    my $serialized = shift;
    my $ACE = shift;
    my $inner_role = shift;
    my $primary_records = shift;

    my $principal = $self->CanonicalizeRecord($ACE->PrincipalObj);
    my $object = $self->CanonicalizeRecord($ACE->Object);
    my $primary_principal = $self->CanonicalizeRecord($primary_records->{principal}) || $principal;
    my $primary_object = $self->CanonicalizeRecord($primary_records->{object}) || $object;

    if ($principal->isa('RT::Group') || $principal->isa('RT::CustomRole')) {
        my ($inner_class, $inner_id, $inner_count) = @$inner_role;
        my $inner_record = $inner_class->new($self->CurrentUser);
        $inner_record->Load($inner_id);

        $inner_class =~ s/^RT:://i;
        my $detail = "$inner_class #$inner_id ";
        $detail .= $principal->isa('RT::Group') ? 'Role' : 'CustomRole';

        $serialized->{principal}{detail} = $detail;
        $serialized->{principal}{detail_url} = $self->URLForRecord($inner_record);

        if ($inner_count) {
            $serialized->{principal}{detail_extra} = $self->CurrentUser->loc("(+[quant,_1,other,others])", $inner_count);

            if ($inner_class eq 'Ticket' && $primary_principal->isa('RT::User')) {
                my $query;
                if ($ACE->Object->isa('RT::Queue')) {
                    my $name = $ACE->Object->Name;
                    $name =~ s/(['\\])/\\$1/g;
                    $query .= "Queue = '$name' AND ";
                }
                my $user_name = $primary_principal->Name;
                $user_name =~ s/(['\\])/\\$1/g;

                my $role_name = $principal->Name;
                $role_name =~ s/(['\\])/\\$1/g;

                my $role_term = $principal->isa('RT::Group') ? $role_name
                              : "CustomRole.{$role_name}";

                $query .= "$role_term.Name = '$user_name'";

                $serialized->{principal}{detail_extra_url} = RT->Config->Get('WebURL') . 'Search/Results.html?Query=' . _EscapeURI($query);
            }
        }
    }
}

# primary display label for a record (e.g. user name, ticket subject)
sub LabelForRecord {
    my $self = shift;
    my $record = shift;

    if ($record->isa('RT::Ticket')) {
        return $record->Subject || $self->CurrentUser->loc('(No subject)');
    }

    return $record->Name || $self->CurrentUser->loc('(No name)');
}

# boolean indicating whether the record should be labeled as disabled in the UI
sub DisabledForRecord {
    my $self = shift;
    my $record = shift;

    if ($record->can('Disabled') || $record->_Accessible('Disabled', 'read')) {
        return $record->Disabled;
    }

    return 0;
}

# secondary detail information for a record (e.g. ticket #)
sub DetailForRecord {
    my $self = shift;
    my $record = shift;

    my $id = $record->Id;

    return 'Global System' if $record->isa('RT::System');

    return 'System User' if $record->isa('RT::User')
                         && ($id == RT->SystemUser->Id || $id == RT->Nobody->Id);

    # like RT::Group->SelfDescription but without the redundant labels
    if ($record->isa('RT::Group')) {
        if ($record->RoleClass) {
            my $class = $record->RoleClass;
            $class =~ s/^RT:://i;
            return "$class Role";
        }
        elsif ($record->Domain eq 'SystemInternal') {
            return "System Group";
        }
    }

    my $type = ref($record);
    $type =~ s/^RT:://;

    return $type . ' #' . $id;
}

# most appropriate URL for a record. admin UI preferred, but for objects without
# admin UI (such as ticket) then user UI is fine
sub URLForRecord {
    my $self = shift;
    my $record = shift;
    my $id = $record->id;

    if ($record->isa('RT::Queue')) {
        return RT->Config->Get('WebURL') . 'Admin/Queues/Modify.html?id=' . $id;
    }
    elsif ($record->isa('RT::User')) {
        return undef if $id == RT->SystemUser->id
                     || $id == RT->Nobody->id;

        return RT->Config->Get('WebURL') . 'Admin/Users/Modify.html?id=' . $id;
    }
    elsif ($record->isa('RT::Group')) {
        if ($record->Domain eq 'UserDefined') {
            return RT->Config->Get('WebURL') . 'Admin/Groups/Modify.html?id=' . $id;
        }
        elsif ($record->Domain eq 'RT::System-Role') {
            return RT->Config->Get('WebURL') . 'Admin/Global/GroupRights.html#acl-' . $id;
        }
        elsif ($record->Domain eq 'RT::Queue-Role') {
            return RT->Config->Get('WebURL') . 'Admin/Queues/GroupRights.html?id=' . $record->Instance . '#acl-' . $id;
        }
        elsif ($record->Domain eq 'RT::Catalog-Role') {
            return RT->Config->Get('WebURL') . 'Admin/Assets/Catalogs/GroupRights.html?id=' . $record->Instance . '#acl-' . $id;
        }
        else {
            return undef;
        }
    }
    elsif ($record->isa('RT::CustomField')) {
        return RT->Config->Get('WebURL') . 'Admin/CustomFields/Modify.html?id=' . $id;
    }
    elsif ($record->isa('RT::Class')) {
        return RT->Config->Get('WebURL') . 'Admin/Articles/Classes/Modify.html?id=' . $id;
    }
    elsif ($record->isa('RT::Catalog')) {
        return RT->Config->Get('WebURL') . 'Admin/Assets/Catalogs/Modify.html?id=' . $id;
    }
    elsif ($record->isa('RT::CustomRole')) {
        return RT->Config->Get('WebURL') . 'Admin/CustomRoles/Modify.html?id=' . $id;
    }
    elsif ($record->isa('RT::Ticket')) {
        return RT->Config->Get('WebURL') . 'Ticket/Display.html?id=' . $id;
    }
    elsif ($record->isa('RT::Asset')) {
        return RT->Config->Get('WebURL') . 'Asset/Display.html?id=' . $id;
    }
    elsif ($record->isa('RT::Article')) {
        return RT->Config->Get('WebURL') . 'Articles/Article/Display.html?id=' . $id;
    }

    return undef;
}

1;
