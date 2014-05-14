require 'test_helper'
require "minitest/autorun"
require 'mocha/mini_test'

describe "S3Columns" do
  before do
    S3Columns.default_aws_bucket = "test"
    TestMigration.up
    ClassWithS3Columns.delete_all
    # Stubs S3 stuff
    @key_stub = stub(write: nil, read: Marshal.dump(nil))
    @objects_stub = stub(:[] => @key_stub)
    @buckets_stub = stub(:[] => @objects_stub)
    @s3_stub = stub( buckets: (stubs(:[]).returns(stub( objects: stub(read: nil, write:nil) ))) )
    S3Columns.stubs(:s3_connection).returns(@s3_stub)
  end

  after do
    TestMigration.down
  end

  describe "configuration" do
    it "raises exception if S3Columns.default_aws_bucket is not set" do
      assert_raises(RuntimeError, "Please set a S3Columns.default_aws_bucket") do
        S3Columns.default_aws_bucket = nil
        ClassWithS3Columns.s3_column_for :extra_data
      end
    end
  end
  
  it "reads from db for non S3 column" do
    test_object = ClassWithS3Columns.create(name: 'hey')
    assert_equal "hey", test_object.name
  end
  
  it "uploads marshalled value of columns to s3 and save s3 key to db" do
    SimpleUUID::UUID.any_instance.stubs(:to_guid).returns('unique')
    
    test_object = ClassWithS3Columns.create(name: "unique")
    value = {something: 'else', goes: 'here'}
    
    @key_stub.expects(:write).with(Marshal.dump(value))
    @objects_stub.expects(:[]).with("extra_data/unique").returns(@key_stub)
    @buckets_stub.expects(:[]).with("test").returns(stub(objects: @objects_stub))
    @s3_stub.expects(:buckets).returns(@buckets_stub)
    test_object.extra_data = value
    assert_equal "extra_data/unique", test_object.read_attribute(:extra_data)
  end
  
  it "reads from S3 with key in db and if it exists" do
    test_object = ClassWithS3Columns.create(name: "unique")
    test_object.send(:write_attribute, :extra_data, 'some/key')

    @key_stub.expects(:exists?).returns(true)
    @key_stub.expects(:read).returns(Marshal.dump("some data"))
    @objects_stub.expects(:[]).with("some/key").returns(@key_stub)
    @buckets_stub.expects(:[]).with("test").returns(stub(objects: @objects_stub))
    @s3_stub.expects(:buckets).returns(@buckets_stub)
    assert_equal test_object.extra_data, "some data"
  end

  it "retries S3 read, when S3 key in db, but does not exists (usually because S3 has not persisted object yet)" do
    test_object = ClassWithS3Columns.create(name: "unique")
    test_object.send(:write_attribute, :extra_data, 'some/key')
    
    Retryable.expects(:retryable)
    @key_stub.expects(:exists?).returns(false)
    @objects_stub.expects(:[]).with("some/key").returns(@key_stub)
    @buckets_stub.expects(:[]).with("test").returns(stub(objects: @objects_stub))
    @s3_stub.expects(:buckets).returns(@buckets_stub)
    test_object.extra_data
  end

  it "returns nil and do not hit S3, if key is not in db" do
      @s3_stub.expects(:buckets).at_most(0)
      test_object = ClassWithS3Columns.create(name: "unique")
      assert_nil test_object.extra_data
  end
  
  describe "options" do
    describe ":s3_bucket" do
      it "uses :s3_bucket for S3 bucket name on reader" do
        ClassWithS3Columns.s3_column_for :extra_data, s3_bucket: "some_bucket2"
        test_object = ClassWithS3Columns.create(name: "something")
        test_object.send(:write_attribute, :extra_data, 'some/key')
        
        key_stub = stub(exists?: true, read: Marshal.dump('hey'))
        @buckets_stub.expects(:[]).with("some_bucket2").returns(stub(objects: stub(:[] => key_stub)))
        @s3_stub.expects(:buckets).returns(@buckets_stub)
        test_object.extra_data
      end

      it "uses :s3_bucket for S3 bucket name on writer" do
        ClassWithS3Columns.s3_column_for :extra_data, s3_bucket: "some_bucket2"
        test_object = ClassWithS3Columns.create(name: "something")
        test_object.send(:write_attribute, :extra_data, 'some/key')
        
        @buckets_stub.expects(:[]).with("some_bucket2").returns(stub(objects: @objects_stub))
        @s3_stub.expects(:buckets).returns(@buckets_stub)
        test_object.extra_data = {here: "we go"}
      end
    end
    
    describe ":s3_key" do
      it "changes S3 key" do
        ClassWithS3Columns.s3_column_for :extra_data, s3_key: lambda{|m| "something/hardcored/#{m.name}"}
        test_object = ClassWithS3Columns.create(name: "my_thing")
        assert_equal ClassWithS3Columns.s3_columns_keys[:extra_data].call(test_object), "something/hardcored/my_thing"
      end
    end
  end
  
  describe "s3_column_upload_on_create" do
    it "uploads all S3 columns to S3" do
      ClassWithS3Columns.s3_column_upload_on_create
      
      SimpleUUID::UUID.any_instance.stubs(:to_guid).returns('uuid')
      extra_value = {some_data: 'this is extra'}
      options_value = {toggle: true}
      metadata_value = {user: 1}
      
      key_mock = mock("S3 Key")
      bucket_objects_mock = mock("S3 Objects")
      bucket_mock = mock('Test S3 Bucket')
      other_bucket_mock = mock("Other S3 Bucket")
      other_bucket_objects_mock = mock('Other S3 Objects')
      
      key_mock.expects(:write).with(Marshal.dump(extra_value))
      key_mock.expects(:write).with(Marshal.dump(options_value))
      key_mock.expects(:write).with(Marshal.dump(metadata_value))
      
      bucket_objects_mock.expects(:[]).with("thing/options/aww_yeah").returns(key_mock)
      bucket_objects_mock.expects(:[]).with('extra_data/uuid').returns(key_mock)
      other_bucket_objects_mock.expects(:[]).with("thing/meta/aww_yeah").returns(key_mock)
      
      bucket_mock.expects(:objects).at_least(2).returns(bucket_objects_mock)
      other_bucket_objects_mock
      other_bucket_mock.expects(:objects).returns(other_bucket_objects_mock)
      buckets_mock = mock("S3 Buckets")
      buckets_mock.expects(:[]).with("other").returns(other_bucket_mock)
      buckets_mock.expects(:[]).with("test").at_least(2).returns(bucket_mock)
      s3_stub = mock("S3 Connection")
      s3_stub.expects(:buckets).at_least(2).returns(buckets_mock)
      # S3Columns.unstub(:s3_connection)
      S3Columns.stubs(:s3_connection).returns(s3_stub)
      test_object = ClassWithS3Columns.create(name: 'aww_yeah', extra_data: extra_value, options: options_value, metadata: metadata_value)
      # assert_equal "extra_data/uuid", test_object.read_attribute(:extra_data)
      # assert_equal "thing/options/aww_yeah", test_object.read_attribute(:options)
      # assert_equal "thing/meta/aww_yeah", test_object.read_attribute(:metadata)
    end
    
    
  end

end

S3Columns.default_aws_bucket = "test"
class ClassWithS3Columns < ActiveRecord::Base
  include S3Columns
  s3_column_for :extra_data
  s3_column_for :options, s3_key: lambda{|m| "thing/options/#{m.name}"}
  s3_column_for :metadata, s3_bucket: "other", s3_key: lambda{|m| "thing/meta/#{m.name}"}
end

class TestMigration < ActiveRecord::Migration
  def self.up
    create_table :class_with_s3_columns, :force => true do |t|
      t.column :name, :string
      t.column :extra_data, :string
      t.column :options, :string
      t.column :metadata, :string
    end
  end

  def self.down
    drop_table :class_with_s3_columns
  end
end
