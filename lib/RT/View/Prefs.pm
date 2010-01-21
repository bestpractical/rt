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

package RT::View::Prefs;
use Jifty::View::Declare -base;

template 'index.html' => page { title => _('RT Preferences') } content {
    my $items = {
        A => {
            title       => _('RT at a glance'),
            path        => '/prefs/my_rt',
            description => _('Customize RT at a glance'),
        },
        B => {
            title       => _('Quick Search'),
            path        => '/prefs/quick_search',
            description => _('Customize Quick Search'),
        },
        C => {
            title       => _('SearchOptions'),
            path        => '/prefs/search_options',
            description => _('Customize Search Options'),
        },
        D => {
            title       => _('Other'),
            path        => '/prefs/other',
            description => _('Customize Others'),
        },
        E => {
            title       => _('Me'),
            path        => '/prefs/me',
            description => _('Customize Self'),
        },
    };

    ul {
        class is 'list-menu';
        foreach my $key ( sort keys %$items ) {
            li {
                span {
                    class is 'menu-item';
                    hyperlink(
                        url => RT->config->get('web_path')
                              . $items->{$key}->{'path'},
                        label => $items->{$key}->{'title'},
                    );
                }
                span {
                    class is 'description';
                      $items->{$key}->{description}
                }
            }
        }
    };
}

template 'other' => page { title => _('Customize Others') } content {
    my $self        = shift;

    my $moniker = 'prefs_edit_other';

    my $action = new_action(
        class   => 'EditUserPrefsOther',
        moniker => $moniker,
    );

    my @sections      = RT::Action::EditUserPrefsOther->sections;

    with( name => $moniker ), form {
        for my $section ( @sections ) {
            h2 { _($section->{title}) };
            for my $field ( @{ $section->{fields} } ) {
                outs_raw( $action->form_field($field) );
            }
        }
        form_submit( label => _('Save') );
    };
}

template 'my_rt' => page { title => _('Customize my RT') } content {
    my $self = shift;
    my $moniker = 'prefs_config_my_rt';
    my $action = new_action(
        class   => 'ConfigMyRT',
        moniker => $moniker,
    );

    $action->record( Jifty->web->current_user->user_object );

    with( name => $moniker ), form {
        render_action($action);
        form_submit( label => _('Save') );
    };

};

template 'quick_search' => page { title => _('Customize Quick Search') } content {
    my $self = shift;
    my $moniker = 'prefs_edit_quick_search';
    my $action = new_action(
        class   => 'EditUserPrefsQuickSearch',
        moniker => $moniker,
    );

    with( name => $moniker ), form {
        render_action($action);
        form_submit( label => _('Save') );
    };
};

template 'me' => page { title => _('Customize Myself') } content {
    my $self    = shift;
    my $moniker = 'prefs_edit_me';
    my $action  = new_action(
        class   => 'EditUserPrefsMe',
        moniker => $moniker,
    );
    $action->record( Jifty->web->current_user->user_object );
    my @sections      = RT::Action::EditUserPrefsMe->sections;

    with( name => $moniker ), form {
        for my $section ( @sections ) {
            h2 { _($section->{title}) };
            for my $field ( @{ $section->{fields} } ) {
                outs_raw( $action->form_field($field) );
            }
        }
        form_submit( label => _('Save') );
    };
};


template 'search_options' => page { title => _('Customize Search Options') } content {
    my $self    = shift;
    show( '_search_options', 'SearchDisplay' );
}

template 'search' => page { title => _('Customize Search') }
  content {
    my $self = shift;
    my $name = get('name');
    if ( $name =~ /RT::Model::Attribute-(\d+)/ ) {
        my $id = $1;
        my $search = RT::Model::Attribute->new;
        my ( $status, $msg ) = $search->load_by_id($id);
        if ( $status ) {
            if (
                Jifty->web->current_user->has_right(
                    object => RT->system,
                    right  => 'SuperUser'
                )
              )
            {
                p {
                    outs( _('You can also edit the predefined search itself')
                          . ': ' );

                    hyperlink(
                        url => RT->config->get('web_path')
                          . '/Search/Build.html?'
                          . Jifty->web->query_string(
                            saved_search_load => 'RT::System-1-SavedSearch-'
                              . $id
                          ),
                        label => $search->name,
                    );
                };
            }
            show( '_search_options', $search );
        }
        else {
            outs( _( 'faild to load search: %1', $name ) );
        }
    }
    else {
        outs(_('No search specified'));
    }
}

private template '_search_options' => sub {
    my $self = shift;
    my $name = shift;
    return unless $name;

    my $moniker = 'prefs_edit_search_options';
    my $action  = new_action(
        class   => 'EditUserPrefsSearchOptions',
        moniker => $moniker,
    );
    $action->name($name);

    my ( $format, $available_columns, $current_format ) =
      RT::Interface::Web::QueryBuilder->build_format_string(
        %{Jifty->web->request->arguments},
        format =>
          $action->default_value('format')
      );
    $action->available_columns( $available_columns );
    $action->format( $format );

    with( name => $moniker ), form {
        for my $n ( 1 .. 4 ) {
            outs_raw( $action->form_field("order_by_$n") );
            outs_raw( $action->form_field("order_$n") );
        }
        for my $field (qw/rows_per_page format name/) {
            outs_raw( $action->form_field($field) );
        }
        show( 'edit_format', $current_format, $available_columns );
        div { class is 'submit_button';
            outs_raw( $action->form_field("save") );
        };
    };
};

private template 'edit_format' => sub {
    my $self              = shift;
    my $current_format            = shift;
    my $available_columns = shift;
    table {
        row {
            th { _('add Columns') . ':' };
            th { _('format') . ':' };
            th {};
            th { _('Show Columns') . ':' };
        };
        row {
            cell {
                valign is 'top';
                select {
                    size is 6;
                    name     is 'select_display_columns';
                    multiple is 'multiple';
                      for my $field (@$available_columns) {
                        option {
                            value is $field;
                            _($field);
                        };
                    }
                };
            };

            cell {
                _('Link');
                select {
                    name is 'link';
                      option { value is 'None';    '-' };
                      option { value is 'Display'; _('Display') };
                      option { value is 'Take';    _('Take') };
                };
                br {};
                outs( _('Title') . ':' );
                input {
                    name is 'title';
                    size is 10;
                };
                br {};
                outs( _('Size') );
                select {
                    name is 'size';
                      option { value is '';      '-' };
                      option { value is 'Small'; _('Small') };
                      option { value is 'Large'; _('Large') };
                };
                br {};
                outs( _('Style') );
                select {
                    name is 'face';
                      option { value is '';       '-' };
                      option { value is 'Bold';   _('Bold') };
                      option { value is 'Italic'; _('Italic') };
                };
            };
            cell {
                outs_raw(
'<input type="submit" class="button" name="add_col" value=" &rarr;"'
                );
            };
            cell {
                valign is 'top';
                select {
                    size is 4;
                    name is 'current_display_columns';
                    my $i = 0;
                    for my $field (@$current_format) {
                        option {
                            value is $i++;
                            _( $field->{Column} );
                        };
                    }
                };
                br {};
                center {
                    outs_raw(
'<input type="submit" class="button" name="col_up" value=" &uarr;"'
                    );
                    outs_raw(
'<input type="submit" class="button" name="col_down" value=" &darr;"'
                    );
                    input {
                        type is 'submit';
                        class is 'button';
                        name is 'remove_col';
                        value is _('Delete');
                    };
                };
            };
        };
    }
};

1;

