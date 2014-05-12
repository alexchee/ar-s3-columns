module S3Columns
  module ClassMethods
    
    
    # Creates reader/writer for given column that will upload the marshalled value to S3
    # Options:
    #  * s3_key: S3 key to use, should be a Proc.
    #  * s3_bucket: S3 bucket to use
    def s3_column_for(column_name, options={})
      raise "Please set a S3Columns.default_aws_bucket" if S3Columns.default_aws_bucket.blank?
      options[:s3_key]  ||= Proc.new{|object| "#{column_name}/#{object.id}"}
      options[:s3_bucket]    ||= S3Columns.default_aws_bucket
      self.s3_columns ||= []
      self.s3_columns_keys ||= {}
      self.s3_columns << column_name unless self.s3_columns.include?(column_name)
      self.s3_columns_keys[column_name.to_sym] = options[:s3_key]
      self.s3_columns_buckets ||= {}
      self.s3_columns_buckets[column_name.to_sym] = options[:s3_bucket]
      
      # Creates a reader
      self.class_eval %Q{
        def #{column_name}
          key_path = read_attribute(:#{column_name})
          if key_path.present?
            key = S3Columns.s3_connection.buckets["#{options[:s3_bucket]}"].objects[key_path]

            if key.exists?
              @#{column_name} ||= Marshal.load(key.read)
            else
              # Retry in case it is not persisted in S3 yet
              Retryable.retryable :on => [AWS::S3::Errors::NoSuchKey], :tries => 10, :sleep => 1 do
                @#{column_name} ||= Marshal.load(key.read)
              end
            end

          else
            nil
          end
        end
      }
      
      # Creates writer
      self.class_eval %Q{
        def #{column_name}=(value)
          marshalled_value = Marshal.dump(value)
          key_path = self.class.s3_columns_keys[:#{column_name}].call(self)
          S3Columns.s3_connection.buckets["#{options[:s3_bucket]}"].objects[key_path].write(marshalled_value)
          # update column with new key
          write_attribute(:#{column_name}, key_path)
        end
      }
    end
  end
end
