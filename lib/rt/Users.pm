# $Header$
# (c) 1996-1999 Jesse Vincent <jesse@fsck.com>
# This software is redistributable under the terms of the GNU GPL

package RT::Users;
@ISA= qw(DBIx::EasySearch);


sub new {
  my $pkg= shift;
  my $self = SUPER::new $pkg;
  
  $self->{'table'} = "users";
  $self->{'primary_key'} = "id";
  return($self);
}

sub Limit {
  my $self = shift;
my %args = ( ENTRYAGGREGATOR => 'AND',
             @_);

  $self->SUPER::Limit(%args);
}

sub NewItem {
  my $self = shift;
  my $item;
  $item = new RT::User($self->{'user'});
  return($item);
}
  1;

