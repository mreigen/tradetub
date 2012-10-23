ENV["REDISTOGO_URL"] ||= "redis://mreigen:f1292b62466c4d4749157ad6d96a8a84@herring.redistogo.com:9704/"
uri = URI.parse(ENV["REDISTOGO_URL"])
Resque.redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)

Dir["#{Rails.root}/app/jobs/*.rb"].each { |file| require file }