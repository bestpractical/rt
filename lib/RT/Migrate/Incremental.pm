# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2011 Best Practical Solutions, LLC
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

package RT::Migrate::Incremental;

use strict;
use warnings;
require Storable;
require MIME::Base64;

our %UPGRADES = (
    '3.3.0' => {
        'RT::Transaction' => sub {
            my ($ref) = @_;
            $ref->{ObjectType} = 'RT::Ticket';
            $ref->{ObjectId} = delete $ref->{Ticket};
            delete $ref->{EffectiveTicket};
        },
        'RT::TicketCustomFieldValue' => sub {
            my ($ref, $classref) = @_;
            $$classref = "RT::ObjectCustomFieldValue";
            $ref->{ObjectType} = 'RT::Ticket';
            $ref->{ObjectId} = delete $ref->{Ticket};
        },
        '-RT::TicketCustomFieldValue' => sub {
            my ($ref, $classref) = @_;
            $$classref = "RT::ObjectCustomFieldValue";
        },
        'RT::CustomField' => sub {
            my ($ref) = @_;
            $ref->{MaxValues} = 0 if $ref->{Type} =~ /Multiple$/;
            $ref->{MaxValues} = 1 if $ref->{Type} =~ /Single$/;
            $ref->{Type} = 'Select'   if $ref->{Type} =~ /^Select/;
            $ref->{Type} = 'Freeform' if $ref->{Type} =~ /^Freeform/;
            $ref->{LookupType} = 'RT::Queue-RT::Ticket';
            delete $ref->{Queue};
        },
        '+RT::CustomField' => sub {
            my ($ref) = @_;
            return [
                "RT::ObjectCustomField" => rand(1),
                {
                    id            => undef,
                    CustomField   => $ref->{id},
                    ObjectId      => $ref->{Queue},
                    SortOrder     => $ref->{SortOrder},
                    Creator       => $ref->{Creator},
                    LastUpdatedBy => $ref->{LastUpdatedBy},
                }
            ];
        }
    },

    '3.3.11' => {
        'RT::ObjectCustomFieldValue' => sub {
            my ($ref) = @_;
            $ref->{Disabled} = not delete $ref->{Current};
        },
    },

    '3.7.19' => {
        'RT::Scrip' => sub {
            my ($ref) = @_;
            return if defined $ref->{Description} and length $ref->{Description};

            my $scrip = RT::Scrip->new( $RT::SystemUser );
            $scrip->Load( $ref->{id} );
            my $condition = $scrip->ConditionObj->Name
                || $scrip->ConditionObj->Description
                || ('On Condition #'. $scrip->Condition);
            my $action = $scrip->ActionObj->Name
                || $scrip->ActionObj->Description
                || ('Run Action #'. $scrip->Action);
            $ref->{Description} = join ' ', $condition, $action;
        },
    },

    # XXX BrandedQueues
    # XXX iCal

    '3.8.2' => {
        'RT::Template' => sub {
            my ($ref) = @_;
            return unless $ref->{Queue};

            my $queue = RT::Queue->new( $RT::SystemUser );
            $queue->Load( $ref->{Queue} );
            return unless $queue->Id and $queue->Name eq "___Approvals";

            $ref->{Name} = "[OLD] ".$ref->{Name};
        },
        'RT::Attribute' => sub {
            my ($ref) = @_;
            return unless $ref->{Name} eq "Dashboard";

            my $v = eval {
                Storable::thaw(MIME::Base64::decode_base64($ref->{Content}))
              };
            return unless $v and exists $v->{Searches};
            $v->{Panes} = {
                body => [
                    map {
                        my ($privacy, $id, $desc) = @$_;
                        +{
                            portlet_type => 'search',
                            privacy      => $privacy,
                            id           => $id,
                            description  => $desc,
                            pane         => 'body',
                        }
                    } @{ delete $v->{Searches} }
                ],
            };
            $ref->{Content} = MIME::Base64::encode_base64(
                Storable::nfreeze($v) );
        },
        'RT::Scrip' => sub {
            my ($ref, $classref) = @_;
            return unless $ref->{Queue};

            my $queue = RT::Queue->new( $RT::SystemUser );
            $queue->Load( $ref->{Queue} );
            return unless $queue->Id and $queue->Name eq "___Approvals";

            $$classref = undef;
        },
    },

    '3.8.3' => {
        'RT::ScripAction' => sub {
            my ($ref) = @_;
            return unless ($ref->{Argument}||"") eq "All";
            if ($ref->{ExecModule} eq "Notify") {
                $ref->{Name} = 'Notify Owner, Requestors, Ccs and AdminCcs';
                $ref->{Description} = 'Send mail to owner and all watchers';
            } elsif ($ref->{ExecModule} eq "NotifyAsComment") {
                $ref->{Name} = 'Notify Owner, Requestors, Ccs and AdminCcs as Comment';
                $ref->{Description} = 'Send mail to owner and all watchers as a "comment"';
            }
        },
    },

    '3.8.4' => {
        'RT::ScripAction' => sub {
            my ($ref) = @_;
            return unless $ref->{ExecModule} eq "NotifyGroup"
                or $ref->{ExecModule} eq "NotifyGroupAsComment";

            my $argument = $ref->{Argument};
            if ( my $struct = eval { Storable::thaw( $argument ) } ) {
                my @res;
                foreach my $r ( @{ $struct } ) {
                    my $obj;
                    next unless $r->{'Type'};
                    if( lc $r->{'Type'} eq 'user' ) {
                        $obj = RT::User->new( $RT::SystemUser );
                    } elsif ( lc $r->{'Type'} eq 'group' ) {
                        $obj = RT::Group->new( $RT::SystemUser );
                    } else {
                        next;
                    }
                    $obj->Load( $r->{'Instance'} );
                    next unless $obj->id ;

                    push @res, $obj->id;
                }
                $ref->{Argument} = join ",", @res;
            } else {
                $ref->{Argument} = join ",", grep length, split /[^0-9]+/, $argument;
            }
        },
    },

    '3.8.8' => {
        'RT::ObjectCustomField' => sub {
            # XXX Removing OCFs applied both global and non-global
            # XXX Fixing SortOrder on OCFs
        },
    },

    '3.8.9' => {
        'RT::Link' => sub {
            my ($ref) = @_;
            my $prefix = RT::URI::fsck_com_rt->LocalURIPrefix . '/ticket/';
            for my $dir (qw(Target Base)) {
                next unless $ref->{$dir} =~ /^$prefix(.*)/;
                next unless int($1) eq $1;
                next if $ref->{'Local'.$dir};
                $ref->{'Local'.$dir} = $1;
            }
        },
        'RT::Template' => sub {
            my ($ref) = @_;

            return unless $ref->{Name} =~
                /^(All Approvals Passed|Approval Passed|Approval Rejected)$/;

            my $queue = RT::Queue->new( $RT::SystemUser );
            $queue->Load( $ref->{Queue} );
            return unless $queue->Id and $queue->Name eq "___Approvals";

            $ref->{Content} =~
s!(?<=Your ticket has been (?:approved|rejected) by { eval { )\$Approval->OwnerObj->Name!\$Approver->Name!;
        },
    },

    '3.9.1' => {
        'RT::Template' => sub {
            my ($ref) = @_;
            $ref->{Type} = 'Perl';
        },
        # XXX: Add ExecuteCode to principals that currently have ModifyTemplate or ModifyScrips
    },

    '3.9.2' => {
        'RT::ACE' => sub {
            my ($ref, $classref) = @_;
            $$classref = undef if $ref->{DelegatedBy} > 0
                               or $ref->{DelegatedFrom} > 0;
        },

        'RT::GroupMember' => sub {
            my ($ref, $classref) = @_;
            my $group = RT::Group->new( $RT::SystemUser );
            $group->Load( $ref->{GroupId} );
            $$classref = undef if $group->Domain eq "Personal";
        },
        'RT::Group' => sub {
            my ($ref, $classref) = @_;
            $$classref = undef if $ref->{Domain} eq "Personal";
        },
        'RT::Principal' => sub {
            my ($ref, $classref) = @_;
            return unless $ref->{PrincipalType} eq "Group";
            my $group = RT::Group->new( $RT::SystemUser );
            $group->Load( $ref->{ObjectId} );
            $$classref = undef if $group->Domain eq "Personal";
        },
    },

    '3.9.3' => {
        'RT::ACE' => sub {
            my ($ref) = @_;
            delete $ref->{DelegatedBy};
            delete $ref->{DelegatedFrom};
        },
    },

    '3.9.5' => {
        'RT::CustomFieldValue' => sub {
            my ($ref) = @_;
            my $attr = RT::Attribute->new( $RT::SystemUser );
            $attr->LoadByCols(
                ObjectType => "RT::CustomFieldValue",
                ObjectId   => $ref->{Id},
                Name       => "Category",
            );
            $ref->{Category} = $attr->Content if $attr->id;
        },
        'RT::Attribute' => sub {
            my ($ref, $classref) = @_;
            $$classref = undef if $ref->{Name} eq "Category"
                and $ref->{ObjectType} eq "RT::CustomFieldValue";
        },
    },

    '3.9.7' => {
        'RT::User' => sub {
            my ($ref) = @_;
            my $attr = RT::Attribute->new( $RT::SystemUser );
            $attr->LoadByCols(
                ObjectType => "RT::User",
                ObjectId   => $ref->{id},
                Name       => "AuthToken",
            );
            $ref->{AuthToken} = $attr->Content if $attr->id;
        },
        'RT::CustomField' => sub {
            my ($ref) = @_;
            for my $name (qw/RenderType BasedOn ValuesClass/) {
                my $attr = RT::Attribute->new( $RT::SystemUser );
                $attr->LoadByCols(
                    ObjectType => "RT::CustomField",
                    ObjectId   => $ref->{id},
                    Name       => $name,
                );
                $ref->{$name} = $attr->Content if $attr->id;
            }
        },
        'RT::Queue' => sub {
            my ($ref) = @_;
            my $attr = RT->System->FirstAttribute('BrandedSubjectTag');
            return unless $attr;
            my $map = $attr->Content || {};
            return unless $map->{$ref->{id}};
            $ref->{SubjectTag} = $map->{$ref->{id}};
        },
        'RT::Attribute' => sub {
            my ($ref, $classref) = @_;
            if ($ref->{ObjectType} eq "RT::User" and $ref->{Name} eq "AuthToken") {
                $$classref = undef;
            } elsif ($ref->{ObjectType} eq "RT::CustomField" and $ref->{Name} eq "RenderType") {
                $$classref = undef;
            } elsif ($ref->{ObjectType} eq "RT::CustomField" and $ref->{Name} eq "BasedOn") {
                $$classref = undef;
            } elsif ($ref->{ObjectType} eq "RT::CustomField" and $ref->{Name} eq "ValuesClass") {
                $$classref = undef;
            } elsif ($ref->{ObjectType} eq "RT::System" and $ref->{Name} eq "BrandedSubjectTag") {
                $$classref = undef;
            }
        },
    },

    '3.9.8' => {
        # XXX RTFM => Articles
    },

    '4.0.0rc7' => {
        'RT::Queue' => sub {
            my ($ref) = @_;
            return unless $ref->{Name} eq '___Approvals';
            $ref->{Lifecycle} = "approvals";
        },
    },

    '4.0.1' => {
        'RT::ACE' => sub {
            my ($ref, $classref) = @_;
            my $group = RT::Group->new( $RT::SystemUser );
            $group->LoadByCols(
                id     => $ref->{PrincipalId},
                Domain => "Personal",
            );
            $$classref = undef if $group->id;
            $$classref = undef if $ref->{RightName} =~
                /^(AdminOwnPersonalGroups|AdminAllPersonalGroups|DelegateRights)$/;
            $$classref = undef if $ref->{RightName} =~
                /^(RejectTicket|ModifyTicketStatus)$/;
        },
    },
);

1;
