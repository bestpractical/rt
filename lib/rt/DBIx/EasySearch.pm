# Copyright 1999 Jesse Vincent <jesse@fsck.com>
# Released under the terms of the GNU Public License 
# $Id$ 
#
# This code is not used yet.

package DBIx::EasySearch;

#instantiate a new object.
sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->{'must_redo_search'}=1;
  #we have no limit statements. DoSearch won't work.
  $self->isLimited(0);
  return ($self)
}

#todo $self->item should point to our current fact.

sub Count {
  my $self = shift;
  
  if ($self->{'must_redo_search'}) {
    return ($self->_DoSearch);
  }
  else {
    return($self->{'rows'});
  }
}

sub _DoSearch {
  my $self = shift;
  my ($QueryString, $OrderClause);

  #compile all the standard restrictions
  $self->_CompileRestrictions();
  #compile the order by and order 
  if ($self->{'orderby'}) {
    $OrderClause = "ORDER BY ". $self->{'orderby'};
  }
  else {
    $OrderClause = "ORDER BY main.id ";
    
  }
  
  if ($self->{'order'} =~ /^des/) {
    $OrderClause .= " DESC";
  }
  else {
    $OrderClause .= " ASC";
    
  }


  
  $QueryString = "SELECT distinct main.id FROM ".$self->{'table'}." AS main". $self->{'auxillary_tables'}." WHERE ".$self->{'where_clause'}." ".$self->{'table_links'}." ".$self->{'limit_clause'} . " ". $OrderClause;
  
  #print STDERR "MKIA::Database::RecordSet->DoSearch Query:  $QueryString\n\n(End Query) ";
  
  
  $self->{'records'} = $MKIA::Database::dbh->prepare($QueryString);
  
  
  if (!$self->{'records'}) {
    die "Error:" . $dbh->errstr . "\n";
  }
  if (!$self->{'records'}->execute) {
    die "facts->DoSearch error:" . $self->{'records'}->errstr . "\n\tQuery String is $QueryString";
  }
  
  
  $self->{'rows'} = $self->{'records'}->rows();

 # print STDERR "found ". $self->{'rows'}." rows\n";
  
  
  $self->{'must_redo_search'}=0;
  return($self->{'rows'});
  
  
}


sub Next {
  my $self = shift;
  
  my @row;
  my $ObjectType = $self->{'table'};

  if (!$self->isLimited) {
    return(0);
  }
  if ($self->{'must_redo_search'} != 0) {
    #print STDERR "RecordSet->Next: Redoing search\n";
    $self->_DoSearch();
  }
  
  if (( @row = $self->{'records'}->fetchrow_array() ) and ($row[0])) {
    
    # TODO: what we want to do is instantiate a new object for the item of the apropriate type.
    # we know what sort of table we're working with because we needed it to instantiate the RecordSet
    
    $self->{'item'} = $self->NewItem;                  ;
    $self->{'item'}->load($row[0]);
    
    return ($self->{'item'});
  }
  else {
    #we've gone through the whole list.
    # TODO do we want to toggle "must-redo-search"?
    return(0);
    
  }
  
}




sub NewItem {
my $self = shift;
$foo = (caller(1))[3];                                                        
#print STDERR "calling subroutine is $foo\n"; 
die "Database::RecordSet needs to be subclassed. you can't use it directly.\n";
}

sub isLimited {
  my $self = shift;
  if (@_) {
    $self->{'is_limited'} = shift;
  }
  else {
    return ($self->{'is_limited'});
  }
}

#####
#####Process LIMIT Statements 
#####This is where we do our magic
#####
sub Limit {
  my $self = shift;
  my %args = (
	      TABLE => $self->{'table'},
	      FIELD => undef,
	      VALUE => undef,
	      ALIAS => undef,
	      TYPE => undef, 
	      ENTRYAGGREGATOR => 'or',
	      INT_LINKFIELD => $self->{'primary_key'},
	      EXT_LINKFIELD => 'id',
	      OPERATOR => '=',
	      OFFSET => 0,
	      ORDERBY => undef,
	      ORDER => undef,
	      ROWS => undef,
	      @_ # get the real argumentlist
	     );
  
  my ($Alias);
  

  $self->isLimited(1);
 
  #Do we want "ASC"ending order or "DESC"ending order
  if ($args{'ORDER'}) {
    $self->{'order'} = $args{'ORDER'};
  }
  #print STDERR "in RecordSet->Limit: Field is $args{'FIELD'}\n";

  if ($args{'FIELD'}) {
    if ($args{'OPERATOR'} eq "LIKE") {
      $args{'VALUE'} = "%".$args{'VALUE'} ."%";
    }
    $args{'VALUE'} = $MKIA::Database::dbh->quote($args{'VALUE'});
  }
  
  $Alias = $self->_GenericRestriction(%args);
  #print STDERR "Alias is $Alias\n";
  
#                                        TABLE => "$args{'TABLE'}",
#					FIELD => "$args{'FIELD'}",
#					ENTRYAGGREGATOR => "$args{'ENTRYAGGREGATOR'}",
#					OPERATOR => "$args{'OPERATOR'}",
#					ALIAS => "$args{'ALIAS'}",

#					VALUE => "$args{'VALUE'}"); 
    
    

  
  
  # Set the limit clause. used for restricting ourselves to subsets of the search.
  if ( $args{'ROWS'}) {
      $self->{'limit_clause'} = "LIMIT ";
      if ($args{'OFFSET'} != 0) {
	  $self->{'limit_clause'} .= $args{'OFFSET'} . ", ";
      }
    $self->{'limit_clause'} .= $args{'ROWS'};
  }
  
  #If we're setting an OrderBy, set it here
  # TODO: this may be broken. it needs to divine the right Column alias
  # it tries to be smart. here are the steps:
  # 1. if an alias was passed in, use that. 
  # 2. if an alias was generated, use that.
  # 3. use the primary
  if ($args{'ORDERBY'}) {
     if ($args{'ALIAS'}) {
       $self->{'orderby'} = $args{'ALIAS'}.".".$args{'ORDERBY'};
     }
     elsif ($Alias) {
       $self->{'orderby'} = "$Alias.".$args{'ORDERBY'};
     }
     else {
       $self->{'orderby'} = "main.".$args{'ORDERBY'};
     }
   }
  
  
  if ($Alias) {
      #ok. now we're limited. people can do searches.

    return($Alias);
  }
  else {
    return(0);
  }
}

  
#Show Restrictions
sub ShowRestrictions {
   my $self = shift;
  $self->_CompileRestrictions();
  return($self->{'where_clause'});
  
}


