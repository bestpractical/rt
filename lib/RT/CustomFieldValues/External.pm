# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
# 
# This software is Copyright (c) 1996-2009 Best Practical Solutions, LLC
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

package RT::CustomFieldValues::External;

use strict;
use warnings;

use base qw(RT::CustomFieldValues);

=head1 NAME

RT::CustomFieldValues::External - Pull possible values for a custom
field from an arbitrary external data source.

=head1 SYNOPSIS

Custom field value lists can be produced by creating a class that
inherits from C<RT::CustomFieldValues::External>, and overloading
C<SourceDescription> and C<ExternalValues>.  See
L<RT::CustomFieldValues::Groups> for a simple example.

=head1 DESCRIPTION

Subclasses should implement the following methods:

=head2 SourceDescription

This method should return a string describing the data source; this is
the identifier by which the user will see the dropdown.

=head2 ExternalValues

This method should return an array reference of hash references.  The
hash references should contain keys for C<name>, C<description>, and
C<sortorder>.

=head1 SEE ALSO

L<docs/creating_external_custom_fields.pod>

=cut

sub _Init {
    my $self = shift;
    $self->Table( '' );
    return ( $self->SUPER::_Init(@_) );
}

sub CleanSlate {
    my $self = shift;
    delete $self->{ $_ } foreach qw(
        __external_cf
        __external_cf_limits
    );
    return $self->SUPER::CleanSlate(@_);
}

sub _ClonedAttributes {
    my $self = shift;
    return qw(
        __external_cf
        __external_cf_limits
    ), $self->SUPER::_ClonedAttributes;
}

sub Limit {
    my $self = shift;
    my %args = (@_);
    push @{ $self->{'__external_cf_limits'} ||= [] }, {
        %args,
        CALLBACK => $self->__BuildLimitCheck( %args ),
    };
    return $self->SUPER::Limit( %args );
}

sub __BuildLimitCheck {
    my ($self, %args) = (@_);
    return undef unless $args{'FIELD'} =~ /^(?:Name|Description)$/;

    $args{'OPERATOR'} ||= '=';
    my $quoted_value = $args{'VALUE'};
    if ( $quoted_value ) {
        $quoted_value =~ s/'/\\'/g;
        $quoted_value = "'$quoted_value'";
    }

    my $code = <<END;
my \$record = shift;
my \$value = \$record->$args{'FIELD'};
my \$condition = $quoted_value;
END

    if ( $args{'OPERATOR'} =~ /^(?:=|!=|<>)$/ ) {
        $code .= 'return 0 unless defined $value;';
        my %h = ( '=' => ' eq ', '!=' => ' ne ', '<>' => ' ne ' );
        $code .= 'return 0 unless $value'. $h{ $args{'OPERATOR'} } .'$condition;';
        $code .= 'return 1;'
    }
    elsif ( $args{'OPERATOR'} =~ /^(?:LIKE|NOT LIKE)$/i ) {
        $code .= 'return 0 unless defined $value;';
        my %h = ( 'LIKE' => ' =~ ', 'NOT LIKE' => ' !~ ' );
        $code .= 'return 0 unless $value'. $h{ uc $args{'OPERATOR'} } .'/\Q$condition/i;';
        $code .= 'return 1;'
    }
    else {
        $code .= 'return 0;'
    }
    $code = "sub {$code}";
    my $cb = eval "$code";
    $RT::Logger->error( "Couldn't build callback '$code': $@" ) if $@;
    return $cb;
}

sub __BuildAggregatorsCheck {
    my $self = shift;

    my %h = ( OR => ' || ', AND => ' && ' );
    
    my $code = '';
    for( my $i = 0; $i < @{ $self->{'__external_cf_limits'} }; $i++ ) {
        next unless $self->{'__external_cf_limits'}->[$i]->{'CALLBACK'};
        $code .= $h{ uc($self->{'__external_cf_limits'}->[$i]->{'ENTRYAGGREGATOR'} || 'OR') } if $code;
        $code .= '$sb->{\'__external_cf_limits\'}->['. $i .']->{\'CALLBACK\'}->($record)';
    }
    return unless $code;

    $code = "sub { my (\$sb,\$record) = (\@_); return $code }";
    my $cb = eval "$code";
    $RT::Logger->error( "Couldn't build callback '$code': $@" ) if $@;
    return $cb;
}

sub _DoSearch {
    my $self = shift;

    delete $self->{'items'};

    my %defaults = (
            id => 1,
            name => '',
            customfield => $self->{'__external_cf'},
            sortorder => 0,
            description => '',
            creator => $RT::SystemUser->id,
            created => undef,
            lastupdatedby => $RT::SystemUser->id,
            lastupdated => undef,
    );

    my $i = 0;

    my $check = $self->__BuildAggregatorsCheck;
    foreach( @{ $self->ExternalValues } ) {
        my $value = $self->NewItem;
        $value->LoadFromHash( { %defaults, %$_ } );
        next if $check && !$check->( $self, $value );
        $self->AddRecord( $value );
    }
    $self->{'must_redo_search'} = 0;
    return $self->_RecordCount;
}

sub _DoCount {
    my $self = shift;

    my $count;
    $count = $self->_DoSearch if $self->{'must_redo_search'};
    $count = $self->_RecordCount unless defined $count;

    return $self->{'count_all'} = $self->{'raw_rows'} = $count;
}

sub LimitToCustomField {
    my $self = shift;
    $self->{'__external_cf'} = $_[0];
    return $self->SUPER::LimitToCustomField( @_ );
}

eval "require RT::CustomFieldValues::External_Vendor";
if ($@ && $@ !~ qr{^Can't locate RT/CustomFieldValues/External_Vendor.pm}) {
    die $@;
};

eval "require RT::CustomFieldValues::External_Local";
if ($@ && $@ !~ qr{^Can't locate RT/CustomFieldValues/External_Local.pm}) {
    die $@;
};

1;
