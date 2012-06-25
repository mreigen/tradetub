# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
Barzit::Application.initialize!

Barzit::Application.configure do
  config.gem 'paperclip'
end