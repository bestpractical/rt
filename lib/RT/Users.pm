# $Header$
# (c) 1996-1999 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL

package RT::Users;
use RT::EasySearch;
@ISA= qw(RT::EasySearch);


# {{{ sub new 
sub new  {
  my $pkg= shift;
  my $self = SUPER::new $pkg;
  
  $self->{'table'} = "Users";
  $self->{'primary_key'} = "id";
  return($self);
}
# }}}

# {{{ sub Limit 
# Why do we need this?  I thought "AND" was default, anyway?
sub Limit  {
  my $self = shift;
my %args = ( ENTRYAGGREGATOR => 'AND',
             @_);

  $self->SUPER::Limit(%args);
}
# }}}

# {{{ sub NewItem 
# What is this?
sub NewItem  {
  my $self = shift;
  my $Handle = shift;
  my $item;
  $item = new RT::User($self->{'user'});
  return($item);
}
# }}}

sub LimitToEmail {
    my $self=shift;
    $self->Limit(FIELD=>'EmailAddress', VALUE=>shift);
}

  1;

