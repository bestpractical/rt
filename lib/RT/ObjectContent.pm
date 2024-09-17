# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2024 Best Practical Solutions, LLC
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

=head1 NAME

RT::ObjectContent

=head1 SYNOPSIS

  use RT::ObjectContent

=head1 DESCRIPTION

ObjectContent is an object where you can store content.

=cut

package RT::ObjectContent;

use strict;
use warnings;

use base 'RT::Record';

use JSON ();
my $json = JSON->new->canonical;

=head1 NAME

RT::ObjectContent

=cut

=head1 METHODS

=head2 Create PARAMHASH

Create takes a hash of values and creates a row in the database.  Available
keys are:

=over 4

=item Content

If you provide a reference, we will automatically serialize the data structure
using L<JSON>. Otherwise any string is passed through as-is.

=back

Returns a tuple of (status, msg) on failure and (id, msg) on success.

=cut

sub Create {
    my $self = shift;
    my %args = (
        ObjectType => '',
        ObjectId   => '',
        Content    => '',
        ContentEncoding => '',
        @_,
    );

    ( $args{ContentEncoding}, $args{Content} ) = $self->_EncodeContent($args{Content}) if ref $args{Content};

    my %attrs = map { $_ => 1 } $self->ReadableAttributes;

    my ( $id, $msg ) = $self->SUPER::Create( map { $_ => $args{$_} } grep exists $args{$_}, keys %attrs );

    return ($id, $msg);
}

sub Delete {
    my $self = shift;
    my ( $ret, $msg ) = $self->SetDisabled( 1 );
    return wantarray ? ( $ret, $msg ) : $ret;
}

sub DecodedContent {
    my $self = shift;

    # Here we call _Value to run the ACL check.
    my $content = $self->_Value('Content');

    my $type = $self->__Value('ContentEncoding') || '';

    if ($type eq 'json') {
        return $json->decode($content);
    }

    return $content;
}

sub _EncodeContent {
    my $self    = shift;
    my $content = shift;
    return ref $content ? ( 'json', $json->encode($content) ) : ( '', $content );
}

