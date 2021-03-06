#!/usr/bin/env ruby
# encoding: utf-8
# kate: space-indent on; indent-width 2; mixedindent off; indent-mode ruby;
require 'spec_helper'
require 'pp'

describe "ch.oddb.org" do

  before :all do
    @idx = 0
    waitForOddbToBeReady(@browser, OddbUrl)
    login
  end

  before :each do
    @browser.goto OddbUrl
    if @browser.link(:text=>'Plus').exists?
      puts "Going from instant to plus"
    @browser.link(:text=>'Plus').click
    end
  end

  after :each do
    @idx += 1
    createScreenshot(@browser, '_'+@idx.to_s)
    # sleep
    @browser.goto OddbUrl
  end

  after :all do
    @browser.close
  end

  def session_uniq_email
     "#{get_session_timestamp}@ywesee.com"
  end

    possible_rights_are = %(
edit yus.entities
login org.oddb.RootUser
login org.oddb.AdminUser
login org.oddb.PowerUser
login org.oddb.CompanyUser
login org.oddb.PowerLinkUser
edit org.oddb.drugs
edit org.oddb.powerlinks
create org.oddb.registration
create org.oddb.task.background
edit org.oddb.model.!company.*
edit org.oddb.model.!sponsor.*
edit org.oddb.model.!indication.*
edit org.oddb.model.!galenic_group.*
edit org.oddb.model.!address.*
edit org.oddb.model.!atc_class.*
view org.oddb.patinfo_stats
view org.oddb.patinfo_stats.associated
credit org.oddb.download
)
  def create_or_update_user(email = session_uniq_email, yus_rights= ['yus_privileges[login|org.oddb.CompanyUser]'])
    @browser.goto OddbUrl
    login
    @browser.link(:text=>'Admin').click
    @browser.link(:text=>'Benutzer').click
    @browser.button(:name => 'new_user').click
    if @browser.link(:text => /#{email}/).exists?
      @browser.goto OddbUrl
    end
    @browser.text_field(:name => 'name').set email
    @browser.text_field(:name => 'name_last').set "Familie #{get_session_timestamp}"
    @browser.text_field(:name => 'name_first').set 'Hans'
    @browser.text_field(:name => 'address').set 'Im Dorf'
    @browser.text_field(:name => 'plz').set Time.now.strftime('%H%M')
    @browser.text_field(:name => 'city').set 'Irgendwo'
    yus_rights.each {|right| @browser.checkbox(:name => right).set }
    @browser.button(:name => 'update').click
    @browser.goto OddbUrl
    login
    @browser.link(:text=>'Admin').click
    @browser.link(:text=>'Benutzer').click
    @browser.link(:text => /#{email}/).exists?.should == true
    @browser.goto OddbUrl
  end

  def upload_pat_info(original)
    File.exists?(original).should be true
    @browser.select_list(:name, "search_type").select("Swissmedic-# (5-stellig)")
    @browser.text_field(:id, "searchbar").set("43788")
    @browser.button(:value,"Suchen").click
    @browser.link(:name, "seqnr").click
    @browser.link(:name, "ikscd").click
    if @browser.button(:name,"delete_patinfo").exists?
      @browser.button(:name,"delete_patinfo").click
    end
    @browser.link(:text, "PI").exists?.should be false
    @browser.file_field(:name =>  "patinfo_upload").set(original)
    @browser.button(:name,"update").click
    @browser.link(:text, "PI").exists?.should be true
    diffFiles = check_download(@browser.link(:text, "PI"))
    diffFiles.size.should == 1
    FileUtils.compare_file(original, diffFiles.first).should be true
  end

  def check_sort(link_name)
    @browser.link(:name => link_name).exists?.should be true
    @browser.link(:name => link_name).click
    text_before = @browser.text
    text_before.should_not match /RangeError/i
    text_before.size.should > 100
    @browser.link(:name => link_name).exists?.should be true
    @browser.link(:name => link_name).click
    text_after = @browser.text
    text_after.should_not match /RangeError/i
    text_after.size.should > 100
    text_after.should_not eql? text_before
  end

  # we do this for two files to be ensure that the upload really was done
  originals =  [ File.expand_path(File.join(__FILE__, '../../test/data/dummy_patinfo.pdf')),
    File.expand_path(File.join(__FILE__, '../../test/data/dummy_patinfo_2.pdf'))
  ]
  originals.each { |original|
           it "should be possible to upload #{File.basename(original)} to a given package" do
             FileUtils.compare_file(originals[0], originals[1]).should_not be true
             upload_pat_info(original)
           end
         }

  it "should be possible to create a CompanyUser" do
    create_or_update_user
  end

  [ 'th_affiliations', 'th_name_first', 'th_name_last', 'th_email'].each {
    |link_name|
      it "should be possible to sort users by #{link_name.sub('th_','')}" do
        pending # does not work (september 2014)
        @browser.goto OddbUrl
        login
        @browser.link(:text=>'Admin').click
        @browser.link(:text=>'Benutzer').click
        check_sort(link_name)
      end
  }
end
