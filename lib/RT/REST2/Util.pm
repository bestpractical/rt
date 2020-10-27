# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2020 Best Practical Solutions, LLC
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

package RT::REST2::Util;
use strict;
use warnings;

use JSON ();
use Scalar::Util qw( blessed );
use List::MoreUtils 'uniq';

use Sub::Exporter -setup => {
    exports => [qw[
        looks_like_uid
        expand_uid
        expand_uri
        serialize_record
        deserialize_record
        error_as_json
        record_type
        record_class
        escape_uri
        query_string
        custom_fields_for
        format_datetime
        update_custom_fields
        process_uploads
    ]]
};

sub looks_like_uid {
    my $value = shift;
    return 0 unless ref $value eq 'HASH';
    return 0 unless $value->{type} and $value->{id} and $value->{_url};
    return 1;
}

sub expand_uid {
    my $uid = shift;
       $uid = $$uid if ref $uid eq 'SCALAR';

    return if not defined $uid;

    my $Organization = RT->Config->Get('Organization');
    my ($class, $id) = $uid =~ /^([\w:]+)(?:-\Q$Organization\E)?-(.+)$/g;

    return unless $class and $id;

    $class =~ s/^RT:://;
    $class = lc $class;

    return {
        type    => $class,
        id      => $id,
        _url    => RT::REST2->base_uri . "/$class/$id",
    };
}

sub expand_uri {
    my $uri = shift;

    return {
        type    => 'external',
        _url    => $uri,
    };
}

sub format_datetime {
    my $sql  = shift;
    my $date = RT::Date->new( RT->SystemUser );
    $date->Set( Format => 'sql', Value => $sql );
    return $date->W3CDTF( Timezone => 'UTC' );
}

sub serialize_record {
    my $record = shift;
    my %data   = $record->Serialize(@_);

    no warnings 'redefine';
    local *RT::Deprecated = sub {
        # don't trigger deprecation warnings for $record->$column below
        # such as RT::Group->Type on 4.2
    };

    for my $column (grep !ref($data{$_}), keys %data) {
        if ($record->_Accessible($column => "read")) {
            # Replace values via the Perl API for consistency, access control,
            # and utf-8 handling.
            $data{$column} = $record->$column;

            # Promote raw SQL dates to a standard format
            if ($record->_Accessible($column => "type") =~ /(datetime|timestamp)/i) {
                $data{$column} = format_datetime( $data{$column} );
            }
        } else {
            delete $data{$column};
        }
    }

    # Add available values for Select RT::CustomField
    if (ref($record) eq 'RT::CustomField' && $record->Type eq 'Select') {
        my $values = $record->Values;
        while (my $val = $values->Next) {
            my $category = $record->BasedOn ? $val->Category : '';
            if (exists $data{Values}) {
                push @{$data{Values}}, {name => $val->Name, category => $category};
            } else {
                $data{Values} = [{name => $val->Name, category => $category}];
            }
        }
    }

    # Replace UIDs with object placeholders
    for my $uid (grep ref eq 'SCALAR', values %data) {
        $uid = expand_uid($uid);
    }

    # Include role members, if applicable
    if ($record->DOES("RT::Record::Role::Roles")) {
        for my $role ($record->Roles(ACLOnly => 0)) {
            my $members = $data{$role} = [];
            my $group = $record->RoleGroup($role);
            my $gm = $group->MembersObj;
            while ($_ = $gm->Next) {
                push @$members, expand_uid($_->MemberObj->Object->UID);
            }

            # Avoid the extra array ref for single member roles
            $data{$role} = shift @$members
                if $group->SingleMemberRoleGroup;
        }
    }

    if (my $cfs = custom_fields_for($record)) {
        my %values;
        while (my $cf = $cfs->Next) {
            if (! defined $values{$cf->Id}) {
                $values{$cf->Id} = {
                    %{ expand_uid($cf->UID) },
                    name   => $cf->Name,
                    values => [],
                };
            }
            my $ocfvs  = $cf->ValuesForObject( $record );
            my $type   = $cf->Type;
            while (my $ocfv = $ocfvs->Next) {
                my $content = $ocfv->Content;
                if ($type eq 'DateTime') {
                    $content = format_datetime($content);
                }
                elsif ($type eq 'Image' or $type eq 'Binary') {
                    $content = {
                        content_type => $ocfv->ContentType,
                        filename     => $content,
                        _url         => RT::REST2->base_uri . "/download/cf/" . $ocfv->id,
                    };
                }
                push @{ $values{$cf->Id}{values} }, $content;
            }
        }

        push @{ $data{CustomFields} }, values %values;
    }
    return \%data;
}

