# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2003 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
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
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK
=head1 NAME

  RT::Record - Base class for RT record objects

=head1 SYNOPSIS


=head1 DESCRIPTION


=begin testing

ok (require RT::Record);

=end testing

=head1 METHODS

=cut

package RT::Record;
use RT::Date;
use RT::User;

use RT::Base;
use DBIx::SearchBuilder::Record::Cachable;

use strict;
use vars qw/@ISA/;

@ISA = qw(RT::Base);

if ($RT::DontCacheSearchBuilderRecords ) {
    push (@ISA, 'DBIx::SearchBuilder::Record');
} else {
    push (@ISA, 'DBIx::SearchBuilder::Record::Cachable');

}

# {{{ sub _Init 

sub _Init {
    my $self = shift;
    $self->CurrentUser(@_);

}

# }}}

# {{{ _PrimaryKeys

=head2 _PrimaryKeys

The primary keys for RT classes is 'id'

=cut

sub _PrimaryKeys {
    my $self = shift;
    return ( ['id'] );
}

# }}}

# {{{ sub _Handle 
sub _Handle {
    my $self = shift;
    return ($RT::Handle);
}

# }}}

# {{{ sub Create 

=item  Create PARAMHASH

Takes a PARAMHASH of Column -> Value pairs.
If any Column has a Validate$PARAMNAME subroutine defined and the 
value provided doesn't pass validation, this routine returns
an error.

If this object's table has any of the following atetributes defined as
'Auto', this routine will automatically fill in their values.

=cut

sub Create {
    my $self    = shift;
    my %attribs = (@_);
    foreach my $key ( keys %attribs ) {
        my $method = "Validate$key";
        unless ( $self->$method( $attribs{$key} ) ) {
            if (wantarray) {
                return ( 0, $self->loc('Invalid value for [_1]', $key) );
            }
            else {
                return (0);
            }
        }
    }
    my $now = RT::Date->new( $self->CurrentUser );
    $now->Set( Format => 'unix', Value => time );
    $attribs{'Created'} = $now->ISO() if ( $self->_Accessible( 'Created', 'auto' ) && !$attribs{'Created'});

    if ($self->_Accessible( 'Creator', 'auto' ) && !$attribs{'Creator'}) {
         $attribs{'Creator'} = $self->CurrentUser->id || '0'; 
    }
    $attribs{'LastUpdated'} = $now->ISO()
      if ( $self->_Accessible( 'LastUpdated', 'auto' ) && !$attribs{'LastUpdated'});

    $attribs{'LastUpdatedBy'} = $self->CurrentUser->id || '0'
      if ( $self->_Accessible( 'LastUpdatedBy', 'auto' ) && !$attribs{'LastUpdatedBy'});

    my $id = $self->SUPER::Create(%attribs);
    if ( UNIVERSAL::isa( $id, 'Class::ReturnValue' ) ) {
        if ( $id->errno ) {
            if (wantarray) {
                return ( 0,
                    $self->loc( "Internal Error: [_1]", $id->{error_message} ) );
            }
            else {
                return (0);
            }
        }
    }
    # If the object was created in the database, 
    # load it up now, so we're sure we get what the database 
    # has.  Arguably, this should not be necessary, but there
    # isn't much we can do about it.

   unless ($id) { 
    if (wantarray) {
        return ( $id, $self->loc('Object could not be created') );
    }
    else {
        return ($id);
    }

   }

    if  (UNIVERSAL::isa('errno',$id)) {
        exit(0);
       warn "It's here!";
        return(undef);
    }

    $self->Load($id) if ($id);



    if (wantarray) {
        return ( $id, $self->loc('Object created') );
    }
    else {
        return ($id);
    }

}

# }}}

# {{{ sub LoadByCols

=head2 LoadByCols

Override DBIx::SearchBuilder::LoadByCols to do case-insensitive loads if the 
DB is case sensitive

=cut

sub LoadByCols {
    my $self = shift;
    my %hash = (@_);

    # If this database is case sensitive we need to uncase objects for
    # explicit loading
    if ( $self->_Handle->CaseSensitive ) {
        my %newhash;
        foreach my $key ( keys %hash ) {

            # If we've been passed an empty value, we can't do the lookup. 
            # We don't need to explicitly downcase integers or an id.
            if ( $key =~ '^id$'
                || !defined( $hash{$key} )
                || $hash{$key} =~ /^\d+$/
                 )
            {
                $newhash{$key} = $hash{$key};
            }
            else {
                my ($op, $val);
                ($key, $op, $val) = $self->_Handle->_MakeClauseCaseInsensitive($key, '=', $hash{$key});
                $newhash{$key}->{operator} = $op;
                $newhash{$key}->{value} = $val;
            }
        }

        # We've clobbered everything we care about. bash the old hash
        # and replace it with the new hash
        %hash = %newhash;
    }
    $self->SUPER::LoadByCols(%hash);
}

# }}}

# {{{ Datehandling

# There is room for optimizations in most of those subs:

# {{{ LastUpdatedObj

