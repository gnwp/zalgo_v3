
DB = Sequel.connect("postgres://antifa:antifa@127.0.0.1/antifa")
CACHE_CLIENT = Dalli::Client.new( '127.0.0.1:11211', :value_max_bytes => 5242880, :namespace => "antifa" )
SPHINX = Sequel.connect("mysql2://127.0.0.1/sphinx?port=9306")
SPHINX_T = "doc1"
URL_BASE = "/kibice" #no trailing slash
