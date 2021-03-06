#!/usr/bin/env ruby
# encoding: utf-8
# ODDB::TestUpdater -- oddb.org -- 19.01.2012 -- mhatakeyama@ywesee.com

$: << File.expand_path('..', File.dirname(__FILE__))
$: << File.expand_path("../../src", File.dirname(__FILE__))

gem 'minitest'
require 'minitest/autorun'
require 'flexmock'
require 'util/latest'

module ODDB
  class Latest
    @@today = Time.utc(2015,3,13)
  end

  DefaultContent = 'default content'
  ChangedContent = 'changed content size'

  class TestLatest <MiniTest::Unit::TestCase
    include FlexMock::TestCase
    def setup
      @archive = File.expand_path('../var', File.dirname(__FILE__))
      FileUtils.rm_rf(@archive) if File.exists?(@archive)
      FileUtils.makedirs(@archive)
      @latest = File.join(@archive, 'tst-latest.txt')
      @file_today = File.join(@archive, 'tst-2015.03.13.txt')
      @url = 'http://www.example.com'
      @page  = flexmock('page')
      @page.should_receive(:body).by_default.and_return(DefaultContent)
      @agent = flexmock(Mechanize.new)
      @agent.should_receive(:get).and_return(@page)
    end

    def test_first_download
      assert_equal(false, File.exists?(@file_today))
      res = Latest.get_latest_file(@latest, @url, @agent)
      puts "test_first_download #{Dir.glob(File.join(@archive, '*'))}" # if $VERBOSE
      assert_equal(true, File.exists?(@file_today))
      assert_equal(@latest, res)
    end

    def test_today_different_content_today_latest
      puts 'test_today_different_content_today_latest'  if $VERBOSE
      File.open(@latest, 'w+') {|f| f.write(ChangedContent) }
      assert_equal(true, File.exists?(@latest))
      res = Latest.get_latest_file(@latest, @url, @agent)
      puts "test_today_different_content_today_latest #{Dir.glob(File.join(@archive, '*'))}" # if $VERBOSE
      assert_equal(@latest, res)
      assert_equal(true, File.exists?(@file_today))
      assert_equal(true, File.exists?(@latest))
      assert_equal(DefaultContent.size, File.size(@latest))
    end

    def test_today_different_content_new_content
      puts 'test_today_different_content_new_content'  if $VERBOSE
      File.open(@latest, 'w+') {|f| f.write(ChangedContent) }
      assert_equal(false, File.exists?(@file_today))
      res = Latest.get_latest_file(@latest, @url, @agent)
      system("ls -l #{@archive}/*") if $VERBOSE
      assert_equal(@latest, res)
      assert_equal(true, File.exists?(@file_today))
      assert_equal(true, File.exists?(@latest))
      assert_equal(DefaultContent.size, File.size(@latest))
    end

    def test_today_same_latest
      puts 'test_today_different_content_new_content'  if $VERBOSE
      File.open(@latest, 'w+') {|f| f.write(DefaultContent) }
      File.open(@file_today, 'w+') {|f| f.write(DefaultContent) }
      res = Latest.get_latest_file(@latest, @url, @agent)
      assert_equal(false, res)
      assert_equal(true, File.exists?(@file_today))
      assert_equal(true, File.exists?(@latest))
      assert_equal(DefaultContent.size, File.size(@latest))
    end

    def test_no_file_today
      puts 'test_today_content_same_latest_content'  if $VERBOSE
      File.open(@latest, 'w+') {|f| f.write(DefaultContent) }
      res = Latest.get_latest_file(@latest, @url, @agent)
      assert_equal(false, res)
      assert_equal(true, File.exists?(@file_today))
      assert_equal(true, File.exists?(@latest))
      assert_equal(DefaultContent.size, File.size(@latest))
    end

  end
end