sub LastUpdatedObj {
    my $self = shift;
    my $obj  = new RT::Date( $self->CurrentUser );

    $obj->Set( Format => 'sql', Value => $self->LastUpdated );
    return $obj;
}

# }}}

# {{{ CreatedObj

sub CreatedObj {
    my $self = shift;
    my $obj  = new RT::Date( $self->CurrentUser );

    $obj->Set( Format => 'sql', Value => $self->Created );

    return $obj;
}

# }}}

# {{{ AgeAsString
#
# TODO: This should be deprecated
#
sub AgeAsString {
    my $self = shift;
    return ( $self->CreatedObj->AgeAsString() );
}

# }}}

# {{{ LastUpdatedAsString

# TODO this should be deprecated

sub LastUpdatedAsString {
    my $self = shift;
    if ( $self->LastUpdated ) {
        return ( $self->LastUpdatedObj->AsString() );

    }
    else {
        return "never";
    }
}

# }}}

# {{{ CreatedAsString
#
# TODO This should be deprecated 
#
sub CreatedAsString {
    my $self = shift;
    return ( $self->CreatedObj->AsString() );
}

# }}}

# {{{ LongSinceUpdateAsString
#
# TODO This should be deprecated
#
sub LongSinceUpdateAsString {
    my $self = shift;
    if ( $self->LastUpdated ) {

        return ( $self->LastUpdatedObj->AgeAsString() );

    }
    else {
        return "never";
    }
}

# }}}

# }}} Datehandling

# {{{ sub _Set 
sub _Set {
    my $self = shift;

    my %args = (
        Field => undef,
        Value => undef,
        IsSQL => undef,
        @_
    );

    #if the user is trying to modify the record
    # TODO: document _why_ this code is here

    if ( ( !defined( $args{'Field'} ) ) || ( !defined( $args{'Value'} ) ) ) {
        $args{'Value'} = 0;
    }

    $self->_SetLastUpdated();
    my ( $val, $msg ) = $self->SUPER::_Set(
        Field => $args{'Field'},
        Value => $args{'Value'},
        IsSQL => $args{'IsSQL'}
    );
}

# }}}

# {{{ sub _SetLastUpdated

=head2 _SetLastUpdated

This routine updates the LastUpdated and LastUpdatedBy columns of the row in question
It takes no options. Arguably, this is a bug

=cut

sub _SetLastUpdated {
    my $self = shift;
    use RT::Date;
    my $now = new RT::Date( $self->CurrentUser );
    $now->SetToNow();

    if ( $self->_Accessible( 'LastUpdated', 'auto' ) ) {
        my ( $msg, $val ) = $self->__Set(
            Field => 'LastUpdated',
            Value => $now->ISO
        );
    }
    if ( $self->_Accessible( 'LastUpdatedBy', 'auto' ) ) {
        my ( $msg, $val ) = $self->__Set(
            Field => 'LastUpdatedBy',
            Value => $self->CurrentUser->id
        );
    }
}

# }}}

# {{{ sub CreatorObj 

=head2 CreatorObj

Returns an RT::User object with the RT account of the creator of this row

=cut

sub CreatorObj {
    my $self = shift;
    unless ( exists $self->{'CreatorObj'} ) {

        $self->{'CreatorObj'} = RT::User->new( $self->CurrentUser );
        $self->{'CreatorObj'}->Load( $self->Creator );
    }
    return ( $self->{'CreatorObj'} );
}

# }}}

# {{{ sub LastUpdatedByObj

=head2 LastUpdatedByObj

  Returns an RT::User object of the last user to touch this object

=cut

sub LastUpdatedByObj {
    my $self = shift;
    unless ( exists $self->{LastUpdatedByObj} ) {
        $self->{'LastUpdatedByObj'} = RT::User->new( $self->CurrentUser );
        $self->{'LastUpdatedByObj'}->Load( $self->LastUpdatedBy );
    }
    return $self->{'LastUpdatedByObj'};
}

# }}}


require Encode::compat if $] < 5.007001;
require Encode;

sub __Value {
    my $self  = shift;
    my $field = shift;
    my %args = ( decode_utf8 => 1,
                 @_ );

    unless (defined $field && $field) {
        $RT::Logger->error("$self __Value called with undef field");
    }
    my $value = $self->SUPER::__Value($field);

    return('') if ( !defined($value) || $value eq '');

    return Encode::decode_utf8($value) || $value if $args{'decode_utf8'};
    return $value;
}

# Set up defaults for DBIx::SearchBuilder::Record::Cachable

sub _CacheConfig {
  {
     'cache_p'        => 1,
     'fast_update_p'  => 1,
     'cache_for_sec'  => 30,
  }
}

=head2 _DecodeUTF8

 When passed a string will "decode" it int a proper UTF-8 string

=cut

eval "require RT::Record_Vendor";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Record_Vendor.pm});
eval "require RT::Record_Local";
die $@ if ($@ && $@ !~ qr{^Can't locate RT/Record_Local.pm});

1;
