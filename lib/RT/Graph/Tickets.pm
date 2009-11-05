# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2008 Best Practical Solutions, LLC
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

package RT::Graph::Tickets;

use strict;
use warnings;

=head1 NAME

RT::Graph::Tickets - view relations between tickets as graphs

=cut

unless ($RT::DisableGraphViz) {
    require IPC::Run;
    IPC::Run->import;
    require IPC::Run::SafeHandles;
    IPC::Run::SafeHandles->import;
    require GraphViz;
    GraphViz->import;
}

our %ticket_status_style = (
    new      => { fontcolor => '#FF0000', fontsize => 10 },
    open     => { fontcolor => '#000000', fontsize => 10 },
    stalled  => { fontcolor => '#DAA520', fontsize => 10 },
    resolved => { fontcolor => '#00FF00', fontsize => 10 },
    rejected => { fontcolor => '#808080', fontsize => 10 },
    deleted  => { fontcolor => '#A9A9A9', fontsize => 10 },
);

our %link_style = (
    member_of  => { style => 'solid' },
    depends_on => { style => 'dashed' },
    refers_to  => { style => 'dotted' },
);

# We don't use qw() because perl complains about "possible attempt to put comments in qw() list"
our @fill_colors = split ' ', <<EOT;
    #0000FF #8A2BE2 #A52A2A #DEB887 #5F9EA0 #7FFF00 #D2691E #FF7F50
    #6495ED #FFF8DC #DC143C #00FFFF #00008B #008B8B #B8860B #A9A9A9
    #A9A9A9 #006400 #BDB76B #8B008B #556B2F #FF8C00 #9932CC #8B0000
    #E9967A #8FBC8F #483D8B #2F4F4F #2F4F4F #00CED1 #9400D3 #FF1493
    #00BFFF #696969 #696969 #1E90FF #B22222 #FFFAF0 #228B22 #FF00FF
    #DCDCDC #F8F8FF #FFD700 #DAA520 #808080 #808080 #008000 #ADFF2F
    #F0FFF0 #FF69B4 #CD5C5C #4B0082 #FFFFF0 #F0E68C #E6E6FA #FFF0F5
    #7CFC00 #FFFACD #ADD8E6 #F08080 #E0FFFF #FAFAD2 #D3D3D3 #D3D3D3
    #90EE90 #FFB6C1 #FFA07A #20B2AA #87CEFA #778899 #778899 #B0C4DE
    #FFFFE0 #00FF00 #32CD32 #FAF0E6 #FF00FF #800000 #66CDAA #0000CD
    #BA55D3 #9370D8 #3CB371 #7B68EE #00FA9A #48D1CC #C71585 #191970
    #F5FFFA #FFE4E1 #FFE4B5 #FFDEAD #000080 #FDF5E6 #808000 #6B8E23
    #FFA500 #FF4500 #DA70D6 #EEE8AA #98FB98 #AFEEEE #D87093 #FFEFD5
    #FFDAB9 #CD853F #FFC0CB #DDA0DD #B0E0E6 #800080 #FF0000 #BC8F8F
    #4169E1 #8B4513 #FA8072 #F4A460 #2E8B57 #FFF5EE #A0522D #C0C0C0
    #87CEEB #6A5ACD #708090 #708090 #FFFAFA #00FF7F #4682B4 #D2B48C
    #008080 #D8BFD8 #FF6347 #40E0D0 #EE82EE #F5DEB3 #FFFF00 #9ACD32
EOT