sub Serialize {
    my $self  = shift;
    my %args  = (@_);
    my %store = $self->SUPER::Serialize(@_);

    if ( my $content = $self->DecodedContent ) {
        if ( $self->ObjectType eq 'RT::SavedSearch' ) {
            if ( my $group_by = $content->{GroupBy} ) {
                my @new_group_by;
                my $stacked_group_by = $content->{StackedGroupBy};
                for my $entry ( ref $group_by ? @$group_by : $group_by ) {
                    if ( $entry =~ /^CF\.\{(\d+)\}$/ ) {
                        push @new_group_by, \( join '-', 'RT::CustomField', $RT::Organization, $1 );
                        if ( $entry eq ( $stacked_group_by // '' ) ) {
                            $stacked_group_by = $new_group_by[-1];
                        }
                    }
                    else {
                        push @new_group_by, $entry;
                    }
                }
                $content->{GroupBy}        = \@new_group_by;
                $content->{StackedGroupBy} = $stacked_group_by if $stacked_group_by;
            }
        }
        elsif ( $self->ObjectType eq 'RT::Dashboard' ) {
            for my $entry ( RT::Dashboard->Portlets($content->{Elements} || []) ) {
                next unless $entry->{portlet_type} =~ /^(?:dashboard|search)$/;
                my $class = $entry->{portlet_type} eq 'dashboard' ? 'RT::Dashboard' : 'RT::SavedSearch';
                $entry->{id} = \( join '-', $class, $RT::Organization, $entry->{id} );
            }
        }
        elsif ( $self->ObjectType eq 'RT::DashboardSubscription' ) {

            # encode user/groups to be UIDs
            for my $type (qw/Users Groups/) {
                if ( $content->{Recipients}{$type} ) {
                    my $class = $type eq 'Users' ? 'RT::User' : 'RT::Group';
                    my @uids;
                    for my $id ( @{ $content->{Recipients}{$type} } ) {
                        my $object = $class->new( RT->SystemUser );
                        $object->Load($id);
                        if ( $object->Id ) {
                            push @uids,
                                \(
                                    join '-', $class,
                                    $class eq 'RT::User' ? $object->Name : ( $RT::Organization, $object->Id )
                                );
                        }
                    }
                    $content->{Recipients}{$type} = \@uids;
                }
            }
        }
        $store{Content} = RT::Attribute->_SerializeContent($content);
    }

    return %store;
}

sub PreInflate {
    my $class = shift;
    my ( $importer, $uid, $data ) = @_;

    if ( $data->{Content} ) {
        my $content = RT::Attribute->_DeserializeContent( $data->{Content} );
        if ( $data->{ObjectType} eq 'RT::SavedSearch' ) {
            if ( my $group_by = $content->{GroupBy} ) {
                my @new_group_by;
                my $stacked_group_by = $content->{StackedGroupBy};

                for my $entry ( ref $group_by ? @$group_by : $group_by ) {
                    next unless ref $entry eq 'SCALAR';
                    my $obj = $importer->LookupObj( $entry );
                    if ( $obj && $obj->Id ) {
                        push @new_group_by, 'CF.{' . $obj->Id . '}';
                        if ( $entry eq ( $stacked_group_by // '' ) ) {
                            $stacked_group_by = $new_group_by[-1];
                        }
                    }
                }
                $content->{GroupBy}        = \@new_group_by;
                $content->{StackedGroupBy} = $stacked_group_by if $stacked_group_by;
            }
        }
        elsif ( $data->{ObjectType} eq 'RT::Dashboard' ) {
            for my $entry ( RT::Dashboard->Portlets($content->{Elements} || []) ) {
                next unless $entry->{portlet_type} =~ /^(?:dashboard|search)$/;
                next unless ref $entry->{id} eq 'SCALAR';
                my $obj = $importer->LookupObj( ${ $entry->{id} } );
                if ( $obj && $obj->Id ) {
                    $entry->{id} = $obj->Id;
                }
                else {
                    RT->Logger->warning("Couldn't find ${ $entry->{id} }");
                    $entry->{id} = $1 if ${ ${ $entry->{id} } } =~ /(\d+)$/;
                }
            }
        }
        elsif ( $data->{ObjectType} eq 'RT::DashboardSubscription' ) {
            for my $type (qw/Users Groups/) {
                if ( my $list = $content->{Recipients}{$type} ) {
                    my @ids;
                    for my $item (@$list) {
                        if ( ref $item eq 'SCALAR' ) {
                            my $obj = $importer->LookupObj($$item);
                            if ( $obj && $obj->Id ) {
                                push @ids, $obj->Id;
                            }
                            else {
                                RT->Logger->warning("Couldn't find $type: $$item");
                            }
                        }
                        else {
                            push @ids, $item;
                        }
                    }
                    @$list = @ids;
                }
            }
        }
        $data->{Content} = $class->_EncodeContent($content);
    }
    return $class->SUPER::PreInflate( $importer, $uid, $data );
}

sub Table { "ObjectContents" }

sub _CoreAccessible {
    {
        id              => { read => 1, type => 'int(19)', default => '' },
        ObjectType      => { read => 1, write => 1, sql_type => 12, length => 64, is_blob => 0,  is_numeric => 0,  type => 'varchar(64)', default => '' },
        ObjectId        => { read => 1, write => 1, sql_type => 4, length => 11, is_blob => 0,  is_numeric => 1,  type => 'int(11)', default => '' },
        Content         => { read => 1, write => 1, sql_type => -4, length => 0, is_blob => 1,  is_numeric => 0,  type => 'longblob', default => '' },
        ContentEncoding => { read => 1, write => 1, sql_type => 12, length => 64, is_blob => 0,  is_numeric => 0,  type => 'varchar(64)', default => '' },
        Creator         => { read => 1, type => 'int(11)', default => '0', auto => 1 },
        Created         => { read => 1, type => 'datetime', default => '',  auto => 1 },
        LastUpdatedBy   => { read => 1, type => 'int(11)', default => '0', auto => 1 },
        LastUpdated     => { read => 1, type => 'datetime', default => '',  auto => 1 },
        Disabled        => { read => 1, write => 1, sql_type => 5, length => 6,  is_blob => 0,  is_numeric => 1,  type => 'smallint(6)', default => '0' },
    }
}

RT::Base->_ImportOverlays();

1;
