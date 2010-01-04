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
                . ' disabled '
                  . lc( $self->object_type )
                  . 'in listing.'
            ),
            url => '',
            parameters => { include_disabled => $include_disabled ? 0 : 1 },
        );
    }
};

# no popup update link
private template view_item_controls  => sub { };

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
        $self =~ /(Users|Groups|Queues|CustomFields)$/
        && $args{field} =~ /^(id|name)$/
      )
    {
        $self->view_via_callback(
            %args,
            callback => sub {
                my %args = @_;
                hyperlink(
                    label => $args{current_value},
                    url   => "?id=" . $args{id},
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
        render_action($action);
        form_submit( label => _('Save') );
    };
};

1;
