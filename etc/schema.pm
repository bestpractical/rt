#   column, type, nullability, length, default, database-local

my $gratuitous = {

'Groups' => {
  'columns' => [
    'id', 'serial', '', '', '', '',
    'Name', 'varchar', 'NULL', '16', '', '',
    'Description', 'varchar', 'NULL', '64', '', '',
    'Pseudo', 'integer', '', '', '0', '',
  ],
  'primary_key' => 'id',
  'unique' => [ ['Name'] ],
  'index' => [  ],
},

'ACL' => {
  'columns' => [
    'id', 'serial', '', '', '', '',
    'PrincipalId', 'integer', 'NULL', '', '', '',
    'PrincipalType', 'varchar', 'NULL', '25', '', '',
    'RightName', 'varchar', 'NULL', '25', '', '',
    'RightScope', 'varchar', 'NULL', '25', '', '',
    'RightAppliesTo', 'integer', 'NULL', '', '', '',
  ],
  'primary_key' => 'id',
  'unique' => [  ],
  'index' => [ ['RightScope','RightAppliesTo','RightName','PrincipalType','PrincipalId'] ],
},

'Watchers' => {
  'columns' => [
    'id', 'serial', '', '', '', '',
    'Type', 'varchar', 'NULL', '16', '', '',
    'Scope', 'varchar', 'NULL', '16', '', '',
    'Value', 'integer', 'NULL', '', '', '',
    'Email', 'varchar', 'NULL', '255', '', '',
    'Quiet', 'integer', 'NULL', '', '', '',
    'Owner', 'integer', 'NULL', '', '', '',
    'Creator', 'integer', 'NULL', '', '', '',
    'Created', 'timestamp', 'NULL', '', '', '',
    'LastUpdatedBy', 'integer', 'NULL', '', '', '',
    'LastUpdated', 'timestamp', 'NULL', '', '', '',
  ],
  'primary_key' => 'id',
  'unique' => [  ],
  'index' => [ ['Scope','Value','Type','Owner'] ],
},

'Links' => {
  'columns' => [
    'id', 'serial', '', '', '', '',
    'Base', 'varchar', 'NULL', '240', '', '',
    'Target', 'varchar', 'NULL', '240', '', '',
    'Type', 'varchar', '', '20', '', '',
    'LocalTarget', 'integer', 'NULL', '', '', '',
    'LocalBase', 'integer', 'NULL', '', '', '',
    'LastUpdatedBy', 'integer', 'NULL', '', '', '',
    'LastUpdated', 'timestamp', 'NULL', '', '', '',
    'Creator', 'integer', 'NULL', '', '', '',
    'Created', 'timestamp', 'NULL', '', '', '',
  ],
  'primary_key' => 'id',
  'unique' => [ ['Base', 'Target', 'Type'] ],
  'index' => [  ],
},

'Users' => {
  'columns' => [
    'id', 'serial', '', '', '', '',
    'Name', 'varchar', '', '120', '', '',
    'Password', 'varchar', 'NULL', '40', '', '',
    'Comments', 'blob', 'NULL', '', '', '',
    'Signature', 'blob', 'NULL', '', '', '',
    'EmailAddress', 'varchar', 'NULL', '120', '', '',
    'FreeformContactInfo', 'blob', 'NULL', '', '', '',
    'Organization', 'varchar', 'NULL', '200', '', '',
    'Privileged', 'integer', 'NULL', '', '', '',
    'RealName', 'varchar', 'NULL', '120', '', '',
    'Nickname', 'varchar', 'NULL', '16', '', '',
    'Lang', 'varchar', 'NULL', '16', '', '',
    'EmailEncoding', 'varchar', 'NULL', '16', '', '',
    'WebEncoding', 'varchar', 'NULL', '16', '', '',
    'ExternalContactInfoId', 'varchar', 'NULL', '100', '', '',
    'ContactInfoSystem', 'varchar', 'NULL', '30', '', '',
    'ExternalAuthId', 'varchar', 'NULL', '100', '', '',
    'AuthSystem', 'varchar', 'NULL', '30', '', '',
    'Gecos', 'varchar', 'NULL', '16', '', '',
    'HomePhone', 'varchar', 'NULL', '30', '', '',
    'WorkPhone', 'varchar', 'NULL', '30', '', '',
    'MobilePhone', 'varchar', 'NULL', '30', '', '',
    'PagerPhone', 'varchar', 'NULL', '30', '', '',
    'Address1', 'varchar', 'NULL', '200', '', '',
    'Address2', 'varchar', 'NULL', '200', '', '',
    'City', 'varchar', 'NULL', '100', '', '',
    'State', 'varchar', 'NULL', '100', '', '',
    'Zip', 'varchar', 'NULL', '16', '', '',
    'Country', 'varchar', 'NULL', '50', '', '',
    'Creator', 'integer', 'NULL', '', '', '',
    'Created', 'timestamp', 'NULL', '', '', '',
    'LastUpdatedBy', 'integer', 'NULL', '', '', '',
    'LastUpdated', 'timestamp', 'NULL', '', '', '',
    'Disabled', 'int2', '','','0','',
  ],
  'primary_key' => 'id',
  'unique' => [ ['Name'] ],
  'index' => [ ['EmailAddress'] ],
},

'Tickets' => {
  'columns' => [
    'id', 'serial', '', '', '', '',
    'EffectiveId', 'integer', 'NULL', '', '', '',
    'Queue', 'integer', 'NULL', '', '', '',
    'Type', 'varchar', 'NULL', '16', '', '',
    'IssueStatement', 'integer', 'NULL', '', '', '',
    'Resolution', 'integer', 'NULL', '', '', '',
    'Owner', 'integer', 'NULL', '', '', '',
    'Subject', 'varchar', 'NULL', '200', '[no subject]', '',
    'InitialPriority', 'integer', 'NULL', '', '', '',
    'FinalPriority', 'integer', 'NULL', '', '', '',
    'Priority', 'integer', 'NULL', '', '', '',
    'Status', 'varchar', 'NULL', '10', '', '',
    'TimeWorked', 'integer', 'NULL', '', '', '',
    'TimeLeft', 'integer', 'NULL', '', '', '',
    'Told', 'timestamp', 'NULL', '', '', '',
    'Starts', 'timestamp', 'NULL', '', '', '',
    'Started', 'timestamp', 'NULL', '', '', '',
    'Due', 'timestamp', 'NULL', '', '', '',
    'Resolved', 'timestamp', 'NULL', '', '', '',
    'LastUpdatedBy', 'integer', 'NULL', '', '', '',
    'LastUpdated', 'timestamp', 'NULL', '', '', '',
    'Creator', 'integer', 'NULL', '', '', '',
    'Created', 'timestamp', 'NULL', '', '', '',
    'Disabled', 'int2', '','','0','',
  ],
  'primary_key' => 'id',
  'unique' => [ [] ],
  'index' => [ ['Queue', 'Status'], [ 'id', 'Status' ] ],
},

'GroupMembers' => {
  'columns' => [
    'id', 'serial', '', '', '', '',
    'GroupId', 'integer', 'NULL', '', '', '', #foreign key, Groups::id
    'UserId', 'integer', 'NULL', '', '', '', #foreign key, Users::id
  ],
  'primary_key' => 'id',
  'unique' => [ ['GroupId', 'UserId']  ],
  'index' => [  ],
},

'Queues' => {
  'columns' => [
    'id', 'serial', '', '', '', '',
    'Name', 'varchar', '', '40', '', '', #Textual 'name' for this queue
    'Description', 'varchar', 'NULL', '120', '', '', #Textual descr. of this
    #queue
    'CorrespondAddress', 'varchar', 'NULL', '40', '', '',
    'CommentAddress', 'varchar', 'NULL', '40', '', '',
    'InitialPriority', 'integer', 'NULL', '', '', '',
    'FinalPriority', 'integer', 'NULL', '', '', '',
    'DefaultDueIn', 'integer', 'NULL', '', '', '',

    'Creator', 'integer', 'NULL', '', '', '',
    'Created', 'timestamp', 'NULL', '', '', '',
    'LastUpdatedBy', 'integer', 'NULL', '', '', '',
    'LastUpdated', 'timestamp', 'NULL', '', '', '',
    'Disabled', 'int2', '','','0','',
  ],
  'primary_key' => 'id',
  'unique' => [ ['Name'] ],
  'index' => [  ],
},

'Transactions' => {
  'columns' => [
    'id', 'serial', '', '', '', '',
    'EffectiveTicket', 'integer', 'NULL', '', '', '', 
    'Ticket', 'integer', 'NULL', '', '', '',  #Foreign key Ticket::id
    'TimeTaken', 'integer', 'NULL', '', '', '', #Time spent on this trans in min
    'Type', 'varchar', 'NULL', '20', '', '',
    'Field', 'varchar', 'NULL', '40', '', '', #If it's a "Set" transaction, what
    #field was set.
    'OldValue', 'varchar', 'NULL', '255', '', '', 
    'NewValue', 'varchar', 'NULL', '255', '', '',
    'Data', 'varchar', 'NULL', '100', '', '',


    'Creator', 'integer', 'NULL', '', '', '',
    'Created', 'timestamp', 'NULL', '', '', '',

  ],
  'primary_key' => 'id',
  'unique' => [  ],
  'index' => [  ],
},

'ScripActions' => {
  'columns' => [
		'id', 'serial', '', '', '', '',
		'Name', 'varchar', 'NULL', '255', '', '',  # Alias
		'Description', 'varchar', 'NULL', '255', '', '', #Textual description
		'ExecModule', 'varchar', 'NULL', '60', '', '', #This calles RT::Action::___
		'Argument', 'varchar', 'NULL', '255', '', '', #We can pass a single argument
		#to the scrip. sometimes, it's who to send mail to.
		'Creator', 'integer', 'NULL', '', '', '',
		'Created', 'timestamp', 'NULL', '', '', '',
		'LastUpdatedBy', 'integer', 'NULL', '', '', '',
		'LastUpdated', 'timestamp', 'NULL', '', '', '',
  ],
  'primary_key' => 'id',
  'unique' => [  ],
  'index' => [  ],
},

'ScripConditions' => {
  'columns' => [
		'id', 'serial', '', '', '', '',
		'Name', 'varchar', 'NULL', '255', '', '',  # Alias
		'Description', 'varchar', 'NULL', '255', '', '', #Textual description
		'ExecModule', 'varchar', 'NULL', '60', '', '', #This calles RT::Condition::
		'Argument', 'varchar', 'NULL', '255', '', '', #We can pass a single argument
		#to the scrip. sometimes, it's who to send mail to.
		'ApplicableTransTypes', 'varchar', 'NULL', '60', '', '',#Transaction types this scrip
		# acts on. comma or / delimited is just great.
		'Creator', 'integer', 'NULL', '', '', '',
		'Created', 'timestamp', 'NULL', '', '', '',
		'LastUpdatedBy', 'integer', 'NULL', '', '', '',
		'LastUpdated', 'timestamp', 'NULL', '', '', '',
  ],
  'primary_key' => 'id',
  'unique' => [  ],
  'index' => [  ],
},
'Scrips' => {
		 'columns' => [
			       'id', 'serial', '', '', '', '',
			       'ScripCondition', 'integer', 'NULL', '', '', '', #Foreign key ScripConditions::id
			       'ScripAction', 'integer', 'NULL', '', '', '', #Foreign key ScripActions::id
			       'Stage', 'varchar', 'NULL', '32','','', #What stage does this scrip
			       #Happen in.  for now, everything is 'TransactionCreate',
			       'Queue', 'integer', 'NULL', '', '', '', #Foreign key Queues::id
			       'Template', 'integer', 'NULL', '', '', '', #Foreign key Templates::id
			       
			       'Creator', 'integer', 'NULL', '', '', '',
			       'Created', 'timestamp', 'NULL', '', '', '',
			       'LastUpdatedBy', 'integer', 'NULL', '', '', '',
			       'LastUpdated', 'timestamp', 'NULL', '', '', '',
			      ],
		 'primary_key' => 'id',
		 'unique' => [  ],
		 'index' => [  ],
},

'Attachments' => {
  'columns' => [
    'id', 'serial', '', '', '', '',
    'TransactionId', 'integer', '', '', '', '', #Foreign key Transactions::Id
    'Parent', 'integer', 'NULL', '', '', '', # Attachments::Id
    'MessageId', 'varchar', 'NULL', '160', '', '', #RFC822 messageid, if any
    'Subject', 'varchar', 'NULL', '255', '', '', 
    'Filename', 'varchar', 'NULL', '255', '', '',
    'ContentType', 'varchar', 'NULL', '80', '', '',
    'ContentEncoding', 'varchar', 'NULL', '80', '', '',
    'Content', 'long varbinary', 'NULL', '', '', '',
    'Headers', 'long varbinary', 'NULL', '', '', '',

    'Creator', 'integer', 'NULL', '', '', '',
    'Created', 'timestamp', 'NULL', '', '', '',

  ],
  'primary_key' => 'id',
  'unique' => [  ],
  'index' => [  ],
},

'Templates' => {
  'columns' => [
    'id', 'serial', '', '', '', '',
    'Queue', 'integer', 'NOT NULL', '', '0', '',
    'Name', 'varchar', '', '40', '', '',
    'Description', 'varchar', 'NULL', '120', '', '',
    'Type', 'varchar', 'NULL', '16', '','',
    'Language', 'varchar', 'NULL', '16', '', '',
    'TranslationOf', 'integer', 'NULL', '', '', '',
    'Content', 'blob', 'NULL', '', '', '',
    'LastUpdated', 'timestamp', 'NULL', '', '', '',
    'LastUpdatedBy', 'integer', 'NULL', '', '', '',
    'Creator', 'integer', 'NULL', '', '', '',
    'Created', 'timestamp', 'NULL', '', '', '',
  ],
  'primary_key' => 'id',
  'unique' => [ [''] ],
  'index' => [  ],
},

'Keywords' => {
  'columns' => [
    'id', 'serial', '', '', '', '',
    'Name', 'varchar', 'NOT NULL', '255', '', '',
    'Description', 'varchar', 'NULL', '255', '', '',
    'Parent', 'integer', 'NULL', '', '', '',
    'Disabled', 'int2', '','','0','',
],
  'primary_key' => 'id',
  'unique' => [ [ 'Name', 'Parent' ] ],
  'index' => [ [ 'Name', ], [ 'Parent' ] ],
},

'ObjectKeywords' => {
  'columns' =>  [
    'id', 'serial', '', '', '', '',
    'Keyword', 'integer', 'NOT NULL', '', '', '',
    'KeywordSelect', 'integer', 'NOT NULL', '', '', '',
    'ObjectType', 'varchar', 'NOT NULL', '32', '', '',
    'ObjectId', 'integer', 'NOT NULL', '', '', '',
  ],
  'primary_key' => 'id',
  'unique' => [ [  'ObjectId', 'ObjectType','KeywordSelect', 'Keyword' ] ],
  'index' => [ [ 'ObjectId', 'ObjectType'  ] , ['Keyword'] ],

},

'KeywordSelects' => {
  'columns' =>  [
    'id', 'serial', '', '', '', '',
    'Name','varchar','NULL','255','','',
    'Keyword', 'integer', 'NULL', '', '', '',
    'Single', 'integer', 'NULL', '', '', '',
    'Depth', 'integer', 'NOT NULL', '', 0, '',
    'ObjectType', 'varchar', 'NOT NULL',  '32', '', '',
    'ObjectField', 'varchar', 'NULL', '32', '', '',
    'ObjectValue', 'varchar', 'NULL', '255', '', '',
    'Disabled', 'int2', '','','0','',
  ],
  'primary_key' => 'id',
  'unique' => [ [ ] ],
  'index' => [ [ 'Keyword' ], [ 'ObjectType', 'ObjectField', 'ObjectValue'] ],
},

};
