package rt;
use Mysql;

&connectdb;




require RT_ReadConf;

&rt::load_user_info();
&rt::load_queue_conf();
&rt::load_queue_acls();
&rt::load_queue_areas();

sub connectdb {
   if (!($dbh = Mysql->Connect($host, $dbname, $rtpass, $rtuser,))){
           die "not ok 1: $Mysql::db_errstr\n";
         }
  }

sub selectdb {

    if (!($dbh->SelectDB("$rt::dbname"))){
	die "[selectdb] not ok: $Msql::db_errstr
Please make sure that a database \"$rt::dbname\" exists
and that user $rtuser has access to it.
 
";

    }
}

# scrub will make strings safe to submit to an mySQL database
# it replaces ' with \' and \ with \\
# it also encases the string in  single quotes
sub scrub {
        local($^W) = 0; #YEAH, i know I shouldn't turn off error checking. so sue me
	local ($str) = @_;
    $str =~ s/\\/\\\\/g;
    $str =~ s/\'/\\\'/g;
    $str = "\'$str\'";
    return ($str);
}

1;