sub gv_escape($) {
    my $value = shift;
    $value =~ s{(?=")}{\\}g;
    return $value;
}

our ( %fill_cache, @available_colors ) = ();

our %property_cb = (
    queue => sub { return $_[0]->queue->name || $_[0]->queue },
    cf => sub {
        my $values = $_[0]->custom_field_values( $_[1] );
        return join ', ', map $_->content, @{ $values->items_array_ref };
    },
);
foreach my $field (qw(subject status time_left time_worked time_estimated)) {
    $property_cb{$field} = sub { return $_[0]->$field },;
}
foreach my $field (qw(creator last_updated_by owner)) {
    $property_cb{$field} = sub {
        return $_[0]->$field->name;
    };
}
foreach my $field (qw(requestor cc admin_cc)) {
    $property_cb{ $field . "s" } = sub {
        return $_[0]->role_group( $field )->member_emails;
    };
}
foreach my $field (qw(told starts started due resolved last_updated created)) {
    $property_cb{$field} = sub {
        my $method = $field . '_obj';
        return $_[0]->$method->as_string;
    };
}
foreach my $field (qw(members depended_on_by referred_to_by)) {
    $property_cb{$field} = sub {
        return join ', ', map $_->base_obj->id,
          @{ $_[0]->$field->items_array_ref };
    };
}
foreach my $field (qw(member_of depends_on refersTo)) {
    $property_cb{$field} = sub {
        return join ', ', map $_->target_obj->id,
          @{ $_[0]->$field->items_array_ref };
    };
}

sub ticket_properties {
    my $self = shift;
    my $user = shift;
    my @res = (
        basics => [qw(subject status queue time_left time_worked time_estimated)]
        ,    # loc_qw
        people => [qw(owner requestors ccs admin_ccs creator last_updated_by)]
        ,    # loc_qw
        dates => [qw(created starts started due resolved told last_updated)]
        ,    # loc_qw
        links =>
          [qw(member_of members depends_on depended_on_by refers_to referred_to_by)]
        ,    # loc_qw
    );
    my $cfs = RT::Model::CustomFieldCollection->new(current_user => $user);
    $cfs->limit_to_lookup_type('RT::Model::Queue-RT::Model::Ticket');
    $cfs->order_by( column => 'name' );
    my ( $first, %seen ) = (1);
    while ( my $cf = $cfs->next ) {
        next if $seen{ lc $cf->name }++;
        next if $cf->type eq 'image';
        if ($first) {
            push @res, 'CustomFields', [];
            $first = 0;
        }
        push @{ $res[-1] }, 'CF.{' . $cf->name . '}';
    }
    return @res;
}

sub _split_property {
    my $self     = shift;
    my $property = shift;
    my ( $key, @subkeys ) = split /\./, $property;
    foreach ( grep /^{.*}$/, @subkeys ) {
        s/^{//;
        s/}$//;
    }
    return $key, @subkeys;
}

sub _properties_to_fields {
    my $self = shift;
    my %args = (
        ticket       => undef,
        graph        => undef,
        current_depth => 1,
        @_
    );

    my @properties;
    if ( my $tmp = $args{ 'level-' . $args{'current_depth'} . '-properties' } ) {
        @properties = ref $tmp ? @$tmp : ($tmp);
    }

    my @fields;
    foreach my $property (@properties) {
        my ( $key, @subkeys ) = $self->_split_property($property);
        unless ( $property_cb{$key} ) {
            Jifty->log->error(
"Couldn't find property handler for '$key' and '@subkeys' subkeys"
            );
            next;
        }
        push @fields,
          ( $subkeys[0] || $key ) . ': '
          . $property_cb{$key}->( $args{'ticket'}, @subkeys );
    }

    return @fields;
}

sub add_ticket {
    my $self = shift;
    my %args = (
        ticket       => undef,
        properties   => [],
        graph        => undef,
        current_depth => 1,
        @_
    );

    my %node_style = (
        style => 'filled,rounded',
        %{ $ticket_status_style{ $args{'ticket'}->status } || {} },
        URL => RT->config->get('web_path') . '/Ticket/Display.html?id=' . $args{'ticket'}->id,
        tooltip =>
          gv_escape( $args{'ticket'}->subject || '#' . $args{'ticket'}->id ),
    );

    my @fields = $self->_properties_to_fields(%args);
    if (@fields) {
        unshift @fields, $args{'ticket'}->id;
        my $label = join ' | ', map { s/(?=[{}|])/\\/g; $_ } @fields;
        $label = "{ $label }"
          if ( $args{'direction'} || 'TB' ) =~ /^(?:TB|BT)$/;
        $node_style{'label'} = gv_escape($label);
        $node_style{'shape'} = 'record';
    }

    if ( $args{'fill_using'} ) {
        my ( $key, @subkeys ) = $self->_split_property( $args{'fill_using'} );
        my $value;
        if ( $property_cb{$key} ) {
            $value = $property_cb{$key}->( $args{'ticket'}, @subkeys );
        }
        else {
            Jifty->log->error("Couldn't find property callback for '$key'");
        }
        if ( defined $value && length $value && $value =~ /\S/ ) {
            my $fill = $fill_cache{$value};
            $fill = $fill_cache{$value} = shift @available_colors
              unless $fill;
            if ($fill) {
                $node_style{'fillcolor'} = $fill;
                $node_style{'style'} ||= '';
                $node_style{'style'} = join ',',
                  split( ',', $node_style{'style'} ), 'filled'
                  unless $node_style{'style'} =~ /\bfilled\b/;
            }
        }
    }

    $args{'graph'}->add_node( $args{'ticket'}->id, %node_style );
}

sub ticket_links {
    my $self = shift;
    my %args = (
        ticket => undef,

        graph     => undef,
        direction => 'TB',
        seen      => undef,
        seen_edge  => undef,

        leading_link => 'members',
        show_links   => [],

        max_depth     => 0,
        current_depth => 1,

        show_link_descriptions => 0,
        @_
    );
    unless ( $args{'graph'} ) {
        $args{'graph'} = GraphViz->new(
            name    => 'ticket_links_' . $args{'ticket'}->id,
            bgcolor => "transparent",

            # TODO: patch GraphViz to support all posible RDs
            rankdir => ( $args{'direction'} || "TB" ) eq "LR",
            node => {
                shape     => 'box',
                style     => 'filled,rounded',
                fillcolor => 'white'
            },
        );
        %fill_cache       = ();
        @available_colors = @fill_colors;
    }

    $args{'seen'} ||= {};
    return $args{'graph'} if $args{'seen'}{ $args{'ticket'}->id }++;

    $self->add_ticket(%args);

    return $args{'graph'}
      if $args{'max_depth'} && $args{'current_depth'} >= $args{'max_depth'};

    $args{'seen_edge'} ||= {};

    my $show_link_descriptions = $args{'show_link_descriptions'}
      && RT::Model::Link->can('description');

    foreach my $type ( $args{'leading_link'}, @{ $args{'show_links'} } ) {
        my $links = $args{'ticket'}->$type();
        $links->goto_first_item;
        while ( my $link = $links->next ) {
            next if $args{'seen_edge'}{ $link->id }++;

            my $target = $link->target_obj;
            next unless $target && $target->isa('RT::Model::Ticket');

            my $base = $link->base_obj;
            next unless $base && $base->isa('RT::Model::Ticket');

            my $next = $target->id == $args{'ticket'}->id ? $base : $target;

            $self->ticket_links(
                %args,
                ticket => $next,
                $type eq $args{'leading_link'}
                ? ( current_depth => $args{'current_depth'} + 1 )
                : (
                    max_depth     => $args{'current_depth'} + 1,
                    current_depth => $args{'current_depth'} + 1
                ),
            );

            my $desc;
            $desc = $link->description if $show_link_descriptions;
            $args{'graph'}->add_edge(

                # we revers order of member links to get better layout
                $link->type eq 'member_of'
                ? ( $target->id => $base->id, dir => 'back' )
                : ( $base->id => $target->id ),
                %{ $link_style{ $link->type } || {} },
                $desc ? ( label => gv_escape $desc) : (),
            );
        }
    }

    return $args{'graph'};
}

1;
