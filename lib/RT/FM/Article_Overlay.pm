# BEGIN LICENSE BLOCK
# 
#  Copyright (c) 2002 Jesse Vincent <jesse@bestpractical.com>
#  
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of version 2 of the GNU General Public License 
#  as published by the Free Software Foundation.
# 
#  A copy of that license should have arrived with this
#  software, but in any event can be snarfed from www.gnu.org.
# 
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
# 
# END LICENSE BLOCK

no warnings qw/redefine/;

use RT::FM::Content;

# {{{ Create


=item Create PARAMHASH

Create takes a hash of values and creates a row in the database:

  int(11) 'id'.
  varchar(200) 'Name'.
  varchar(200) 'Summary'.
  int(11) 'Content'.
  int(11) 'Parent'.
  int(11) 'SortOrder'.
  int(11) 'CreatedBy'.
  datetime 'Created'.
  int(11) 'UpdatedBy'.
  datetime 'Updated'.


=begin testing

use_ok(RT::FM::Article);
my $user = RT::CurrentUser->new('root');
my $article = RT::FM::Article->new($user);
ok (UNIVERSAL::isa($article, 'RT::FM::Article'));
ok (UNIVERSAL::isa($article, 'RT::FM::Record'));
ok (UNIVERSAL::isa($article, 'RT::Record'));
ok (UNIVERSAL::isa($article, 'DBIx::SearchBuilder::Record'));

ok($article->Create( Summary => "Test", Content => "This is content"));
my $id = $article->Id;
is ($article->Summary, 'Test');

my $at = RT::FM::Article->new($RT::SystemUser);
$at->Load($id);
is ($at->id , $id);
is ($at->Summary, $article->Summary);


=end testing


=cut




sub Create {
    my $self = shift;
    my %args = ( 
                id => undef,
                Name => undef,
                Summary => undef,
                Content => undef,
		Parent => 0,
                SortOrder => undef,
                CreatedBy => undef,
                Created => undef,
                UpdatedBy => undef,
                Updated => undef,
,
		  @_);

    # TODO, check for actual parent object and make sure
    # we're not creating some sort of circular incestuous 
    # relationship

    my $ContentObj = new RT::FM::Content($self->CurrentUser);
    my ($value) = $ContentObj->Create ( Subject => $args{'Summary'},
					ContentType => 'application/x-rtfm-content',
					Body => $args{'Content'} );
    unless ($value) {
	return (0, "Couldn't create new Content blob");
    }

    $self->SUPER::Create(
                         id => $args{'id'},
                         Name => $args{'Name'},
                         Summary => $args{'Summary'},
                         Content => $value,
                         Parent => $args{'Parent'},
                         SortOrder => $args{'SortOrder'},
                         CreatedBy => $args{'CreatedBy'},
                         Created => $args{'Created'},
                         UpdatedBy => $args{'UpdatedBy'},
                         Updated => $args{'Updated'},
			);

}

# }}}

=item SetContent VALUE

Set Content to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Content will be stored as a int(11).)

=cut

sub SetContent {
    my $self = shift;
    my $new_value = shift;
    my $content = new RT::FM::Content($self->CurrentUser);
    my ($value) = $content->Create ( Subject => $self->Summary(),
				     ContentType => 'application/x-rtfm-content',
				     Body => $new_value );
    unless ($value) {
	return (0, "Couldn't create new Content blob");
    }
    
    
    $self->SUPER::SetContent($value);
}	

    


# }}}

# {{{ Parent

=item Parent

Returns the current value of Parent. 
(In the database, Parent is stored as int(11).)


=item SetParent VALUE

Set Parent to VALUE. 
Returns (1, 'Status message') on success and (0, 'Error Message') on failure.
(In the database, Parent will be stored as a int(11).)

=cut


=item ParentObj

Returns the Parent Object which has the id returned by Parent


=cut

sub ParentObj {
	my $self = shift;
	my $Parent = new RT::FM::Article($self->CurrentUser);
	$Parent->Load($self->Parent());
	return($Parent);
}

# }}}

# {{{ Children

=item Children

Returns an RT::FM::ArticleCollection object which contains
all articles which have this article as their parent.  This 
routine will not recurse and will not find grandchildren, great-grandchildren, uncles, aunts, nephews or any other such thing.  

