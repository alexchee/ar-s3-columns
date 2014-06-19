require 'aws-sdk'
require 'retryable'
require 'simple_uuid'
require 'ar_s3_columns/class_methods'
require 'ar_s3_columns/instance_methods'

module S3Columns
  class <<self
    attr_accessor :default_aws_bucket, :default_s3_write_options
    
    def s3_connection
      Thread.current[:aws_s3_connection] ||= AWS::S3.new
    end
  end

  extend ActiveSupport::Concern
  included do
    class_attribute :s3_columns, :s3_columns_keys, :s3_columns_buckets, :s3_write_options
    s3_write_options ||= {}
    
    extend S3Columns::ClassMethods
    include S3Columns::InstanceMethods
    before_destroy :s3_column_destroy_all_s3_data
    
  end
end
