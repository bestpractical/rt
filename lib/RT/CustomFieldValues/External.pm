package RT::CustomFieldValues::External;

use strict;
use warnings;

use base qw(RT::CustomFieldValues);

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
    return unless $args{'FIELD'} =~ /^(?:Name|Description)$/;

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

1;
