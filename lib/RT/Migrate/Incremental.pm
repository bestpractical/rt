# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2018 Best Practical Solutions, LLC
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
s!(?<=Your ticket has been (?:approved|rejected) by \{ eval \{ )\$Approval->OwnerObj->Name!\$Approver->Name!;
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
            my $attr = RT::Attribute->new(
                ObjectType => "RT::System",
                ObjectId   => 1,
                Name       => "BrandedSubjectTag",
            );;
            return unless $attr->id;
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

    '4.0.4' => {
        'RT::Template' => sub {
            my ($ref) = @_;
            $ref->{Type} ||= 'Perl';
        },
    },

    '4.0.6' => {
        'RT::Transaction' => sub {
            my ($ref) = @_;
            return unless $ref->{ObjectType} eq "RT::User" and $ref->{Field} eq "Password";
            $ref->{OldValue} = $ref->{NewValue} = '********';
        },
    },

    '4.0.9' => {
        'RT::Queue' => sub {
            my ($ref) = @_;
            $ref->{Lifecycle} ||= 'default';
        },
    },

    '4.0.19' => {
        'RT::CustomField' => sub {
            my ($ref) = @_;
            $ref->{LookupType} = 'RT::Class-RT::Article'
                if $ref->{LookupType} eq 'RT::FM::Class-RT::FM::Article';
        },
        'RT::ObjectCustomFieldValue' => sub {
            my ($ref) = @_;
            $ref->{ObjectType} = 'RT::Article'
                if $ref->{ObjectType} eq 'RT::FM::Article';
        },
    },


    '4.1.0' => {
        'RT::Attribute' => sub {
            my ($ref) = @_;
            return unless $ref->{Name} eq "HomepageSettings";

            my $v = eval {
                Storable::thaw(MIME::Base64::decode_base64($ref->{Content}))
              };
            return if not $v or $v->{sidebar};
            $v->{sidebar} = delete $v->{summary};
            $ref->{Content} = MIME::Base64::encode_base64(
                Storable::nfreeze($v) );
        },
    },

    '4.1.1' => {
        '+RT::Scrip' => sub {
            my ($ref) = @_;
            my $new = [
                "RT::ObjectScrip" => rand(1),
                {
                    id            => undef,
                    Scrip         => $ref->{id},
                    Stage         => delete $ref->{Stage},
                    ObjectId      => delete $ref->{Queue},
                    Creator       => $ref->{Creator},
                    Created       => $ref->{Created},
                    LastUpdatedBy => $ref->{LastUpdatedBy},
                    LastUpdated   => $ref->{LastUpdated},
                }
            ];
            if ( $new->[2]{Stage} eq "Disabled" ) {
                $ref->{Disabled} = 1;
                $new->[2]{Stage} = "TransactionCreate";
            } else {
                $ref->{Disabled} = 0;
            }
            # XXX SortOrder
            return $new;
        },
    },

    '4.1.4' => {
        'RT::Group' => sub {
            my ($ref) = @_;
            $ref->{Instance} = 1
                if $ref->{Domain} eq "RT::System-Role"
                    and $ref->{Instance} = 0;
        },
        # XXX Invalid rights
    },

    '4.1.5' => {
        'RT::Scrip' => sub {
            my ($ref) = @_;
            my $template = RT::Template->new( $RT::SystemUser );
            $template->Load( $ref->{Template} );
            $ref->{Template} = $template->id ? $template->Name : 'Blank';
        },
    },

    '4.1.6' => {
        'RT::Attribute' => sub {
            my ($ref) = @_;
            return unless $ref->{Name} eq RT::User::_PrefName( RT->System )
                and $ref->{ObjectType} eq "RT::User";
            my $v = eval {
                Storable::thaw(MIME::Base64::decode_base64($ref->{Content}))
              };
            return if not $v or $v->{ShowHistory};
            $v->{ShowHistory} = delete $v->{DeferTransactionLoading}
                ? "click" : "delay";
            $ref->{Content} = MIME::Base64::encode_base64(
                Storable::nfreeze($v) );
        },
    },

    '4.1.7' => {
        'RT::Transaction' => sub {
            my ($ref) = @_;
            return unless $ref->{ObjectType} eq 'RT::Ticket'
                      and $ref->{Type} eq 'Set'
                      and $ref->{Field} eq 'TimeWorked';
            $ref->{TimeTaken} = $ref->{NewValue} - $ref->{OldValue};
        },
    },

    '4.1.8' => {
        'RT::Ticket' => sub {
            my ($ref) = @_;
            $ref->{IsMerged} = 1 if $ref->{id} != $ref->{EffectiveId};
        },
    },

    '4.1.10' => {
        'RT::ObjectcustomFieldValue' => sub {
            my ($ref) = @_;
            $ref->{Content} = undef if defined $ref->{LargeContent}
                and defined $ref->{Content} and $ref->{Content} eq '';
        },
    },

    '4.1.11' => {
        'RT::CustomField' => sub {
            my ($ref) = @_;
            delete $ref->{Repeated};
        },
    },

    '4.1.13' => {
        'RT::Group' => sub {
            my ($ref) = @_;
            $ref->{Name} = $ref->{Type}
                if $ref->{Domain} =~ /^(ACLEquivalence|SystemInternal|.*-Role)$/;
        },
    },

    '4.1.14' => {
        'RT::Scrip' => sub {
            my ($ref) = @_;
            delete $ref->{ConditionRules};
            delete $ref->{ActionRules};
        },
    },

    '4.1.17' => {
        'RT::Attribute' => sub {
            my ($ref) = @_;
            return unless $ref->{Name} eq 'SavedSearch';
            my $v = eval {
                Storable::thaw(MIME::Base64::decode_base64($ref->{Content}))
              };
            return unless $v and ref $v and ($v->{SearchType}||'') eq 'Chart';

            # Switch from PrimaryGroupBy to GroupBy name
            # Switch from "CreatedMonthly" to "Created.Monthly"
            $v->{GroupBy} ||= [delete $v->{PrimaryGroupBy}];
            for (@{$v->{GroupBy}}) {
                next if /\./;
                s/(?<=[a-z])(?=[A-Z])/./;
            }
            $ref->{Content} = MIME::Base64::encode_base64(
                Storable::nfreeze($v) );
        },
    },

    '4.1.19' => {
        'RT::Template' => sub {
            my ($ref) = @_;
            delete $ref->{Language};
            delete $ref->{TranslationOf};
        },
    },

    '4.1.20' => {
        'RT::Template' => sub {
            my ($ref) = @_;
            if ($ref->{Name} eq 'Forward') {
                $ref->{Description} = 'Forwarded message';
                if ( $ref->{Content} =~
                     m/^\n*This is (a )?forward of transaction #\{\s*\$Transaction->id\s*\} of (a )?ticket #\{\s*\$Ticket->id\s*\}\n*$/
                   ) {
                    $ref->{Content} = q{
{ $ForwardTransaction->Content =~ /\S/ ? $ForwardTransaction->Content : "This is a forward of transaction #".$Transaction->id." of ticket #". $Ticket->id }
};
                } else {
                    RT->Logger->error('Current "Forward" template is not the default version, please check docs/UPGRADING-4.2');
                }
            } elsif ($ref->{Name} eq 'Forward Ticket') {
                $ref->{Description} = 'Forwarded ticket message';
                if ( $ref->{Content} eq q{

This is a forward of ticket #{ $Ticket->id }
} ) {
                    $ref->{Content} = q{
{ $ForwardTransaction->Content =~ /\S/ ? $ForwardTransaction->Content : "This is a forward of ticket #". $Ticket->id }
};
                } else {
                    RT->Logger->error('Current "Forward Ticket" template is not the default version, please check docs/UPGRADING-4.2');
                }
            }
        },
    },

    '4.1.21' => {
        # XXX User dashboards
    },

    '4.1.22' => {
        'RT::Template' => sub {
            my ($ref) = @_;
            return unless $ref->{Name} eq 'Error: bad GnuPG data';
            $ref->{Name} = 'Error: bad encrypted data';
            $ref->{Description} =
                'Inform user that a message he sent has invalid encryption data';
            $ref->{Content} =~ s/GnuPG signature/signature/g;
        },
        # XXX SMIME keys
        'RT::Attribute' => sub {
            my ($ref, $classref) = @_;
            if ($ref->{ObjectType} eq "RT::User" and $ref->{Name} eq "SMIMEKeyNotAfter") {
                $$classref = undef;
            }
        },
    },

    '4.2.1' => {
        'RT::Attribute' => sub {
            my ($ref, $classref) = @_;
            if ($ref->{ObjectType} eq "RT::System" and $ref->{Name} eq "BrandedSubjectTag") {
                $$classref = undef;
            }
        },
    },

    '4.2.2' => {
        'RT::CustomField' => sub {
            my ($ref) = @_;
            $ref->{LookupType} = 'RT::Class-RT::Article'
                if $ref->{LookupType} eq 'RT::FM::Class-RT::FM::Article';
        },
        'RT::ObjectCustomFieldValue' => sub {
            my ($ref) = @_;
            $ref->{ObjectType} = 'RT::Article'
                if $ref->{ObjectType} eq 'RT::FM::Article';
        },
    },

    '4.3.1' => {
        'RT::CustomField' => sub {
            my ($ref) = @_;
            $ref->{EntryHint} //= RT::CustomField->FriendlyType( $ref->{Type}, $ref->{MaxValues} );
        },
    },

);

1;
