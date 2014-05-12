lib = File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'active_record'
require 'ar_s3_columns'

# ActiveRecord setup
dbconfig = {
  :adapter  => 'mysql2',
  :database => 's3_columns_test',
  :username => 'root',
  :encoding => 'utf8'
}

database = dbconfig.delete(:database)

ActiveRecord::Base.establish_connection(dbconfig)
begin
  ActiveRecord::Base.connection.create_database database
rescue ActiveRecord::StatementInvalid => e # database already exists
end
ActiveRecord::Base.establish_connection(dbconfig.merge(:database => database))

ActiveRecord::Migration.verbose = false
