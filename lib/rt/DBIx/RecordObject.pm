package DBIx::RecordObject;
require RT::Database;
{
#instantiate a new record object.
    sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self  = {};
	bless ($self, $class);
	return $self;
    }

    sub _set_and_return {
	my $self =shift;
	my $field = shift;
	my ($value, $error_condition);

	if (@_) {
	    $value = shift;
	    if ($value ne $self->{'values'}->{"$field"}) {
	      #TODO: Update value in db
	      $error_condition = MKIA::Database::UpdateTableValue($self->{'table'}, $field,$value,$self->id);
      $self->{'values'}->{"$field"} = $value;
	    }
	}
	return($self->{'values'}->{"$field"});
    }


# Functions which return data
    sub Id {
	my $self = shift;
	return ($self->{'values'}->{'id'});
    }
    sub id {
	my $self = shift;
	return ($self->Id);
    }


# load should do a bit of overloading
# if we call it with only one argument, we're trying to load by reference.
# if we call it with a passel of arguments, we're trying to load by value
# The latter is primarily important when we've got a whole set of record that we're
# reading in with a recordset class and want to instantiate objefcts for each record.

    sub load {
	my $self = shift;
#	if (#@_ > 2) {
#	    $self->load_by_value(@_);
#	}
#	else {
	    $self->load_by_reference(@_);
#	}
    }

# TODO
# load by value is intended to be called when it's loading a 
# bunch of attestations. it takes a hash of the values of the record and
# instantiates the object from that. 

    sub load_by_value {
	my $self = shift;
	die ("Method not implemented");
    }

# load by reference is intended for loading a single record. slower, but 
# self contained

    sub load_by_reference {
	my $self = shift;
	my $id = shift;

	my ($QueryString, $hash, $sth);
	$QueryString = "SELECT  * FROM ".$self->{'table'}." WHERE id = $id";
	print STDERR "MKIA::Database::Record->load_by_reference $QueryString\n";
	$sth = $MKIA::Database::dbh->prepare($QueryString);
	

	if (!$sth) {
	    die "Error:" . $MKIA::Database::dbh->errstr . "\n";
	}
	if (!$sth->execute) {
	    die "Error:" . $sth->errstr . "\n";
	}
	#TODO this only gets the first row. we should check to see if there are more.
	$self->{'values'} = $sth->fetchrow_hashref;
	$self->{'values'}->{'id'} = $id;
	

    }

    sub create {

#       print STDERR "MKIA::Database::Record::create entered\n";
	my $self = shift;
	my @keyvalpairs = (@_);

	my ($QueryString, $value, $key, $cols, $vals);

       while ($key = shift @keyvalpairs) {
	 $value = shift @keyvalpairs;
	 #print STDERR "key: $key - val: $value\n";
	 $cols .= $key . ", ";
	 $vals .= &MKIA::Database::safe_quote($value).", ";
	 #	    $vals .= &MKIA::Database::safe_quote($keyvalpairs{"$key"}) . ", ";
	 
       }	
       

       $cols =~ s/, $//;
       $vals =~ s/, $//;
       #TODO Check to make sure the key's not already listed.
       #TODO update internal data structure
       $QueryString = "INSERT INTO ".$self->{'table'}." ($cols) VALUES ($vals)";
	#print STDERR "\nMKIA::Database::Record->Create Query: $QueryString\n\n";

       my $sth = $MKIA::Database::dbh->prepare($QueryString);
	if (!$sth) {

	    if ($main::debug) {
		die "Error:" . $MKIA::Database::dbh->errstr . "\n";
	    }
	    else {
		return (0);

	    }
	}
	if (!$sth->execute) {
	    if ($main::debug) {
		die "Error:" . $sth->errstr . "\n";
	    }
	    else {
		return(0);
	    }

	}

	$self->{'id'}=$sth->{'insertid'};

	return( $sth->{'insertid'}); #Add Succeded. return the id
    }


#This routine removes a relationship
    sub delete {
	my $self = shift;

	my $QueryString;

	#TODO Check to make sure the key's not already listed.
	#TODO Update internal data structure
	$QueryString = "DELETE FROM ".$self->{'table'} . " WHERE id  = ". $self->id();
	my $sth = $MKIA::Database::dbh->prepare($QueryString);
	if (!$sth) {
	    if ($main::debug) {
		die "Error:" . $MKIA::Database::dbh->errstr . "\n";
	    }
	    else {
		return (0);
	    }
	}
	if (!$sth->execute) {
	    if ($main::debug) {
		die "Error:" . $sth->errstr . "\n";
	    }
	    else {
		return(0);
	    }

	}

	return (1);		#Update Succeded
    }

}

1;
