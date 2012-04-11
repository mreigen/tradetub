# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
ActiveadminDepot::Application.initialize!

ActiveadminDepot::Application.configure do
  config.gem 'paperclip'
end