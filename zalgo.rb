#!/usr/bin/ruby
#coding: utf-8

require "rubygems"
require "bundler"
require "date"

Bundler.require

load "settings.rb"

load "helpers.rb"
load "database.rb"


Sequel::Model.plugin :query_cache, CACHE_CLIENT, :ttl => 3600, :cache_by_default => { :always => true }

class Zalgo < Sinatra::Base
	register Sinatra::Synchrony

	def initialize
		super
		@c = HtmlCompressor::Compressor.new
	end

	error 400..510 do
		'oh shit'
	end


	get %r{/zalgo/(.*)$} do
		redirect "/#{params[:captures].first}"
	end
	get "/" do
		logger "/"
		@form = {}
		@title = "Szukaj"
		@zalgo_url = "/"

		cached = CACHE_CLIENT.get("/routes/home")
		return cached unless cached.nil?
		cached = @c.compress( erb :home )
		CACHE_CLIENT.set("/routes/home", cached)
		return cached

	end

	get "/query" do
		# new, sphinx-based query
		logger "/query/" + params.map{ |k,v| "#{k}='#{v}'" }.join( " " )
		cache_key = OpenSSL::Digest::MD5.hexdigest( [params[:q], params[:s]].flatten.join())
		cached = CACHE_CLIENT.get("/routes/query/#{cache_key}")
		return cached unless cached.nil?

		query = params[:q].to_s
		if params[:s].class == Array && params[:s].count > 0
			query += "( "
			query += params[:s].uniq.map{|s| "(@source #{clean_sphinx(s)})"}.join(" | ")
			query += ") "
		end

		post_ids = SPHINX["SELECT id FROM doc1 WHERE match(?) LIMIT 50", query].all
		post_ids.map!{ |i| i[:id] }
		if post_ids.count > 0
			@title = params[:q].to_s
			@zalgo_url = "/search?q=#{params[:q].gsub(/[ ]+/, "+")}"
		else
			@title = "Szukaj"
			@zalgo_url = "/search"
			post_ids << 999999999999999 #to trigger do-not-exist error
		end

		@posts = get_posts( :texts__id => post_ids )
		@form = {
			:q => params[:q].to_s,
			:s => params[:s]
		}
		@num_posts = @posts.count + 1

		if @posts.nil? or @posts.count == 0
			cached = @c.compress( erb :"404" )
		else
			cached = @c.compress( erb :node )
		end
		CACHE_CLIENT.set("/routes/query/#{cache_key}", cached)
		return cached
	end

	get "/search" do
		# ugly, hard-coded search. To be replaced by something more modular and nicer.
		# now used only as handler for old urls
		logger "/search/" + params.map{ |k,v| "#{k}='#{v}'" }.join( " " )
		cache_key = OpenSSL::Digest::MD5.hexdigest(params.to_a.join)
		cached = CACHE_CLIENT.get("/routes/search/#{cache_key}")
		return cached unless cached.nil?

		@zalgo_url = "/search"
		@form = {}
		if params[:q].nil? or params[:q].strip == ""
			query = get_posts( )
			@title = "Szukaj"
		else
			query = get_posts( )
			query.full_text_search!( params[:q] )
			@form[:q] = params[:q]
			@title = params[:q]
			@zalgo_url = "/search?q=#{params[:q]}"
		end

		unless( params[:ds].nil? or params[:ds] == "" )

			if( params[:de].nil? or params[:de] == "" )
				begin
					ds = DateTime.parse( params[:ds] ).to_date
					de = DateTime.now.to_date
				rescue Exception
					ds = nil
					de = nil
				end
			else
				begin
					de = DateTime.parse( params[:de] ).to_date
					ds = DateTime.parse( params[:ds] ).to_date
				rescue Exception
					ds = nil
					de = nil
				end
			end

			if( ds.nil? || de.nil? )
				@form[:ds] = ""
				@form[:de] = ""
			else
				query.where!( :texts__date => (ds..(de+1)) )
				@form[:ds] = ds
				@form[:de] = de
			end
		end

		unless params[:s].nil? or params[:s] == ""
			params[:s].gsub!( "*", "%" )
			params[:s].gsub!( "?", "_" )
			query.filter!( :sources__title.ilike( params[:s] ) )
			@form[:s] = params[:s]
		end

		unless params[:r].nil? or params[:r] == ""
			params[:r].gsub!( "*", "%" )
			params[:r].gsub!( "?", "_" )
			query.filter!( :receiver__login => params[:r].split( "," ) )
			@form[:r] = params[:r]
		end

		unless params[:u].nil? or params[:u] == ""
			params[:u].gsub!( "*", "%" )
			params[:u].gsub!( "?", "_" )
			query.filter!( :sender__login => params[:u].split( "," ) )
			@form[:u] = params[:u]
		end

		unless params[:t].nil? or params[:t] == ""
			params[:t].gsub!( "*", "%" )
			params[:t].gsub!( "?", "_" )
			query.filter!( :texts__title.ilike( params[:t] ) )
			@form[:t] = params[:t]
		end

		unless params[:n].nil? or params[:n] == ""
			params[:n].gsub!( "*", "%" )
			params[:n].gsub!( "?", "_" )
			query.filter!( :nodes__title.ilike( params[:n] ) )
			@form[:n] = params[:n]
		end

		unless params[:l].nil? or params[:l] == ""
			l = params[:l].to_i
			l = 1 if l < 1
			l = 200 if l > 50

			query.limit!( l )
			@form[:l] = l
		else
			query.limit!( 50 )
			@form[:l] = 50
		end

		@posts = query.order(:ts_rank.sql_function( 'public.polish', :plainto_tsquery.sql_function( params[:q] ) ) ).all
		@num_posts = @posts.count + 1


		if @posts.nil? or @posts.count == 0
			cached = @c.compress( erb :"404" )
		else
			cached = @c.compress( erb :node )
		end
		CACHE_CLIENT.set("/routes/search/#{cache_key}", cached)
		return cached
	end

	get "/user/:id" do |id|
		logger "/user/#{id}"
		cache_key = id.to_i
		cached = CACHE_CLIENT.get("/routes/user/#{cache_key}")
		return cached unless cached.nil?

		@zalgo_url = "/user/#{id}"
		@form = {}
		@posts = get_posts( { :texts__sender => id.to_i, :texts__receiver => id.to_i }.sql_or ).order( :texts__id.desc ).limit( 50 ).all
		@num_posts = @posts.count + 1


		if @posts.nil? or @posts.count == 0
			cached = @c.compress( erb :"404" )
		else
			@title = get_user( id.to_i )[:login]
			cached = @c.compress( erb :node )
		end
		CACHE_CLIENT.set("/routes/user/#{cache_key}", cached)
		return cached

	end

	get "/node/:id" do |id|
		logger "/node/#{id}"
		cache_key = id.to_i
		cached = CACHE_CLIENT.get("/routes/node/#{cache_key}")
		return cached unless cached.nil?

		@zalgo_url = "/node/#{id}"
		@form = {}
		@posts = get_posts( :nodes__id => id.to_i ).order( :texts__id.desc ).all
		if @posts and @posts.count > 0
			@num_posts = @posts.count + 1
			@title = @posts.first[:node_title]
		end
		if @posts.nil? or @posts.count == 0
			cached = @c.compress( erb :"404" )
		else
			cached = @c.compress( erb :node )
		end

		CACHE_CLIENT.set("/routes/node/#{cache_key}", cached)
		return cached

	end

	get "/post/:id" do |id|
		logger "/post/#{id}"
		id = id.split("+").map{|i| i.to_i}.uniq
		cache_key = OpenSSL::Digest::MD5.hexdigest( id.join(".") )
		cached = CACHE_CLIENT.get("/routes/post/#{cache_key}")
		return cached unless cached.nil?

		@zalgo_url = "/post/#{id}"
		@num_posts = id.length + 1;
		@form = {}
		@posts = get_posts( :texts__id => id ).all


		if @posts.nil? or @posts.count == 0
			cached = @c.compress( erb :"404" )
		else
			@title = [@posts.first[:node_title], @posts.first[:text_title]].reject{|i| i.nil? || i.to_s.strip == ""}.join(" - ")
			cached = @c.compress( erb :node )
		end

		CACHE_CLIENT.set("/routes/post/#{cache_key}", cached)
		return cached
	end


end
