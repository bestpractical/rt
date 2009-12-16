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
    title => _('Modify Transitions Interface'),
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
    title => _('Modify Workflow Statuses'),
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

template 'transitions' => page {
    title => _('Modify Transitions'),
} content {
    my $self    = shift;
    my $name = get('name');
    my $moniker = 'modify_workflow_transitions';
    my $action = new_action(
        class   => 'EditWorkflowTransitions',
        moniker => $moniker,
    );
    $action->name( $name );
    my $schema = RT::Workflow->new->load( $name );
    my $args = $action->arguments;
    with( name => $moniker ), form {
        table {
            row {
                th { _('From') };
                th {
                    attr { rowspan => scalar $schema->valid + 1 }
                      outs_raw('&rarr;');
                };
                th { _('To (check valid transitions)') };
            };
            for my $from ( keys %$args ) {
                next if $from eq 'name';
                row {
                    th { _($from) };
                    cell {
                        outs_raw( $action->form_field($from) );
                    };
                }
            }
        };
        input { type is 'hidden'; name is 'name'; value is $name };
        outs_raw( $action->form_field('name') );
        form_submit( label => _('Update') );
    };
}


template 'index.html' => page {
    title => _('Modify System Workflows'),
} content {
    my @list = RT::Workflow->new->list;
    table {
        row { th { _('Schema') };
            th { _('Statuses') };
            th { _('Queues') };
        };

        for my $schema ( @list ) {
            my $obj = RT::Workflow->load( $schema );
            row {
                cell {
                    a {
                        attr {  href => RT->config->get('web_path')
                              . '/admin/global/workflows/summary?name='
                              . $schema } $schema;
                    }
                };
                cell { join ', ', map _($_), $obj->valid };
                cell { join ', ', map $_->name,
                    @{$obj->queues->items_array_ref } };
            }
        };
    };

    my $moniker = 'create_workflow';
    my $action = new_action(
        class   => 'CreateWorkflow',
        moniker => $moniker,
    );
    my $args = $action->arguments;
    with( name => $moniker ), form {
        render_action($action);
        form_submit( label => _('Create') );
    };
}

template 'summary' => page {
    title => _('Workflow Summary'),
} content {
    my $name = get('name');
    return unless $name;
    my $schema = RT::Workflow->new->load( $name );
    h2 { _('Statuses') };
    unless ( $schema->valid ) {
        p{ _('This schema has no statuses defined, quite useless.') };
    }
    else {
        ul {
            for my $set( qw(initial active inactive) ) {
                li { outs(_($set));
                    ul { 
                        for my $status( $schema->$set() ) {
                            li { _($status) };
                        }
                    }
                }
            }
        };
    }
    my $url_base = RT->config->get('web_path') ."/admin/global/workflows";
    br {};
    a {
        attr { href => $url_base . '/statuses?name=' . $name }
          _('Modify Statuses');
    };

    h2 { _('Queues') };
    my $queues = $schema->queues;
    ul {
        while ( my $queue = $queues->next ) {
            li { $queue->name };
        }
    };

    return unless $schema->valid;

    h2 { _('Transitions') };
    my %transitions = $schema->transitions;
    ul {
        for my $from ( $schema->valid ) {
            li {
                outs_raw(_($from) . '&rarr');
                ul {
                    for my $to ( @{ $transitions{ $from } || [] } ) {
                        li {
                            outs( _($to) );
                            my $label =
                              $schema->transition_label( $from => $to );
                            outs( '- ' . _( "labeled '%1'", _($label) ) );
                            my $action =
                              $schema->transition_action( $from => $to );
                            if ( $action eq 'hide' ) {
                                outs( _("and hidden from UI") );
                            }
                            elsif ( $action eq 'comment' ) {
                                outs( _("and comment page is shown") );
                            }
                            elsif ( $action eq 'respond' ) {
                                outs( _("and correspond page is shown") );
                            }
                            else {
                                outs(
                                    _("and no additional interface is shown") );
                            }
                        }
                    }
                }
            }
        }
    };

    br {};
    a { attr { href => $url_base . '/transitions?name=' . $name }
        _('Modify Transitions') };
    br {};
    a { attr { href => $url_base . '/interface?name=' . $name }
        _('Modify Actions and Labels') };

    show( 'missing_maps', $name );
}

private template 'missing_maps' => sub {
    my $self = shift;
    my $name = shift;
    my $schema = RT::Workflow->new->load($name);
    my @maps = RT::Workflow->no_maps;
    if ($schema) {
        my @tmp;
        while ( my ( $f, $t ) = splice @maps, 0, 2 ) {
            next unless $f eq $name || $t eq $name;
            push @tmp, $f, $t;
        }
        @maps = @tmp;
    }
    return unless @maps;
 
    h2 { _("No mappings between following schemas") };
    ul {
        while ( my ( $f, $t ) = splice @maps, 0, 2 ) {
            li {
                a {
                    attr { href => RT->config->get('web_path')
                          . "/admin/global/workflows/mappings?name=$name&from=$f&to=$t"
                    }
                    outs_raw( $f . '&rarr;' . $t );
                };
            };
        }
    };
};

1;

