# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC
#                                          <jesse@bestpractical.com>
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
# http://www.gnu.org/copyleft/gpl.html.
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
use warnings;
use strict;

package RT::View::Admin::Global::Workflows;
use Jifty::View::Declare -base;
use RT::Workflow;

template 'localization' => page {
    title => _('Localization of Statuses'),
} content {
    outs(_("Status values stored in the DB are limitted to ASCII. To localize values you have to change po-files. Copy text block below, insert it into a local po file for language you want to localize into and translate. If you don't have local po files then you can borrow a header from RT's core po files. Don't change general po files as those are over written on every update."));
    pre {
        for my $str ( RT::Workflow->for_localization ) {
            outs_raw( qq{msgid "$str"\nmsgstr ""\n} );
        }
    };
}

template 'interface' => page {
    title => _('Transitions Interface'),
} content {
    my $self    = shift;
    my $name = get('name');
    my $moniker = 'modify_workflow_interface';
    my $action = new_action(
        class   => 'EditWorkflowInterface',
        moniker => $moniker,
    );
    $action->name( $name );
    my $args = $action->arguments;
    with( name => $moniker ), form {
        my (%info);

        for my $arg ( keys %$args ) {
            next unless $arg =~ /(.*)___(label|action)___(.*)/;
            $info{$2}{$1} ||= [];
            push @{ $info{$2}{$1} }, $3;
        }

        for my $type (qw/label action/) {

            h2 {
                _(
                    $type eq 'label'
                    ? 'Transition Labels'
                    : 'Ticket Actions on Transitions'
                );
            };

            table {
                row {
                    th { _('From') };
                    th { ' ' };
                    th { _('To') };
                    th { _( ucfirst $type ) };
                };
                for my $from ( sort keys %{ $info{$type} } ) {
                    row {
                        cell {
                            attr { rowspan => scalar @{ $info{$type}{$from} } }
                              _($from);
                        };
                        cell {
                            attr { rowspan => scalar @{ $info{$type}{$from} } }
                              outs_raw('&rarr;');
                        };
                        for my $to ( @{ $info{$type}{$from} } ) {
                            if ( $to eq $info{$type}{$from}->[0] ) {
                                cell { _($to) };
                                cell {
                                    outs_raw(
                                        $action->form_field(
                                            $from . "___${type}___" . $to
                                        )
                                    );
                                };
                            }
                            else {
                                row {
                                    cell { _($to) };
                                    cell {
                                        outs_raw(
                                            $action->form_field(
                                                $from . "___${type}___" . $to
                                            )
                                        );
                                    };
                                };
                            }
                        }
                    };
                    row {
                        cell { attr { colspan => 4 } ' ' };
                    };
                }
            };
        }

        input { type is 'hidden'; name is 'name'; value is $name };
        outs_raw( $action->form_field('name') );
        form_submit( label => _('Update') );
    };
}

template 'statuses' => page {
    title => _('Workflow Statuses'),
} content {
    my $self    = shift;
    my $name = get('name');
    my $moniker = 'modify_workflow_statuses';
    my $action = new_action(
        class   => 'EditWorkflowStatuses',
        moniker => $moniker,
    );
    $action->name( $name );
    my $args = $action->arguments;
    with( name => $moniker ), form {
        input { type is 'hidden'; name is 'name'; value is $name };
        render_action($action);
        form_submit( label => _('Update') );
    };
}

1;