#import a restrictions clause

sub ImportRestrictions {
  my $self = shift;
  $self->{'where_clause'} = shift;
}



sub _GenericRestriction {
  my $self = shift;
  ;my %args = (
	      TABLE => $self->{'table'},
	      FIELD => undef,
	      VALUE => undef,   #TODO: $Value should take an array of values and generate the proper where clause.
	      ALIAS => undef,	     
	      ENTRYAGGREGATOR => undef,
	      OPERATOR => '=',
	       INT_LINKFIELD => undef,
	       EXT_LINKFIELD => undef,
	      @_);
    my ($QualifiedField);
  
  #since we're changing the search criteria, we need to redo the search
  $self->{'must_redo_search'}=1;
  

#if the operator is a like, we need to add %s on ether side of the VALUE

  # if there's no alias set, we need to set it
  if (!$args{'ALIAS'}) {
    
    #if the table we're looking at is the same as the main table
    if ($args{'TABLE'} eq $self->{'table'}) {
      
      # main is the alias of the "primary table. this code assumes no self 
      # joins on that table. if someone can name   case where we'd want to do that, I'll change it.
      
      $args{'ALIAS'} = 'main';
    }
    
    # if we're joining, we need to work out the table alias
    else {
      $self->{'aliascount'}++;
      $args{'ALIAS'} = $args{'TABLE'}."_".$self->{'aliascount'};
      $self->{'auxillary_tables'} .= ",".$args{'TABLE'}." as $args{'ALIAS'}";
      
      #      if ($self->{'table_links'} ne undef) {
      
      # do this every time. we need the initial and as well as any joining ands
      $self->{'table_links'} .= ' AND ';
      
      #      }
      #     else {
      #supress a warning
      #	$self->{'table_links'} = "";
      #      }
      
      # we need to build the table of links.
      $self->{'table_links'} .= " main.". $args{'INT_LINKFIELD'}."=".$args{'ALIAS'}.".".$args{'EXT_LINKFIELD'};
      
      
    }
  }
  #If we were just setting an alias, return
  #TODO: all code above this point should be seperate
  if (!$args{'FIELD'}) {
    return ($args{'ALIAS'});
    
  }
  
  #Set this to the name of the field and the alias.
  $QualifiedField = $args{'ALIAS'}.".".$args{'FIELD'};
 # print STDERR "Database::RecordSet->_GenericRestriction  QualifiedField is $QualifiedField\n";:
  
  #If we're overwriting this sort of restriction, 
  if (($args{'ENTRYAGGREGATOR'} eq 'none') or 
      (!$self->{'restrictions'}{"$QualifiedField"})) {
    $self->{'restrictions'}{"$QualifiedField"} = 
      "($QualifiedField $args{'OPERATOR'} $args{'VALUE'})";  
  #  print STDERR "self->{'restrictions'}{$QualifiedField} cmpval is ($QualifiedField $args{'OPERATOR'} $args{'VALUE'})";  

  }
  else {
    $self->{'restrictions'}{"$QualifiedField"} .= 
      " $args{'ENTRYAGGREGATOR'} ($QualifiedField $args{'OPERATOR'} $args{'VALUE'})";
   # print STDERR "self->{'restrictions'}{$QualifiedField} cmpval is added to by: ($QualifiedField $args{'OPERATOR'} $args{'VALUE'})"; 
  }

 return ($ARG{'ALIAS'});
 
}
  
#Compile the restrictions to a WHERE Clause


sub _CompileRestrictions {
  my $self = shift;
  my ($restriction, $RelType);
  
  $self->{'where_clause'} = "";
  
  foreach $restriction (keys %{ $self->{'restrictions'}}) {
    
    if ($self->{'where_clause'} ne '') {
      $self->{'where_clause'} .= " AND ";
      }
    $self->{'where_clause'} .= "" . $self->{'restrictions'}{"$restriction"} . "";
  }
  
}




1;
