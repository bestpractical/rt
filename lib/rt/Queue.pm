package RT::Queue;
@ISA= qw(RT::Record);

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
#  print STDERR "MKIA::Article::create::",join(", ",@_),"\n";
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



sub Load {
  my $self = shift;
  my $queue_id = shift;
  $self->SUPER::load($queue_id);
}

sub load {
  my $self = shift;
  return($self->Load(@_);)
}

sub CorrespondAddress {
  my $self = shift;
  $self->_set_and_return('created',@_);
}


sub id {
  my $self = shift;
  return($self->id);
}
sub CommentAddress {
  my $self = shift;
  $self->_set_and_return('effective_sn',@_);
}



sub StartingPriority {
  my $self = shift;
  $self->_set_and_return('area',@_);
}
sub FinalPriority {
  my $self = shift;
  $self->_set_and_return('alias',@_);
}

sub PermitNonmemberCreate {
  my $self = shift;
  $self->_set_and_return('requestors',@_);
}



sub MailOwnerOnTransaction {
  my $self = shift;
  $self->_set_and_return('subject',@_);
}

sub MailMembersOnTransaction {
  my $self = shift;
  $self->_set_and_return('subject',@_);
}

sub MailRequestorOnTransaction {
  my $self = shift;
  $self->_set_and_return('subject',@_);
}


sub MailMembersOnCorrespondence {
  my $self = shift;
  $self->_set_and_return('subject',@_);
}

sub MailMembersOnComment {
  my $self = shift;
  $self->_set_and_return('subject',@_);
}



sub Display_Permitted {
  my $self = shift;
  my $actor = shift || my $actor = $self->{'user'};
  return(1);
  #if it's not permitted,
  return(0);

}
sub Modify_Permitted {
  my $self = shift;
 my $actor = shift || my $actor = $self->{'user'};
  return(1);
  #if it's not permitted,
  return(0);

}

1;


