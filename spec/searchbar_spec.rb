#!/usr/bin/env ruby
# encoding: utf-8
# kate: space-indent on; indent-width 2; mixedindent off; indent-mode ruby;
require 'spec_helper'
require 'pp'
require 'tmpdir'
require "selenium-webdriver"

describe "ch.oddb.org" do

  def enter_search_to_field_by_name(search_text, field_name)
    idx = -2
    chooser = @browser.text_field(:name,field_name)
    0.upto(2).each{ 
      |idx|
      break if chooser and chooser.present?
      sleep 1
      chooser = @browser.text_field(:name,field_name)
    }
    unless chooser and chooser.present?
      msg = "idx #{idx} could not find textfield #{field_name} in #{@browser.url}"
      puts msg
      # require 'pry'; binding.pry
      raise msg
    end
    0.upto(30).each{ |idx|
                      begin
                        chooser.set(search_text)
                        sleep idx*0.1
                        chooser.send_keys(:down)
                        sleep idx*0.1
                        chooser.send_keys(:enter)
                        sleep idx*0.1
                        value = chooser.value
                        break unless /#{search_text}/.match(value)
                        sleep 0.5
                      rescue StandardError => e
                        puts "in rescue"
                        createScreenshot(@browser, "rescue_#{search_text}_#{__LINE__}")
                        puts e.inspect
                        puts caller[0..5]
                        return
                      end
                    }
    chooser.set(chooser.value + "\n")
    # puts "chooser value #{chooser.value} text  #{chooser.text}"
    createScreenshot(@browser, "_#{search_text}_#{__LINE__}")
  end
  
  before :all do
    $prescription_test_id = 1
    waitForOddbToBeReady(@browser, OddbUrl)
    login
  end

  before :each do
    @timestamp = Time.now.strftime('%Y%m%d%H%M%S')
    # puts "before #{$prescription_test_id} with #{@browser.windows.size} windows"
    while @browser.windows.size > 1
      @browser.windows.first.use
      @browser.windows.last.close if @browser.windows.last
    end
    @browser.goto OddbUrl
  end

  def enter_fachinfo_search
    if @browser.link(:name=>'fachinfo_search').exists?
      @browser.link(:name=>'fachinfo_search').click;  small_delay

    end
  end
  
  after :each do
    createScreenshot(@browser, '_'+$prescription_test_id.to_s) if @browser
    $prescription_test_id += 1
  end

  { '125Dihydroxycholecalciferol 1000' => '1,25-Dihydroxycholecalciferol',
    '125'                              => '125',
    '125'                              => '1,25-Dihydroxycholecalciferol',
    '125Dihydroxycholecalciferol'      => '1,25-Dihydroxycholecalciferol',
  }.each {
    |searchterm, searchtext|
    it "should be possible to find #{searchtext} when searching via #{searchterm} in analysen" do
      @browser.link(:name,'analysis').click;  small_delay

      small_delay unless @browser.text_field(:name, "search_query").exists?
      @browser.text_field(:name, "search_query").value = searchterm
      @browser.button(:name => 'search').click;  small_delay

      @browser.text.should_not match LeeresResult
      @browser.text.should match /#{searchtext}/
    end
  }  unless ['just-medical'].index(Flavor)

  chapters = {
    'Unerw.Wirkungen' => 'Kopfschmerzen',
    'Dos./Anw.' => 'Kinder',
    'Interakt.' => 'Tocilizumab',
  }
  chapters.each{ |chapter_name, text|
    it "should should work (58868 Actemra) with #{chapter_name} and #{text}" do
      enter_fachinfo_search
      enter_search_to_field_by_name('Actemra', 'searchbar');

      @browser.select_list(:name, "fachinfo_search_type").select(chapter_name)
      @browser.checkbox(:name,'fachinfo_search_full_text').set
      @browser.text_field(:name => 'fachinfo_search_term').set(text)
      @browser.text_field(:name => 'fachinfo_search_term').send_keys :tab
      @browser.button(:id => 'fi_search').click;  small_delay

      @browser.text.should match text
      @browser.text.should match /Actemra/
    end
  }
  it "should should be possible to add and delete several drugs:" do
    enter_fachinfo_search
    @browser.text.should_not match /Actemra/
    @browser.text.should_not match /Aspirin/
    enter_search_to_field_by_name('Actemra', 'searchbar');
    enter_search_to_field_by_name('Aspirin', 'searchbar');
    @browser.text.should match /Actemra/
    @browser.text.should match /Aspirin/
    @browser.element(:id => /minus_Actemra/i).click;  small_delay

    @browser.text.should_not match /Actemra/
    @browser.text.should match /Aspirin/
    @browser.element(:id => /minus_Aspirin/i).click;  small_delay

    @browser.text.should_not match /Actemra/
    @browser.text.should_not match /Aspirin/
    # @browser.url.should match /fachinfo_search\/$/
  end

  it "should should be possible to delete all drugs:" do
    enter_fachinfo_search
    @browser.text.should_not match /Actemra/
    @browser.text.should_not match /Aspirin/
    enter_search_to_field_by_name('Actemra', 'searchbar');
    enter_search_to_field_by_name('Aspirin', 'searchbar');
    enter_search_to_field_by_name('Ponstan', 'searchbar');
    @browser.text.should match /Actemra/
    @browser.text.should match /Aspirin/
    @browser.text.should match /Ponstan/
    @browser.element(:name => 'delete').click;  small_delay
