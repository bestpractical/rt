# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2019 Best Practical Solutions, LLC
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

package RT::REST2::Resource::Record::Writable;
use strict;
use warnings;

use Moose::Role;
use namespace::autoclean;
use JSON ();
use RT::REST2::Util qw( deserialize_record error_as_json expand_uid update_custom_fields );
use List::MoreUtils 'uniq';

with 'RT::REST2::Resource::Role::RequestBodyIsJSON'
     => { type => 'HASH' };

requires 'record';
requires 'record_class';

sub post_is_create            { 1 }
sub allow_missing_post        { 1 }
sub create_path_after_handler { 1 }
sub create_path {
    $_[0]->record->id || undef
}

sub content_types_accepted { [ {'application/json' => 'from_json'}, { 'multipart/form-data' => 'from_multipart' } ] }

sub from_multipart {
    my $self = shift;
    my $json_str = $self->request->parameters->{JSON};
    return error_as_json(
        $self->response,
        \400, "Json is a required field for multipart/form-data")
            unless $json_str;

    my $json = JSON::decode_json($json_str);

    my $cfs = delete $json->{CustomFields};
    if ($cfs) {
        foreach my $id (keys %$cfs) {
            my $value = delete $cfs->{$id};

            if (ref($value) eq 'ARRAY') {
                my @values;
                foreach my $single_value (@$value) {
                    if ( ref $single_value eq 'HASH' && ( my $field_name = $single_value->{UploadField} ) ) {
                        my $file = $self->request->upload($field_name);
                        if ($file) {
                            open my $filehandle, '<', $file->tempname;
                            if (defined $filehandle && length $filehandle) {
                                my ( @content, $buffer );
                                while ( my $bytesread = read( $filehandle, $buffer, 72*57 ) ) {
                                    push @content, MIME::Base64::encode_base64($buffer);
                                }
                                close $filehandle;

                                push @values, {
                                    FileName    => $file->filename,
                                    FileType    => $file->headers->{'content-type'},
                                    FileContent => join("\n", @content),
                                };
                            }
                        }
                    }
                    else {
                        push @values, $single_value;
                    }
                }
                $cfs->{$id} = \@values;
            }
            elsif ( ref $value eq 'HASH' && ( my $field_name = $value->{UploadField} ) ) {
                my $file = $self->request->upload($field_name);
                if ($file) {
                    open my $filehandle, '<', $file->tempname;
                    if (defined $filehandle && length $filehandle) {
                        my ( @content, $buffer );
                        while ( my $bytesread = read( $filehandle, $buffer, 72*57 ) ) {
                            push @content, MIME::Base64::encode_base64($buffer);
                        }
                        close $filehandle;

                        $cfs->{$id} = {
                            FileName    => $file->filename,
                            FileType    => $file->headers->{'content-type'},
                            FileContent => join("\n", @content),
                        };
                    }
                }
            }
            else {
                $cfs->{$id} = $value;
            }
        }
        $json->{CustomFields} = $cfs;
    }

    return $self->from_json($json);
}

sub from_json {
    my $self = shift;
    my $params = shift || JSON::decode_json( $self->request->content );

    %$params = (
        %$params,
        %{ $self->request->query_parameters->mixed },
    );

    my $data = deserialize_record(
        $self->record,
        $params,
    );

    my $method = $self->request->method;
    return $method eq 'PUT'  ? $self->update_resource($data) :
           $method eq 'POST' ? $self->create_resource($data) :
                                                        \501 ;
}

sub update_record {
    my $self = shift;
    my $data = shift;

    my @results = $self->record->Update(
        ARGSRef       => $data,
        AttributesRef => [ $self->record->WritableAttributes ],
    );

    push @results, update_custom_fields($self->record, $data->{CustomFields});
    push @results, $self->_update_role_members($data);
    push @results, $self->_update_disabled($data->{Disabled})
      unless grep { $_ eq 'Disabled' } $self->record->WritableAttributes;
    push @results, $self->_update_privileged($data->{Privileged})
      unless grep { $_ eq 'Privileged' } $self->record->WritableAttributes;

    # XXX TODO: Figure out how to return success/failure?  Core RT::Record's
    # ->Update will need to be replaced or improved.
    return @results;
}

