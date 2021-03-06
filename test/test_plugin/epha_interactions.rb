#!/usr/bin/env ruby
# encoding: utf-8

$: << File.expand_path('..', File.dirname(__FILE__))
$: << File.expand_path("../../src", File.dirname(__FILE__))

gem 'minitest'
require 'minitest/autorun'
require 'stub/odba'
require 'fileutils'
require 'flexmock'
require 'plugin/epha_interactions'
require 'model/text'
require 'model/atcclass'
require 'model/fachinfo'
require 'model/commercial_form'
require 'model/registration'

module ODDB
  module SequenceObserver
    def initialize
    end
    def select_one(param)
    end
  end
  class PseudoFachinfoDocument
    def descriptions
      { :de => FlexMock.new('descriptions') }
    end
  end
    class StubLog
      include ODDB::Persistence
      attr_accessor :report, :pointers, :recipients, :hash
      def notify(arg=nil)
      end
    end
    class StubPackage
      attr_accessor :commercial_forms
      def initialize
        puts "StubPackage addin CommercialForm"
        @commercial_mock = FlexMock.new(ODDB::CommercialForm)
        @commercial_forms = [@commercial_mock]
      end
    end
    class ODDB::Registration
     def initialize(iksnr)
        @pointer = FlexMock.new(Persistence::Pointer)
        @pointer.should_receive(:descriptions).and_return(@descriptions)
        @pointer.should_receive(:pointer).and_return(@pointer)
        @pointer.should_receive(:creator).and_return([])
        @pointer.should_receive(:+).and_return(@pointer)
      @iksnr = iksnr
      @sequences = {}
      end
    end
    class StubApp
      attr_writer :log_group
      attr_reader :pointer, :values, :model
      attr_accessor :last_date, :epha_interactions, :registrations
      def initialize
        @model = StubLog.new
        @epha_interactions = []
        @registrations = {}
        @company_mock = FlexMock.new(ODDB::Company)
        @company_mock.should_receive(:pointer).and_return(@pointer)
        epha_mock = FlexMock.new(@epha_interactions)
        epha_mock = FlexMock.new(@epha_interactions)
        epha_mock.should_receive(:odba_store)
        product_mock = FlexMock.new(@registrations)
        product_mock.should_receive(:odba_store)
        @pointer_mock = FlexMock.new(Persistence::Pointer)
        @descriptions_mock = FlexMock.new('descriptions')
        @pointer_mock.should_receive(:descriptions).and_return(@descriptions_mock)
        @pointer_mock.should_receive(:pointer).and_return(@pointer_mock)
        @pointer_mock.should_receive(:notify).and_return([])
        @pointer_mock.should_receive(:+).and_return(@pointer_mock)
      end
      def atc_class(name)
        @atc_name = name
        @atc_class_mock = FlexMock.new(ODDB::AtcClass)
        @atc_class_mock.should_receive(:pointer).and_return(@pointer_mock)
        @atc_class_mock.should_receive(:pointer_descr).and_return(@atc_name)
        @atc_class_mock.should_receive(:code).and_return(@atc_name)
        return @atc_class_mock
      end
      def commercial_form_by_name(name)
        if name.match(/Fertigspritze/i)
          @commercial_mock = FlexMock.new(ODDB::CommercialForm)
          @commercial_mock.should_receive(:pointer).and_return(@pointer_mock)
          return @commercial_mock
        else
          return nil
        end
      end
      def create_registration(name)
        @registration_stub = ODDB::Registration.new(name)
        @registrations[name] = @registration_stub
        @registration_stub
      end
      def company_by_name(name, matchValue)
        @registration_stub
      end
      def registration(number)
        @registrations[number.to_s]
      end
      def sequence(number)
        @sequence_mock
      end
      def create_fachinfo
        @fachinfo
      end
      def odba_store
      end
      def odba_isolated_store
      end
      def delete_all_epha_interactions
		@epha_interactions = {}
      end
	  def create_epha_interaction(first, second)
		epha_interaction = ODDB::EphaInteraction.new
		@epha_interactions ||= {}
		@epha_interactions[[first,second]] = epha_interaction
		epha_interaction
	  end
      def update(pointer, values, reason = nil)
        @pointer = pointer
        @values = values
        if reason and reason.to_s.match('medical_product')
          return @commercial_mock
        end
        return @company_mock if reason and reason.to_s.match('company')
        if reason.to_s.match(/registration/)
          number = pointer.to_yus_privilege.match(/\d+/)[0]
          stub = Registration.new(number)
          @registrations[number] = stub
          return stub
        elsif reason and reason.to_s.eql?('text_info')
           return PseudoFachinfoDocument.new
        end
        return PseudoFachinfoDocument.new
        @pointer_mock
      end
      def log_group(key)
        @log_group
      end
      def create(pointer)
        @log_group
      end
      def recount
        'recount'
      end
    end

  class TestEphaInteractionPlugin <MiniTest::Unit::TestCase
    include FlexMock::TestCase
    
    def setup
      @app = StubApp.new
      @@datadir = File.expand_path '../data/csv/', File.dirname(__FILE__)
      @@vardir = File.expand_path '../var', File.dirname(__FILE__)
      assert(File.directory?(@@datadir), "Directory #{@@datadir} must exist")
      FileUtils.mkdir_p @@vardir
      ODDB.config.data_dir = @@vardir
      ODDB.config.log_dir = @@vardir
      @sequence = flexmock('sequence',
                           :packages => ['packages'],
                           :pointer => 'pointer',
                           :creator => 'creator')
      seq_ptr = flexmock('seq_ptr',
                          :pointer => 'seq_ptr.pointer')
      @pointer = flexmock('pointer',
                          :pointer => seq_ptr,
                          :packages => ['packages'])
      @sequence = flexmock('sequence',
                           :creator => @sequence)
      seq_ptr.should_receive(:+).with([:sequence, 0]).and_return(@sequence)
      @fileName = File.join(@@datadir, 'epha_interactions_de_utf8-example.csv')
      @latest = @fileName.sub('.csv', '-latest.csv')
      @agent = flexmock(Mechanize.new)
      @page  = flexmock('page')
      @page.should_receive(:body).by_default.and_return(IO.read(@fileName))
      @agent.should_receive(:get).and_return(@page)
    end
    
    def teardown
      FileUtils.rm_rf @@vardir
      super # to clean up FlexMock
    end

    def test_update_epha_interactions_update
      assert(File.exists?(@fileName), "File #{@fileName} must exist")
      @plugin = ODDB::EphaInteractionPlugin.new(@app, {})
      FileUtils.rm(@latest, :verbose => false) if File.exists?(@latest)
      assert(@plugin.update(@agent, @fileName))
      report = @plugin.report
      assert(report.match("EphaInteractionPlugin.update latest"))
      assert(report.match(/Added 1 interactions/))
    end
  end
end 
