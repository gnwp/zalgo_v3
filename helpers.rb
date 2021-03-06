class Symbol
	def not
		return Sequel.~( self )
	end


end

class Hash
	def sql_or
		return Sequel.or(self)
	end
end
class NilClass
	def strftime(x)
		return "error"
	end
end


class Sinatra::Base


	helpers do

		def uu
			return URL_BASE
		end

		def logger( text )
			puts Time.now.strftime("%H:%M:%S") + "	" + text
			return nil
		end

		def escape_sphinx(input)
			return input
		end

		def clean_sphinx(input)
			return input.gsub(/\W+/, " ")
		end


		def get_sources( )
			sources = CACHE_CLIENT.get( "/get_sources" )
			if sources.nil?
				sources = Source.all
				CACHE_CLIENT.set( "/get_sources", sources )
			end

			return sources
		end

		def get_posts_hl( opts = {}, query )
			post = Text.filter( opts ).
				left_outer_join( :nodes, :nodes__id => :texts__node ).
				left_outer_join( :sources, :sources__id => :nodes__source ).
				left_outer_join( :users.as(:sender), :sender__id => :texts__sender ).
				left_outer_join( :users.as(:receiver), :receiver__id => :texts__receiver ).
				select{ [
					:nodes__id.as( :node_id ),
					:nodes__title.as( :node_title ),
					:sources__title.as( :source_title ),
					:sources__url.as( :source_url ),
					:sources__notes.as( :source_notes ),
					:texts__date.as( :text_date ),
					:texts__id.as( :text_id ),
					:texts__title.as( :text_title ),
					:ts_headline.sql_function( "public.polish", :texts__content, :plainto_tsquery.sql_function( "public.polish", query ) ).as( :text_content ) ,
					:texts__sender.as( :sender_id ),
					:texts__receiver.as( :receiver_id ),
					:sender__login.as( :sender_login ),
					:receiver__login.as( :receiver_login ),
					:texts__rating.as( :text_rating )

				]}.order( :texts__date.desc )
			return post

		end

		def get_posts( opts = {} )

			post = Text.filter( opts ).
				left_outer_join( :nodes, :nodes__id => :texts__node ).
				left_outer_join( :sources, :sources__id => :nodes__source ).
				left_outer_join( :users.as(:sender), :sender__id => :texts__sender ).
				left_outer_join( :users.as(:receiver), :receiver__id => :texts__receiver ).
				select{ [
					:nodes__id.as( :node_id ),
					:nodes__title.as( :node_title ),
					:sources__title.as( :source_title ),
					:sources__url.as( :source_url ),
					:sources__notes.as( :source_notes ),
					:texts__date.as( :text_date ),
					:texts__id.as( :text_id ),
					:texts__title.as( :text_title ),
					:texts__content.as( :text_content ),
					:texts__sender.as( :sender_id ),
					:texts__receiver.as( :receiver_id ),
					:sender__login.as( :sender_login ),
					:receiver__login.as( :receiver_login ),
					:texts__rating.as( :text_rating )

				]}.order( :texts__date.desc )

			return post
		end

		def get_users( opts = {} )
			user = User.filter( opts ).
				left_outer_join( :sources, :sources__id => :users__source ).
				select{ [
					:users__id.as( :user_id ),
					:users__login.as( :user_login ),
					:users__email.as( :user_email ),
					:users__hash.as( :user_hash ),
					:users__pass.as( :user_pass ),
					:users__id.as( :user_id ),
					:sources__title.as( :source_title ),
					:sources__url.as( :source_url ),
					:sources__notes.as( :source_notes )

				] }
			return user
		end


		def get_user( id )
			cache_key = OpenSSL::Digest::MD5.hexdigest(id.to_s)
			cached = CACHE_CLIENT.get("/get_user/#{cache_key}")
			return cached unless cached.nil?

			cached = User.filter( :id => id.to_i ).first
			CACHE_CLIENT.set("/get_user/#{cache_key}", cached)
			return cached
		end

		def get_topics( opts = {} )
			Node.filter( opts )
		end

		def get_texts( opts = {} )
			Text.filter( opts )
		end

		def html_strip( content )
			return content.gsub("<b>", "[b]").gsub("</b>", "[/b]").gsub( /\<img.*?\/\>/imx, "" ).gsub( /\<\!\-\-.*?\-\-\>/imx, "" ).gsub( /\</imx, "&lt;" ).gsub( /\>/imx, "&gt;" )
		end

		def bbcode_strip( content )
			return content.gsub( /\[\/?(?:b|i|u|url|quote|code|img|color|size)*?.*?\]/imx, "" ).gsub( /(.)\"\](.)/imx, "$1 $2" )
		end

		def bbcode( content )
			c = html_strip( content )
			c = c.gsub( /\[b.*?\]/imx, "<b>" ).gsub( /\[\/b.*?\]/imx, "</b>" )

			c = c.gsub( /\[quote.*?"(.*?)".*?\]/imx, "<blockquote>::\\1::" )
			c = c.gsub( /\[quote.*?\]/imx, "<blockquote>" ).gsub( /\[\/quote.*?\]/imx, "</blockquote>" )
			c = c.gsub( /\<blockquote\>::(.*?)::(.*?)\<\/blockquote\>/imx, "<blockquote>\\2<footer><cite>\\1</cite></footer></blockquote>")
			return ::Nokogiri::HTML::DocumentFragment.parse( bbcode_strip( c ) ).to_html
		end

	end
end
