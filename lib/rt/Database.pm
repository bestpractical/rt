# Copyright 1999 Jesse Vincent <jesse@fsck.com>
# Released under the terms of the GNU Public License 
# $Id$ 
#
# This code is not used yet.

package RT::Database;

use DBI;

sub Connect {
  my $Database = shift;
  my $User = shift;
  my $Password = shift;

  my $Driver = "mysql";
  $dsn = "dbi:$Driver:$Database:$Host";
  
  $dbh = DBI->connect($dsn, $User, $Password) || 
	print STDERR "Connect Failed $DBI::errstr\n" ;
}


sub UpdateTableValue {

  my $Table = shift;
  my $Col = shift;
  my $NewValue = shift;
  my $Record = shift;
  my $QueryString;
  
  # quote the value
  $NewValue=&MKIA::Database::safe_quote($NewValue);
  # build the query string
  $QueryString = "UPDATE $Table SET $Col = $NewValue WHERE id = $Record";

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
  
  return (1); #Update Succeded
}

sub safe_quote {
  my $in_val = shift;
  my ($out_val);
  if (!$in_val) {
    return ("''");
    
  }
  else {
    $out_val = $RT::Database::dbh->quote($in_val);
  }
  return("$out_val");
  
}
1;
