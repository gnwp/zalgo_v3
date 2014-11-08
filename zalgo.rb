#!/usr/bin/ruby
#coding: utf-8

require "rubygems"
require "bundler"

Bundler.require

class Zalgo < Sinatra::Base
	register Sinatra::Synchrony


end
