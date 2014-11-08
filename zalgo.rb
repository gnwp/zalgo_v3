#!/usr/bin/ruby
#coding: utf-8

require "rubygems"
require "bundler"

Bundler.require

DB = Sequel.connect("postgres://antifa:antifa@localhost/antifa")

load "helpers.rb"
load "database.rb"


class Zalgo < Sinatra::Base
	register Sinatra::Synchrony

	def initialize
		super
		@c = HtmlCompressor::Compressor.new
	end

	get "/" do
		@c.compress("<h1>test</h1>")
	end

	get "/search" do

	end

	get "/user/:id" do |id|
		logger "/user/#{id}"

	end

	get "/node/:id" do |id|
		logger "/node/#{id}"
		
		@posts = get_posts( :nodes__id => id.to_i )

		if @posts.nil? or @posts.count == 0
			erb :"404"
		else
			erb :node
		end

	end

	get "/post/:id" do |id|
		logger "/post/#{id}"
		id = id.split("+").map{|i| i.to_i}.uniq
		@posts = get_posts( :texts__id => id )

		if @posts.nil? or @posts.count == 0
			erb :"404"
		else
			erb :node
		end
	end


end