sub deserialize_record {
    my $record = shift;
    my $data   = shift;

    my $does_roles = $record->DOES("RT::Record::Role::Roles");

    # Sanitize input for the Perl API
    for my $field (sort keys %$data) {
        next if $field eq 'CustomFields';

        my $value = $data->{$field};
        next unless ref $value;
        if (looks_like_uid($value)) {
            # Deconstruct UIDs back into simple foreign key IDs, assuming it
            # points to the same record type (class).
            $data->{$field} = $value->{id} || 0;
        }
        elsif ($does_roles and ($field =~ /^RT::CustomRole-\d+$/ or $record->HasRole($field))) {
            my @members = ref $value eq 'ARRAY'
                ? @$value : $value;

            for my $member (@members) {
                $member = $member->{id} || 0
                    if looks_like_uid($member);
            }
            $data->{$field} = \@members;
        }
        else {
            RT->Logger->debug("Received unknown value via JSON for field $field: ".ref($value));
            delete $data->{$field};
        }
    }
    return $data;
}

sub error_as_json {
    my $response = shift;
    my $return = shift;

    my $body = JSON::encode_json({ message => join "", @_ });

    $response->content_type( "application/json; charset=utf-8" );
    $response->content_length( length $body );
    $response->body( $body );

    return $return;
}

sub record_type {
    my $object = shift;
    my ($type) = blessed($object) =~ /::(\w+)$/;
    return $type;
}

sub record_class {
    my $type = record_type(shift);
    return "RT::$type";
}

sub escape_uri {
    my $uri = shift;
    RT::Interface::Web::EscapeURI(\$uri);
    return $uri;
}

sub query_string {
    my %args = @_;
    my @params;
    for my $key (sort keys %args) {
        my $value = $args{$key};
        next unless defined $value;
        $key = escape_uri($key);
        if (UNIVERSAL::isa($value, 'ARRAY')) {
            push @params,
                map $key ."=". escape_uri($_),
                    map defined $_ ? $_ : '',
                        @$value;
        } else {
            push @params, $key . "=" . escape_uri($value);
        }
    }

    return join '&', @params;
}

sub custom_fields_for {
    my $record = shift;

    # no role yet, but we have registered lookup types
    my %registered_type = map {; $_ => 1 } RT::CustomField->LookupTypes;
    if ($registered_type{$record->CustomFieldLookupType}) {
        # see $HasTxnCFs in /Elements/ShowHistoryPage; seems like it's working
        # around a bug in RT::Transaction->CustomFieldLookupId
        if ($record->isa('RT::Transaction')) {
            my $object = $record->Object;
            if ($object->can('TransactionCustomFields') && $object->TransactionCustomFields->Count) {
                return $object->TransactionCustomFields;
            }
        }
        else {
            return $record->CustomFields;
        }
    }

    return;
}

