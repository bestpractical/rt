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

package RT::View::CRUD;
use Jifty::View::Declare -base;
use base 'Jifty::View::Declare::CRUD';

__PACKAGE__->use_mason_wrapper;

use constant per_page => 50;

template 'index.html' => page {
    title => shift->page_title,
} content {
    my $self = shift;

    form {
        render_region(
            name     => $self->object_type.'-list',
            path     => $self->fragment_base_path.'/list',
        );
    };

    if ( grep { $_ eq 'disabled' } $self->display_columns ) {
        my $include_disabled = get('include_disabled');
        hyperlink(
            label => _(
                ( $include_disabled ? 'Exclude' : 'Include' )
                . ' disabled ones in listing'
            ),
            url        => '',
            parameters => { include_disabled => $include_disabled ? 0 : 1 },
        );
    }
};

template 'sort_header' => sub {
    my $self = shift;
    my $item_path = shift;
    my $sort_by = shift;
    my $order = shift;
    my $record_class = $self->record_class;
    my $update = $record_class->as_update_action();

    div {
        { class is "crud-column-headers" };
        for my $argument ($self->display_columns($update)) {
            my $column = $record_class->column($argument);
            unless ($column) {
                # in case we want to show a field but it's not a real column
                div {
                    { class is 'crud-column-header' };
                    if ( $argument =~ /^cf_(\d+)/ ) {
                        my $id = $1;
                        my $cf = RT::Model::CustomField->new;
                        $cf->load($id);
                        'cf( ' . $cf->name . ' )';
                    }
                    else {
                        $argument;
                    }
                };
                next;
            }

            div {
                { class is 'crud-column-header' };
                ul { attr { class => 'crud-sort-menu', style => 'display:none;' };
                    li {
                        my $imgdown ="<img height='16' width='16' src='/images/silk/bullet_arrow_down.png' alt='down' name='down'>";
                        hyperlink(
                            label => $imgdown,
                            escape_label => 0,
                            onclick =>
                                { args => { sort_by => $argument, order => undef } },
                        );
                    } if (!($sort_by && !$order && $argument eq $sort_by));
                    li {
                        my $imgup ="<img height='16' width='16' src='/images/silk/bullet_arrow_up.png' alt='up' name='up'>";
                        hyperlink(
                            label => $imgup,
                            escape_label => 0,
                            onclick =>
                                { args => { sort_by => $argument, order => 'D' } },
                        );
                    } if (!($sort_by && $order && $argument eq $sort_by));
                    li {
                        my $imgup ="<img height='16' width='16' rc='/images/silk/cancel_grey.png' alt='del' name='del'>";
                        hyperlink(
                            label => $imgup,
                            escape_label => 0,
                            onclick =>
                                { args => { sort_by =>'', order => '' } },
                        );
                    } if ($sort_by && $argument eq $sort_by);
                };
                span{
                    {class is "field"};
                    my $label = $record_class->column($argument)->label || $argument;
                    if ( $sort_by && $argument eq $sort_by ) {
                        div { class is 'crud-sort-selected';
                        hyperlink ( label =>$label );
                        my $img = ($order eq 'D')?'up':'down';
                        img { attr {
                            height => 16,
                            width  => 16,
                            src    => '/images/silk/bullet_arrow_'.$img.'.png' }; };
                        };
                    }
                    else {
                        hyperlink(label => $label);
                    };
                };
            }
        }
    };
    outs_raw("<script type=\"text/javascript\">
    jQuery(document).ready(function() {
      jQuery('.crud-sort-menu').each(function(){
        jQuery(this).parent().hover(
        function(){
        jQuery(this).children('.crud-sort-menu').show();
        },
        function(){
            jQuery(this).children('.crud-sort-menu').hide();
        });
      });
    });
    </script>");

};

private template view_item_controls => sub {
    my $self   = shift;
    my $record = shift;

    my @can_delete = qw/RT::View::Admin::CustomFields::Values
      RT::View::Admin::Queues::Templates
      RT::View::Admin::Global::Templates
      /;
    return unless grep { $self eq $_ } @can_delete;

    my $delete = $record->as_delete_action(
        moniker => 'delete-' . Jifty->web->serial,
    );
    my $view_region = Jifty->web->qualified_region;

    if ( $record->current_user_can('delete') ) {
        $delete->button(
            label   => _('Delete'),
            onclick => [
                {
                    submit  => $delete,
                    confirm => _('Really delete?'),
                },
                {
                    region       => $view_region,
                    replace_with => '/__jifty/empty',
                },
            ],
            class => 'delete',
        );
    }
};

sub view_via_callback {
    my $self = shift;
    my %args = @_;

    my $field = $args{action}->form_field($args{field}, render_mode => 'read');

    $args{id} = $args{action}->argument_value('id');
    $args{current_value} = "@{[$field->current_value]}";

    # I don't see a clean way to do this :(
    $field->render_wrapper_start();
    $field->render_preamble();

    # render the value with a hyperlink
    span {
        attr { class is "@{[ $field->classes ]} value" };
        $args{callback}->(%args);
    };

    $field->render_wrapper_end();

    return;
}

sub view_field {
    my $self = shift;
    my %args = @_;

# we just want to do this hyperlink thing for those specfic views
    if (
        $self =~ /(Users|Groups|Queues|CustomFields|Templates|Values)$/
        && $args{field} =~ /^(id|name)$/
      )
    {
        $self->view_via_callback(
            %args,
            callback => sub {
                my %args = @_;
                my $url;

                if ( $self eq 'RT::View::Admin::Queues::Templates' ) {
                    $url .= 'edit?id=' . $args{id} . '&queue=' . get('queue');
                }
                elsif ( $self eq 'RT::View::Admin::Global::Templates' ) {
                    $url .= 'edit?id=' . $args{id};
                }
                elsif ( $self eq 'RT::View::Admin::CustomFields::Values' ) {
                    $url .=
                        'edit?id='
                      . $args{id}
                      . '&custom_field='
                      . get('custom_field');
                }
                else {
                    $url = "?id=" . $args{id};
                }

                hyperlink(
                    label => $args{current_value},
                    url   => $url,
                );
            }
        );
    }
    elsif ( $args{field} =~ /^cf_(\d+)$/ ) {
        my $ocfvs = $args{action}->record->custom_field_values( $1 );
        $self->render_custom_field_values( $ocfvs );
    }
    else {
        $self->SUPER::view_field(@_);
    }
}

sub render_custom_field_values {
    my $self  = shift;
    my $ocfvs = shift;
    return '' unless $ocfvs->count;
    my $cf = $ocfvs->first->custom_field;

    my $method = $self->can( 'render_custom_field_' . lc $cf->type );

    $ocfvs->goto_first_item;
    while ( my $ocfv = $ocfvs->next ) {
        if ( $method ) {
            $method->( $self, $ocfv );
        }
        else {
            outs( $ocfv->content );
            outs_raw( '<br />' );
        }
    }
}

sub render_custom_field_text {
    my $self    = shift;
    my $object  = shift;
    my $content = $object->large_content || $object->content;
    $content = RT::Interface::Web->scrub_html($content);
    $content =~ s!\n!<br />!g;
    outs_raw($content);
}

sub render_custom_field_wikitext {
    my $self   = shift;
    my $object = shift;
    require Text::WikiFormat;
    my $content = $object->large_content || $object->content;
    $content = RT::Interface::Web->scrub_html($content);
    my $base         = $object->object->wiki_base;
    my $wiki_content = Text::WikiFormat::format(
        $content . "\n",
        {},
        {
            extended       => 1,
            absolute_links => 1,
            implicit_links => RT->config->get('wiki_implicit_links'),
            prefix         => $base
        }
    );
    outs_raw($wiki_content);
}

sub render_custom_field_image {
    my $self   = shift;
    my $object = shift;
    my $url =
      '/Download/CustomFieldValue/' . $object->id . '/' . $object->content;
    hyperlink(
        label => $object->content,
        url   => $url,
    );
    img {
        attr {
            type   => $object->content_type,
            height => 64,
            src    => $url,
            align  => 'middle'
        };
    };
}

sub render_custom_field_binary {
    my $self = shift;
    my $object = shift;
    hyperlink(
        label => $object->content,
        url   => '/Download/CustomFieldValue/'
          . $object->id . '/'
          . $object->content,
    );
}

sub custom_field_columns {
    my $self   = shift;
    my $object = shift;
    my $cfs    = $object->custom_fields;
    return map { 'cf_' . $_->id } @{ $cfs->items_array_ref };
}

# we can't use jifty's default update is because that's a json one
# which is not capable since we may have file cf
template 'edit' => page { title => _( 'Update ' . shift->object_type ), }
content {
    my $self   = shift;
    my $class  = 'RT::Model::' . $self->object_type;
    my $object = $class->new;
    $object->load( get('id') );

    my $moniker = 'update_' . lc $self->object_type;
    my $action = $object->as_update_action( moniker => $moniker, );
    with( name => $moniker ), form {
        for my $field ( $self->edit_columns($action) ) {
            div {
                { class is 'update-argument-' . $field };
                $self->render_field(
                    mode   => 'edit',
                    action => $action,
                    field  => $field,
                );
            }
        }
        form_submit( label => _('Save') );
    };
};

private template 'new_item_controls' => sub {
    my $self          = shift;
    my $create        = shift;
    my ($object_type) = ( $self->object_type );

    outs(
        Jifty->web->form->submit(
            label   => _('Create'),
            onclick => [
                { submit       => $create },
                { refresh_self => 1 },
                {
                    delete =>
                      Jifty->web->qualified_parent_region('no_items_found')
                },
                {
                    element => Jifty->web->current_region->parent->get_element(
                        'div.crud-list'),
                    append => $self->fragment_for('view'),
                    args => {
                        object_type  => $object_type,
                        id           => { result_of => $create, name => 'id' },
                        custom_field => get('custom_field'),
                        queue        => get('queue'),
                    },
                },
            ]
        )
    );
};


1;
