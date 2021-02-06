$:.unshift File.dirname($0)
require "selenium-webdriver"
require "securerandom"
require "dotenv"
require "selenium_driver"
include SeleniumDriver

Dotenv.load File.dirname($0) + "/.env"
MANUAL_URL = ENV["MANUAL_URL"]
FESS_URL = ENV["FESS_URL"] || "http://localhost:8080"
FESS_USER = ENV["FESS_USER"] || "admin"
FESS_PASS = ENV["FESS_PASS"] || "admin"

def get_manual_data(driver)
  # get manual information
  driver.navigate.to MANUAL_URL

  # get version
  title = driver.find_element(:tag_name, "h1")
  version = title.text.split[-1]

  # get os type
  os_tag = driver.find_element(:class, "vmiddle")
  os_type = os_tag.attribute("alt")

  # get urls
  urls = []
  labelparams = []
  parent_url = MANUAL_URL.slice(/https:\/\/[a-zA-Z0-9.]+/)
  ps = driver.find_elements(:xpath, "//td/p")
  ps.each_with_index do |pe, i|
    b = pe.text.split('\n')
    a = pe.find_element(:tag_name, "a")
    url = parent_url + a.attribute('onclick').slice(/\/.+\/.+\.(html|pdf)/)
    urls.push(url)
    # modify url for label
    labelurl = url.gsub(/index.html$/, '.*')
    # modify name for label
    b[0].slice!(/PRIMECLUSTER /)
    name = b[0][0..(b[0].index('PDF')-1)] if b[0].index('PDF')
    labelparams.push({:name => name, :url => labelurl})
    # break if i > 5
  end
  return {
    :version => version,
    :os_type => os_type,
    :urls => urls,
    :labelparams => labelparams
  }
end

def fess_auto_login(driver)
  puts "start auto login"
  driver.navigate.to FESS_URL + "/login/"
  
  user = driver.find_element(:id, 'username')
  user.send_keys FESS_USER
  
  pass = driver.find_element(:name, 'password')
  pass.send_keys FESS_PASS
  
  login = driver.find_element(:name, 'login')
  login.click
  puts "end auto login"
end

def navigate_with_auto_login(driver, url)
  driver.navigate.to url
  if driver.current_url.include?('login')
    fess_auto_login(driver)
    driver.navigate.to url
  end
end

def create_web_crawl_setting(driver, manual_params)
  navigate_with_auto_login(driver, FESS_URL + "/admin/webconfig/createnew/")
  driver.find_element(:name, 'name').send_keys manual_params[:os_type] + ' ' + manual_params[:version]
  driver.find_element(:name, 'urls').clear
  driver.find_element(:name, 'urls').send_keys manual_params[:urls].join("\n")
  puts "Enter the following Manual URLs in crawl settings"
  puts  manual_params[:urls].join("\n")
  driver.find_element(:name, 'depth').send_keys 2
  driver.find_element(:name, 'numOfThread').clear
  driver.find_element(:name, 'numOfThread').send_keys 1
  driver.find_element(:name, 'intervalTime').clear
  driver.find_element(:name, 'intervalTime').send_keys 1000
  driver.find_element(:name, 'create').click
  driver.save_screenshot('fess-webconfig.png')
end

def create_labels(driver, manual_params)
  manual_params[:labelparams].each_with_index do |labelparam, i|
    navigate_with_auto_login(driver, FESS_URL + "/admin/labeltype/createnew/")
    driver.find_element(:name, 'name').send_keys labelparam[:name]
    driver.find_element(:name, 'value').send_keys SecureRandom.uuid.delete('-')[0..19]
    driver.find_element(:name, 'includedPaths').send_keys labelparam[:url]
    driver.find_element(:name, 'sortOrder').clear
    driver.find_element(:name, 'sortOrder').send_keys i
    driver.find_element(:name, 'create').click
    puts "create label = " + labelparam[:name]
  end
  # driver.save_screenshot('fess-label.png')
end

def start_web_crawl(driver)
  navigate_with_auto_login(driver, FESS_URL + "/admin/scheduler/")
  tds = driver.find_elements(:tag_name, "td")
  tds.each do |td|
    if td.text == "Default Crawler"
      puts "start_web_crawl"
      td.click
      driver.find_element(:class, "btn-success").click
      break
    end
  end
end

def stop_crawler(driver)
  navigate_with_auto_login(driver, FESS_URL + "/admin/scheduler/")
  tds = driver.find_elements(:tag_name, "td")
  tds.each do |td|
    if td.text == "Default Crawler"
      td.click
      begin
        stop = driver.find_element(:class, "btn-danger")
        puts "stop_crawler"
        stop.click
      rescue Selenium::WebDriver::Error::NoSuchElementError
      end
      break
    end
  end
end

driver = create_driver

# for selenium server
# driver = Selenium::WebDriver.for :remote, 
#   url: "http://localhost:4444/wd/hub",
#   desired_capabilities: :firefox

manual_params = get_manual_data(driver)
create_web_crawl_setting(driver, manual_params)
create_labels(driver, manual_params)
start_web_crawl(driver)
# stop_crawler(driver)