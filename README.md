ar-s3-columns
=============

Adds an column that is backed by S3 for Rails models.

To Use:
 Configure AWS-SDK with your AWS creds and set a default bucket to use for S3Columns, probably in an initializer.
```
AWS.config({
  :access_key_id => AWS_ACCESS_KEY,
  :secret_access_key => AWS_SECRET_ACCESS_KEY,
})

S3Columns.default_aws_bucket = "my-bucket"
```

To configure write options for AWS SDK, set default_s3_write_options:
```
S3Columns.default_s3_write_options = {acl: :authenticated_read }
```
This will set an ACL to each uploaded data as Authenticated Reads.


Include S3Columns and declare columns that will be pushed to S3
```
class User < ActiveRecord::Base
  include S3Columns
  
  s3_column_for :extra_data
...
```
This will add attribute accessors prefixed with "s3_column_#{column name}"
```
user = User.new
# Uploads to S3
user.s3_column_extra_data = {something: 'here'}

# reads from S3
user.s3_column_extra_data
```

Additional options:
 * s3_key: S3 key for column value
 * s3_bucket: S3 bucket to write to 

```
s3_column_for :metadata, s3_bucket: "other_bucket", s3_key: lambda{|m| "thing/metadata/#{m.name}"}
```

Before Create hook:
If you want to automatically upload the columns to S3 on create:
```
class User < ActiveRecord::Base
  include S3Columns
  s3_column_upload_on_create
  
  s3_column_for :extra_data
...
```
This will create a before_create hook to upload to s3 if the attribute is set in the create:
```
# This will automatically upload extra_data to S3
User.create(name: 'aww_yeah', extra_data: extra_value)
```
