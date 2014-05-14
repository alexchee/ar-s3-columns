module S3Columns
  module InstanceMethods
    def s3_column_upload_on_create
      self.class.s3_columns.each do |column_name|
        column_value = self.read_attribute(column_name.to_sym)
        next if column_value.blank?
        marshalled_data = Marshal.dump(column_value)
        key_path = self.class.s3_columns_keys[column_name.to_sym].call(self)
        bucket_name = self.class.s3_columns_buckets[column_name.to_sym]
        bucket=S3Columns.s3_connection.buckets[bucket_name]
        objs=bucket.objects[key_path]
        self.send("#{column_name}_will_change!".to_sym)
        objs.write(marshalled_data)
        # saves key to column
        write_attribute(column_name.to_sym, key_path)
      end
    end
    
  end
end
