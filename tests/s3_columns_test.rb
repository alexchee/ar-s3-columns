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
    test_object = ClassWithS3Columns.create(name: "unique")
    value = {something: 'else', goes: 'here'}
    
    @key_stub.expects(:write).with(Marshal.dump(value))
    @objects_stub.expects(:[]).with("thing/extras/unique").returns(@key_stub)
    @buckets_stub.expects(:[]).with("test").returns(stub(objects: @objects_stub))
    @s3_stub.expects(:buckets).returns(@buckets_stub)
    test_object.extra_data = value
    assert_equal test_object.read_attribute(:extra_data), "thing/extras/unique"
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
  
end

S3Columns.default_aws_bucket = "test"
class ClassWithS3Columns < ActiveRecord::Base
  include S3Columns
  s3_column_for :extra_data, s3_key: lambda{|m| "thing/extras/#{m.name}"}
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
