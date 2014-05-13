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


 Include S3Columns and declare columns that will be pushed to S3
```
class User < ActiveRecord::Base
  include S3Columns
  
  s3_column_for :extra_data
...
```

Additional options:
 * s3_key: S3 key for column value
 * s3_bucket: S3 bucket to write to 

```
s3_column_for :metadata, s3_bucket: "other_bucket", s3_key: lambda{|m| "thing/metadata/#{m.name}"}
```
