# coding: utf-8


DB["SET default_text_search_config = 'public.polish';"]


# all users/origins of given data
class User < Sequel::Model( :users )
	def self._create_table!
		DB.create_table! :users do
			primary_key		:id
			foreign_key( :source, :sources, :key => :id )
			Integer			:orig_id
			String			:login
			String			:email
			String			:hash
			String			:pass
		end
	end
end

# "topics"
class Node < Sequel::Model( :nodes )
	def self._create_table!
		DB.create_table! :nodes do
			primary_key		:id
			foreign_key( :source, :sources, :key => :id )
			foreign_key( :type, :types, :key => :id )
			String			:uid
			String			:title
		end
	end
end

# where was the data gathered?
class Source < Sequel::Model( :sources )
	def self._create_table!
		DB.create_table! :sources do
			primary_key			:id
			String				:title
			String				:url
			Text				:notes
		end
	end
end

# search engine and text storage, "posts"
class Text < Sequel::Model( :texts )
	def self._create_table!
		DB.create_table! :texts do
			primary_key			:id
			foreign_key( :node, :nodes, :key => :id )
			Integer				:sender
			Integer				:receiver
			Integer				:rating
			DateTime			:date
			Varchar				:title
			Text				:content
			tsvector			:search
		end
		DB.execute( "CREATE TRIGGER tsvectorupdate BEFORE INSERT OR UPDATE
					ON texts FOR EACH ROW EXECUTE PROCEDURE
					tsvector_update_trigger(search, 'public.polish', content);" )

		DB.execute( "CREATE INDEX search_idx ON texts USING gin( search )" )
		self.db = DB
	end
	def_dataset_method( :full_text_search ) { |query|
		filter( "search @@ plainto_tsquery(?)", query )
	}
	def_dataset_method( :full_text_search! ) { |query|
		filter!( "search @@ plainto_tsquery(?)", query )
	}

end

# type of node - email, forum post, privmsg...
class Type < Sequel::Model( :types )
	def self._create_table!
		DB.create_table! :types do
			primary_key			:id
			String				:title
			Text				:notes
		end
	end

end

