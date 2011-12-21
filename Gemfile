source "http://rubygems.org"

gem "rails", "2.3.14"
gem "activerecord-jdbc-adapter", :platforms => :jruby

# We don't ship database drivers in the .WAR file; they are provided by the J2EE container.
group :development do
  platforms :jruby do
    gem "activerecord-jdbcsqlite3-adapter"
    gem "activerecord-jdbcmysql-adapter"
    gem "activerecord-jdbcmssql-adapter"
    gem "activerecord-jdbcderby-adapter"
    gem "warbler"
  end

  platforms :ruby do
    gem "mysql2", "~> 0.2.6"    # 0.3.x only works on Rails 3.1 and above
  end
end
