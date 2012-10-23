module CacheItemsJob
  @queue = :cached_items
  
  def self.perform(parsed_item, state_code)
    puts "parsed_item = "
    #puts parsed_item
    puts "state_code"
    #puts state_code
    return if parsed_item.blank? || parsed_item.is_a?(CachedItem)
    puts "after return if..."
    # getting lat / long
    # title has location inside (...)
    lat, lng, zip = parse_cl_location(parsed_item[:title], state_code)
    parsed_item[:lat] = lat unless lat.blank?
    parsed_item[:lng] = lng unless lng.blank?
    parsed_item[:zip] = zip unless zip.blank?

    new_cached_item = CachedItem.create(parsed_item)
    puts "new_cached_item"
    puts new_cached_item
  end
  
  def self.parse_cl_location(title, state_code)
    location = /\(.*\)/.match(title).to_s
    unless location.blank?
      location.gsub!("(", "").gsub!(")", "")
      location += (", " + state_code) unless location.include?(",")
      parsed_location = Geokit::Geocoders::GoogleGeocoder.reverse_geocode(location)
      puts [parsed_location.lat, parsed_location.lng, parsed_location.zip]
      return parsed_location.lat, parsed_location.lng, parsed_location.zip
    end
    return nil, nil, nil
  end
  
  def self.parse_cl_price(title)
    price = /\$[\d]+/.match(title).to_s
    price.gsub!("$", "")
  end
  
end