sub update_custom_fields {
    my $record = shift;
    my $data = shift;

    my @results;

    foreach my $cfid (keys %{ $data }) {
        my $val = $data->{$cfid};

        my $cf = $record->LoadCustomFieldByIdentifier($cfid);
        next unless $cf->ObjectTypeFromLookupType($cf->__Value('LookupType'))->isa(ref $record);

        if ($cf->SingleValue) {
            my %args;
            my $old_val = $record->FirstCustomFieldValue($cfid);
            if (!defined $val && $old_val) {
                my ($ok, $msg) = $record->DeleteCustomFieldValue(
                    Field => $cf,
                    Value => $old_val,
                );
                push @results, $msg;
                next;
            }
            elsif (ref($val) eq 'ARRAY') {
                $val = $val->[0];
            }
            elsif (ref($val) eq 'HASH' && $cf->Type =~ /^(?:Image|Binary)$/) {
                my @required_fields;
                foreach my $field ('FileName', 'FileType', 'FileContent') {
                    unless ($val->{$field}) {
                        push @required_fields, "$field is a required field for Image/Binary ObjectCustomFieldValue";
                    }
                }
                if (@required_fields) {
                    push @results, @required_fields;
                    next;
                }
                $args{ContentType} = delete $val->{FileType};
                $args{LargeContent} = MIME::Base64::decode_base64(delete $val->{FileContent});
                $val = delete $val->{FileName};
            }
            elsif (ref($val)) {
                die "Invalid value type for CustomField $cfid";
            }

            my ($ok, $msg) = $record->AddCustomFieldValue(
                Field => $cf,
                Value => $val,
                %args,
            );
            push @results, $msg;
        }
        else {
            my %count;
            my @vals = ref($val) eq 'ARRAY' ? @$val : $val;
            my @content_vals;
            my %args;
            for my $value (@vals) {
                if (ref($value) eq 'HASH' && $cf->Type =~ /^(?:Image|Binary)$/) {
                    my @required_fields;
                    foreach my $field ('FileName', 'FileType', 'FileContent') {
                        unless ($value->{$field}) {
                            push @required_fields, "$field is a required field for Image/Binary ObjectCustomFieldValue";
                        }
                    }
                    if (@required_fields) {
                        push @results, @required_fields;
                        next;
                    }
                    my $key = delete $value->{FileName};
                    $args{$key}->{ContentType} = delete $value->{FileType};
                    $args{$key}->{LargeContent} = MIME::Base64::decode_base64(delete $value->{FileContent});
                    $count{$key}++;
                    push @content_vals, $key;
                }
                elsif (ref($value)) {
                    die "Invalid value type for CustomField $cfid";
                }
                else {
                    $count{$value}++;
                }
            }
            @vals = @content_vals if @content_vals;

            my $ocfvs = $cf->ValuesForObject( $record );
            my %ocfv_id;
            while (my $ocfv = $ocfvs->Next) {
                my $content = $ocfv->Content;
                $count{$content}--;
                push @{ $ocfv_id{$content} }, $ocfv->Id;
            }

            # we want to provide a stable order, so first go by the order
            # provided in the argument list, and then for any custom fields
            # that are being removed, remove in sorted order
            for my $key (uniq(@vals, sort keys %count)) {
                my $count = $count{$key};
                if ($count == 0) {
                    # new == old, no change needed
                }
                elsif ($count > 0) {
                    # new > old, need to add new
                    while ($count-- > 0) {
                        my ($ok, $msg) = $record->AddCustomFieldValue(
                            Field => $cf,
                            Value => $key,
                            $args{$key} ? %{$args{$key}} : (),
                        );
                        push @results, $msg;
                    }
                }
                elsif ($count < 0) {
                    # old > new, need to remove old
                    while ($count++ < 0) {
                        my $id = shift @{ $ocfv_id{$key} };
                        my ($ok, $msg) = $record->DeleteCustomFieldValue(
                            Field   => $cf,
                            ValueId => $id,
                        );
                        push @results, $msg;
                    }
                }
            }
        }
    }

    return @results;
}

sub process_uploads {
    my @attachments = @_;
    my @ret;
    foreach my $attachment (@attachments) {
        open my $filehandle, '<', $attachment->tempname;
        if ( defined $filehandle && length $filehandle ) {
            my ( @content, $buffer );
            while ( read( $filehandle, $buffer, 72 * 57 ) ) {
                push @content, MIME::Base64::encode_base64($buffer);
            }
            close $filehandle;

            push @ret,
                {
                FileName    => $attachment->filename,
                FileType    => $attachment->headers->{'content-type'},
                FileContent => join( "\n", @content ),
                };
        }
    }
    return @ret;
}

1;
