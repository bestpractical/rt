package rt::ui::cli;

sub question_string {
    local ($question,$default)=@_;
    local ($response);
    if ($default) {
	print "$question \[$default\]: ";
    }
    else {
	print "$question: ";
    }
  $response=&input_string($default);
    return($response);
}
sub question_yes_no {
    local ($question,$default)=@_;
    local ($response);
    if ($default) {    
	if ($default eq "1") {
	    $default='Y';
	}
	else {
	    $default='N';
	}
	
	print "$question \[$default\]: ";
    }
    else {
	print "$question [N]: ";
    }    $response=&input_yes_no($default);
    return($response);
}
sub question_int {
    local ($question,$default)=@_;
    local ($response);
    if ($default) {
	print "$question \[$default\]: ";
    }
    else {
	print "$question: ";
    }    $response=&input_int($default||0);
    return($response);
}


sub input_yes_no {
    local ($default) =@_;
    local ($input);
    chop($input=<STDIN>);
    if (!$input) {
	$input=$default;
    }
    if ($input =~ /^(y|Y|1|t)/) {
	return(1);
    }
    else {
	return(0);
    }
}

sub input_string {
    local ($default) =@_;
    local ($input);
 
    chop($input=<STDIN>||"");
 
    if (!$input) {
	$input=$default||"";
 
    }
    return($input);
}

sub input_int {
    local ($default) =@_;
    local ($input);
    
    chop($input=<STDIN>||""); 
    return $input eq "" ? ($default||undef) : int($input);
}

1;
