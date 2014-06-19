module S3Columns
  module InstanceMethods
    def s3_column_upload_on_create
      self.class.s3_columns.each do |column_name|
        column_value = self.read_attribute(column_name.to_sym)
        next if column_value.blank?
        marshalled_data = Marshal.dump(column_value)
        key_path = self.class.s3_columns_keys[column_name.to_sym].call(self)
        bucket_name = self.class.s3_columns_buckets[column_name.to_sym]
        write_options = S3Columns.default_s3_write_options || {}
        S3Columns.s3_connection.buckets[bucket_name].objects[key_path].write(marshalled_data, write_options)
        # saves key to column
        write_attribute(column_name.to_sym, key_path)
      end
    end
    
    def s3_column_destroy_all_s3_data
      self.s3_columns.each do |column_name|
        self.send("s3_column_destroy_#{column_name}")
      end
    end
  end
end
