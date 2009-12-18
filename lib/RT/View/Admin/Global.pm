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

package RT::View::Admin::Global;
use Jifty::View::Declare -base;

require RT::View::Admin::Global::Templates;
alias RT::View::Admin::Global::Templates under 'templates/';

require RT::View::Admin::Global::Workflows;
alias RT::View::Admin::Global::Workflows under 'workflows/';

template 'index.html' => page { title => _('Global Configuration') } content {
    my $items = {
        B => {
            title => _('Templates'),
            text  => _('Edit system templates'),
            path  => '/admin/global/templates',
        },
        C => {
            title => _('Workflows'),
            text  => _('Modify system workflows'),
            path  => '/admin/global/workflows/',
        },
        F => {
            title => _('Custom Fields'),
            text  => _('Modify global custom fields'),
            path  => '/admin/global/select_custom_fields',
        },
        G => {
            title => _('Group Rights'),
            text  => _('Modify global group rights'),
            path  => '/admin/global/group_rights',
        },
        H => {
            title => _('User Rights'),
            text  => _('Modify global user rights'),
            path  => '/admin/global/user_rights',
        },
        I => {
            title => _('RT at a glance'),
            text  => _('Modify the default "RT at a glance" view'),
            path  => '/admin/global/my_rt',
        },
        Y => {
            title => _('Jifty'),
            text  => _('Configure Jifty'),
            path  => '/admin/global/jifty',
        },
        Z => {
            title => _('System'),
            text  => _('Modify System'),
            path  => '/admin/global/system',
        },
    };

    ul {
        attr { class => 'list-menu' };
        foreach my $key ( sort keys %$items ) {
            li {
                span {
                    attr { class => 'menu-item' };
                    a {
                        attr { href => RT->config->get('web_path')
                              . $items->{$key}->{'path'} };
                        $items->{$key}->{'title'};
                    }
                }
                span {
                    attr { class => 'description' }
                      $items->{$key}->{text}
                }

            }
        }
    };
}

template 'system' => page { title => _('Configure RT') } content {
    my $self    = shift;
    my $section = get('section');
    my $config  = new_action(
        class   => 'ConfigSystem',
        moniker => 'config_system',
    );
    $config->order(1);
    my $restart = new_action(
        class   => 'Jifty::Plugin::Config::Action::Restart',
        moniker => 'restart',
    );
    $restart->order(2);
    my $args = $config->arguments_by_sections;
    my $meta = $config->meta;

    if ($section) {
        with( name => 'config_system' ), form {
            for my $field ( sort keys %{ $args->{$section} } ) {
                div {
                    attr { class => 'hints' };
                    outs_raw($meta->{$field} && $meta->{$field}{doc});
                };
                outs_raw( $config->form_field($field) );
            }
            form_submit( label => _('Save') );
            form_submit(
                label  => _('Save and Restart RT'),
                submit => [
                    $config,
                    { action => $restart, arguments => { url => '/' } },
                ],
            );
        };
    }
    else {
        my $items      = {};
        my $sort_order = 'A';    # sort order begins with 'A'
        for my $section ( sort keys %$args ) {
            $items->{ $sort_order++ } = {
                title => _($section),
                path  => "/admin/global/system?section=$section"
            };
        }
        ul {
            attr { class => 'list-menu' };
            foreach my $key ( sort keys %$items ) {
                li {
                    span {
                        attr { class => 'menu-item' };
                        a {
                            attr { href => RT->config->get('web_path')
                                  . $items->{$key}->{'path'} };
                            $items->{$key}->{'title'};
                        }
                    }
                    span {
                        attr { class => 'description' }
                          $items->{$key}->{description}
                          || $items->{$key}->{text}
                          || '';
                    }

                }
            }
        };
    }
}

private template 'rights' => sub {
    my $self = shift;
    my $type = shift || 'user';

    my $class   = 'Edit' . ucfirst($type) . 'Rights';
    my $moniker = 'modify_' . $type . '_rights';

    my $rights = new_action(
        class   => $class,
        moniker => $moniker,
    );

    $rights->object( RT->system );

    with( name => $moniker ), form {
        render_action($rights);
        form_submit( label => _('Save') );
    };
};

template 'user_rights' => page { title => _('Modify Global User Rights') }
  content {
    show( 'rights', 'user' );
  };

template 'group_rights' => page { title => _('Modify Global Group Rights') }
  content {
    show( 'rights', 'group' );
  };

template 'select_custom_fields' =>
  page { title => _('Select Global Custom Fields') } content {
    my $self   = shift;
    my $action = new_action(
        class   => 'SelectCustomFields',
        moniker => 'select_cfs',
    );

    # set it to RT::Model::Queue-RT::Model::Ticket-RT::Model::Transaction
    # to select transaction cfs
    my $lookup_type = get('lookup_type');
    if ($lookup_type) {
        if ( $lookup_type =~ /(Queue|Group|User)/ ) {
            my $class = 'RT::Model::' . $1;
            $action->object( $class->new );
        }

        $action->lookup_type($lookup_type);

        with( name => 'select_cfs' ), form {
            input {
                type is 'hidden';
                name is 'lookup_type';
                value is $lookup_type;
            };
            render_action($action);
            form_submit( label => _('Save') );
        };
    }
    else {
        my $tabs = {
            'RT::Model::User' => {
                title => _('Users'),
                text  => _('Select custom fields for all users'),
            },
            'RT::Model::Group' => {
                title => _('Groups'),
                text  => _('Select custom fields for all user groups'),
            },
            'RT::Model::Queue' => {
                title => _('Queues'),
                text  => _('Select custom fields for all queues'),
            },

            'RT::Model::Queue-RT::Model::Ticket' => {
                title => _('Tickets'),
                text  => _('Select custom fields for tickets in all queues'),
            },

            'RT::Model::Queue-RT::Model::Ticket-RT::Model::Transaction' => {
                title => _('Ticket Transactions'),
                text  => _(
'Select custom fields for transactions on tickets in all queues'
                ),
            },
        };
        ul {
            for my $key ( sort keys %$tabs ) {
                li {
                    span {
                        a {
                            attr {  href => Jifty->web->request->path
                                  . '?lookup_type='
                                  . $key } $tabs->{$key}{title};
                        }
                    }
                    $tabs->{$key}{text};
                }
            }
        }
    }
  };

template 'my_rt' => page { title => _('Configure My RT') } content {
    my $self = shift;
    my $moniker = 'config_my_rt';
    my $action = new_action(
        class   => 'ConfigMyRT',
        moniker => $moniker,
    );

    $action->object( RT->system );

    with( name => $moniker ), form {
        render_action($action);
        form_submit( label => _('Save') );
    };
};

1;