; small_delay
    @browser.text.should_not match /Actemra/
    @browser.text.should_not match /Aspirin/
    @browser.text.should_not match /Ponstan/
    @browser.url.should match /fachinfo_search\/$/
  end

  it "should work with the privatetemplate searchbar" do
    field_name = 'search_query'
    @browser.links.find{ |item| item.href.match(/fachinfo\/swissmedic/) != nil}.click;  small_delay

    @browser.text_field(:name => field_name).text.should == ""
    @browser.text_field(:name => field_name).value.should == "HIER Suchbegriff eingeben"
    @browser.text_field(:name => field_name).value = 'Aspirin'
    @browser.text_field(:name => field_name).send_keys :enter
    @browser.url.should match /search_query/
    @browser.url.should match /Aspirin/
    @browser.text.scan(/aspirin/i).count.should > 10 # was 17 in august 2014
  end unless ['just-medical'].index(Flavor)

  it "should be possible to find Dr. Peter Schönbucher via doctors " do
    @browser.link(:name, "doctors").click;  small_delay

    @browser.text_field(:name, "search_query").value = "Schönbucher"
    @browser.button(:name, 'search').click;  small_delay

    @browser.text.should match /Schönbucher Peter/
  end unless ['just-medical'].index(Flavor)

  it "should be possible to find Abacavir via Wirkstoffe" do
    @browser.link(:name, 'substances').click;  small_delay
    # @browser.text.should_not match /substance_search_explain/
    @browser.text_field(:name, "search_query").value = "Abacavirum"
    @browser.button(:name, 'search').click;  small_delay

    @browser.text.should_not match LeeresResult
    @browser.text.should match /Deutsche Bezeichnung/
    @browser.text.should match /Abacavir/
  end unless ['just-medical'].index(Flavor)

  it "should be possible to find the Kantonsspital Glarus via Spital" do
    @browser.link(:name, 'hospitals').click;  small_delay

    # @browser.text.should_not match /substance_search_explain/
    @browser.text_field(:name, "search_query").value = "Glarus"    
    @browser.button(:name, 'search').click;  small_delay

    @browser.text.should_not match LeeresResult
    @browser.text.should match /Abteilung/
    @browser.text.should match /Kantonsspital Glarus/
  end unless ['just-medical'].index(Flavor)

  it "should be possible to find Krücke via MiGeL" do
    @browser.link(:name, 'migel').click;  small_delay

    # @browser.text.should_not match /substance_search_explain/
    @browser.text_field(:name, "search_query").value = "Krücke"    
    @browser.button(:name, 'search').click;  small_delay

    @browser.text.should_not match LeeresResult
    @browser.text.should match /Beschreibung/
    @browser.text.should match /Krücken/
  end unless ['just-medical'].index(Flavor)

  it "should be possible to find Novartis via Zulassungsinhaber" do
    @browser.link(:name, 'companies').click;  small_delay

    # @browser.text.should_not match /substance_search_explain/
    @browser.text_field(:name, "search_query").value = "Novartis"    
    @browser.button(:name, 'search').click;  small_delay

    @browser.text.should_not match LeeresResult
    @browser.text.should match /Aktuelle Einträge/
    @browser.text.should match /Novartis Pharma Schweiz AG/
  end unless ['just-medical'].index(Flavor)

  pending "should work with the notify searchbar" do
    false.should == true
  end

  pending "should work with the notify_confirm searchbar" do
    false.should == true
  end

  pending "should work with the drugs/fachinfos searchbar" do
    false.should == true
  end

  pending "should work with the drugs/vaccines searchbar" do
    false.should == true
  end

  pending "should work with the drugs/limitationtexts searchbar" do
    false.should == true
  end

  pending "should work with the drugs/feedbacks searchbar" do
    false.should == true
  end

  pending "should work with the drugs/patinfos searchbar" do
    false.should == true
  end

  pending "should work with the  drugs/sequences searchbar" do
    false.should == true
  end

  pending "should work with the drugs/resultlimit searchbar" do
    false.should == true
  end

  pending "should work with the substances/result searchbar" do
    false.should == true
  end

  it "should be possible to find Budenofalk and Budesonid Sandoz via combined search" do
    @browser.link(:name, 'drugs').click;  small_delay

    @browser.select_list(:name, "search_type").select("Preisvergleich und Inhaltsstoff")
    @browser.text_field(:name, "search_query").value = "Budesonid"
    @browser.button(:name, 'search').click;  small_delay

    text = @browser.text.clone
    text.should_not match LeeresResult
    text.should match('Budesonid Sandoz') # by price
    text.should match('Budenofalk')       # by component
  end unless ['just-medical'].index(Flavor)

  after :all do
    @browser.close
  end
end