sub _update_role_members {
    my $self = shift;
    my $data = shift;

    my $record = $self->record;

    return unless $record->DOES('RT::Record::Role::Roles');

    my @results;

    foreach my $role ($record->Roles) {
        next unless exists $data->{$role};

        # special case: RT::Ticket->Update already handles Owner for us
        next if $role eq 'Owner' && $record->isa('RT::Ticket');

        my $val = $data->{$role};

        if ($record->Role($role)->{Single}) {
            if (ref($val) eq 'ARRAY') {
                $val = $val->[0];
            }
            elsif (ref($val)) {
                die "Invalid value type for role $role";
            }

            my ($ok, $msg);
            if ($record->can('AddWatcher')) {
                ($ok, $msg) = $record->AddWatcher(
                    Type => $role,
                    User => $val,
                );
            } else {
                ($ok, $msg) = $record->AddRoleMember(
                    Type => $role,
                    User => $val,
                );
            }
            push @results, $msg;
        }
        else {
            my %count;
            my @vals;

            for (ref($val) eq 'ARRAY' ? @$val : $val) {
                my ($principal_id, $msg);

                if (/^\d+$/) {
                    $principal_id = $_;
                }
                elsif ($record->can('CanonicalizePrincipal')) {
                    ((my $principal), $msg) = $record->CanonicalizePrincipal(User => $_);
                    $principal_id = $principal->Id;
                }
                else {
                    my $user = RT::User->new($record->CurrentUser);
                    if (/@/) {
                        ((my $ok), $msg) = $user->LoadOrCreateByEmail( $_ );
                    } else {
                        ((my $ok), $msg) = $user->Load( $_ );
                    }
                    $principal_id = $user->PrincipalId;
                }

                if (!$principal_id) {
                    push @results, $msg;
                    next;
                }

                push @vals, $principal_id;
                $count{$principal_id}++;
            }

            my $group = $record->RoleGroup($role);
            my $members = $group->MembersObj;
            while (my $member = $members->Next) {
                $count{$member->MemberId}--;
            }

            # RT::Ticket has specialized methods
            my $add_method = $record->can('AddWatcher') ? 'AddWatcher' : 'AddRoleMember';
            my $del_method = $record->can('DeleteWatcher') ? 'DeleteWatcher' : 'DeleteRoleMember';

            # we want to provide a stable order, so first go by the order
            # provided in the argument list, and then for any role members
            # that are being removed, remove in sorted order
            for my $id (uniq(@vals, sort keys %count)) {
                my $count = $count{$id};
                if ($count == 0) {
                    # new == old, no change needed
                }
                elsif ($count > 0) {
                    # new > old, need to add new
                    while ($count-- > 0) {
                        my ($ok, $msg) = $record->$add_method(
                            Type        => $role,
                            PrincipalId => $id,
                        );
                        push @results, $msg;
                    }
                }
                elsif ($count < 0) {
                    # old > new, need to remove old
                    while ($count++ < 0) {
                        my ($ok, $msg) = $record->$del_method(
                            Type        => $role,
                            PrincipalId => $id,
                        );
                        push @results, $msg;
                    }
                }
            }
        }
    }

    return @results;
}

sub _update_disabled {
    my $self = shift;
    my $data = shift;
    my @results;

    my $record = $self->record;
    return unless defined $data and $data =~ /^[01]$/;

    return unless $record->can('SetDisabled');

    my ($ok, $msg) = $record->SetDisabled($data);
    push @results, $msg;

    return @results;
}

sub _update_privileged {
    my $self = shift;
    my $data = shift;
    my @results;

    my $record = $self->record;
    return unless defined $data and $data =~ /^[01]$/;

    return unless $record->can('SetPrivileged');

    my ($ok, $msg) = $record->SetPrivileged($data);
    push @results, $msg;

    return @results;
}

