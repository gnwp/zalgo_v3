#!/usr/bin/ruby
#coding: utf-8

require "rubygems"
require "bundler"
require "date"

Bundler.require

DB = Sequel.connect("postgres://antifa:antifa@localhost/antifa")

load "helpers.rb"
load "database.rb"
Pry.start()
