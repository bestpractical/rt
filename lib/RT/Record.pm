package RT::Record;
@ISA= qw(DBIx::Record);

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->{'table'} = "each_req";
  $self->{'user'} = shift;
  return $self;
}


sub create {
  my $self = shift;
  my $id = $self->SUPER::create(@_);
  $self->load_by_reference($id);

  #TODO: this is horrificially wasteful. we shouldn't commit 
  # to the db and then instantly turn around and load the same data

#sub create is handled by the baseclass. we should be calling it like this:
#$id = $article->create( title => "This is a a title",
#		  mimetype => "text/plain",
#		  author => "jesse@arepa.com",
#		  summary => "this article explains how to from a widget",
#		  content => "lots and lots of content goes here. it doesn't 
#                              need to be preqoted");
# TODO: created is not autoset
}


sub _set_and_return {
  my $self = shift;
  my $field = shift;
  #if the user is trying to display only {
  if (@_ == undef) {
    
    if ($self->Display_Permitted) {
      #if the user doesn't have display permission, return an error
      $self->SUPER::_set_and_return($field);
    }
    else {
      return(0, "Permission Denied");
    }
  }
  #if the user is trying to modify the record
  else {
    if ($self->Modify_Permitted) {
      #instantiate a transaction 
      #record what's being done in the transaction
 
      #Figure out where to send mail
      
      $self->_update_date_acted;

      $self->SUPER::_set_and_return($field, @_);
    }
    else {
      return (0, "Permission Denied");
    }
  }
  
}

    

1;


