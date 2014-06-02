module S3Columns
  module ClassMethods
    
    # Adds before_create to upload each S3 column to S3, to prevent it writing the values to DB.
    # Warning: The default s3_key uses the object's ID which will be nil at this point, should set a custom :s3_key
    def s3_column_upload_on_create
      self.class_eval %Q{
        before_create :s3_column_upload_on_create
      }
    end
    
    # Creates reader/writer for given column that will upload the marshalled value to S3
    # Options:
    #  * s3_key: S3 key to use, should be a Proc.
    #  * s3_bucket: S3 bucket to use
    def s3_column_for(column_name, options={})
      raise "Please set a S3Columns.default_aws_bucket" if S3Columns.default_aws_bucket.blank?
      options[:s3_key]  ||= Proc.new{|object| "#{column_name}/#{SimpleUUID::UUID.new.to_guid}"}
      options[:s3_bucket]    ||= S3Columns.default_aws_bucket
      self.s3_columns ||= []
      self.s3_columns_keys ||= {}
      self.s3_columns << column_name unless self.s3_columns.include?(column_name)
      self.s3_columns_keys[column_name.to_sym] = options[:s3_key]
      self.s3_columns_buckets ||= {}
      self.s3_columns_buckets[column_name.to_sym] = options[:s3_bucket]
      
      # Creates a reader
      self.class_eval %Q{
        def s3_column_#{column_name}
          if self.persisted? && key_path = read_attribute(:#{column_name})
            key = S3Columns.s3_connection.buckets["#{options[:s3_bucket]}"].objects[key_path]
            # Retry in case it is not persisted in S3 yet
            Retryable.retryable :on => [AWS::S3::Errors::NoSuchKey], :tries => 10, :sleep => 1 do
              @#{column_name} ||= Marshal.load(key.read)
            end
          else
            @#{column_name}
          end
        end
      }
      
      # Creates writer
      self.class_eval %Q{
        def s3_column_#{column_name}=(value)
          marshalled_value = Marshal.dump(value)
          key_path = self.class.s3_columns_keys[:#{column_name}].call(self)
          write_options = S3Columns.default_s3_write_options || {}
          S3Columns.s3_connection.buckets["#{options[:s3_bucket]}"].objects[key_path].write(marshalled_value, write_options)
          # update column with new key
          write_attribute(:#{column_name}, key_path)
          @#{column_name} = value
        end
      }
    end
  end
end
