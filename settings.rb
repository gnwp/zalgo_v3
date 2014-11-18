
DB = Sequel.connect("postgres://antifa:antifa@localhost/antifa")
CACHE_CLIENT = Dalli::Client.new( '127.0.0.1:11211', :value_max_bytes => 5242880 )
