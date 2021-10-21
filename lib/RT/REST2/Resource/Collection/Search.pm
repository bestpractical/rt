# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2021 Best Practical Solutions, LLC
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

package RT::REST2::Resource::Collection::Search;
use strict;
use warnings;

use Moose::Role;
use namespace::autoclean;

requires 'collection';
use Regexp::Common qw/delimited/;

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    my %args = @_;

    if ( my $id = $args{request}->param('search') ) {
        my $search = RT::REST2::Resource::Search::_load_search( $args{request}, $id );

        if ( $search && $search->Id ) {
            if ( !defined $args{query} && !defined $args{request}->param('query') ) {
                if ( my $query = $search->GetParameter('Query') ) {
                    $args{request}->parameters->set( query => $query );
                }
            }

            if ( !defined $args{order} && !defined $args{request}->param('order') ) {
                if ( my $order = $search->GetParameter('Order') ) {
                    $args{request}->parameters->set( order => split /\|/, $order );
                }
            }

            if ( !defined $args{orderby} && !defined $args{request}->param('orderby') ) {
                if ( my $orderby = $search->GetParameter('OrderBy') ) {
                    $args{request}->parameters->set( orderby => split /\|/, $orderby );
                }
            }

            if ( !defined $args{per_page} && !defined $args{request}->param('per_page') ) {
                if ( my $per_page = $search->GetParameter('RowsPerPage') ) {
                    $args{request}->parameters->set( per_page => $per_page );
                }
            }

            if ( !defined $args{fields} && !defined $args{request}->param('fields') ) {
                if ( my $format = $search->GetParameter('Format') ) {
                    my @attrs;

                    # Main logic is copied from share/html/Elements/CollectionAsTable/ParseFormat
                    while ( $format =~ /($RE{delimited}{-delim=>qq{\'"}}|[{}\w.]+)/go ) {
                        my $col    = $1;
                        my $colref = {};

                        if ( $col =~ /^$RE{quoted}$/o ) {
                            substr( $col, 0,  1 ) = "";
                            substr( $col, -1, 1 ) = "";
                            $col =~ s/\\(.)/$1/g;
                        }

                        while ( $col =~ s{/(STYLE|CLASS|TITLE|ALIGN|SPAN|ATTRIBUTE):([^/]*)}{}i ) {
                            $colref->{ lc $1 } = $2;
                        }

                        unless ( length $col ) {
                            $colref->{'attribute'} = '' unless defined $colref->{'attribute'};
                        }
                        elsif ( $col =~ /^__(NEWLINE|NBSP)__$/ || $col =~ /^(NEWLINE|NBSP)$/ ) {
                            $colref->{'attribute'} = '';
                        }
                        elsif ( $col =~ /__(.*?)__/io ) {
                            while ( $col =~ s/^(.*?)__(.*?)__//o ) {
                                $colref->{'last_attribute'} = $2;
                            }
                            $colref->{'attribute'} = $colref->{'last_attribute'}
                                unless defined $colref->{'attribute'};
                        }
                        else {
                            $colref->{'attribute'} = $col
                                unless defined $colref->{'attribute'};
                        }

                        if ( $colref->{'attribute'} ) {
                            push @attrs, $colref->{'attribute'};
                        }
                    }

                    my %fields;

                    if (@attrs) {
                        my $record_class = $args{collection_class}->RecordClass;
                        while ( my $attr = shift @attrs ) {
                            if ( $attr =~ /^(Requestors?|AdminCc|Cc|CustomRole\.\{.+?\})(?:\.(.+))?/ ) {
                                my $role  = $1;
                                my $field = $2;

                                if ( $role eq 'Requestors' ) {
                                    $role = 'Requestor';
                                }
                                elsif ( $role =~ /^CustomRole\.\{(.+?)\}/ ) {
                                    my $name        = $1;
                                    my $custom_role = RT::CustomRole->new( $args{request}->env->{"rt.current_user"} );
                                    $custom_role->Load($name);
                                    if ( $custom_role->Id ) {
                                        $role = $custom_role->GroupType;
                                    }
                                    else {
                                        next;
                                    }
                                }

                                $fields{$role} = 1;
                                if ($field) {
                                    $field = 'CustomFields' if $field =~ /^CustomField\./;
                                    $args{request}->parameters->set(
                                        "fields[$role]" => join ',',
                                        $field,
                                        $args{request}->parameters->get("fields[$role]") || ()
                                    );
                                }
                            }
                            elsif ( $attr =~ /^CustomField\./ ) {
                                $fields{CustomFields} = 1;
                            }
                            elsif ( $attr
                                =~ /^(?:RefersTo|ReferredToBy|DependsOn|DependedOnBy|MemberOf|Members|Parents|Children)$/
                                )
                            {
                                $fields{_hyperlinks} = 1;
                            }
                            elsif ( $record_class->can('_Accessible') && $record_class->_Accessible( $attr => 'read' ) )
                            {
                                $fields{$attr} = 1;
                            }
                            elsif ( $attr =~ s/Relative$// ) {

                                # Date fields like LastUpdatedRelative
                                push @attrs, $attr;
                            }
                            elsif ( $attr =~ s/Name$// ) {

                                # Fields like OwnerName, QueueName
                                push @attrs, $attr;
                                $args{request}->parameters->set(
                                    "fields[$attr]" => join ',',
                                    'Name',
                                    $args{request}->parameters->get("fields[$attr]") || ()
                                );
                            }
                        }
                    }

                    $args{request}->parameters->set( 'fields' => join ',', sort keys %fields );
                }
            }
        }
    }

    return $class->$orig( %args );
};

1;
