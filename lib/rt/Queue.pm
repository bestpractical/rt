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

sub Create {
  my $self = shift;
  return($self->create(@_));
}


sub Load {
  my $self = shift;
  my $queue_id = shift;
  $self->SUPER::load_by_col("QueueId", $queue_id);
}

sub load {
  my $self = shift;
  return($self->Load(@_);)
}

sub CorrespondAddress {
  my $self = shift;
  $self->_set_and_return('CorrespondAddress',@_);
}

sub QueueId {
  my $self = shift;
  $self->_set_and_return('QueueId');
  
}

sub id {
  my $self = shift;
  return($self->id);
}
sub CommentAddress {
  my $self = shift;
  $self->_set_and_return('CommentAddress',@_);
}



sub StartingPriority {
  my $self = shift;
  $self->_set_and_return('StartingPriority',@_);
}
sub FinalPriority {
  my $self = shift;
  $self->_set_and_return('FinalPriority',@_);
}

sub PermitNonmemberCreate {
  my $self = shift;
  $self->_set_and_return('PermitNonmemberCreate',@_);
}



sub MailOwnerOnTransaction {
  my $self = shift;
  $self->_set_and_return('MailOwnerOnTransaction',@_);
}

sub MailMembersOnTransaction {
  my $self = shift;
  $self->_set_and_return('MailMembersOnTransaction',@_);
}

sub MailRequestorOnTransaction {
  my $self = shift;
  $self->_set_and_return('MailRequestorOnTransaction',@_);
}
sub MailRequestorOnCreation {
  my $self = shift;
  $self->_set_and_return('MailRequestorOnCreation',@_);
}

sub MailMembersOnCorrespondence {
  my $self = shift;
  $self->_set_and_return('MailMembersOnCorrespondence',@_);
}

sub MailMembersOnComment {
  my $self = shift;
  $self->_set_and_return('MailMembersOnComment',@_);
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


