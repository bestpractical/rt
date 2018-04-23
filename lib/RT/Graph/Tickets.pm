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

package RT::Graph::Tickets;

use strict;
use warnings;

=head1 NAME

RT::Graph::Tickets - view relations between tickets as graphs

=cut

unless ($RT::DisableGraphViz) {
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
    MemberOf  => { style => 'solid' },
    DependsOn => { style => 'dashed' },
    RefersTo  => { style => 'dotted' },
);

# We don't use qw() because perl complains about "possible attempt to put comments in qw() list"
our @fill_colors = split ' ',<<EOT;
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
    $value =~ s{(?=["\\])}{\\}g;
    return $value;
}

sub loc { return HTML::Mason::Commands::loc(@_) };

our (%fill_cache, @available_colors) = ();

our %property_cb = (
    Queue  => sub { return $_[0]->QueueObj->Name || $_[0]->Queue },
    Status => sub { return loc($_[0]->Status) },
    CF     => sub {
        my $values = $_[0]->CustomFieldValues( $_[1] );
        return join ', ', map $_->Content, @{ $values->ItemsArrayRef };
    },
);
foreach my $field (qw(Subject TimeLeft TimeWorked TimeEstimated)) {
    $property_cb{ $field } = sub { return $_[0]->$field },
}
foreach my $field (qw(Creator LastUpdatedBy Owner)) {
    $property_cb{ $field } = sub {
        my $method = $field .'Obj';
        return $_[0]->$method->Name;
    };
}
foreach my $field (qw(Requestor Cc AdminCc)) {
    $property_cb{ $field."s" } = sub {
        my $method = $field .'Addresses';
        return $_[0]->$method;
    };
}
foreach my $field (qw(Told Starts Started Due Resolved LastUpdated Created)) {
    $property_cb{ $field } = sub {
        my $method = $field .'Obj';
        return $_[0]->$method->AsString;
    };
}
foreach my $field (qw(Members DependedOnBy ReferredToBy)) {
    $property_cb{ $field } = sub {
        my $links = $_[0]->$field;
        my @string;
        while ( my $link = $links->Next ) {
            next if UNIVERSAL::isa($link->BaseObj, 'RT::Article') && $link->BaseObj->Disabled;
            next if $field eq 'ReferredToBy' && UNIVERSAL::isa($link->BaseObj, 'RT::Ticket') && $link->BaseObj->Type eq 'reminder';
            my $prefix =
                UNIVERSAL::isa( $link->BaseObj, 'RT::Ticket' ) ? ''
              : UNIVERSAL::isa( $link->BaseObj, 'RT::Article' ) ? 'a:'
              :                                                   $link->BaseURI->Scheme . ':';
            push @string, $prefix . $link->BaseObj->id;
        }
        return join ', ', @string;
    };
}
foreach my $field (qw(MemberOf DependsOn RefersTo)) {
    $property_cb{ $field } = sub {
        my $links = $_[0]->$field;
        my @string;
        while ( my $link = $links->Next ) {
            next if UNIVERSAL::isa($link->TargetObj, 'RT::Article') && $link->TargetObj->Disabled;
            my $prefix =
                UNIVERSAL::isa( $link->TargetObj, 'RT::Ticket' ) ? ''
              : UNIVERSAL::isa( $link->TargetObj, 'RT::Article' ) ? 'a:'
              :                                                   $link->TargetURI->Scheme . ':';
            push @string, $prefix . $link->TargetObj->id;
        }
        return join ', ', @string;
    };
}


sub TicketProperties {
    my $self = shift;
    my $user = shift;
    my @res = (
        Basics => [qw(Subject Status Queue TimeLeft TimeWorked TimeEstimated)], # loc_qw
        People => [qw(Owner Requestors Ccs AdminCcs Creator LastUpdatedBy)], # loc_qw
        Dates  => [qw(Created Starts Started Due Resolved Told LastUpdated)], # loc_qw
        Links  => [qw(MemberOf Members DependsOn DependedOnBy RefersTo ReferredToBy)], # loc_qw
    );
    my $cfs = RT::CustomFields->new( $user );
    $cfs->LimitToLookupType('RT::Queue-RT::Ticket');
    $cfs->OrderBy( FIELD => 'Name' );
    my ($first, %seen) = (1);
    while ( my $cf = $cfs->Next ) {
        next if $seen{ lc $cf->Name }++;
        next if $cf->Type eq 'Image';
        if ( $first ) {
            push @res, 'Custom Fields', # loc
                [];
            $first = 0;
        }
        push @{ $res[-1] }, 'CF.{'. $cf->Name .'}';
    }
    return @res;
}

sub _SplitProperty {
    my $self = shift;
    my $property = shift;
    my ($key, @subkeys) = split /\./, $property;
    foreach ( grep /^{.*}$/, @subkeys ) {
        s/^{//;
        s/}$//;
    }
    return $key, @subkeys;
}

sub _PropertiesToFields {
    my $self = shift;
    my %args = (
        Ticket       => undef,
        Graph        => undef,
        CurrentDepth => 1,
        @_
    );

    my @properties;
    if ( my $tmp = $args{ 'Level-'. $args{'CurrentDepth'} .'-Properties' } ) {
        @properties = ref $tmp? @$tmp : ($tmp);
    }

    my @fields;
    foreach my $property( @properties ) {
        my ($key, @subkeys) = $self->_SplitProperty( $property );
        unless ( $property_cb{ $key } ) {
            $RT::Logger->error("Couldn't find property handler for '$key' and '@subkeys' subkeys");
            next;
        }
        my $label = $key eq 'CF' ? $subkeys[0] : loc($key);
        push @fields, $label .': '. $property_cb{ $key }->( $args{'Ticket'}, @subkeys );
    }

    return @fields;
}

sub AddTicket {
    my $self = shift;
    my %args = (
        Ticket       => undef,
        Properties   => [],
        Graph        => undef,
        CurrentDepth => 1,
        @_
    );

    my %node_style = (
        style => 'filled,rounded',
        %{ $ticket_status_style{ $args{'Ticket'}->Status } || {} },
        URL   => $RT::WebPath .'/Ticket/Display.html?id='. $args{'Ticket'}->id,
        tooltip => gv_escape( $args{'Ticket'}->Subject || '#'. $args{'Ticket'}->id ),
    );

    my @fields = $self->_PropertiesToFields( %args );
    if ( @fields ) {
        unshift @fields, $args{'Ticket'}->id;
        my $label = join ' | ', map { s/(?=[{}|><])/\\/g; $_ } @fields;
        $label = "{ $label }" if ($args{'Direction'} || 'TB') =~ /^(?:TB|BT)$/;
        $node_style{'label'} = gv_escape( $label );
        $node_style{'shape'} = 'record';
    }
    
    if ( $args{'FillUsing'} ) {
        my ($key, @subkeys) = $self->_SplitProperty( $args{'FillUsing'} );
        my $value;
        if ( $property_cb{ $key } ) {
            $value = $property_cb{ $key }->( $args{'Ticket'}, @subkeys );
        } else {
            $RT::Logger->error("Couldn't find property callback for '$key'");
        }
        if ( defined $value && length $value && $value =~ /\S/ ) {
            my $fill = $fill_cache{ $value };
            $fill = $fill_cache{ $value } = shift @available_colors
                unless $fill;
            if ( $fill ) {
                $node_style{'fillcolor'} = $fill;
                $node_style{'style'} ||= '';
                $node_style{'style'} = join ',', split( ',', $node_style{'style'} ), 'filled'
                    unless $node_style{'style'} =~ /\bfilled\b/;
            }
        }
    }

    $args{'Graph'}->add_node( $args{'Ticket'}->id, %node_style );
}

sub TicketLinks {
    my $self = shift;
    my %args = (
        Ticket               => undef,

        Graph                => undef,
        Direction            => 'TB',
        Seen                 => undef,
        SeenEdge             => undef,

        LeadingLink          => 'Members',
        ShowLinks            => [],

        MaxDepth             => 0,
        CurrentDepth         => 1,

        ShowLinkDescriptions => 0,
        @_
    );

    my %valid_links = map { $_ => 1 }
        qw(Members MemberOf RefersTo ReferredToBy DependsOn DependedOnBy);

    # Validate our link types
    $args{ShowLinks}   = [ grep { $valid_links{$_} } @{$args{ShowLinks}} ];
    $args{LeadingLink} = 'Members' unless $valid_links{ $args{LeadingLink} };

    unless ( $args{'Graph'} ) {
        $args{'Graph'} = GraphViz->new(
            name    => 'ticket_links_'. $args{'Ticket'}->id,
            bgcolor => "transparent",
# TODO: patch GraphViz to support all posible RDs
            rankdir => ($args{'Direction'} || "TB") eq "LR",
            node => { shape => 'box', style => 'filled,rounded', fillcolor => 'white' },
        );
        %fill_cache = ();
        @available_colors = @fill_colors;
    }

    $args{'Seen'} ||= {};
    if ( $args{'Seen'}{ $args{'Ticket'}->id } && $args{'Seen'}{ $args{'Ticket'}->id } <= $args{'CurrentDepth'} ) {
      return $args{'Graph'};
    } elsif ( ! defined $args{'Seen'}{ $args{'Ticket'}->id } ) {
      $self->AddTicket( %args );
    }
    $args{'Seen'}{ $args{'Ticket'}->id } = $args{'CurrentDepth'};

    return $args{'Graph'} if $args{'MaxDepth'} && $args{'CurrentDepth'} >= $args{'MaxDepth'};

    $args{'SeenEdge'} ||= {};

    my $show_link_descriptions = $args{'ShowLinkDescriptions'}
        && RT::Link->can('Description');

    foreach my $type ( $args{'LeadingLink'}, @{ $args{'ShowLinks'} } ) {
        my $links = $args{'Ticket'}->$type();
        $links->GotoFirstItem;
        while ( my $link = $links->Next ) {
            next if $args{'SeenEdge'}{ $link->id }++;

            my $target = $link->TargetObj;
            next unless $target && $target->isa('RT::Ticket');

            my $base = $link->BaseObj;
            next unless $base && $base->isa('RT::Ticket');

            my $next = $target->id == $args{'Ticket'}->id? $base : $target;

            $self->TicketLinks(
                %args,
                Ticket => $next,
                $type eq $args{'LeadingLink'}
                    ? ( CurrentDepth => $args{'CurrentDepth'} + 1 )
                    : ( MaxDepth => $args{'CurrentDepth'} + 1,
                        CurrentDepth => $args{'CurrentDepth'} + 1 ),
            );

            my $desc;
            $desc = $link->Description if $show_link_descriptions;
            $args{'Graph'}->add_edge(
                # we revers order of member links to get better layout
                $link->Type eq 'MemberOf'
                    ? ($target->id => $base->id, dir => 'back')
                    : ($base->id => $target->id),
                %{ $link_style{ $link->Type } || {} },
                $desc? (label => gv_escape $desc): (),
            );
        }
    }

    return $args{'Graph'};
}

RT::Base->_ImportOverlays();

1;
