#!/usr/bin/ruby
#coding: utf-8

require "rubygems"
require "bundler"
require "date"

Bundler.require

DB = Sequel.connect("postgres://antifa:antifa@localhost/antifa")

load "helpers.rb"
load "database.rb"

CACHE_CLIENT = Dalli::Client.new( '127.0.0.1:11211' )
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
		@c.compress( erb :home )


	end

	get "/search" do
		# ugly, hard-coded search. To be replaced by something more modular and nicer.
		logger "/search/" + params.map{ |k,v| "#{k}='#{v}'" }.join( " " )
		@zalgo_url = "/search"
		@form = {}
		if params[:q].nil? or params[:q] == ""
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
			@c.compress( erb :"404" )
		else
			@c.compress( erb :node )
		end

	end

	get "/user/:id" do |id|
		logger "/user/#{id}"
		@zalgo_url = "/user/#{id}"
		@form = {}
		@posts = get_posts( { :texts__sender => id.to_i, :texts__receiver => id.to_i }.sql_or ).order( :texts__id.desc ).limit( 50 ).all
		@num_posts = @posts.count + 1
		@title = User[:id =>id.to_i][:login]
		if @posts.nil? or @posts.count == 0
			@c.compress( erb :"404" )
		else
			@c.compress( erb :node )
		end
	end

	get "/node/:id" do |id|
		logger "/node/#{id}"
		@zalgo_url = "/node/#{id}"
		@form = {}
		@posts = get_posts( :nodes__id => id.to_i ).order( :texts__id.desc ).all
		@num_posts = @posts.count + 1
		@title = @posts.first[:node_title]
		if @posts.nil? or @posts.count == 0
			@c.compress( erb :"404" )
		else
			@c.compress( erb :node )
		end

	end

	get "/post/:id" do |id|
		logger "/post/#{id}"
		@zalgo_url = "/post/#{id}"
		id = id.split("+").map{|i| i.to_i}.uniq
		@num_posts = 2;
		@form = {}
		@posts = get_posts( :texts__id => id ).all
		@title = [@posts.first[:node_title], @posts.first[:text_title]].reject{|i| i.nil? || i.to_s.strip == ""}.join(" - ")
		if @posts.nil? or @posts.count == 0
			@c.compress( erb :"404" )
		else
			@c.compress( erb :node )
		end
	end


end
