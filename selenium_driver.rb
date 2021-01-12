module SeleniumDriver
  def create_driver(headless=true)
    options = Selenium::WebDriver::Firefox::Options.new
    options.add_argument('-headless') if headless
    driver = Selenium::WebDriver.for :firefox, options: options
    return driver
  end
end