load "parsers/craigslist.rb"

module Parser
  
  def self.parse_item_list(options)
    closest_city_code = options[:closest_city_code]
    sub_area = options[:sub_area]
    page = options[:page]
    query = options[:query]
    source = options[:source]
    state_code = options[:state_code]
    country_name_code = options[:country_name_code]
    limit = options[:limit]
    limit = limit.to_i unless limit.blank?

    ret_array = []

    case source
    when "cl"
      # getting the city code of the closest city supported by CL
      closest_city_code = Craigslist::get_closest_city_code({ :source => source, :lat => options[:lat], :lng => options[:lng] })
      return [] if closest_city_code.blank?

      cl_search_url = "http://#{closest_city_code}.craigslist.org/search/sss#{sub_area.blank? ? '' : '/' + sub_area}?query=#{query}&minAsk=&maxAsk=&hasPic=1&format=rss&srchType=T&s=#{15*page}"
      feed = Feedzirra::Feed.fetch_and_parse(cl_search_url)

      counter = 0
      feed.entries.each do |e|
        @ret = parse_item(options.merge({:link => e.url, :fields => %w(price image)}))
        ret_array.push(@ret) unless @ret.blank?
      end # end for

      # create a new thread, run the caching inside this thread
      Thread.new {
        ret_array.each do |ra|
          parsed_item = parse_item({ :source => "cl", :link => ra[:url] })
          unless parsed_item.is_a?(CachedItem)
            Resque.enqueue(CacheItemsJob, parsed_item, state_code)
          end
        end
      }
    end #end case

    ret_array
  end
  
  def self.parse_item(parse_options)
    source = parse_options[:source]
    case source
    when "cl"
      guid = Digest::MD5.hexdigest(parse_options[:link] + "-cl")
      already_cached_item = CachedItem.find_by_guid(guid)
      if already_cached_item.blank?
        Craigslist::parse(parse_options)
      else
        already_cached_item
      end
    end # end case
  end
  
end