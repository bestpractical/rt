#   column, type, nullability, length, default, database-local

my $gratuitous = {
'Article' => {
  'columns' => [
    'id', 'serial', '', '', '', '',
    'Name', 'varchar', 'NULL', '200', '', '',
    'Summary', 'varchar', 'NULL', '200', '', '',
    'Content', 'integer', 'NULL', '', '', '', # MIMEObject::Id
    'Parent', 'integer', 'NULL', '', '', '', # MIMEObject::Id
    'SortOrder', 'integer', 'NULL', '', '', '', 
    'CreatedBy', 'integer', 'NULL', '', '', '',
    'Created', 'timestamp', 'NULL', '', '', '',
    'UpdatedBy', 'integer', 'NULL', '', '', '',
    'Updated', 'timestamp', 'NULL', '', '', '',
    'Disabled', 'int2', '','','0','',
  ],
  'primary_key' => 'id',
  'unique' => [ [] ],
  'index' => [ [] ],
},




'CustomField' => {
  'columns' => [
    'id', 'serial', '', '', '', '',
    'Name', 'varchar', 'NULL', '200', '', '',
    'Type', 'varchar', 'NULL', '200', '', '', # One of 'SelectSingle', 
					      # 'SelectMultiple', 							      # 'FreeformSingle', 
					      # 'FreeformMultiple'
    'Description', 'varchar', 'NULL', '200', '', '',
    'SortOrder', 'integer', 'NULL', '', '', '', 
    'CreatedBy', 'integer', 'NULL', '', '', '',
    'Created', 'timestamp', 'NULL', '', '', '',
    'UpdatedBy', 'integer', 'NULL', '', '', '',
    'Updated', 'timestamp', 'NULL', '', '', '',
  ],
  'primary_key' => 'id',
  'unique' => [ [] ],
  'index' => [ [] ],
},


'CustomFieldValues' => {
  'columns' => [
    'id', 'serial', '', '', '', '',
    'CustomField', 'int', '', '', '', '',
    'Name', 'varchar', 'NULL', '200', '', '',
    'Description', 'varchar', 'NULL', '200', '', '',
    'SortOrder', 'integer', 'NULL', '', '', '', 
    'CreatedBy', 'integer', 'NULL', '', '', '',
    'Created', 'timestamp', 'NULL', '', '', '',
    'UpdatedBy', 'integer', 'NULL', '', '', '',
    'Updated', 'timestamp', 'NULL', '', '', '',
  ],
  'primary_key' => 'id',
  'unique' => [ [] ],
  'index' => [ [] ],
},

'CustomFieldObjectValues' => {
  'columns' => [
    'id', 'serial', '', '', '', '',
    'Article', 'int', '', '', '', '',
    'CustomField', 'int', '', '', '', '',
    'Content', 'varchar', 'NULL', '255', '', '',
    'SortOrder', 'integer', 'NULL', '', '', '', 
    'CreatedBy', 'integer', 'NULL', '', '', '',
    'Created', 'timestamp', 'NULL', '', '', '',
    'UpdatedBy', 'integer', 'NULL', '', '', '',
    'Updated', 'timestamp', 'NULL', '', '', '',
  ],
  'primary_key' => 'id',
  'unique' => [ [] ],
  'index' => [ [] ],
},




'Transaction' => {
  'columns' => [
  'id', 'serial', '', '', '', '',
  'Article', 'integer', 'NULL', '', '', '', # Article::Id
  'ChangeLog', 'text', 'NULL', '', '','',
  'CreatedBy', 'integer', 'NULL', '', '', '',
  'Created', 'timestamp', 'NULL', '', '', '',
  ],
  'primary_key' => 'id',
  'unique' => [ [] ],
  'index' => [ [] ],
},

'Delta' => {
  'columns' => [
  'id', 'serial', '', '', '', '',
  'Transaction', 'integer', 'NULL', '', '', '', # ChangeSet::Id
  'Type', 'varchar', 'NULL', '64', '', '',
  'Field', 'varchar', 'NULL', '64', '', '',
  'OldValue', 'varchar', 'NULL', '255', '', '',
  'NewValue', 'varchar', 'NULL', '255', '', '',
  ],
  'primary_key' => 'id',
  'unique' => [ [] ],
  'index' => [ [] ],
},	
	

'Content' => {
  'columns' => [
    'id', 'serial', '', '', '', '',
    'Parent', 'integer', 'NULL', '', '', '', # MIMEObject::Id
    'MessageId', 'varchar', 'NULL', '160', '', '', #RFC822 messageid, if any
    'Subject', 'varchar', 'NULL', '255', '', '', 
    'Filename', 'varchar', 'NULL', '255', '', '',
    'ContentType', 'varchar', 'NULL', '80', '', '',
    'ContentEncoding', 'varchar', 'NULL', '80', '', '',
    'Body', 'long varbinary', 'NULL', '', '', '',
    'Headers', 'long varbinary', 'NULL', '', '', '',
    'CreatedBy', 'integer', 'NULL', '', '', '',
    'Created', 'timestamp', 'NULL', '', '', '',
    'UpdatedBy', 'integer', 'NULL', '', '', '',
    'Updated', 'timestamp', 'NULL', '', '', '',
  ],
  'primary_key' => 'id',
  'unique' => [  ],
  'index' => [ [] ],
},


};