=cut

sub Children {
    my $self = shift;
    my $kids = new RT::FM::ArticleCollection($self->CurrentUser);
    $kids->LimitToParent($self->Id);
    return($kids);
}

# }}}

# {{{ sub CustomFieldValues

=item CustomFieldValues CUSTOMFIELDID

Returns an RT::FM::CustomFieldObjectValueCollection object containing
the values of CustomField CUSTOMFIELDID for this Article


=cut

sub CustomFieldValues {
    my $self = shift;
    my $customfield = shift;
    
    my $cfovc = new RT::FM::CustomFieldObjectValueCollection($self->CurrentUser);
    $cfovc->LimitToArticle($self->Id);
    $cfovc->LimitToCustomField($customfield);
    return ($cfovc);
}

# }}}

sub AddCustomFieldValue {
    my $self = shift;
    my %args = ( CustomField => undef,  # id of a customfield record
		 Value => undef, #id of the keyword to add
		 @_
	       );
    
    my ($OldValue, $Value, $PrintableValue);

    my $CustomFieldObj = new RT::FM::CustomField($self->CurrentUser);
    $CustomFieldObj->Load($args{'CustomField'});
   
    my $CurrentValuesObj = $self->CustomFieldValues($CustomFieldObj->id);
    
    unless ($CustomFieldObj->Id()) {
	return(0, "Couldn't load custom field ". $args{'CustomField'});
    }
    
    if ($CustomFieldObj->Type =~ /^Select/) {
	my $ValueObj =  $CustomFieldObj->ValuesObj->HasEntry($args{'Value'}); 
	unless ($ValueObj) {
	    return(0, "Couldn't find value ". $args{'Value'} ." for the field ".
		   $CustomFieldObj->Name );
	}
   

	$Value = $ValueObj->id;
	$PrintableValue = $ValueObj->Name;
 

    }
    # if we're not restricting possible values to a set
    else {
	$Value = $args{'Value'};
	$PrintableValue = $Value;
    }	
    

    #If the ticket already has this custom field value, just get out of here.
    if (grep {$_->Content eq $Value }  	@{$CurrentValuesObj->ItemsArrayRef} ) {
		return(0, "That is already the current value");
    }	
    


    #If the keywordselect wants this to be a singleton:

    if ($CustomFieldObj->Type =~ /Single$/) {

	#Whack any old values...keep track of the last value that we get.
	#we shouldn't need a loop ehre, but we do it anyway, to try to 
	# help keep the database clean.
	while (my $OldKey = $CurrentValuesObj->Next) {
	    $OldValue = $OldKey->CustomFieldValueObj->Name;
	    $OldKey->Delete();
	}	
	
	
    }

    # create the new objectkeyword 
    my $ObjectValue = new RT::FM::CustomFieldObjectValue($self->CurrentUser);
    my $result = $ObjectValue->Create( Content => $Value,
				       Article => $self->Id,
				       CustomField => $CustomFieldObj->Id );
    
    
    return (1, "Custom value $PrintableValue added to ". $CustomFieldObj->Name . " for article ".$self->Id);

}	

=item DeleteCustomFieldValue
  
  Takes a paramhash. Deletes the Keyword denoted by the I<Keyword> parameter from this
  ticket's object keywords.

=cut

sub DeleteCustomFieldValue {
    my $self = shift;
    my %args = ( Value => undef,
		 CustomField => undef,
		 @_ );

    #Load up the ObjectKeyword we\'re talking about
    my $CFObjectValue = new RT::FM::CustomFieldObjectValue($self->CurrentUser);
    $CFObjectValue->LoadByCols( Content  => $args{'Value'},
			        CustomField => $args{'CustomField'},
			        Article => $self->id()
			      );
    
    #if we can\'t find it, bail
    unless ($CFObjectValue->id) {
	return (undef, "Couldn't load custom field valuewhile trying to delete it.");
    };
    
    #record transaction here.
   
    $CFObjectValue->Delete();
    
    return (1, "Value ".$CFObjectValue-Name ." deleted from custom field ".$CustomField.".");
    
}


1;