sub update_resource {
    my $self = shift;
    my $data = shift;

    if (not $self->resource_exists) {
        return error_as_json(
            $self->response,
            \404, "Resource does not exist; use POST to create");
    }

    my @results = $self->update_record($data);
    $self->response->body( JSON::encode_json(\@results) );
    return;
}

sub create_record {
    my $self = shift;
    my $data = shift;

    my $record = $self->record;
    my %args = %$data;

    my $cfs = delete $args{CustomFields};

    # Lookup CustomFields by name.
    if ($cfs) {
        foreach my $id (keys(%$cfs)) {
			my $value = delete $cfs->{$id};
            if ( ref($value) eq 'HASH' ) {
                foreach my $field ( 'FileName', 'FileType', 'FileContent' ) {
                    return ( 0, 0, "$field is a required field for Image/Binary ObjectCustomFieldValue" )
                        unless $value->{$field};
                }
                $value->{Value}        = delete $value->{FileName};
                $value->{ContentType}  = delete $value->{FileType};
                $value->{LargeContent} = MIME::Base64::decode_base64( delete $value->{FileContent} );
            }
            elsif ( ref($value) eq 'ARRAY' ) {
                my $i = 0;
                foreach my $single_value (@$value) {
                    if ( ref($single_value) eq 'HASH' ) {
                        foreach my $field ( 'FileName', 'FileType', 'FileContent' ) {
                            return ( 0, 0,
                                "$field is a required field for Image/Binary ObjectCustomFieldValue" )
                                unless $single_value->{$field};
                        }
                        $single_value->{Value}       = delete $single_value->{FileName};
                        $single_value->{ContentType} = delete $single_value->{FileType};
                        $single_value->{LargeContent}
                            = MIME::Base64::decode_base64( delete $single_value->{FileContent} );
                        $value->[$i] = $single_value;
                    }
                    $i++;
                }
            }
            $cfs->{$id} = $value;

            if ($id !~ /^\d+$/) {
                my $cf = $record->LoadCustomFieldByIdentifier($id);

                if ($cf->Id) {
                    $cfs->{$cf->Id} = $cfs->{$id};
                    delete $cfs->{$id};
                } else {
                    # I would really like to return an error message, but, how?
                    # RT appears to treat missing permission to a CF or
                    # non-existance of a CF as a non-fatal error.
                    RT->Logger->error( $record->loc( "Custom field [_1] not found", $id ) );
                }
            }
        }
    }

    # if a record class handles CFs in ->Create, use it (so it doesn't generate
    # spurious transactions and interfere with default values, etc). Otherwise,
    # add OCFVs after ->Create
    if ($record->isa('RT::Ticket') || $record->isa('RT::Asset')) {
        if ($cfs) {
            while (my ($id, $value) = each(%$cfs)) {
                delete $cfs->{$id};
                $args{"CustomField-$id"} = $value;
            }
        }
    }

    my $method = $record->isa('RT::Group') ? 'CreateUserDefinedGroup' : 'Create';
    my ($ok, @rest) = $record->$method(%args);

    if ($ok && $cfs) {
        update_custom_fields($record, $cfs);
    }

    return ($ok, @rest);
}

sub create_resource {
    my $self = shift;
    my $data = shift;

    if ($self->resource_exists) {
        return error_as_json(
            $self->response,
            \409, "Resource already exists; use PUT to update");
    }

    my ($ok, $msg) = $self->create_record($data);
    if (ref($ok)) {
        return error_as_json(
            $self->response,
            $ok, $msg || "Create failed for unknown reason");
    }
    elsif ($ok) {
        my $response = $self->response;
        my $body = JSON::encode_json(expand_uid($self->record->UID));
        $response->content_type( "application/json; charset=utf-8" );
        $response->content_length( length $body );
        $response->body( $body );
        return;
    } else {
        return error_as_json(
            $self->response,
            \400, $msg || "Create failed for unknown reason");
    }
}

1;
