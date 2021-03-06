#!/usr/bin/env ruby
# encoding: utf-8

# This is the most important integration test, which ensures that handling payment via paypal works
# It requires the following setup:
# * must be run on the server (to be able to check in the log for the URL for new users)
# * etc/oddb.yml must be configured to use the sandbox (check here in the code)
# * test-account on developer.paypal.com must exist and specified correctly
#

require 'spec_helper'
require 'pry'

@workThread = nil

describe "ch.oddb.org" do
  CompleteCheckout    = 0
  CancelCheckoutEarly = 1
  CancelCheckoutLater = 2
  OneYear             = 365
  OneMonth            = 30
  OneDay              = 1
	Password_Dummy      = '87654321'
  Six_Test_Drug_Names = [ 'Marcoumar', 'inderal', 'Sintrom', 'Incivo', 'Certican', 'Amikin']
  before :all do
    @idx = 0
    @act_id     = Time.now.strftime('%Y%m%d-%H%M%S')
		# the pwd used here must be changed also on the sandbox.paypal.com!!
    @customer_1 = { :email => 'customer-1@ywesee.com',       :pwd => '12345678', :family_name => 'Müller', :first_name => 'Max' }
    @customer_2 = { :email => 'poor_soul@ywesee.com',        :pwd => '87654321', :family_name => 'Wesen',  :first_name => 'Armes' }
    @receiver   = { :user =>  'test_paypal_api1.ywesee.com', :pwd => '1401791830',
                    :signature => 'ArMY3QHPQrA9ttub.wccQPPgmgPiAiJr7-05DWZV41xVYcNN9KNECII9',
                }
    @oddb_yml    = File.expand_path(File.join(__FILE__, '../../etc/oddb.yml'))

    check_paypal_setup
    waitForOddbToBeReady(@browser, OddbUrl)
  end

  before :each do
    @browser.goto OddbUrl
  end

  after :each do
    @idx += 1
    createScreenshot(@browser, '_'+@idx.to_s)
    # sleep
    @browser.goto OddbUrl
  end

   def check_paypal_setup
    error_msg = "File #{@oddb_yml} should exist and be correctly configured for sandbox.paypal.com"
    puts error_msg unless File.exists?(@oddb_yml)
    File.exists?(@oddb_yml).should == true
    oddb_config = IO.read(@oddb_yml)

    cmd = "curl -s --insecure https://api-3t.sandbox.paypal.com/nvp -d  \"USER=#{@receiver[:user]}&PWD=#{@receiver[:pwd]}&SIGNATURE=#{@receiver[:signature]}&METHOD=SetExpressCheckout&VERSION=98&PAYMENTREQUEST_0_AMT=10&PAYMENTREQUEST_0_CURRENCYCODE=USD&PAYMENTREQUEST_0_PAYMENTACTION=SALE&cancelUrl=http://ch.oddb.org/cancel.html&returnUrl=http://ch.oddb.org/return.hml\""
    res = `#{cmd}`
    okay = /ACK=Success/.match(res) != nil
    puts res
    puts "Paypal connection is #{okay ? 'okay' : 'not working'}"
    okay.should == true
  end

  def create_user_and_login(username)
    true.should == false
  end

  def init_paypal_checkout(customer)
    sleep(1) # is needed, don't know how to wait for link
    @browser.text_field(:name, "email").     set(customer[:email]) if @browser.text_field(:name, "email").enabled?
    @browser.text_field(:name, "pass").      set(customer[:pwd])   if @browser.text_field(:name, "pass").exists? and @browser.text_field(:name, "pass").enabled?
    @browser.text_field(:name, "set_pass_2").set(customer[:pwd])   if @browser.text_field(:name, "set_pass_2").exists? and  @browser.text_field(:name, "set_pass_2").enabled?
    @browser.text_field(:name, "name_last"). set(customer[:family_name])
    @browser.text_field(:name, "name_first").set(customer[:first_name])
  end

  def choose_medi_and_csv_display(customer)
    test_medi = Six_Test_Drug_Names.first
    if customer
      if res = login(customer[:email], customer[:pwd])
        puts "Login for customer successful"
      else
        puts "Login for customer failed first_time"
        logout
      end
    end
    @browser.text_field(:name, "search_query").set(test_medi)
    @browser.button(:name, "search").click; small_delay
    @browser.button(:value,"Resultat als CSV Downloaden").click
  end

  def paypal_common(customer, complete = CompleteCheckout)
    sleep(1) # must loose some time
    login_button = @browser.button(:name => /login_button/i)
    if login_button and login_button.exists?
      login_button.click
      @browser.window(:title => /Pay with a PayPal account/).wait_until_present
    end
    @browser.text_field(:id, "login_email").set(customer[:email])
    @browser.text_field(:id, "login_password").set(customer[:pwd])
    puts "PayPal: Log In"
    if complete == CancelCheckoutEarly
      @browser.button(:name,"cancel_return").click
    else
      @browser.button(:value,"Log In").click
      @browser.window(:title => /Angaben prüfen/).wait_until_present
      if complete == CancelCheckoutLater
        @browser.button(:name,"cancel_return").click
      else
        puts "PayPal: Jetzt zahlen. Must accept first #{@browser.button(:id => /accept.x/).exists?}"
        if @browser.button(:id => /accept.x/).exists?
          @browser.button(:id => /accept.x/).click
        else
          @browser.button(:value,"Jetzt zahlen").click
        end
        @browser.window(:title => /Ihre Zahlung ist jetzt/).wait_until_present
        puts "PayPal: Return to oddb.ch"
        @browser.button(:name,"merchant_return_link").click
        puts "URL after merchant_return_link was #{@browser.url}"
        @browser.window(:url => /paypal_return/).wait_until_present
      end
    end
    puts "URL after preceeding to paypal was #{@browser.url}"
  end

  def search_for_medi(name)
    waitForOddbToBeReady(@browser, OddbUrl)
    @browser.text_field(:name, "search_query").set(name)
    @browser.button(:name, "search").click; small_delay
  end

  def select_poweruser(duration = OneDay)
    waitForOddbToBeReady(@browser, OddbUrl)
    logout
    res = false
    saved = @idx
    Six_Test_Drug_Names.each {
      |name|
        search_for_medi(name)
        if /Abfragebeschränkung auf 5 Abfragen pro Tag/.match(@browser.text)
          res = true
          break
        end
        @idx += 1
    }
    (@idx -saved).should <= 5
    search_for_medi(Six_Test_Drug_Names.first) # I want a medi with few packages
    sleep(1) # delay a little
    if duration == OneYear
      @browser.radio(:name => 'days', :value => OneYear.to_s).set
    elsif duration ==  OneMonth
      @browser.radio(:name => 'days', :value => OneMonth.to_s).set
    else
      @browser.radio(:name => 'days', :value => OneDay.to_s).set
    end
    sleep 5
  end

  it "should be possible to checkout oddb.csv via paypal" do
    new_customer_email = "#{@act_id}@ywesee.com"
    customer = { :email => new_customer_email,  :pwd => Password_Dummy,
                    :family_name => 'Demo',
                    :first_name => 'Fritz' }
    waitForOddbToBeReady(@browser, OddbUrl)
		logout
		@browser.link(:name, "user").click; small_delay
    sleep(1) # is needed, don't know how to wait for link
		@browser.link(:name, "download_export").click; small_delay; small_delay
    @browser.select_list(:name, "compression").select("TAR/GZ")
		@browser.link(:name, "directlink_oddb_csv").click; small_delay # 500
    init_paypal_checkout(customer)
    @browser.select_list(:name, "business_area").select("Medi-Information")
		@browser.text_field(:name, "address").set 'Adresse'
		@browser.text_field(:name, "plz").set 'plz'
		@browser.text_field(:name, "city").set 'city'
		@browser.text_field(:name, "phone").set 'phone'
    puts "email #{new_customer_email}: URL before preceeding to paypal was #{@browser.url}"
    @browser.button(:name => /checkout/).click; small_delay
    paypal_common(@customer_1)
    @browser.text.should_not match /Ihre Bezahlung ist von PayPal noch nicht bestätigt worden./
    @browser.text.should match /Vielen Dank! Sie können jetzt mit dem untigen Link die Daten downloaden./
    createScreenshot(@browser, 'paypal_oddb_csv')
    link = @browser.link(:name => 'download')
    link.exists?.should be true
    link.click; small_delay
    @browser.url.should_not match  /errors/
    @browser.url.should_not match /appdown/
  end if false

  it "should be checkout via paypal a poweruser" do
    select_poweruser(OneDay)
    new_customer_email = "#{@act_id}@ywesee.com"
    customer = { :email => new_customer_email,  :pwd => Password_Dummy,
                    :family_name => 'Demo',
                    :first_name => 'Fritz' }
    puts "email #{new_customer_email}: URL before preceeding to paypal was #{@browser.url}"
    @browser.button(:name, "proceed_poweruser").click; small_delay
    init_paypal_checkout(customer)
    @browser.button(:name => 'checkout').click; small_delay
    @browser.text.should_not match /Ihre Bezahlung ist von PayPal noch nicht bestätigt worden./
    paypal_common(@customer_1)
    forward_to_home = @browser.link(:name => 'forward_to_home')

    puts "PayPal: Payment okay? #{forward_to_home.exists?}  #{forward_to_home.exists? ? forward_to_home.href : 'no href'}"
    forward_to_home.exists?.should be true
    createScreenshot(@browser, 'paypal_poweruser')
    @browser.url.should_not match /appdown/
    forward_to_home.click; small_delay
    @browser.url.should match OddbUrl
    saved = @idx
    # ensure that login a new power user works and that he can visit as many drugs as he wants
    logout
    login(customer[:email], customer[:pwd])
    Six_Test_Drug_Names.each {
      |name|
        search_for_medi(name)
        @browser.text.should_not match /Abfragebeschränkung auf 5 Abfragen pro Tag/
    }
  end

  it "should return a correct link to a CSV file if the payment is okay" do
    @browser.goto OddbUrl
    new_customer_email = "#{@act_id}@ywesee.com"
    customer = { :email => new_customer_email,  :pwd => Password_Dummy,
                    :family_name => 'Demo',
                    :first_name => 'Fritz' }
    puts "email #{new_customer_email}: URL before preceeding to paypal was #{@browser.url}"
    choose_medi_and_csv_display(nil)
    init_paypal_checkout(customer)
    @browser.button(:name => /checkout/).click; small_delay
    paypal_common(@customer_1)
    filesBeforeDownload =  Dir.glob(GlobAllDownloads)
    @browser.text.should_not match /Ihre Bezahlung ist von PayPal noch nicht bestätigt worden/
    @browser.url.should_not match  /errors/
    @browser.text.should match /Vielen Dank! Sie können jetzt mit dem untigen Link die Daten downloaden./
    createScreenshot(@browser, 'paypal_csv_okay')
    link = @browser.link(:name => 'download')
    link.exists?.should be true
    link.click; small_delay
    @browser.url.should_not match /errors/
    @browser.url.should_not match /appdown/
    sleep(1) # it takes some time to download the file
    filesAfterDownload =  Dir.glob(GlobAllDownloads)
    diffFiles = (filesAfterDownload - filesBeforeDownload)
    diffFiles.size.should == 1
    IO.read(diffFiles.first).should match /#{Six_Test_Drug_Names.first}/i
  end

  it "should not download a CSV file if the payment was not accepted" do
    @browser.goto OddbUrl
    filesBeforeDownload =  Dir.glob(GlobAllDownloads)
    choose_medi_and_csv_display(@customer_2)
    init_paypal_checkout(@customer_2)
    @browser.button(:name => 'checkout_paypal').click; small_delay
    paypal_common(@customer_2)
    @browser.text.should_not match /Ihre Bezahlung ist von PayPal noch nicht bestätigt worden/
    @browser.url.should_not match  /errors/
    sleep(1) # it takes some time to download the file
    filesAfterDownload =  Dir.glob(GlobAllDownloads)
    diffFiles = (filesAfterDownload - filesBeforeDownload)
    diffFiles.size.should == 0
  end

  it "should be possible to cancel a paypal before login" do
    waitForOddbToBeReady(@browser, OddbUrl)
    @browser.goto OddbUrl
    choose_medi_and_csv_display(@customer_1)
    init_paypal_checkout(@customer_1)
    @browser.button(:name => 'checkout_paypal').click; small_delay
    paypal_common(@customer_1, CancelCheckoutEarly)
    puts "URL after #{@browser.url} OddbUrl"
    createScreenshot(@browser, 'paypal_csv_payment_cancelled')
    @browser.text.should_not match /Ihre Bezahlung ist von PayPal noch nicht bestätigt worden./
    @browser.url.index(OddbUrl).should_not be nil
  end

  it "should be possible to cancel a paypal after login but before paying" do
    waitForOddbToBeReady(@browser, OddbUrl)
    @browser.goto OddbUrl
    choose_medi_and_csv_display(@customer_1)
    init_paypal_checkout(@customer_1)
    @browser.button(:name => 'checkout_paypal').click; small_delay
    paypal_common(@customer_1, CancelCheckoutLater)
    puts "URL after #{@browser.url} OddbUrl"
    @browser.text.should_not match /Ihre Bezahlung ist von PayPal noch nicht bestätigt worden./
    @browser.url.index(OddbUrl).should_not be nil
  end
  after :all do
    @browser.close
  end
end unless ['just-medical'].index(Flavor)
