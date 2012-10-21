class CachingItemThread
  
  def self.push_item(ret_data, state_code)
    # getting lat / long
    # title has location inside (...)
    lat, lng, zip = parse_cl_location(ret_data[:title], state_code)
    ret_data[:lat] = lat unless lat.blank?
    ret_data[:lng] = lng unless lng.blank?
    ret_data[:zip] = zip unless zip.blank?
    # getting price
    # title has price in the format of $xxxx
    
    #raise ret_data.inspect
  end
  
  def self.parse_cl_location(title, state_code)
    location = /\(.*\)/.match(title).to_s
    unless location.blank?
      location.gsub!("(", "").gsub!(")", "")
      location += (", " + state_code) unless location.include?(",")
      parsed_location = Geokit::Geocoders::GoogleGeocoder.reverse_geocode(location)
      return parsed_location.lat, parsed_location.lng, parsed_location.zip
    end
    return nil, nil, nil
  end
  
end

class Api::V1::ItemsController < ApplicationController
  def show
    @item = Item.find(params[:id])
    @user = User.find(@item.user_id)
    @ret = {}
    
    render :json => {:error => "missing url"}, :status => 500 and return if params[:url].blank?
    
    parse_options = {
      :user => @user,
      :link => params[:url]
    }
    case params[:source]
    when "ebay"
      parse_options[:source] = "ebay"
    when "cl"
      parse_options[:source] = "cl"
    when "oodle"
      parse_options[:source] = "oodle"
    when "etsy"
      parse_options[:source] = "etsy"
    else
      # our items are priority
      @ret = {
        :id => @item.id,
        :title => @item.title,
        :description => @item.description,
        :image => @item.image_uploads.first.image.url,
        :price => @item.price,
        :cat_id => @item.cat_id,
        :link => nil,
        :lat => nil,
        :long => nil,
        :zip => nil,
        :posted_at => @item.created_at,
        :user_id => @user.id,
        :phone => nil,
        :email => @user.email,
        :text => nil
      }
    end
       
    @ret = parse_item(parse_options) if @ret.blank?
    
    if params[:key] == "123"
      render :status => 200, :json => @ret
    end
  end
  
  def test
    # scrape city codes
    city_codes = []
    city_names = []
    state_name = ""
    @ret = []
    
    doc = Nokogiri::HTML(open("http://www.craigslist.org/about/sites"))
    doc.css(".state_delimiter").children().each do |state|
      state_name = state.text
      state.parent.next_element.css("li a").children().each do |a|
        _ret = {:state => state_name}
        city_code = a.parent["href"]
        city_code = city_code.to_s.gsub(/\.craigslist\..*/, "").gsub(/http:\/\//, "")
        city_codes.push(city_code)
        _ret[:city_code] = city_code
        
        a = a.to_s
        if a.downcase != state_name.downcase
          a = a + ", " + state_name
        end
        city_names.push(a)
        _ret[:city] = a
        
        a = CGI.escape(a)
        url = URI.parse("http://maps.googleapis.com/maps/api/geocode/json?address=#{a}&sensor=false")
        
        res = Net::HTTP.get(url)
        parsed_json = ActiveSupport::JSON.decode(res)
        location_results = parsed_json["results"]
        _location = {}
        unless location_results.blank?
          location = location_results[0]["geometry"]["location"]
          lat = location["lat"]
          lng = location["lng"]
          _location = {:lat => lat, :lng => lng}
        end
        _ret[:location] = _location
        
        @ret.push(_ret)
      end
      
    end
    
    
    # find state by lat and long
    # http://maps.googleapis.com/maps/geo?q=37.714224,-112.961452&output=json&sensor=false
    
    render :json => @ret.to_json
  end
  
  def string_difference_percent
    a = params[:a]
    b = params[:b]
    
    longer = [a.size, b.size].max
    same = a.each_char.zip(b.each_char).select { |a,b| a == b }.size
    render :json => ((longer - same) / a.size.to_f).to_json
  end
  
  def list
    lat = params[:lat]
    lng = params[:lng]
    zip = params[:zip]
    query = params[:query] || ""
    query = CGI::escape(query)
    
    # craigslist only
    sub_area = params[:sub_area] || ""
    page = params[:page]
    page = page.blank? ? 0 : page.to_i
    
    if !lat.blank? && !lng.blank?
      geo_query = "#{lat},#{lng}"
    elsif !zip.blank?
      geo_query = zip
    end
    
    @ret_array = []
    
    res = Geokit::Geocoders::GoogleGeocoder.reverse_geocode(geo_query)
    country_name_code = res.country
    state_code = res.state
    
    if !zip.blank?
      lat = res.lat
      lng = res.lng
    end
    
    parse_options = {
      :sub_area => "",
      :page => page,
      :query => query,
      :lat => lat,
      :lng => lng,
      :zip => zip,
      :state_code => state_code,
      :country_name_code => country_name_code
    }
    case params[:source]
    when "ebay"
      parse_options[:source] = "ebay"
    when "cl"
      parse_options[:source] = "cl"
    when "oodle"
      parse_options[:source] = "oodle"
    when "etsy"
      parse_options[:source] = "etsy"
    end
    
    @ret_array = parse_item_list(parse_options)
    if params[:key] == "123"
      render :status => 200, :json => @ret_array
    end
  end
  
  def parse_item_list(options)
    closest_city_code = options[:closest_city_code]
    sub_area = options[:sub_area]
    page = options[:page]
    query = options[:query]
    source = options[:source]
    state_code = options[:state_code]
    country_name_code = options[:country_name_code]
    
    ret_array = []
    
    case source
    when "cl"
      # getting the city code of the closest city supported by CL
      closest_city_code = get_closest_city_code({ :source => source, :lat => options[:lat], :lng => options[:lng] })
      return [] if closest_city_code.blank?
    
      cl_search_url = "http://#{closest_city_code}.craigslist.org/search/sss#{sub_area.blank? ? '' : '/' + sub_area}?query=#{query}&minAsk=&maxAsk=&hasPic=1&format=rss&srchType=A&s=#{15*page}"
      feed = Feedzirra::Feed.fetch_and_parse(cl_search_url)
    
      feed.entries.each do |e|
        url = e.url
        @ret = {
          :guid => Digest::MD5.hexdigest(url + "-cl"),
          :title => e.title,
          :description => e.summary,
          :posted_at => e.published,
          :url => e.url,
          :source => "cl",
          :lat => nil,
          :lng => nil,
          :zip => nil
        }
        ret_array.push(@ret)
      
        #CachingItemThread.push_item(@ret, state_code)
        Thread.new { CachingItemThread.push_item(@ret, state_code) }
      end
    end #end case
    
    ret_array
  end
  
  def parse_item(parse_options)
    source = parse_options[:source]
    case source
    when "cl"
      get_cl_info(parse_options)
    end # end case
  end
  
  def get_closest_city_code(options)
    source = options[:source]
    lat = options[:lat]
    lng = options[:lng]
    
    case source
    when "cl"
      # HARD CODED USA FOR NOW
      country_info = cl_city_site_info("usa")
      city_info = country_info.collect {|city| { :city_code => city["city_code"], :location => city["location"] } }
    
      min_distance = 999999.99
      closest_city_code = ""
      city_info.each do |c|
        ll = c[:location]
        city_lat = ll["lat"]
        city_lng = ll["lng"]
        curr_distance = distance(city_lat, city_lng, lat, lng)
      
        if min_distance > curr_distance
          min_distance = curr_distance
          closest_city_code = c[:city_code]
        end
      end
    end
    
    closest_city_code
  end
  
  def get_cl_info(options)
    user = options[:user]
    link = options[:link]
    
    doc = Nokogiri::HTML(open(link))
    # see if this posting "has been flagged for removal"
    render :json => {:error => "item has been removed"}, :status => 500 and return if (/has been flagged for removal/.match(doc.at_css("#userbody")))
    
    # scrape title
    title = doc.at_css("body h2").text
    
    # scrape description
    description = ""
    doc.css("#userbody").children().each do |child|
      description += child.text if child.type() == 3
    end
    
    # scrape price
    price = /\$[\d]+/.match(title).to_s
    price ||= /\$[\d]+/.match(description).to_s
    price.gsub!(/\$/,"")
    
    # scrape posted time
    posted_at_tag = doc.at_css(".postingdate")
    posted_at = posted_at_tag.blank? ? nil : posted_at_tag.text.to_datetime
    
    # main image
    image_tag = doc.at_css("div.iw img")
    image = image_tag.blank? ? nil : image_tag["src"]
    
    # scrape email
    email_tag = doc.at_css("a[href ^= 'mailto']")
    email = email_tag["href"].gsub!("mailto:","").to_s unless email_tag.blank?
    
    # phone number
    phone = /\(?([0-9]{3})\)?[-. ]?([0-9]{3})[-. ]?([0-9|zero]{4})/.match(description).to_s
    phone.gsub!(/[-. ]/, "")
    
    @ret = {
      :id => nil,
      :title => title,
      :description => description,
      :image => image,
      :thumb => image.gsub(/craigslist\.org\//, "craigslist.org/thumb/"),
      :medium => image.gsub(/craigslist\.org\//, "craigslist.org/medium/"),
      :price => price,
      :lat => nil,
      :long => nil,
      :zip => nil,
      :posted_at => posted_at,
      :user_id => user.id,
      :phone => phone,
      :email => email,
      :text => phone
    }
  end
  
  def radian(x)
    #PI = 3.141592653589793
    return x * 3.141592653589793 / 180
  end
  
  def distance(lat1, lng1, lat2, lng2)
    return Geocoder::Calculations.distance_between([lat1.to_f, lng1.to_f], [lat2.to_f, lng2.to_f])
  end
  
  # region => usa, canada, asia, europe, oceana, australia, south_america, africa
  def cl_city_site_info(region)
    usa = [{
      "state" => "AL",
      "city_code" => "auburn",
      "city" => "auburn, AL",
      "location" => {
        "lat" => 32.6098566,
        "lng" => -85.48078249999999
      }
    },
    {
      "state" => "AL",
      "city_code" => "bham",
      "city" => "birmingham, AL",
      "location" => {
        "lat" => 33.5206608,
        "lng" => -86.80248999999999
      }
    },
    {
      "state" => "AL",
      "city_code" => "dothan",
      "city" => "dothan, AL",
      "location" => {
        "lat" => 31.2232313,
        "lng" => -85.3904888
      }
    },
    {
      "state" => "AL",
      "city_code" => "shoals",
      "city" => "florence / muscle shoals, AL",
      "location" => {
        "lat" => 34.7448112,
        "lng" => -87.66752919999999
      }
    },
    {
      "state" => "AL",
      "city_code" => "gadsden",
      "city" => "gadsden-anniston, AL",
      "location" => {
        "lat" => 32.9807725,
        "lng" => -85.40309690000001
      }
    },
    {
      "state" => "AL",
      "city_code" => "huntsville",
      "city" => "huntsville / decatur, AL",
      "location" => {
        "lat" => 34.6059253,
        "lng" => -86.9833417
      }
    },
    {
      "state" => "AL",
      "city_code" => "mobile",
      "city" => "mobile, AL",
      "location" => {
        "lat" => 30.6943566,
        "lng" => -88.04305409999999
      }
    },
    {
      "state" => "AL",
      "city_code" => "montgomery",
      "city" => "montgomery, AL",
      "location" => {
        "lat" => 32.3668052,
        "lng" => -86.2999689
      }
    },
    {
      "state" => "AL",
      "city_code" => "tuscaloosa",
      "city" => "tuscaloosa, AL",
      "location" => {
        "lat" => 33.2098407,
        "lng" => -87.56917349999999
      }
    },
    {
      "state" => "AK",
      "city_code" => "anchorage",
      "city" => "anchorage / mat-su, AK",
      "location" => {
        "lat" => 61.5615967,
        "lng" => -149.254337
      }
    },
    {
      "state" => "AK",
      "city_code" => "fairbanks",
      "city" => "fairbanks, AK",
      "location" => {
        "lat" => 64.8377778,
        "lng" => -147.7163889
      }
    },
    {
      "state" => "AK",
      "city_code" => "kenai",
      "city" => "kenai peninsula, AK",
      "location" => {
        "lat" => 59.87852219999999,
        "lng" => -150.3952272
      }
    },
    {
      "state" => "AK",
      "city_code" => "juneau",
      "city" => "southeast alaska, AK",
      "location" => {
        "lat" => 64.2008413,
        "lng" => -149.4936733
      }
    },
    {
      "state" => "AZ",
      "city_code" => "flagstaff",
      "city" => "flagstaff / sedona, AZ",
      "location" => {
        "lat" => 34.8697395,
        "lng" => -111.7609896
      }
    },
    {
      "state" => "AZ",
      "city_code" => "mohave",
      "city" => "mohave county, AZ",
      "location" => {
        "lat" => 35.2143346,
        "lng" => -113.7632828
      }
    },
    {
      "state" => "AZ",
      "city_code" => "phoenix",
      "city" => "phoenix, AZ",
      "location" => {
        "lat" => 33.4483771,
        "lng" => -112.0740373
      }
    },
    {
      "state" => "AZ",
      "city_code" => "prescott",
      "city" => "prescott, AZ",
      "location" => {
        "lat" => 34.5400242,
        "lng" => -112.4685025
      }
    },
    {
      "state" => "AZ",
      "city_code" => "showlow",
      "city" => "show low, AZ",
      "location" => {
        "lat" => 34.2542084,
        "lng" => -110.0298327
      }
    },
    {
      "state" => "AZ",
      "city_code" => "sierravista",
      "city" => "sierra vista, AZ",
      "location" => {
        "lat" => 31.5455001,
        "lng" => -110.2772856
      }
    },
    {
      "state" => "AZ",
      "city_code" => "tucson",
      "city" => "tucson, AZ",
      "location" => {
        "lat" => 32.2217429,
        "lng" => -110.926479
      }
    },
    {
      "state" => "AZ",
      "city_code" => "yuma",
      "city" => "yuma, AZ",
      "location" => {
        "lat" => 32.6926512,
        "lng" => -114.6276916
      }
    },
    {
      "state" => "AR",
      "city_code" => "fayar",
      "city" => "fayetteville , AR",
      "location" => {
        "lat" => 36.0625795,
        "lng" => -94.1574263
      }
    },
    {
      "state" => "AR",
      "city_code" => "fortsmith",
      "city" => "fort smith, AR",
      "location" => {
        "lat" => 35.3859242,
        "lng" => -94.39854749999999
      }
    },
    {
      "state" => "AR",
      "city_code" => "jonesboro",
      "city" => "jonesboro, AR",
      "location" => {
        "lat" => 35.84229670000001,
        "lng" => -90.704279
      }
    },
    {
      "state" => "AR",
      "city_code" => "littlerock",
      "city" => "little rock, AR",
      "location" => {
        "lat" => 34.7464809,
        "lng" => -92.28959479999999
      }
    },
    {
      "state" => "AR",
      "city_code" => "texarkana",
      "city" => "texarkana, AR",
      "location" => {
        "lat" => 33.4417915,
        "lng" => -94.0376881
      }
    },
    {
      "state" => "CA",
      "city_code" => "bakersfield",
      "city" => "bakersfield, CA",
      "location" => {
        "lat" => 35.3732921,
        "lng" => -119.0187125
      }
    },
    {
      "state" => "CA",
      "city_code" => "chico",
      "city" => "chico, CA",
      "location" => {
        "lat" => 39.7284944,
        "lng" => -121.8374777
      }
    },
    {
      "state" => "CA",
      "city_code" => "fresno",
      "city" => "fresno / madera, CA",
      "location" => {
        "lat" => 37.251926,
        "lng" => -119.6962677
      }
    },
    {
      "state" => "CA",
      "city_code" => "goldcountry",
      "city" => "gold country, CA",
      "location" => {
        "lat" => 38.6235149,
        "lng" => -121.2457183
      }
    },
    {
      "state" => "CA",
      "city_code" => "hanford",
      "city" => "hanford-corcoran, CA",
      "location" => {
        "lat" => 36.3274502,
        "lng" => -119.6456844
      }
    },
    {
      "state" => "CA",
      "city_code" => "humboldt",
      "city" => "humboldt county, CA",
      "location" => {
        "lat" => 40.7450055,
        "lng" => -123.8695086
      }
    },
    {
      "state" => "CA",
      "city_code" => "imperial",
      "city" => "imperial county, CA",
      "location" => {
        "lat" => 33.0113694,
        "lng" => -115.4733554
      }
    },
    {
      "state" => "CA",
      "city_code" => "inlandempire",
      "city" => "inland empire, CA",
      "location" => {
        "lat" => 34.9592083,
        "lng" => -116.419389
      }
    },
    {
      "state" => "CA",
      "city_code" => "losangeles",
      "city" => "los angeles, CA",
      "location" => {
        "lat" => 34.0522342,
        "lng" => -118.2436849
      }
    },
    {
      "state" => "CA",
      "city_code" => "mendocino",
      "city" => "mendocino county, CA",
      "location" => {
        "lat" => 39.5500194,
        "lng" => -123.438353
      }
    },
    {
      "state" => "CA",
      "city_code" => "merced",
      "city" => "merced, CA",
      "location" => {
        "lat" => 37.3021632,
        "lng" => -120.4829677
      }
    },
    {
      "state" => "CA",
      "city_code" => "modesto",
      "city" => "modesto, CA",
      "location" => {
        "lat" => 37.63909719999999,
        "lng" => -120.9968782
      }
    },
    {
      "state" => "CA",
      "city_code" => "monterey",
      "city" => "monterey bay, CA",
      "location" => {
        "lat" => 36.878192,
        "lng" => -121.947311
      }
    },
    {
      "state" => "CA",
      "city_code" => "orangecounty",
      "city" => "orange county, CA",
      "location" => {
        "lat" => 33.7174708,
        "lng" => -117.8311428
      }
    },
    {
      "state" => "CA",
      "city_code" => "palmsprings",
      "city" => "palm springs, CA",
      "location" => {
        "lat" => 33.8302961,
        "lng" => -116.5452921
      }
    },
    {
      "state" => "CA",
      "city_code" => "redding",
      "city" => "redding, CA",
      "location" => {
        "lat" => 40.5865396,
        "lng" => -122.3916754
      }
    },
    {
      "state" => "CA",
      "city_code" => "sacramento",
      "city" => "sacramento, CA",
      "location" => {
        "lat" => 38.5815719,
        "lng" => -121.4943996
      }
    },
    {
      "state" => "CA",
      "city_code" => "sandiego",
      "city" => "san diego, CA",
      "location" => {
        "lat" => 32.7153292,
        "lng" => -117.1572551
      }
    },
    {
      "state" => "CA",
      "city_code" => "sfbay",
      "city" => "san francisco bay area, CA",
      "location" => {
        "lat" => 37.7749295,
        "lng" => -122.4194155
      }
    },
    {
      "state" => "CA",
      "city_code" => "slo",
      "city" => "san luis obispo, CA",
      "location" => {
        "lat" => 35.2827524,
        "lng" => -120.6596156
      }
    },
    {
      "state" => "CA",
      "city_code" => "santabarbara",
      "city" => "santa barbara, CA",
      "location" => {
        "lat" => 34.4208305,
        "lng" => -119.6981901
      }
    },
    {
      "state" => "CA",
      "city_code" => "santamaria",
      "city" => "santa maria, CA",
      "location" => {
        "lat" => 34.9530337,
        "lng" => -120.4357191
      }
    },
    {
      "state" => "CA",
      "city_code" => "siskiyou",
      "city" => "siskiyou county, CA",
      "location" => {
        "lat" => 41.7743261,
        "lng" => -122.5770126
      }
    },
    {
      "state" => "CA",
      "city_code" => "stockton",
      "city" => "stockton, CA",
      "location" => {
        "lat" => 37.9577016,
        "lng" => -121.2907796
      }
    },
    {
      "state" => "CA",
      "city_code" => "susanville",
      "city" => "susanville, CA",
      "location" => {
        "lat" => 40.4162842,
        "lng" => -120.6530063
      }
    },
    {
      "state" => "CA",
      "city_code" => "ventura",
      "city" => "ventura county, CA",
      "location" => {
        "lat" => 34.3704884,
        "lng" => -119.1390642
      }
    },
    {
      "state" => "CA",
      "city_code" => "visalia",
      "city" => "visalia-tulare, CA",
      "location" => {
        "lat" => 36.3302284,
        "lng" => -119.2920585
      }
    },
    {
      "state" => "CA",
      "city_code" => "yubasutter",
      "city" => "yuba-sutter, CA",
      "location" => {
        "lat" => 39.1598915,
        "lng" => -121.7527482
      }
    },
    {
      "state" => "CO",
      "city_code" => "boulder",
      "city" => "boulder, CO",
      "location" => {
        "lat" => 40.0149856,
        "lng" => -105.2705456
      }
    },
    {
      "state" => "CO",
      "city_code" => "cosprings",
      "city" => "colorado springs, CO",
      "location" => {
        "lat" => 38.8338816,
        "lng" => -104.8213634
      }
    },
    {
      "state" => "CO",
      "city_code" => "denver",
      "city" => "denver, CO",
      "location" => {
        "lat" => 39.737567,
        "lng" => -104.9847179
      }
    },
    {
      "state" => "CO",
      "city_code" => "eastco",
      "city" => "eastern CO, CO",
      "location" => {
        "lat" => 39.979502,
        "lng" => -104.8060022
      }
    },
    {
      "state" => "CO",
      "city_code" => "fortcollins",
      "city" => "fort collins / north CO, CO",
      "location" => {
        "lat" => 40.5852602,
        "lng" => -105.084423
      }
    },
    {
      "state" => "CO",
      "city_code" => "rockies",
      "city" => "high rockies, CO",
      "location" => {
        "lat" => 39.7210402,
        "lng" => -104.8956337
      }
    },
    {
      "state" => "CO",
      "city_code" => "pueblo",
      "city" => "pueblo, CO",
      "location" => {
        "lat" => 38.2544472,
        "lng" => -104.6091409
      }
    },
    {
      "state" => "CO",
      "city_code" => "westslope",
      "city" => "western slope, CO",
      "location" => {
        "lat" => 38.480032,
        "lng" => -107.8677474
      }
    },
    {
      "state" => "CT",
      "city_code" => "newlondon",
      "city" => "eastern CT, CT",
      "location" => {
        "lat" => 41.7195293,
        "lng" => -72.2166961
      }
    },
    {
      "state" => "CT",
      "city_code" => "hartford",
      "city" => "hartford, CT",
      "location" => {
        "lat" => 41.76371109999999,
        "lng" => -72.6850932
      }
    },
    {
      "state" => "CT",
      "city_code" => "newhaven",
      "city" => "new haven, CT",
      "location" => {
        "lat" => 41.3081527,
        "lng" => -72.9281577
      }
    },
    {
      "state" => "CT",
      "city_code" => "nwct",
      "city" => "northwest CT, CT",
      "location" => {
        "lat" => 41.6032207,
        "lng" => -73.087749
      }
    },
    {
      "state" => "DE",
      "city_code" => "delaware",
      "city" => "delaware",
      "location" => {
        "lat" => 38.9108325,
        "lng" => -75.52766989999999
      }
    },
    {
      "state" => "DC",
      "city_code" => "washingtondc",
      "city" => "washington, DC",
      "location" => {
        "lat" => 38.8951118,
        "lng" => -77.0363658
      }
    },
    {
      "state" => "FL",
      "city_code" => "daytona",
      "city" => "daytona beach, FL",
      "location" => {
        "lat" => 29.2108147,
        "lng" => -81.0228331
      }
    },
    {
      "state" => "FL",
      "city_code" => "keys",
      "city" => "florida keys, FL",
      "location" => {
        "lat" => 24.7433195,
        "lng" => -81.2518833
      }
    },
    {
      "state" => "FL",
      "city_code" => "fortlauderdale",
      "city" => "fort lauderdale, FL",
      "location" => {
        "lat" => 26.1223084,
        "lng" => -80.14337859999999
      }
    },
    {
      "state" => "FL",
      "city_code" => "fortmyers",
      "city" => "ft myers / SW florida, FL",
      "location" => {
        "lat" => 26.640628,
        "lng" => -81.8723084
      }
    },
    {
      "state" => "FL",
      "city_code" => "gainesville",
      "city" => "gainesville, FL",
      "location" => {
        "lat" => 29.6516344,
        "lng" => -82.32482619999999
      }
    },
    {
      "state" => "FL",
      "city_code" => "cfl",
      "city" => "heartland florida, FL",
      "location" => {
        "lat" => 27.3058716,
        "lng" => -81.3675497
      }
    },
    {
      "state" => "FL",
      "city_code" => "jacksonville",
      "city" => "jacksonville, FL",
      "location" => {
        "lat" => 30.3321838,
        "lng" => -81.65565099999999
      }
    },
    {
      "state" => "FL",
      "city_code" => "lakeland",
      "city" => "lakeland, FL",
      "location" => {
        "lat" => 28.0394654,
        "lng" => -81.9498042
      }
    },
    {
      "state" => "FL",
      "city_code" => "lakecity",
      "city" => "north central FL, FL",
      "location" => {
        "lat" => 28.940145,
        "lng" => -81.663991
      }
    },
    {
      "state" => "FL",
      "city_code" => "ocala",
      "city" => "ocala, FL",
      "location" => {
        "lat" => 29.1871986,
        "lng" => -82.14009229999999
      }
    },
    {
      "state" => "FL",
      "city_code" => "okaloosa",
      "city" => "okaloosa / walton, FL",
      "location" => {
        "lat" => 30.5394163,
        "lng" => -86.475644
      }
    },
    {
      "state" => "FL",
      "city_code" => "orlando",
      "city" => "orlando, FL",
      "location" => {
        "lat" => 28.5383355,
        "lng" => -81.3792365
      }
    },
    {
      "state" => "FL",
      "city_code" => "panamacity",
      "city" => "panama city, FL",
      "location" => {
        "lat" => 30.1588129,
        "lng" => -85.6602058
      }
    },
    {
      "state" => "FL",
      "city_code" => "pensacola",
      "city" => "pensacola, FL",
      "location" => {
        "lat" => 30.42130899999999,
        "lng" => -87.2169149
      }
    },
    {
      "state" => "FL",
      "city_code" => "sarasota",
      "city" => "sarasota-bradenton, FL",
      "location" => {
        "lat" => 27.395444,
        "lng" => -82.554389
      }
    },
    {
      "state" => "FL",
      "city_code" => "miami",
      "city" => "south florida, FL",
      "location" => {
        "lat" => 27.6648274,
        "lng" => -81.5157535
      }
    },
    {
      "state" => "FL",
      "city_code" => "spacecoast",
      "city" => "space coast, FL",
      "location" => {
        "lat" => 28.263933,
        "lng" => -80.7214417
      }
    },
    {
      "state" => "FL",
      "city_code" => "staugustine",
      "city" => "st augustine, FL",
      "location" => {
        "lat" => 29.8942639,
        "lng" => -81.3132083
      }
    },
    {
      "state" => "FL",
      "city_code" => "tallahassee",
      "city" => "tallahassee, FL",
      "location" => {
        "lat" => 30.4382559,
        "lng" => -84.28073289999999
      }
    },
    {
      "state" => "FL",
      "city_code" => "tampa",
      "city" => "tampa bay area, FL",
      "location" => {
        "lat" => 27.8976392,
        "lng" => -82.51874169999999
      }
    },
    {
      "state" => "FL",
      "city_code" => "treasure",
      "city" => "treasure coast, FL",
      "location" => {
        "lat" => 27.354305,
        "lng" => -80.372401
      }
    },
    {
      "state" => "FL",
      "city_code" => "westpalmbeach",
      "city" => "west palm beach, FL",
      "location" => {
        "lat" => 26.7153424,
        "lng" => -80.0533746
      }
    },
    {
      "state" => "GA",
      "city_code" => "albanyga",
      "city" => "albany , GA",
      "location" => {
        "lat" => 31.5785074,
        "lng" => -84.15574099999999
      }
    },
    {
      "state" => "GA",
      "city_code" => "athensga",
      "city" => "athens, GA",
      "location" => {
        "lat" => 33.95,
        "lng" => -83.38333329999999
      }
    },
    {
      "state" => "GA",
      "city_code" => "atlanta",
      "city" => "atlanta, GA",
      "location" => {
        "lat" => 33.7489954,
        "lng" => -84.3879824
      }
    },
    {
      "state" => "GA",
      "city_code" => "augusta",
      "city" => "augusta, GA",
      "location" => {
        "lat" => 33.474246,
        "lng" => -82.00967
      }
    },
    {
      "state" => "GA",
      "city_code" => "brunswick",
      "city" => "brunswick, GA",
      "location" => {
        "lat" => 31.1499528,
        "lng" => -81.49148939999999
      }
    },
    {
      "state" => "GA",
      "city_code" => "columbusga",
      "city" => "columbus , GA",
      "location" => {
        "lat" => 32.4609764,
        "lng" => -84.9877094
      }
    },
    {
      "state" => "GA",
      "city_code" => "macon",
      "city" => "macon / warner robins, GA",
      "location" => {
        "lat" => 32.4219655,
        "lng" => -83.63484299999999
      }
    },
    {
      "state" => "GA",
      "city_code" => "nwga",
      "city" => "northwest GA, GA",
      "location" => {
        "lat" => 32.1574351,
        "lng" => -82.90712300000001
      }
    },
    {
      "state" => "GA",
      "city_code" => "savannah",
      "city" => "savannah / hinesville, GA",
      "location" => {
        "lat" => 31.853267,
        "lng" => -81.606141
      }
    },
    {
      "state" => "GA",
      "city_code" => "statesboro",
      "city" => "statesboro, GA",
      "location" => {
        "lat" => 32.4487876,
        "lng" => -81.7831674
      }
    },
    {
      "state" => "GA",
      "city_code" => "valdosta",
      "city" => "valdosta, GA",
      "location" => {
        "lat" => 30.8327022,
        "lng" => -83.2784851
      }
    },
    {
      "state" => "HI",
      "city_code" => "honolulu",
      "city" => "hawaii",
      "location" => {
        "lat" => 19.8967662,
        "lng" => -155.5827818
      }
    },
    {
      "state" => "ID",
      "city_code" => "boise",
      "city" => "boise, ID",
      "location" => {
        "lat" => 43.613739,
        "lng" => -116.237651
      }
    },
    {
      "state" => "ID",
      "city_code" => "eastidaho",
      "city" => "east idaho, ID",
      "location" => {
        "lat" => 44.0682019,
        "lng" => -114.7420408
      }
    },
    {
      "state" => "ID",
      "city_code" => "lewiston",
      "city" => "lewiston / clarkston, ID",
      "location" => {
        "lat" => 46.4162723,
        "lng" => -117.0451581
      }
    },
    {
      "state" => "ID",
      "city_code" => "twinfalls",
      "city" => "twin falls, ID",
      "location" => {
        "lat" => 42.5629668,
        "lng" => -114.4608711
      }
    },
    {
      "state" => "IL",
      "city_code" => "bn",
      "city" => "bloomington-normal, IL",
      "location" => {
        "lat" => 40.4842027,
        "lng" => -88.99368729999999
      }
    },
    {
      "state" => "IL",
      "city_code" => "chambana",
      "city" => "champaign urbana, IL",
      "location" => {
        "lat" => 40.1105875,
        "lng" => -88.2072697
      }
    },
    {
      "state" => "IL",
      "city_code" => "chicago",
      "city" => "chicago, IL",
      "location" => {
        "lat" => 41.8781136,
        "lng" => -87.6297982
      }
    },
    {
      "state" => "IL",
      "city_code" => "decatur",
      "city" => "decatur, IL",
      "location" => {
        "lat" => 39.8403147,
        "lng" => -88.9548001
      }
    },
    {
      "state" => "IL",
      "city_code" => "lasalle",
      "city" => "la salle co, IL",
      "location" => {
        "lat" => 41.3411111,
        "lng" => -89.0908333
      }
    },
    {
      "state" => "IL",
      "city_code" => "mattoon",
      "city" => "mattoon-charleston, IL",
      "location" => {
        "lat" => 39.48308970000001,
        "lng" => -88.37282549999999
      }
    },
    {
      "state" => "IL",
      "city_code" => "peoria",
      "city" => "peoria, IL",
      "location" => {
        "lat" => 40.6936488,
        "lng" => -89.5889864
      }
    },
    {
      "state" => "IL",
      "city_code" => "rockford",
      "city" => "rockford, IL",
      "location" => {
        "lat" => 42.2711311,
        "lng" => -89.0939952
      }
    },
    {
      "state" => "IL",
      "city_code" => "carbondale",
      "city" => "southern illinois, IL",
      "location" => {
        "lat" => 37.7758739,
        "lng" => -89.2526599
      }
    },
    {
      "state" => "IL",
      "city_code" => "springfieldil",
      "city" => "springfield , IL",
      "location" => {
        "lat" => 39.78172130000001,
        "lng" => -89.6501481
      }
    },
    {
      "state" => "IL",
      "city_code" => "quincy",
      "city" => "western IL, IL",
      "location" => {
        "lat" => 41.3804869,
        "lng" => -90.3936722
      }
    },
    {
      "state" => "IN",
      "city_code" => "bloomington",
      "city" => "bloomington, IN",
      "location" => {
        "lat" => 39.165325,
        "lng" => -86.52638569999999
      }
    },
    {
      "state" => "IN",
      "city_code" => "evansville",
      "city" => "evansville, IN",
      "location" => {
        "lat" => 37.9715592,
        "lng" => -87.5710898
      }
    },
    {
      "state" => "IN",
      "city_code" => "fortwayne",
      "city" => "fort wayne, IN",
      "location" => {
        "lat" => 41.079273,
        "lng" => -85.1393513
      }
    },
    {
      "state" => "IN",
      "city_code" => "indianapolis",
      "city" => "indianapolis, IN",
      "location" => {
        "lat" => 39.7685155,
        "lng" => -86.1580736
      }
    },
    {
      "state" => "IN",
      "city_code" => "kokomo",
      "city" => "kokomo, IN",
      "location" => {
        "lat" => 40.486427,
        "lng" => -86.13360329999999
      }
    },
    {
      "state" => "IN",
      "city_code" => "tippecanoe",
      "city" => "lafayette / west lafayette, IN",
      "location" => {
        "lat" => 40.4258686,
        "lng" => -86.90806549999999
      }
    },
    {
      "state" => "IN",
      "city_code" => "muncie",
      "city" => "muncie / anderson, IN",
      "location" => {
        "lat" => 40.080006,
        "lng" => -85.3704217
      }
    },
    {
      "state" => "IN",
      "city_code" => "richmondin",
      "city" => "richmond , IN",
      "location" => {
        "lat" => 39.8289369,
        "lng" => -84.8902382
      }
    },
    {
      "state" => "IN",
      "city_code" => "southbend",
      "city" => "south bend / michiana, IN",
      "location" => {
        "lat" => 41.662672,
        "lng" => -86.23157599999999
      }
    },
    {
      "state" => "IN",
      "city_code" => "terrehaute",
      "city" => "terre haute, IN",
      "location" => {
        "lat" => 39.4667034,
        "lng" => -87.41390919999999
      }
    },
    {
      "state" => "IA",
      "city_code" => "ames",
      "city" => "ames, IA",
      "location" => {
        "lat" => 42.02335,
        "lng" => -93.62562199999999
      }
    },
    {
      "state" => "IA",
      "city_code" => "cedarrapids",
      "city" => "cedar rapids, IA",
      "location" => {
        "lat" => 41.9778795,
        "lng" => -91.6656232
      }
    },
    {
      "state" => "IA",
      "city_code" => "desmoines",
      "city" => "des moines, IA",
      "location" => {
        "lat" => 41.6005448,
        "lng" => -93.6091064
      }
    },
    {
      "state" => "IA",
      "city_code" => "dubuque",
      "city" => "dubuque, IA",
      "location" => {
        "lat" => 42.5005583,
        "lng" => -90.66457179999999
      }
    },
    {
      "state" => "IA",
      "city_code" => "fortdodge",
      "city" => "fort dodge, IA",
      "location" => {
        "lat" => 42.4974694,
        "lng" => -94.16801579999999
      }
    },
    {
      "state" => "IA",
      "city_code" => "iowacity",
      "city" => "iowa city, IA",
      "location" => {
        "lat" => 41.6611277,
        "lng" => -91.5301683
      }
    },
    {
      "state" => "IA",
      "city_code" => "masoncity",
      "city" => "mason city, IA",
      "location" => {
        "lat" => 43.1535728,
        "lng" => -93.20103669999999
      }
    },
    {
      "state" => "IA",
      "city_code" => "quadcities",
      "city" => "quad cities, IA",
      "location" => {
        "lat" => 41.4403733,
        "lng" => -90.4502368
      }
    },
    {
      "state" => "IA",
      "city_code" => "siouxcity",
      "city" => "sioux city, IA",
      "location" => {
        "lat" => 42.4999942,
        "lng" => -96.40030689999999
      }
    },
    {
      "state" => "IA",
      "city_code" => "ottumwa",
      "city" => "southeast IA, IA",
      "location" => {
        "lat" => 41.8780025,
        "lng" => -93.097702
      }
    },
    {
      "state" => "IA",
      "city_code" => "waterloo",
      "city" => "waterloo / cedar falls, IA",
      "location" => {
        "lat" => 42.5102632,
        "lng" => -92.3862973
      }
    },
    {
      "state" => "KS",
      "city_code" => "lawrence",
      "city" => "lawrence, KS",
      "location" => {
        "lat" => 38.9716689,
        "lng" => -95.2352501
      }
    },
    {
      "state" => "KS",
      "city_code" => "ksu",
      "city" => "manhattan, KS",
      "location" => {
        "lat" => 39.18360819999999,
        "lng" => -96.57166939999999
      }
    },
    {
      "state" => "KS",
      "city_code" => "nwks",
      "city" => "northwest KS, KS",
      "location" => {
        "lat" => 39.011902,
        "lng" => -98.4842465
      }
    },
    {
      "state" => "KS",
      "city_code" => "salina",
      "city" => "salina, KS",
      "location" => {
        "lat" => 38.8402805,
        "lng" => -97.61142369999999
      }
    },
    {
      "state" => "KS",
      "city_code" => "seks",
      "city" => "southeast KS, KS",
      "location" => {
        "lat" => 39.011902,
        "lng" => -98.4842465
      }
    },
    {
      "state" => "KS",
      "city_code" => "swks",
      "city" => "southwest KS, KS",
      "location" => {
        "lat" => 39.011902,
        "lng" => -98.4842465
      }
    },
    {
      "state" => "KS",
      "city_code" => "topeka",
      "city" => "topeka, KS",
      "location" => {
        "lat" => 39.0558235,
        "lng" => -95.68901849999999
      }
    },
    {
      "state" => "KS",
      "city_code" => "wichita",
      "city" => "wichita, KS",
      "location" => {
        "lat" => 37.68888889999999,
        "lng" => -97.3361111
      }
    },
    {
      "state" => "KY",
      "city_code" => "bgky",
      "city" => "bowling green, KY",
      "location" => {
        "lat" => 36.9903199,
        "lng" => -86.4436018
      }
    },
    {
      "state" => "KY",
      "city_code" => "eastky",
      "city" => "eastern kentucky, KY",
      "location" => {
        "lat" => 37.51647579999999,
        "lng" => -82.8067126
      }
    },
    {
      "state" => "KY",
      "city_code" => "lexington",
      "city" => "lexington, KY",
      "location" => {
        "lat" => 38.0405837,
        "lng" => -84.5037164
      }
    },
    {
      "state" => "KY",
      "city_code" => "louisville",
      "city" => "louisville, KY",
      "location" => {
        "lat" => 38.2526647,
        "lng" => -85.7584557
      }
    },
    {
      "state" => "KY",
      "city_code" => "owensboro",
      "city" => "owensboro, KY",
      "location" => {
        "lat" => 37.7719074,
        "lng" => -87.1111676
      }
    },
    {
      "state" => "KY",
      "city_code" => "westky",
      "city" => "western KY, KY",
      "location" => {
        "lat" => 37.6783588,
        "lng" => -85.2354349
      }
    },
    {
      "state" => "LA",
      "city_code" => "batonrouge",
      "city" => "baton rouge, LA",
      "location" => {
        "lat" => 30.4582829,
        "lng" => -91.1403196
      }
    },
    {
      "state" => "LA",
      "city_code" => "cenla",
      "city" => "central louisiana, LA",
      "location" => {
        "lat" => 30.554281,
        "lng" => -91.0368766
      }
    },
    {
      "state" => "LA",
      "city_code" => "houma",
      "city" => "houma, LA",
      "location" => {
        "lat" => 29.5957696,
        "lng" => -90.71953479999999
      }
    },
    {
      "state" => "LA",
      "city_code" => "lafayette",
      "city" => "lafayette, LA",
      "location" => {
        "lat" => 30.2240897,
        "lng" => -92.0198427
      }
    },
    {
      "state" => "LA",
      "city_code" => "lakecharles",
      "city" => "lake charles, LA",
      "location" => {
        "lat" => 30.2265949,
        "lng" => -93.2173758
      }
    },
    {
      "state" => "LA",
      "city_code" => "monroe",
      "city" => "monroe, LA",
      "location" => {
        "lat" => 32.5093109,
        "lng" => -92.1193012
      }
    },
    {
      "state" => "LA",
      "city_code" => "neworleans",
      "city" => "new orleans, LA",
      "location" => {
        "lat" => 29.95106579999999,
        "lng" => -90.0715323
      }
    },
    {
      "state" => "LA",
      "city_code" => "shreveport",
      "city" => "shreveport, LA",
      "location" => {
        "lat" => 32.5251516,
        "lng" => -93.7501789
      }
    },
    {
      "state" => "ME",
      "city_code" => "maine",
      "city" => "maine",
      "location" => {
        "lat" => 45.253783,
        "lng" => -69.4454689
      }
    },
    {
      "state" => "MD",
      "city_code" => "annapolis",
      "city" => "annapolis, MD",
      "location" => {
        "lat" => 38.9784453,
        "lng" => -76.4921829
      }
    },
    {
      "state" => "MD",
      "city_code" => "baltimore",
      "city" => "baltimore, MD",
      "location" => {
        "lat" => 39.2903848,
        "lng" => -76.6121893
      }
    },
    {
      "state" => "MD",
      "city_code" => "easternshore",
      "city" => "eastern shore, MD",
      "location" => {
        "lat" => 39.3243325,
        "lng" => -76.4474772
      }
    },
    {
      "state" => "MD",
      "city_code" => "frederick",
      "city" => "frederick, MD",
      "location" => {
        "lat" => 39.41426879999999,
        "lng" => -77.4105409
      }
    },
    {
      "state" => "MD",
      "city_code" => "smd",
      "city" => "southern maryland, MD",
      "location" => {
        "lat" => 38.5351029,
        "lng" => -76.6073347
      }
    },
    {
      "state" => "MD",
      "city_code" => "westmd",
      "city" => "western maryland, MD",
      "location" => {
        "lat" => 39.2922854,
        "lng" => -76.66292899999999
      }
    },
    {
      "state" => "MA",
      "city_code" => "boston",
      "city" => "boston, MA",
      "location" => {
        "lat" => 42.3584308,
        "lng" => -71.0597732
      }
    },
    {
      "state" => "MA",
      "city_code" => "capecod",
      "city" => "cape cod / islands, MA",
      "location" => {
        "lat" => 41.569864,
        "lng" => -70.467475
      }
    },
    {
      "state" => "MA",
      "city_code" => "southcoast",
      "city" => "south coast, MA",
      "location" => {
        "lat" => 41.7668,
        "lng" => -71.2599
      }
    },
    {
      "state" => "MA",
      "city_code" => "westernmass",
      "city" => "western massachusetts, MA",
      "location" => {
        "lat" => 42.3198239,
        "lng" => -70.9933156
      }
    },
    {
      "state" => "MA",
      "city_code" => "worcester",
      "city" => "worcester / central MA, MA",
      "location" => {
        "lat" => 42.276553,
        "lng" => -71.79969059999999
      }
    },
    {
      "state" => "MI",
      "city_code" => "annarbor",
      "city" => "ann arbor, MI",
      "location" => {
        "lat" => 42.2808256,
        "lng" => -83.7430378
      }
    },
    {
      "state" => "MI",
      "city_code" => "battlecreek",
      "city" => "battle creek, MI",
      "location" => {
        "lat" => 42.3211522,
        "lng" => -85.17971419999999
      }
    },
    {
      "state" => "MI",
      "city_code" => "centralmich",
      "city" => "central michigan, MI",
      "location" => {
        "lat" => 42.6198984,
        "lng" => -83.91637419999999
      }
    },
    {
      "state" => "MI",
      "city_code" => "detroit",
      "city" => "detroit metro, MI",
      "location" => {
        "lat" => 42.331427,
        "lng" => -83.0457538
      }
    },
    {
      "state" => "MI",
      "city_code" => "flint",
      "city" => "flint, MI",
      "location" => {
        "lat" => 43.0125274,
        "lng" => -83.6874562
      }
    },
    {
      "state" => "MI",
      "city_code" => "grandrapids",
      "city" => "grand rapids, MI",
      "location" => {
        "lat" => 42.9633599,
        "lng" => -85.6680863
      }
    },
    {
      "state" => "MI",
      "city_code" => "holland",
      "city" => "holland, MI",
      "location" => {
        "lat" => 42.7875235,
        "lng" => -86.1089301
      }
    },
    {
      "state" => "MI",
      "city_code" => "jxn",
      "city" => "jackson , MI",
      "location" => {
        "lat" => 42.245869,
        "lng" => -84.40134619999999
      }
    },
    {
      "state" => "MI",
      "city_code" => "kalamazoo",
      "city" => "kalamazoo, MI",
      "location" => {
        "lat" => 42.2917069,
        "lng" => -85.5872286
      }
    },
    {
      "state" => "MI",
      "city_code" => "lansing",
      "city" => "lansing, MI",
      "location" => {
        "lat" => 42.732535,
        "lng" => -84.5555347
      }
    },
    {
      "state" => "MI",
      "city_code" => "monroemi",
      "city" => "monroe , MI",
      "location" => {
        "lat" => 41.9164343,
        "lng" => -83.3977101
      }
    },
    {
      "state" => "MI",
      "city_code" => "muskegon",
      "city" => "muskegon, MI",
      "location" => {
        "lat" => 43.2341813,
        "lng" => -86.24839209999999
      }
    },
    {
      "state" => "MI",
      "city_code" => "nmi",
      "city" => "northern michigan, MI",
      "location" => {
        "lat" => 43.7500599,
        "lng" => -85.1447013
      }
    },
    {
      "state" => "MI",
      "city_code" => "porthuron",
      "city" => "port huron, MI",
      "location" => {
        "lat" => 42.9708634,
        "lng" => -82.42491419999999
      }
    },
    {
      "state" => "MI",
      "city_code" => "saginaw",
      "city" => "saginaw-midland-baycity, MI",
      "location" => {
        "lat" => 44.3148443,
        "lng" => -85.60236429999999
      }
    },
    {
      "state" => "MI",
      "city_code" => "swmi",
      "city" => "southwest michigan, MI",
      "location" => {
        "lat" => 44.3148443,
        "lng" => -85.60236429999999
      }
    },
    {
      "state" => "MI",
      "city_code" => "thumb",
      "city" => "the thumb, MI",
      "location" => {
        "lat" => 41.6198662,
        "lng" => -87.1926739
      }
    },
    {
      "state" => "MI",
      "city_code" => "up",
      "city" => "upper peninsula, MI",
      "location" => {
        "lat" => 46.9281544,
        "lng" => -87.4040189
      }
    },
    {
      "state" => "MN",
      "city_code" => "bemidji",
      "city" => "bemidji, MN",
      "location" => {
        "lat" => 47.4736111,
        "lng" => -94.8802778
      }
    },
    {
      "state" => "MN",
      "city_code" => "brainerd",
      "city" => "brainerd, MN",
      "location" => {
        "lat" => 46.35722,
        "lng" => -94.19444
      }
    },
    {
      "state" => "MN",
      "city_code" => "duluth",
      "city" => "duluth / superior, MN",
      "location" => {
        "lat" => 46.78667189999999,
        "lng" => -92.1004852
      }
    },
    {
      "state" => "MN",
      "city_code" => "mankato",
      "city" => "mankato, MN",
      "location" => {
        "lat" => 44.1635775,
        "lng" => -93.99939959999999
      }
    },
    {
      "state" => "MN",
      "city_code" => "minneapolis",
      "city" => "minneapolis / st paul, MN",
      "location" => {
        "lat" => 45.2472601,
        "lng" => -93.4553904
      }
    },
    {
      "state" => "MN",
      "city_code" => "rmn",
      "city" => "rochester , MN",
      "location" => {
        "lat" => 44.0216306,
        "lng" => -92.4698992
      }
    },
    {
      "state" => "MN",
      "city_code" => "marshall",
      "city" => "southwest MN, MN",
      "location" => {
        "lat" => 46.729553,
        "lng" => -94.6858998
      }
    },
    {
      "state" => "MN",
      "city_code" => "stcloud",
      "city" => "st cloud, MN",
      "location" => {
        "lat" => 45.5579451,
        "lng" => -94.16324039999999
      }
    },
    {
      "state" => "MS",
      "city_code" => "gulfport",
      "city" => "gulfport / biloxi, MS",
      "location" => {
        "lat" => 30.4078223,
        "lng" => -89.0041925
      }
    },
    {
      "state" => "MS",
      "city_code" => "hattiesburg",
      "city" => "hattiesburg, MS",
      "location" => {
        "lat" => 31.3271189,
        "lng" => -89.29033919999999
      }
    },
    {
      "state" => "MS",
      "city_code" => "jackson",
      "city" => "jackson, MS",
      "location" => {
        "lat" => 32.2987573,
        "lng" => -90.1848103
      }
    },
    {
      "state" => "MS",
      "city_code" => "meridian",
      "city" => "meridian, MS",
      "location" => {
        "lat" => 32.3643098,
        "lng" => -88.703656
      }
    },
    {
      "state" => "MS",
      "city_code" => "northmiss",
      "city" => "north mississippi, MS",
      "location" => {
        "lat" => 32.3546679,
        "lng" => -89.3985283
      }
    },
    {
      "state" => "MS",
      "city_code" => "natchez",
      "city" => "southwest MS, MS",
      "location" => {
        "lat" => 32.3546679,
        "lng" => -89.3985283
      }
    },
    {
      "state" => "MO",
      "city_code" => "columbiamo",
      "city" => "columbia / jeff city, MO",
      "location" => {
        "lat" => 38.5705307,
        "lng" => -92.2433516
      }
    },
    {
      "state" => "MO",
      "city_code" => "joplin",
      "city" => "joplin, MO",
      "location" => {
        "lat" => 37.08422710000001,
        "lng" => -94.51328099999999
      }
    },
    {
      "state" => "MO",
      "city_code" => "kansascity",
      "city" => "kansas city, MO",
      "location" => {
        "lat" => 39.0997265,
        "lng" => -94.5785667
      }
    },
    {
      "state" => "MO",
      "city_code" => "kirksville",
      "city" => "kirksville, MO",
      "location" => {
        "lat" => 40.19475389999999,
        "lng" => -92.5832496
      }
    },
    {
      "state" => "MO",
      "city_code" => "loz",
      "city" => "lake of the ozarks, MO",
      "location" => {
        "lat" => 38.13800030000001,
        "lng" => -92.8103551
      }
    },
    {
      "state" => "MO",
      "city_code" => "semo",
      "city" => "southeast missouri, MO",
      "location" => {
        "lat" => 37.9642529,
        "lng" => -91.8318334
      }
    },
    {
      "state" => "MO",
      "city_code" => "springfield",
      "city" => "springfield, MO",
      "location" => {
        "lat" => 37.2089572,
        "lng" => -93.29229889999999
      }
    },
    {
      "state" => "MO",
      "city_code" => "stjoseph",
      "city" => "st joseph, MO",
      "location" => {
        "lat" => 39.75794399999999,
        "lng" => -94.836541
      }
    },
    {
      "state" => "MO",
      "city_code" => "stlouis",
      "city" => "st louis, MO",
      "location" => {
        "lat" => 38.6270025,
        "lng" => -90.19940419999999
      }
    },
    {
      "state" => "MT",
      "city_code" => "billings",
      "city" => "billings, MT",
      "location" => {
        "lat" => 45.7832856,
        "lng" => -108.5006904
      }
    },
    {
      "state" => "MT",
      "city_code" => "bozeman",
      "city" => "bozeman, MT",
      "location" => {
        "lat" => 45.6834599,
        "lng" => -111.050499
      }
    },
    {
      "state" => "MT",
      "city_code" => "butte",
      "city" => "butte, MT",
      "location" => {
        "lat" => 46.0038232,
        "lng" => -112.5347776
      }
    },
    {
      "state" => "MT",
      "city_code" => "greatfalls",
      "city" => "great falls, MT",
      "location" => {
        "lat" => 47.5002354,
        "lng" => -111.3008083
      }
    },
    {
      "state" => "MT",
      "city_code" => "helena",
      "city" => "helena, MT",
      "location" => {
        "lat" => 46.5958056,
        "lng" => -112.0270306
      }
    },
    {
      "state" => "MT",
      "city_code" => "kalispell",
      "city" => "kalispell, MT",
      "location" => {
        "lat" => 48.200531,
        "lng" => -114.315102
      }
    },
    {
      "state" => "MT",
      "city_code" => "missoula",
      "city" => "missoula, MT",
      "location" => {
        "lat" => 46.8605189,
        "lng" => -114.019501
      }
    },
    {
      "state" => "MT",
      "city_code" => "montana",
      "city" => "montana (old), MT",
      "location" => {
        "lat" => 48.275851,
        "lng" => -111.9260115
      }
    },
    {
      "state" => "NE",
      "city_code" => "grandisland",
      "city" => "grand island, NE",
      "location" => {
        "lat" => 40.9263957,
        "lng" => -98.3420118
      }
    },
    {
      "state" => "NE",
      "city_code" => "lincoln",
      "city" => "lincoln, NE",
      "location" => {
        "lat" => 40.806862,
        "lng" => -96.681679
      }
    },
    {
      "state" => "NE",
      "city_code" => "northplatte",
      "city" => "north platte, NE",
      "location" => {
        "lat" => 41.1238873,
        "lng" => -100.7654232
      }
    },
    {
      "state" => "NE",
      "city_code" => "omaha",
      "city" => "omaha / council bluffs, NE",
      "location" => {
        "lat" => 41.2619444,
        "lng" => -95.8608333
      }
    },
    {
      "state" => "NE",
      "city_code" => "scottsbluff",
      "city" => "scottsbluff / panhandle, NE",
      "location" => {
        "lat" => 41.8912395,
        "lng" => -103.6756715
      }
    },
    {
      "state" => "NV",
      "city_code" => "elko",
      "city" => "elko, NV",
      "location" => {
        "lat" => 40.8324211,
        "lng" => -115.7631232
      }
    },
    {
      "state" => "NV",
      "city_code" => "lasvegas",
      "city" => "las vegas, NV",
      "location" => {
        "lat" => 36.114646,
        "lng" => -115.172816
      }
    },
    {
      "state" => "NV",
      "city_code" => "reno",
      "city" => "reno / tahoe, NV",
      "location" => {
        "lat" => 39.5235877,
        "lng" => -119.8172037
      }
    },
    {
      "state" => "NH",
      "city_code" => "nh",
      "city" => "new hampshire",
      "location" => {
        "lat" => 43.1938516,
        "lng" => -71.5723953
      }
    },
    {
      "state" => "NJ",
      "city_code" => "cnj",
      "city" => "central NJ, NJ",
      "location" => {
        "lat" => 39.829728,
        "lng" => -74.9789595
      }
    },
    {
      "state" => "NJ",
      "city_code" => "jerseyshore",
      "city" => "jersey shore, NJ",
      "location" => {
        "lat" => 40.4533119,
        "lng" => -74.1391436
      }
    },
    {
      "state" => "NJ",
      "city_code" => "newjersey",
      "city" => "north jersey, NJ",
      "location" => {
        "lat" => 40.93044,
        "lng" => -74.03265999999999
      }
    },
    {
      "state" => "NJ",
      "city_code" => "southjersey",
      "city" => "south jersey, NJ",
      "location" => {
        "lat" => 39.9408789,
        "lng" => -74.84340259999999
      }
    },
    {
      "state" => "NM",
      "city_code" => "albuquerque",
      "city" => "albuquerque, NM",
      "location" => {
        "lat" => 35.0844909,
        "lng" => -106.6511367
      }
    },
    {
      "state" => "NM",
      "city_code" => "clovis",
      "city" => "clovis / portales, NM",
      "location" => {
        "lat" => 34.5751567,
        "lng" => -103.2663479
      }
    },
    {
      "state" => "NM",
      "city_code" => "farmington",
      "city" => "farmington, NM",
      "location" => {
        "lat" => 36.72805830000001,
        "lng" => -108.2186856
      }
    },
    {
      "state" => "NM",
      "city_code" => "lascruces",
      "city" => "las cruces, NM",
      "location" => {
        "lat" => 32.3199396,
        "lng" => -106.7636538
      }
    },
    {
      "state" => "NM",
      "city_code" => "roswell",
      "city" => "roswell / carlsbad, NM",
      "location" => {
        "lat" => 33.5875429,
        "lng" => -104.5112491
      }
    },
    {
      "state" => "NM",
      "city_code" => "santafe",
      "city" => "santa fe / taos, NM",
      "location" => {
        "lat" => 35.80439,
        "lng" => -105.921963
      }
    },
    {
      "state" => "NY",
      "city_code" => "albany",
      "city" => "albany, NY",
      "location" => {
        "lat" => 42.6525793,
        "lng" => -73.7562317
      }
    },
    {
      "state" => "NY",
      "city_code" => "binghamton",
      "city" => "binghamton, NY",
      "location" => {
        "lat" => 42.09868669999999,
        "lng" => -75.91797380000001
      }
    },
    {
      "state" => "NY",
      "city_code" => "buffalo",
      "city" => "buffalo, NY",
      "location" => {
        "lat" => 42.88644679999999,
        "lng" => -78.8783689
      }
    },
    {
      "state" => "NY",
      "city_code" => "catskills",
      "city" => "catskills, NY",
      "location" => {
        "lat" => 42.2197051,
        "lng" => -74.5025275
      }
    },
    {
      "state" => "NY",
      "city_code" => "chautauqua",
      "city" => "chautauqua, NY",
      "location" => {
        "lat" => 42.2312829,
        "lng" => -79.560344
      }
    },
    {
      "state" => "NY",
      "city_code" => "elmira",
      "city" => "elmira-corning, NY",
      "location" => {
        "lat" => 42.09300349999999,
        "lng" => -76.7995871
      }
    },
    {
      "state" => "NY",
      "city_code" => "fingerlakes",
      "city" => "finger lakes, NY",
      "location" => {
        "lat" => 42.8334002,
        "lng" => -76.99996689999999
      }
    },
    {
      "state" => "NY",
      "city_code" => "glensfalls",
      "city" => "glens falls, NY",
      "location" => {
        "lat" => 43.3095164,
        "lng" => -73.6440058
      }
    },
    {
      "state" => "NY",
      "city_code" => "hudsonvalley",
      "city" => "hudson valley, NY",
      "location" => {
        "lat" => 41.844399,
        "lng" => -74.074285
      }
    },
    {
      "state" => "NY",
      "city_code" => "ithaca",
      "city" => "ithaca, NY",
      "location" => {
        "lat" => 42.4439614,
        "lng" => -76.5018807
      }
    },
    {
      "state" => "NY",
      "city_code" => "longisland",
      "city" => "long island, NY",
      "location" => {
        "lat" => 40.7891424,
        "lng" => -73.13496049999999
      }
    },
    {
      "state" => "NY",
      "city_code" => "newyork",
      "city" => "new york city, NY",
      "location" => {
        "lat" => 40.7143528,
        "lng" => -74.00597309999999
      }
    },
    {
      "state" => "NY",
      "city_code" => "oneonta",
      "city" => "oneonta, NY",
      "location" => {
        "lat" => 42.4528571,
        "lng" => -75.0637746
      }
    },
    {
      "state" => "NY",
      "city_code" => "plattsburgh",
      "city" => "plattsburgh-adirondacks, NY",
      "location" => {
        "lat" => 43.9724537,
        "lng" => -74.3871856
      }
    },
    {
      "state" => "NY",
      "city_code" => "potsdam",
      "city" => "potsdam-canton-massena, NY",
      "location" => {
        "lat" => 44.9281049,
        "lng" => -74.891865
      }
    },
    {
      "state" => "NY",
      "city_code" => "rochester",
      "city" => "rochester, NY",
      "location" => {
        "lat" => 43.16103,
        "lng" => -77.6109219
      }
    },
    {
      "state" => "NY",
      "city_code" => "syracuse",
      "city" => "syracuse, NY",
      "location" => {
        "lat" => 43.0481221,
        "lng" => -76.14742439999999
      }
    },
    {
      "state" => "NY",
      "city_code" => "twintiers",
      "city" => "twin tiers NY/PA, NY",
      "location" => {
        "lat" => 42.0018587,
        "lng" => -76.6348491
      }
    },
    {
      "state" => "NY",
      "city_code" => "utica",
      "city" => "utica-rome-oneida, NY",
      "location" => {
        "lat" => 43.07700699999999,
        "lng" => -75.218217
      }
    },
    {
      "state" => "NY",
      "city_code" => "watertown",
      "city" => "watertown, NY",
      "location" => {
        "lat" => 43.9747838,
        "lng" => -75.91075649999999
      }
    },
    {
      "state" => "NC",
      "city_code" => "asheville",
      "city" => "asheville, NC",
      "location" => {
        "lat" => 35.6009452,
        "lng" => -82.55401499999999
      }
    },
    {
      "state" => "NC",
      "city_code" => "boone",
      "city" => "boone, NC",
      "location" => {
        "lat" => 36.216795,
        "lng" => -81.6745517
      }
    },
    {
      "state" => "NC",
      "city_code" => "charlotte",
      "city" => "charlotte, NC",
      "location" => {
        "lat" => 35.2270869,
        "lng" => -80.8431267
      }
    },
    {
      "state" => "NC",
      "city_code" => "eastnc",
      "city" => "eastern NC, NC",
      "location" => {
        "lat" => 33.9370119,
        "lng" => -78.21770769999999
      }
    },
    {
      "state" => "NC",
      "city_code" => "fayetteville",
      "city" => "fayetteville, NC",
      "location" => {
        "lat" => 35.0526641,
        "lng" => -78.87835849999999
      }
    },
    {
      "state" => "NC",
      "city_code" => "greensboro",
      "city" => "greensboro, NC",
      "location" => {
        "lat" => 36.0726354,
        "lng" => -79.7919754
      }
    },
    {
      "state" => "NC",
      "city_code" => "hickory",
      "city" => "hickory / lenoir, NC",
      "location" => {
        "lat" => 35.8950756,
        "lng" => -81.52125649999999
      }
    },
    {
      "state" => "NC",
      "city_code" => "onslow",
      "city" => "jacksonville , NC",
      "location" => {
        "lat" => 34.7540524,
        "lng" => -77.4302414
      }
    },
    {
      "state" => "NC",
      "city_code" => "outerbanks",
      "city" => "outer banks, NC",
      "location" => {
        "lat" => 35.5668467,
        "lng" => -75.4684908
      }
    },
    {
      "state" => "NC",
      "city_code" => "raleigh",
      "city" => "raleigh / durham / CH, NC",
      "location" => {
        "lat" => 35.9790681,
        "lng" => -78.6316205
      }
    },
    {
      "state" => "NC",
      "city_code" => "wilmington",
      "city" => "wilmington, NC",
      "location" => {
        "lat" => 34.2257255,
        "lng" => -77.9447102
      }
    },
    {
      "state" => "NC",
      "city_code" => "winstonsalem",
      "city" => "winston-salem, NC",
      "location" => {
        "lat" => 36.09985959999999,
        "lng" => -80.244216
      }
    },
    {
      "state" => "ND",
      "city_code" => "bismarck",
      "city" => "bismarck, ND",
      "location" => {
        "lat" => 46.8083268,
        "lng" => -100.7837392
      }
    },
    {
      "state" => "ND",
      "city_code" => "fargo",
      "city" => "fargo / moorhead, ND",
      "location" => {
        "lat" => 46.8419883,
        "lng" => -96.7168313
      }
    },
    {
      "state" => "ND",
      "city_code" => "grandforks",
      "city" => "grand forks, ND",
      "location" => {
        "lat" => 47.9252568,
        "lng" => -97.0328547
      }
    },
    {
      "state" => "ND",
      "city_code" => "nd",
      "city" => "north dakota",
      "location" => {
        "lat" => 47.5514926,
        "lng" => -101.0020119
      }
    },
    {
      "state" => "OH",
      "city_code" => "akroncanton",
      "city" => "akron / canton, OH",
      "location" => {
        "lat" => 41.0285749,
        "lng" => -81.42488519999999
      }
    },
    {
      "state" => "OH",
      "city_code" => "ashtabula",
      "city" => "ashtabula, OH",
      "location" => {
        "lat" => 41.8650534,
        "lng" => -80.7898089
      }
    },
    {
      "state" => "OH",
      "city_code" => "athensohio",
      "city" => "athens , OH",
      "location" => {
        "lat" => 39.3292396,
        "lng" => -82.1012554
      }
    },
    {
      "state" => "OH",
      "city_code" => "chillicothe",
      "city" => "chillicothe, OH",
      "location" => {
        "lat" => 39.3331197,
        "lng" => -82.9824019
      }
    },
    {
      "state" => "OH",
      "city_code" => "cincinnati",
      "city" => "cincinnati, OH",
      "location" => {
        "lat" => 39.1031182,
        "lng" => -84.5120196
      }
    },
    {
      "state" => "OH",
      "city_code" => "cleveland",
      "city" => "cleveland, OH",
      "location" => {
        "lat" => 41.4994954,
        "lng" => -81.6954088
      }
    },
    {
      "state" => "OH",
      "city_code" => "columbus",
      "city" => "columbus, OH",
      "location" => {
        "lat" => 39.9611755,
        "lng" => -82.99879419999999
      }
    },
    {
      "state" => "OH",
      "city_code" => "dayton",
      "city" => "dayton / springfield, OH",
      "location" => {
        "lat" => 39.76994010000001,
        "lng" => -84.151428
      }
    },
    {
      "state" => "OH",
      "city_code" => "limaohio",
      "city" => "lima / findlay, OH",
      "location" => {
        "lat" => 40.7542001,
        "lng" => -84.08411579999999
      }
    },
    {
      "state" => "OH",
      "city_code" => "mansfield",
      "city" => "mansfield, OH",
      "location" => {
        "lat" => 40.75839,
        "lng" => -82.5154471
      }
    },
    {
      "state" => "OH",
      "city_code" => "sandusky",
      "city" => "sandusky, OH",
      "location" => {
        "lat" => 41.4489396,
        "lng" => -82.7079605
      }
    },
    {
      "state" => "OH",
      "city_code" => "toledo",
      "city" => "toledo, OH",
      "location" => {
        "lat" => 41.6639383,
        "lng" => -83.55521200000001
      }
    },
    {
      "state" => "OH",
      "city_code" => "tuscarawas",
      "city" => "tuscarawas co, OH",
      "location" => {
        "lat" => 40.3947887,
        "lng" => -81.4070577
      }
    },
    {
      "state" => "OH",
      "city_code" => "youngstown",
      "city" => "youngstown, OH",
      "location" => {
        "lat" => 41.0997803,
        "lng" => -80.6495194
      }
    },
    {
      "state" => "OH",
      "city_code" => "zanesville",
      "city" => "zanesville / cambridge, OH",
      "location" => {
        "lat" => 39.9701029,
        "lng" => -82.0093866
      }
    },
    {
      "state" => "OK",
      "city_code" => "lawton",
      "city" => "lawton, OK",
      "location" => {
        "lat" => 34.6035669,
        "lng" => -98.39592909999999
      }
    },
    {
      "state" => "OK",
      "city_code" => "enid",
      "city" => "northwest OK, OK",
      "location" => {
        "lat" => 35.0077519,
        "lng" => -97.092877
      }
    },
    {
      "state" => "OK",
      "city_code" => "oklahomacity",
      "city" => "oklahoma city, OK",
      "location" => {
        "lat" => 35.4675602,
        "lng" => -97.5164276
      }
    },
    {
      "state" => "OK",
      "city_code" => "stillwater",
      "city" => "stillwater, OK",
      "location" => {
        "lat" => 36.1156071,
        "lng" => -97.0583681
      }
    },
    {
      "state" => "OK",
      "city_code" => "tulsa",
      "city" => "tulsa, OK",
      "location" => {
        "lat" => 36.1539816,
        "lng" => -95.99277500000001
      }
    },
    {
      "state" => "OR",
      "city_code" => "bend",
      "city" => "bend, OR",
      "location" => {
        "lat" => 44.0581728,
        "lng" => -121.3153096
      }
    },
    {
      "state" => "OR",
      "city_code" => "corvallis",
      "city" => "corvallis/albany, OR",
      "location" => {
        "lat" => 44.6365107,
        "lng" => -123.1059282
      }
    },
    {
      "state" => "OR",
      "city_code" => "eastoregon",
      "city" => "east oregon, OR",
      "location" => {
        "lat" => 43.8041334,
        "lng" => -120.5542012
      }
    },
    {
      "state" => "OR",
      "city_code" => "eugene",
      "city" => "eugene, OR",
      "location" => {
        "lat" => 44.0520691,
        "lng" => -123.0867536
      }
    },
    {
      "state" => "OR",
      "city_code" => "klamath",
      "city" => "klamath falls, OR",
      "location" => {
        "lat" => 42.224867,
        "lng" => -121.7816704
      }
    },
    {
      "state" => "OR",
      "city_code" => "medford",
      "city" => "medford-ashland, OR",
      "location" => {
        "lat" => 42.1945758,
        "lng" => -122.7094767
      }
    },
    {
      "state" => "OR",
      "city_code" => "oregoncoast",
      "city" => "oregon coast, OR",
      "location" => {
        "lat" => 44.6170542,
        "lng" => -124.0465051
      }
    },
    {
      "state" => "OR",
      "city_code" => "portland",
      "city" => "portland, OR",
      "location" => {
        "lat" => 45.5234515,
        "lng" => -122.6762071
      }
    },
    {
      "state" => "OR",
      "city_code" => "roseburg",
      "city" => "roseburg, OR",
      "location" => {
        "lat" => 43.216505,
        "lng" => -123.3417381
      }
    },
    {
      "state" => "OR",
      "city_code" => "salem",
      "city" => "salem, OR",
      "location" => {
        "lat" => 44.9428975,
        "lng" => -123.0350963
      }
    },
    {
      "state" => "PA",
      "city_code" => "altoona",
      "city" => "altoona-johnstown, PA",
      "location" => {
        "lat" => 40.3536089,
        "lng" => -78.4419478
      }
    },
    {
      "state" => "PA",
      "city_code" => "chambersburg",
      "city" => "cumberland valley, PA",
      "location" => {
        "lat" => 39.8110168,
        "lng" => -78.6341996
      }
    },
    {
      "state" => "PA",
      "city_code" => "erie",
      "city" => "erie, PA",
      "location" => {
        "lat" => 42.12922409999999,
        "lng" => -80.085059
      }
    },
    {
      "state" => "PA",
      "city_code" => "harrisburg",
      "city" => "harrisburg, PA",
      "location" => {
        "lat" => 40.2737002,
        "lng" => -76.8844179
      }
    },
    {
      "state" => "PA",
      "city_code" => "lancaster",
      "city" => "lancaster, PA",
      "location" => {
        "lat" => 40.0378755,
        "lng" => -76.3055144
      }
    },
    {
      "state" => "PA",
      "city_code" => "allentown",
      "city" => "lehigh valley, PA",
      "location" => {
        "lat" => 40.7291847,
        "lng" => -75.2479061
      }
    },
    {
      "state" => "PA",
      "city_code" => "meadville",
      "city" => "meadville, PA",
      "location" => {
        "lat" => 41.6414438,
        "lng" => -80.15144839999999
      }
    },
    {
      "state" => "PA",
      "city_code" => "philadelphia",
      "city" => "philadelphia, PA",
      "location" => {
        "lat" => 39.952335,
        "lng" => -75.16378900000001
      }
    },
    {
      "state" => "PA",
      "city_code" => "pittsburgh",
      "city" => "pittsburgh, PA",
      "location" => {
        "lat" => 40.44062479999999,
        "lng" => -79.9958864
      }
    },
    {
      "state" => "PA",
      "city_code" => "poconos",
      "city" => "poconos, PA",
      "location" => {
        "lat" => 40.9890592,
        "lng" => -75.9866055
      }
    },
    {
      "state" => "PA",
      "city_code" => "reading",
      "city" => "reading, PA",
      "location" => {
        "lat" => 40.3356483,
        "lng" => -75.9268747
      }
    },
    {
      "state" => "PA",
      "city_code" => "scranton",
      "city" => "scranton / wilkes-barre, PA",
      "location" => {
        "lat" => 41.33716099999999,
        "lng" => -75.7240654
      }
    },
    {
      "state" => "PA",
      "city_code" => "pennstate",
      "city" => "state college, PA",
      "location" => {
        "lat" => 40.7933949,
        "lng" => -77.8600012
      }
    },
    {
      "state" => "PA",
      "city_code" => "williamsport",
      "city" => "williamsport, PA",
      "location" => {
        "lat" => 41.2411897,
        "lng" => -77.00107860000001
      }
    },
    {
      "state" => "PA",
      "city_code" => "york",
      "city" => "york, PA",
      "location" => {
        "lat" => 39.9625984,
        "lng" => -76.727745
      }
    },
    {
      "state" => "RI",
      "city_code" => "providence",
      "city" => "rhode island",
      "location" => {
        "lat" => 41.5800945,
        "lng" => -71.4774291
      }
    },
    {
      "state" => "SC",
      "city_code" => "charleston",
      "city" => "charleston, SC",
      "location" => {
        "lat" => 32.7765656,
        "lng" => -79.93092159999999
      }
    },
    {
      "state" => "SC",
      "city_code" => "columbia",
      "city" => "columbia, SC",
      "location" => {
        "lat" => 34.0007104,
        "lng" => -81.0348144
      }
    },
    {
      "state" => "SC",
      "city_code" => "florencesc",
      "city" => "florence, SC",
      "location" => {
        "lat" => 34.1954331,
        "lng" => -79.7625625
      }
    },
    {
      "state" => "SC",
      "city_code" => "greenville",
      "city" => "greenville / upstate, SC",
      "location" => {
        "lat" => 34.5528328,
        "lng" => -82.6483442
      }
    },
    {
      "state" => "SC",
      "city_code" => "hiltonhead",
      "city" => "hilton head, SC",
      "location" => {
        "lat" => 32.216316,
        "lng" => -80.752608
      }
    },
    {
      "state" => "SC",
      "city_code" => "myrtlebeach",
      "city" => "myrtle beach, SC",
      "location" => {
        "lat" => 33.6890603,
        "lng" => -78.8866943
      }
    },
    {
      "state" => "SD",
      "city_code" => "nesd",
      "city" => "northeast SD, SD",
      "location" => {
        "lat" => 43.9695148,
        "lng" => -99.9018131
      }
    },
    {
      "state" => "SD",
      "city_code" => "csd",
      "city" => "pierre / central SD, SD",
      "location" => {
        "lat" => 44.3763969,
        "lng" => -100.3530579
      }
    },
    {
      "state" => "SD",
      "city_code" => "rapidcity",
      "city" => "rapid city / west SD, SD",
      "location" => {
        "lat" => 44.0805434,
        "lng" => -103.2310149
      }
    },
    {
      "state" => "SD",
      "city_code" => "siouxfalls",
      "city" => "sioux falls / SE SD, SD",
      "location" => {
        "lat" => 43.5499749,
        "lng" => -96.700327
      }
    },
    {
      "state" => "SD",
      "city_code" => "sd",
      "city" => "south dakota",
      "location" => {
        "lat" => 43.9695148,
        "lng" => -99.9018131
      }
    },
    {
      "state" => "TN",
      "city_code" => "chattanooga",
      "city" => "chattanooga, TN",
      "location" => {
        "lat" => 35.0456297,
        "lng" => -85.3096801
      }
    },
    {
      "state" => "TN",
      "city_code" => "clarksville",
      "city" => "clarksville, TN",
      "location" => {
        "lat" => 36.5297706,
        "lng" => -87.3594528
      }
    },
    {
      "state" => "TN",
      "city_code" => "cookeville",
      "city" => "cookeville, TN",
      "location" => {
        "lat" => 36.162839,
        "lng" => -85.5016423
      }
    },
    {
      "state" => "TN",
      "city_code" => "jacksontn",
      "city" => "jackson  , TN",
      "location" => {
        "lat" => 35.6145169,
        "lng" => -88.81394689999999
      }
    },
    {
      "state" => "TN",
      "city_code" => "knoxville",
      "city" => "knoxville, TN",
      "location" => {
        "lat" => 35.9606384,
        "lng" => -83.9207392
      }
    },
    {
      "state" => "TN",
      "city_code" => "memphis",
      "city" => "memphis, TN",
      "location" => {
        "lat" => 35.1495343,
        "lng" => -90.0489801
      }
    },
    {
      "state" => "TN",
      "city_code" => "nashville",
      "city" => "nashville, TN",
      "location" => {
        "lat" => 36.1666667,
        "lng" => -86.7833333
      }
    },
    {
      "state" => "TN",
      "city_code" => "tricities",
      "city" => "tri-cities, TN",
      "location" => {
        "lat" => 36.4820692,
        "lng" => -82.4089904
      }
    },
    {
      "state" => "TX",
      "city_code" => "abilene",
      "city" => "abilene, TX",
      "location" => {
        "lat" => 32.4487364,
        "lng" => -99.73314390000002
      }
    },
    {
      "state" => "TX",
      "city_code" => "amarillo",
      "city" => "amarillo, TX",
      "location" => {
        "lat" => 35.2219971,
        "lng" => -101.8312969
      }
    },
    {
      "state" => "TX",
      "city_code" => "austin",
      "city" => "austin, TX",
      "location" => {
        "lat" => 30.267153,
        "lng" => -97.7430608
      }
    },
    {
      "state" => "TX",
      "city_code" => "beaumont",
      "city" => "beaumont / port arthur, TX",
      "location" => {
        "lat" => 29.9851829,
        "lng" => -94.06133600000001
      }
    },
    {
      "state" => "TX",
      "city_code" => "brownsville",
      "city" => "brownsville, TX",
      "location" => {
        "lat" => 25.9017472,
        "lng" => -97.4974838
      }
    },
    {
      "state" => "TX",
      "city_code" => "collegestation",
      "city" => "college station, TX",
      "location" => {
        "lat" => 30.627977,
        "lng" => -96.3344068
      }
    },
    {
      "state" => "TX",
      "city_code" => "corpuschristi",
      "city" => "corpus christi, TX",
      "location" => {
        "lat" => 27.8005828,
        "lng" => -97.39638099999999
      }
    },
    {
      "state" => "TX",
      "city_code" => "dallas",
      "city" => "dallas / fort worth, TX",
      "location" => {
        "lat" => 32.802955,
        "lng" => -96.769923
      }
    },
    {
      "state" => "TX",
      "city_code" => "nacogdoches",
      "city" => "deep east texas, TX",
      "location" => {
        "lat" => 31.3337041,
        "lng" => -94.72990209999999
      }
    },
    {
      "state" => "TX",
      "city_code" => "delrio",
      "city" => "del rio / eagle pass, TX",
      "location" => {
        "lat" => 28.7917675,
        "lng" => -100.5187499
      }
    },
    {
      "state" => "TX",
      "city_code" => "elpaso",
      "city" => "el paso, TX",
      "location" => {
        "lat" => 31.7587198,
        "lng" => -106.4869314
      }
    },
    {
      "state" => "TX",
      "city_code" => "galveston",
      "city" => "galveston, TX",
      "location" => {
        "lat" => 29.3013479,
        "lng" => -94.7976958
      }
    },
    {
      "state" => "TX",
      "city_code" => "houston",
      "city" => "houston, TX",
      "location" => {
        "lat" => 29.7601927,
        "lng" => -95.36938959999999
      }
    },
    {
      "state" => "TX",
      "city_code" => "killeen",
      "city" => "killeen / temple / ft hood, TX",
      "location" => {
        "lat" => 31.1388633,
        "lng" => -97.7587605
      }
    },
    {
      "state" => "TX",
      "city_code" => "laredo",
      "city" => "laredo, TX",
      "location" => {
        "lat" => 27.506407,
        "lng" => -99.5075421
      }
    },
    {
      "state" => "TX",
      "city_code" => "lubbock",
      "city" => "lubbock, TX",
      "location" => {
        "lat" => 33.5778631,
        "lng" => -101.8551665
      }
    },
    {
      "state" => "TX",
      "city_code" => "mcallen",
      "city" => "mcallen / edinburg, TX",
      "location" => {
        "lat" => 26.2643963,
        "lng" => -98.2014032
      }
    },
    {
      "state" => "TX",
      "city_code" => "odessa",
      "city" => "odessa / midland, TX",
      "location" => {
        "lat" => 31.8456816,
        "lng" => -102.3676431
      }
    },
    {
      "state" => "TX",
      "city_code" => "sanangelo",
      "city" => "san angelo, TX",
      "location" => {
        "lat" => 31.4637723,
        "lng" => -100.4370375
      }
    },
    {
      "state" => "TX",
      "city_code" => "sanantonio",
      "city" => "san antonio, TX",
      "location" => {
        "lat" => 29.4241219,
        "lng" => -98.49362819999999
      }
    },
    {
      "state" => "TX",
      "city_code" => "sanmarcos",
      "city" => "san marcos, TX",
      "location" => {
        "lat" => 29.8832749,
        "lng" => -97.9413941
      }
    },
    {
      "state" => "TX",
      "city_code" => "bigbend",
      "city" => "southwest TX, TX",
      "location" => {
        "lat" => 31.9685988,
        "lng" => -99.9018131
      }
    },
    {
      "state" => "TX",
      "city_code" => "texoma",
      "city" => "texoma, TX",
      "location" => {
        "lat" => 32.9624321,
        "lng" => -96.3339578
      }
    },
    {
      "state" => "TX",
      "city_code" => "easttexas",
      "city" => "tyler / east TX, TX",
      "location" => {
        "lat" => 32.3512601,
        "lng" => -95.30106239999999
      }
    },
    {
      "state" => "TX",
      "city_code" => "victoriatx",
      "city" => "victoria , TX",
      "location" => {
        "lat" => 28.8052674,
        "lng" => -97.0035982
      }
    },
    {
      "state" => "TX",
      "city_code" => "waco",
      "city" => "waco, TX",
      "location" => {
        "lat" => 31.549333,
        "lng" => -97.1466695
      }
    },
    {
      "state" => "TX",
      "city_code" => "wichitafalls",
      "city" => "wichita falls, TX",
      "location" => {
        "lat" => 33.9137085,
        "lng" => -98.4933873
      }
    },
    {
      "state" => "UT",
      "city_code" => "logan",
      "city" => "logan, UT",
      "location" => {
        "lat" => 41.7369803,
        "lng" => -111.8338359
      }
    },
    {
      "state" => "UT",
      "city_code" => "ogden",
      "city" => "ogden-clearfield, UT",
      "location" => {
        "lat" => 41.1107771,
        "lng" => -112.0260538
      }
    },
    {
      "state" => "UT",
      "city_code" => "provo",
      "city" => "provo / orem, UT",
      "location" => {
        "lat" => 40.2303886,
        "lng" => -111.7853143
      }
    },
    {
      "state" => "UT",
      "city_code" => "saltlakecity",
      "city" => "salt lake city, UT",
      "location" => {
        "lat" => 40.7607793,
        "lng" => -111.8910474
      }
    },
    {
      "state" => "UT",
      "city_code" => "stgeorge",
      "city" => "st george, UT",
      "location" => {
        "lat" => 37.0952778,
        "lng" => -113.5780556
      }
    },
    {
      "state" => "VT",
      "city_code" => "burlington",
      "city" => "vermont",
      "location" => {
        "lat" => 44.5588028,
        "lng" => -72.57784149999999
      }
    },
    {
      "state" => "VA",
      "city_code" => "charlottesville",
      "city" => "charlottesville, VA",
      "location" => {
        "lat" => 38.0293059,
        "lng" => -78.47667810000002
      }
    },
    {
      "state" => "VA",
      "city_code" => "danville",
      "city" => "danville, VA",
      "location" => {
        "lat" => 36.5859718,
        "lng" => -79.39502279999999
      }
    },
    {
      "state" => "VA",
      "city_code" => "fredericksburg",
      "city" => "fredericksburg, VA",
      "location" => {
        "lat" => 38.3031837,
        "lng" => -77.4605399
      }
    },
    {
      "state" => "VA",
      "city_code" => "norfolk",
      "city" => "hampton roads, VA",
      "location" => {
        "lat" => 36.7862239,
        "lng" => -76.5488232
      }
    },
    {
      "state" => "VA",
      "city_code" => "harrisonburg",
      "city" => "harrisonburg, VA",
      "location" => {
        "lat" => 38.4495688,
        "lng" => -78.8689155
      }
    },
    {
      "state" => "VA",
      "city_code" => "lynchburg",
      "city" => "lynchburg, VA",
      "location" => {
        "lat" => 37.4137536,
        "lng" => -79.14224639999999
      }
    },
    {
      "state" => "VA",
      "city_code" => "blacksburg",
      "city" => "new river valley, VA",
      "location" => {
        "lat" => 37.1753479,
        "lng" => -80.54384499999999
      }
    },
    {
      "state" => "VA",
      "city_code" => "richmond",
      "city" => "richmond, VA",
      "location" => {
        "lat" => 37.5407246,
        "lng" => -77.4360481
      }
    },
    {
      "state" => "VA",
      "city_code" => "roanoke",
      "city" => "roanoke, VA",
      "location" => {
        "lat" => 37.2709704,
        "lng" => -79.9414266
      }
    },
    {
      "state" => "VA",
      "city_code" => "swva",
      "city" => "southwest VA, VA",
      "location" => {
        "lat" => 37.4315734,
        "lng" => -78.6568942
      }
    },
    {
      "state" => "VA",
      "city_code" => "winchester",
      "city" => "winchester, VA",
      "location" => {
        "lat" => 39.1856597,
        "lng" => -78.1633341
      }
    },
    {
      "state" => "Washington",
      "city_code" => "bellingham",
      "city" => "bellingham, Washington",
      "location" => {
        "lat" => 48.7595529,
        "lng" => -122.4882249
      }
    },
    {
      "state" => "Washington",
      "city_code" => "kpr",
      "city" => "kennewick-pasco-richland, Washington",
      "location" => {
        "lat" => 46.1093145,
        "lng" => -119.1994766
      }
    },
    {
      "state" => "Washington",
      "city_code" => "moseslake",
      "city" => "moses lake, Washington",
      "location" => {
        "lat" => 47.1301417,
        "lng" => -119.2780771
      }
    },
    {
      "state" => "Washington",
      "city_code" => "olympic",
      "city" => "olympic peninsula, Washington",
      "location" => {
        "lat" => 47.750087,
        "lng" => -123.7510225
      }
    },
    {
      "state" => "Washington",
      "city_code" => "pullman",
      "city" => "pullman / moscow, Washington",
      "location" => {
        "lat" => 46.7441786,
        "lng" => -117.109102
      }
    },
    {
      "state" => "Washington",
      "city_code" => "seattle",
      "city" => "seattle-tacoma, Washington",
      "location" => {
        "lat" => 47.2528768,
        "lng" => -122.4442906
      }
    },
    {
      "state" => "Washington",
      "city_code" => "skagit",
      "city" => "skagit / island / SJI, Washington",
      "location" => {
        "lat" => 38.8951118,
        "lng" => -77.0363658
      }
    },
    {
      "state" => "Washington",
      "city_code" => "spokane",
      "city" => "spokane / coeur d'alene, Washington",
      "location" => {
        "lat" => 47.7568407,
        "lng" => -116.6222056
      }
    },
    {
      "state" => "Washington",
      "city_code" => "wenatchee",
      "city" => "wenatchee, Washington",
      "location" => {
        "lat" => 47.4234599,
        "lng" => -120.3103494
      }
    },
    {
      "state" => "Washington",
      "city_code" => "yakima",
      "city" => "yakima, Washington",
      "location" => {
        "lat" => 46.6020711,
        "lng" => -120.5058987
      }
    },
    {
      "state" => "WV",
      "city_code" => "charlestonwv",
      "city" => "charleston , WV",
      "location" => {
        "lat" => 38.3498195,
        "lng" => -81.6326234
      }
    },
    {
      "state" => "WV",
      "city_code" => "martinsburg",
      "city" => "eastern panhandle, WV",
      "location" => {
        "lat" => 39.3726499,
        "lng" => -78.0309542
      }
    },
    {
      "state" => "WV",
      "city_code" => "huntington",
      "city" => "huntington-ashland, WV",
      "location" => {
        "lat" => 38.4191667,
        "lng" => -82.4452778
      }
    },
    {
      "state" => "WV",
      "city_code" => "morgantown",
      "city" => "morgantown, WV",
      "location" => {
        "lat" => 39.629526,
        "lng" => -79.95589679999999
      }
    },
    {
      "state" => "WV",
      "city_code" => "wheeling",
      "city" => "northern panhandle, WV",
      "location" => {
        "lat" => 40.079525,
        "lng" => -80.6961501
      }
    },
    {
      "state" => "WV",
      "city_code" => "parkersburg",
      "city" => "parkersburg-marietta, WV",
      "location" => {
        "lat" => 39.2637209,
        "lng" => -81.555488
      }
    },
    {
      "state" => "WV",
      "city_code" => "swv",
      "city" => "southern WV, WV",
      "location" => {
        "lat" => 38.6071338,
        "lng" => -80.8322428
      }
    },
    {
      "state" => "WV",
      "city_code" => "wv",
      "city" => "west virginia (old), WV",
      "location" => {
        "lat" => 37.4315734,
        "lng" => -78.6568942
      }
    },
    {
      "state" => "WI",
      "city_code" => "appleton",
      "city" => "appleton-oshkosh-FDL, WI",
      "location" => {
        "lat" => 43.7844397,
        "lng" => -88.7878678
      }
    },
    {
      "state" => "WI",
      "city_code" => "eauclaire",
      "city" => "eau claire, WI",
      "location" => {
        "lat" => 44.811349,
        "lng" => -91.4984941
      }
    },
    {
      "state" => "WI",
      "city_code" => "greenbay",
      "city" => "green bay, WI",
      "location" => {
        "lat" => 44.51915899999999,
        "lng" => -88.019826
      }
    },
    {
      "state" => "WI",
      "city_code" => "janesville",
      "city" => "janesville, WI",
      "location" => {
        "lat" => 42.6827885,
        "lng" => -89.0187222
      }
    },
    {
      "state" => "WI",
      "city_code" => "racine",
      "city" => "kenosha-racine, WI",
      "location" => {
        "lat" => 42.5847425,
        "lng" => -87.82118539999999
      }
    },
    {
      "state" => "WI",
      "city_code" => "lacrosse",
      "city" => "la crosse, WI",
      "location" => {
        "lat" => 43.8013556,
        "lng" => -91.23958069999999
      }
    },
    {
      "state" => "WI",
      "city_code" => "madison",
      "city" => "madison, WI",
      "location" => {
        "lat" => 43.0730517,
        "lng" => -89.4012302
      }
    },
    {
      "state" => "WI",
      "city_code" => "milwaukee",
      "city" => "milwaukee, WI",
      "location" => {
        "lat" => 43.0389025,
        "lng" => -87.9064736
      }
    },
    {
      "state" => "WI",
      "city_code" => "northernwi",
      "city" => "northern WI, WI",
      "location" => {
        "lat" => 42.9044821,
        "lng" => -91.10417369999999
      }
    },
    {
      "state" => "WI",
      "city_code" => "sheboygan",
      "city" => "sheboygan, WI",
      "location" => {
        "lat" => 43.7508284,
        "lng" => -87.71453
      }
    },
    {
      "state" => "WI",
      "city_code" => "wausau",
      "city" => "wausau, WI",
      "location" => {
        "lat" => 44.9591352,
        "lng" => -89.6301221
      }
    },
    {
      "state" => "WY",
      "city_code" => "wyoming",
      "city" => "wyoming",
      "location" => {
        "lat" => 43.0759678,
        "lng" => -107.2902839
      }
    },
    {
      "state" => "GU",
      "city_code" => "micronesia",
      "city" => "guam-micronesia, Territories",
      "location" => {
        "lat" => 13.444304,
        "lng" => 144.793731
      }
    },
    {
      "state" => "PR",
      "city_code" => "puertorico",
      "city" => "puerto rico, Territories",
      "location" => {}
    },
    {
      "state" => "VI",
      "city_code" => "virgin",
      "city" => "U.S. virgin islands, Territories",
      "location" => {
        "lat" => 18.3204664,
        "lng" => -64.9198081
      }
    }]
    
    canada = [{
      "state" => "Alberta",
      "city_code" => "calgary",
      "city" => "calgary, Alberta",
      "location" => {
        "lat" => 51.0453246,
        "lng" => -114.0581012
      }
    },
    {
      "state" => "Alberta",
      "city_code" => "edmonton",
      "city" => "edmonton, Alberta",
      "location" => {
        "lat" => 53.544389,
        "lng" => -113.4909267
      }
    },
    {
      "state" => "Alberta",
      "city_code" => "ftmcmurray",
      "city" => "ft mcmurray, Alberta",
      "location" => {
        "lat" => 56.72637959999999,
        "lng" => -111.3803407
      }
    },
    {
      "state" => "Alberta",
      "city_code" => "lethbridge",
      "city" => "lethbridge, Alberta",
      "location" => {
        "lat" => 49.69349,
        "lng" => -112.84184
      }
    },
    {
      "state" => "Alberta",
      "city_code" => "hat",
      "city" => "medicine hat, Alberta",
      "location" => {
        "lat" => 50.0405486,
        "lng" => -110.6764258
      }
    },
    {
      "state" => "Alberta",
      "city_code" => "peace",
      "city" => "peace river country, Alberta",
      "location" => {
        "lat" => 53.9332706,
        "lng" => -116.5765035
      }
    },
    {
      "state" => "Alberta",
      "city_code" => "reddeer",
      "city" => "red deer, Alberta",
      "location" => {
        "lat" => 52.2681118,
        "lng" => -113.8112386
      }
    },
    {
      "state" => "British Columbia",
      "city_code" => "cariboo",
      "city" => "cariboo, British Columbia",
      "location" => {
        "lat" => 52.4031805,
        "lng" => -123.4553619
      }
    },
    {
      "state" => "British Columbia",
      "city_code" => "comoxvalley",
      "city" => "comox valley, British Columbia",
      "location" => {
        "lat" => 49.7139296,
        "lng" => -124.8905776
      }
    },
    {
      "state" => "British Columbia",
      "city_code" => "abbotsford",
      "city" => "fraser valley, British Columbia",
      "location" => {
        "lat" => 49.3764104,
        "lng" => -121.8159307
      }
    },
    {
      "state" => "British Columbia",
      "city_code" => "kamloops",
      "city" => "kamloops, British Columbia",
      "location" => {
        "lat" => 50.674522,
        "lng" => -120.3272674
      }
    },
    {
      "state" => "British Columbia",
      "city_code" => "kelowna",
      "city" => "kelowna / okanagan, British Columbia",
      "location" => {
        "lat" => 49.83385,
        "lng" => -119.5236098
      }
    },
    {
      "state" => "British Columbia",
      "city_code" => "cranbrook",
      "city" => "kootenays, British Columbia",
      "location" => {
        "lat" => 50.12841050000001,
        "lng" => -115.7568033
      }
    },
    {
      "state" => "British Columbia",
      "city_code" => "nanaimo",
      "city" => "nanaimo, British Columbia",
      "location" => {
        "lat" => 49.1658836,
        "lng" => -123.9400647
      }
    },
    {
      "state" => "British Columbia",
      "city_code" => "princegeorge",
      "city" => "prince george, British Columbia",
      "location" => {
        "lat" => 53.9170641,
        "lng" => -122.7496693
      }
    },
    {
      "state" => "British Columbia",
      "city_code" => "skeena",
      "city" => "skeena-bulkley, British Columbia",
      "location" => {
        "lat" => 54.7882676,
        "lng" => -127.164868
      }
    },
    {
      "state" => "British Columbia",
      "city_code" => "sunshine",
      "city" => "sunshine coast, British Columbia",
      "location" => {
        "lat" => 49.7604377,
        "lng" => -123.7643986
      }
    },
    {
      "state" => "British Columbia",
      "city_code" => "vancouver",
      "city" => "vancouver, British Columbia",
      "location" => {
        "lat" => 49.261226,
        "lng" => -123.1139268
      }
    },
    {
      "state" => "British Columbia",
      "city_code" => "victoria",
      "city" => "victoria, British Columbia",
      "location" => {
        "lat" => 48.4284207,
        "lng" => -123.3656444
      }
    },
    {
      "state" => "British Columbia",
      "city_code" => "whistler",
      "city" => "whistler, British Columbia",
      "location" => {
        "lat" => 50.1163196,
        "lng" => -122.9573563
      }
    },
    {
      "state" => "Manitoba",
      "city_code" => "winnipeg",
      "city" => "winnipeg, Manitoba",
      "location" => {
        "lat" => 49.8997541,
        "lng" => -97.1374937
      }
    },
    {
      "state" => "New Brunswick",
      "city_code" => "newbrunswick",
      "city" => "new brunswick",
      "location" => {
        "lat" => 40.4862157,
        "lng" => -74.4518188
      }
    },
    {
      "state" => "Newfoundland and Labrador",
      "city_code" => "newfoundland",
      "city" => "st john's, Newfoundland and Labrador",
      "location" => {
        "lat" => 47.5605413,
        "lng" => -52.71283150000001
      }
    },
    {
      "state" => "Northwest Territories",
      "city_code" => "territories",
      "city" => "territories, Northwest Territories",
      "location" => {
        "lat" => 60.0024092,
        "lng" => -106.6115123
      }
    },
    {
      "state" => "Northwest Territories",
      "city_code" => "yellowknife",
      "city" => "yellowknife, Northwest Territories",
      "location" => {
        "lat" => 62.4539717,
        "lng" => -114.3717886
      }
    },
    {
      "state" => "Nova Scotia",
      "city_code" => "halifax",
      "city" => "halifax, Nova Scotia",
      "location" => {
        "lat" => 44.6488625,
        "lng" => -63.5753196
      }
    },
    {
      "state" => "Ontario",
      "city_code" => "barrie",
      "city" => "barrie, Ontario",
      "location" => {
        "lat" => 44.3780902,
        "lng" => -79.7016159
      }
    },
    {
      "state" => "Ontario",
      "city_code" => "belleville",
      "city" => "belleville, Ontario",
      "location" => {
        "lat" => 44.1627589,
        "lng" => -77.3832315
      }
    },
    {
      "state" => "Ontario",
      "city_code" => "brantford",
      "city" => "brantford-woodstock, Ontario",
      "location" => {
        "lat" => 43.1314966,
        "lng" => -80.74716509999999
      }
    },
    {
      "state" => "Ontario",
      "city_code" => "chatham",
      "city" => "chatham-kent, Ontario",
      "location" => {
        "lat" => 42.4048028,
        "lng" => -82.19103779999999
      }
    },
    {
      "state" => "Ontario",
      "city_code" => "cornwall",
      "city" => "cornwall, Ontario",
      "location" => {
        "lat" => 45.0212762,
        "lng" => -74.730345
      }
    },
    {
      "state" => "Ontario",
      "city_code" => "guelph",
      "city" => "guelph, Ontario",
      "location" => {
        "lat" => 43.5448048,
        "lng" => -80.24816659999999
      }
    },
    {
      "state" => "Ontario",
      "city_code" => "hamilton",
      "city" => "hamilton-burlington, Ontario",
      "location" => {
        "lat" => 43.3255196,
        "lng" => -79.7990319
      }
    },
    {
      "state" => "Ontario",
      "city_code" => "kingston",
      "city" => "kingston, Ontario",
      "location" => {
        "lat" => 44.2311717,
        "lng" => -76.4859544
      }
    },
    {
      "state" => "Ontario",
      "city_code" => "kitchener",
      "city" => "kitchener-waterloo-cambridge, Ontario",
      "location" => {
        "lat" => 43.4019123,
        "lng" => -80.37930850000001
      }
    },
    {
      "state" => "Ontario",
      "city_code" => "londonon",
      "city" => "london , Ontario",
      "location" => {
        "lat" => 42.9869502,
        "lng" => -81.243177
      }
    },
    {
      "state" => "Ontario",
      "city_code" => "niagara",
      "city" => "niagara region, Ontario",
      "location" => {
        "lat" => 43.0895577,
        "lng" => -79.0849436
      }
    },
    {
      "state" => "Ontario",
      "city_code" => "ottawa",
      "city" => "ottawa-hull-gatineau, Ontario",
      "location" => {
        "lat" => 45.428731,
        "lng" => -75.71336579999999
      }
    },
    {
      "state" => "Ontario",
      "city_code" => "owensound",
      "city" => "owen sound, Ontario",
      "location" => {
        "lat" => 44.5690305,
        "lng" => -80.9405602
      }
    },
    {
      "state" => "Ontario",
      "city_code" => "peterborough",
      "city" => "peterborough, Ontario",
      "location" => {
        "lat" => 44.30619309999999,
        "lng" => -78.32159589999999
      }
    },
    {
      "state" => "Ontario",
      "city_code" => "sarnia",
      "city" => "sarnia, Ontario",
      "location" => {
        "lat" => 42.974536,
        "lng" => -82.4065901
      }
    },
    {
      "state" => "Ontario",
      "city_code" => "soo",
      "city" => "sault ste marie, Ontario",
      "location" => {
        "lat" => 46.52185799999999,
        "lng" => -84.3460896
      }
    },
    {
      "state" => "Ontario",
      "city_code" => "sudbury",
      "city" => "sudbury, Ontario",
      "location" => {
        "lat" => 46.48999999999999,
        "lng" => -81.00999999999999
      }
    },
    {
      "state" => "Ontario",
      "city_code" => "thunderbay",
      "city" => "thunder bay, Ontario",
      "location" => {
        "lat" => 48.3808951,
        "lng" => -89.2476823
      }
    },
    {
      "state" => "Ontario",
      "city_code" => "toronto",
      "city" => "toronto, Ontario",
      "location" => {
        "lat" => 43.653226,
        "lng" => -79.3831843
      }
    },
    {
      "state" => "Ontario",
      "city_code" => "windsor",
      "city" => "windsor, Ontario",
      "location" => {
        "lat" => 42.3183446,
        "lng" => -83.0342423
      }
    },
    {
      "state" => "Prince Edward Island",
      "city_code" => "pei",
      "city" => "prince edward island",
      "location" => {
        "lat" => 46.510712,
        "lng" => -63.41681359999999
      }
    },
    {
      "state" => "Quebec",
      "city_code" => "montreal",
      "city" => "montreal, Quebec",
      "location" => {
        "lat" => 45.5086699,
        "lng" => -73.55399249999999
      }
    },
    {
      "state" => "Quebec",
      "city_code" => "quebec",
      "city" => "quebec city, Quebec",
      "location" => {
        "lat" => 46.8032826,
        "lng" => -71.242796
      }
    },
    {
      "state" => "Quebec",
      "city_code" => "saguenay",
      "city" => "saguenay, Quebec",
      "location" => {
        "lat" => 48.4280529,
        "lng" => -71.0684923
      }
    },
    {
      "state" => "Quebec",
      "city_code" => "sherbrooke",
      "city" => "sherbrooke, Quebec",
      "location" => {
        "lat" => 45.4009928,
        "lng" => -71.8824288
      }
    },
    {
      "state" => "Quebec",
      "city_code" => "troisrivieres",
      "city" => "trois-rivieres, Quebec",
      "location" => {
        "lat" => 46.3432397,
        "lng" => -72.5432834
      }
    },
    {
      "state" => "Saskatchewan",
      "city_code" => "regina",
      "city" => "regina, Saskatchewan",
      "location" => {
        "lat" => 50.4547222,
        "lng" => -104.6066667
      }
    },
    {
      "state" => "Saskatchewan",
      "city_code" => "saskatoon",
      "city" => "saskatoon, Saskatchewan",
      "location" => {
        "lat" => 52.1343699,
        "lng" => -106.647656
      }
    },
    {
      "state" => "Yukon Territory",
      "city_code" => "whitehorse",
      "city" => "whitehorse, Yukon Territory",
      "location" => {
        "lat" => 60.7211871,
        "lng" => -135.0568449
      }
    }]
    
    europe = [{
      "state" => "Austria",
      "city_code" => "vienna",
      "city" => "vienna, Austria",
      "location" => {
        "lat" => 48.2081743,
        "lng" => 16.3738189
      }
    },
    {
      "state" => "Belgium",
      "city_code" => "brussels",
      "city" => "belgium",
      "location" => {
        "lat" => 50.503887,
        "lng" => 4.469936
      }
    },
    {
      "state" => "Bulgaria",
      "city_code" => "bulgaria",
      "city" => "bulgaria",
      "location" => {
        "lat" => 42.733883,
        "lng" => 25.48583
      }
    },
    {
      "state" => "Croatia",
      "city_code" => "zagreb",
      "city" => "croatia",
      "location" => {
        "lat" => 45.7533427,
        "lng" => 15.9891256
      }
    },
    {
      "state" => "Czech Republic",
      "city_code" => "prague",
      "city" => "prague, Czech Republic",
      "location" => {
        "lat" => 50.0755381,
        "lng" => 14.4378005
      }
    },
    {
      "state" => "Denmark",
      "city_code" => "copenhagen",
      "city" => "copenhagen, Denmark",
      "location" => {
        "lat" => 55.6760968,
        "lng" => 12.5683371
      }
    },
    {
      "state" => "Finland",
      "city_code" => "helsinki",
      "city" => "finland",
      "location" => {
        "lat" => 61.92410999999999,
        "lng" => 25.748151
      }
    },
    {
      "state" => "France",
      "city_code" => "bordeaux",
      "city" => "bordeaux, France",
      "location" => {
        "lat" => 44.837789,
        "lng" => -0.57918
      }
    },
    {
      "state" => "France",
      "city_code" => "rennes",
      "city" => "brittany, France",
      "location" => {
        "lat" => 48.2020471,
        "lng" => -2.9326435
      }
    },
    {
      "state" => "France",
      "city_code" => "grenoble",
      "city" => "grenoble, France",
      "location" => {
        "lat" => 45.188529,
        "lng" => 5.724524
      }
    },
    {
      "state" => "France",
      "city_code" => "lille",
      "city" => "lille, France",
      "location" => {
        "lat" => 50.62925,
        "lng" => 3.057256
      }
    },
    {
      "state" => "France",
      "city_code" => "loire",
      "city" => "loire valley, France",
      "location" => {
        "lat" => 47.504582,
        "lng" => 1.230458
      }
    },
    {
      "state" => "France",
      "city_code" => "lyon",
      "city" => "lyon, France",
      "location" => {
        "lat" => 45.764043,
        "lng" => 4.835659
      }
    },
    {
      "state" => "France",
      "city_code" => "marseilles",
      "city" => "marseille, France",
      "location" => {
        "lat" => 43.296482,
        "lng" => 5.36978
      }
    },
    {
      "state" => "France",
      "city_code" => "montpellier",
      "city" => "montpellier, France",
      "location" => {
        "lat" => 43.610769,
        "lng" => 3.876716
      }
    },
    {
      "state" => "France",
      "city_code" => "cotedazur",
      "city" => "nice / cote d'azur, France",
      "location" => {
        "lat" => 43.7801064,
        "lng" => 7.6019731
      }
    },
    {
      "state" => "France",
      "city_code" => "rouen",
      "city" => "normandy, France",
      "location" => {
        "lat" => 48.634467,
        "lng" => -4.3819795
      }
    },
    {
      "state" => "France",
      "city_code" => "paris",
      "city" => "paris, France",
      "location" => {
        "lat" => 48.856614,
        "lng" => 2.3522219
      }
    },
    {
      "state" => "France",
      "city_code" => "strasbourg",
      "city" => "strasbourg, France",
      "location" => {
        "lat" => 48.583148,
        "lng" => 7.747882
      }
    },
    {
      "state" => "France",
      "city_code" => "toulouse",
      "city" => "toulouse, France",
      "location" => {
        "lat" => 43.604652,
        "lng" => 1.444209
      }
    },
    {
      "state" => "Germany",
      "city_code" => "berlin",
      "city" => "berlin, Germany",
      "location" => {
        "lat" => 52.519171,
        "lng" => 13.4060912
      }
    },
    {
      "state" => "Germany",
      "city_code" => "bremen",
      "city" => "bremen, Germany",
      "location" => {
        "lat" => 53.07929619999999,
        "lng" => 8.8016937
      }
    },
    {
      "state" => "Germany",
      "city_code" => "cologne",
      "city" => "cologne, Germany",
      "location" => {
        "lat" => 50.937531,
        "lng" => 6.9602786
      }
    },
    {
      "state" => "Germany",
      "city_code" => "dresden",
      "city" => "dresden, Germany",
      "location" => {
        "lat" => 51.0504088,
        "lng" => 13.7372621
      }
    },
    {
      "state" => "Germany",
      "city_code" => "dusseldorf",
      "city" => "dusseldorf, Germany",
      "location" => {
        "lat" => 51.2277411,
        "lng" => 6.7734556
      }
    },
    {
      "state" => "Germany",
      "city_code" => "essen",
      "city" => "essen / ruhr, Germany",
      "location" => {
        "lat" => 51.359872,
        "lng" => 7.640398399999999
      }
    },
    {
      "state" => "Germany",
      "city_code" => "frankfurt",
      "city" => "frankfurt, Germany",
      "location" => {
        "lat" => 50.1109221,
        "lng" => 8.6821267
      }
    },
    {
      "state" => "Germany",
      "city_code" => "hamburg",
      "city" => "hamburg, Germany",
      "location" => {
        "lat" => 53.5510846,
        "lng" => 9.9936818
      }
    },
    {
      "state" => "Germany",
      "city_code" => "hannover",
      "city" => "hannover, Germany",
      "location" => {
        "lat" => 52.3758916,
        "lng" => 9.732010400000002
      }
    },
    {
      "state" => "Germany",
      "city_code" => "heidelberg",
      "city" => "heidelberg, Germany",
      "location" => {
        "lat" => 49.3987524,
        "lng" => 8.6724335
      }
    },
    {
      "state" => "Germany",
      "city_code" => "kaiserslautern",
      "city" => "kaiserslautern, Germany",
      "location" => {
        "lat" => 49.4400657,
        "lng" => 7.7491265
      }
    },
    {
      "state" => "Germany",
      "city_code" => "leipzig",
      "city" => "leipzig, Germany",
      "location" => {
        "lat" => 51.3396955,
        "lng" => 12.3730747
      }
    },
    {
      "state" => "Germany",
      "city_code" => "munich",
      "city" => "munich, Germany",
      "location" => {
        "lat" => 48.1366069,
        "lng" => 11.5770851
      }
    },
    {
      "state" => "Germany",
      "city_code" => "nuremberg",
      "city" => "nuremberg, Germany",
      "location" => {
        "lat" => 49.45203,
        "lng" => 11.07675
      }
    },
    {
      "state" => "Germany",
      "city_code" => "stuttgart",
      "city" => "stuttgart, Germany",
      "location" => {
        "lat" => 48.7754181,
        "lng" => 9.181758799999999
      }
    },
    {
      "state" => "Greece",
      "city_code" => "athens",
      "city" => "greece",
      "location" => {
        "lat" => 39.074208,
        "lng" => 21.824312
      }
    },
    {
      "state" => "Hungary",
      "city_code" => "budapest",
      "city" => "budapest, Hungary",
      "location" => {
        "lat" => 47.4984056,
        "lng" => 19.0407578
      }
    },
    {
      "state" => "Iceland",
      "city_code" => "reykjavik",
      "city" => "reykjavik, Iceland",
      "location" => {
        "lat" => 64.13533799999999,
        "lng" => -21.89521
      }
    },
    {
      "state" => "Ireland",
      "city_code" => "dublin",
      "city" => "dublin, Ireland",
      "location" => {
        "lat" => 53.3494426,
        "lng" => -6.260082499999999
      }
    },
    {
      "state" => "Italy",
      "city_code" => "bologna",
      "city" => "bologna, Italy",
      "location" => {
        "lat" => 44.494887,
        "lng" => 11.3426163
      }
    },
    {
      "state" => "Italy",
      "city_code" => "florence",
      "city" => "florence / tuscany, Italy",
      "location" => {
        "lat" => 43.7710332,
        "lng" => 11.2480006
      }
    },
    {
      "state" => "Italy",
      "city_code" => "genoa",
      "city" => "genoa, Italy",
      "location" => {
        "lat" => 44.4056499,
        "lng" => 8.946256
      }
    },
    {
      "state" => "Italy",
      "city_code" => "milan",
      "city" => "milan, Italy",
      "location" => {
        "lat" => 45.4654542,
        "lng" => 9.186516
      }
    },
    {
      "state" => "Italy",
      "city_code" => "naples",
      "city" => "napoli / campania, Italy",
      "location" => {
        "lat" => 40.8517746,
        "lng" => 14.2681244
      }
    },
    {
      "state" => "Italy",
      "city_code" => "perugia",
      "city" => "perugia, Italy",
      "location" => {
        "lat" => 43.1107168,
        "lng" => 12.3908279
      }
    },
    {
      "state" => "Italy",
      "city_code" => "rome",
      "city" => "rome, Italy",
      "location" => {
        "lat" => 41.9015141,
        "lng" => 12.4607737
      }
    },
    {
      "state" => "Italy",
      "city_code" => "sardinia",
      "city" => "sardinia, Italy",
      "location" => {
        "lat" => 40.0861417,
        "lng" => 8.9800261
      }
    },
    {
      "state" => "Italy",
      "city_code" => "sicily",
      "city" => "sicilia, Italy",
      "location" => {
        "lat" => 37.2806905,
        "lng" => 12.8054753
      }
    },
    {
      "state" => "Italy",
      "city_code" => "torino",
      "city" => "torino, Italy",
      "location" => {
        "lat" => 45.0629022,
        "lng" => 7.6784897
      }
    },
    {
      "state" => "Italy",
      "city_code" => "venice",
      "city" => "venice / veneto, Italy",
      "location" => {
        "lat" => 45.4408474,
        "lng" => 12.3155151
      }
    },
    {
      "state" => "Luxembourg",
      "city_code" => "luxembourg",
      "city" => "luxembourg",
      "location" => {
        "lat" => 49.815273,
        "lng" => 6.129582999999999
      }
    },
    {
      "state" => "Netherlands",
      "city_code" => "amsterdam",
      "city" => "amsterdam / randstad, Netherlands",
      "location" => {
        "lat" => 52.3683695,
        "lng" => 5.207230399999999
      }
    },
    {
      "state" => "Norway",
      "city_code" => "oslo",
      "city" => "norway",
      "location" => {
        "lat" => 60.47202399999999,
        "lng" => 8.468945999999999
      }
    },
    {
      "state" => "Poland",
      "city_code" => "warsaw",
      "city" => "poland",
      "location" => {
        "lat" => 51.919438,
        "lng" => 19.145136
      }
    },
    {
      "state" => "Portugal",
      "city_code" => "faro",
      "city" => "faro / algarve, Portugal",
      "location" => {
        "lat" => 37.0286806,
        "lng" => -7.923337
      }
    },
    {
      "state" => "Portugal",
      "city_code" => "lisbon",
      "city" => "lisbon, Portugal",
      "location" => {
        "lat" => 38.7252993,
        "lng" => -9.150036400000001
      }
    },
    {
      "state" => "Portugal",
      "city_code" => "porto",
      "city" => "porto, Portugal",
      "location" => {
        "lat" => 41.1650559,
        "lng" => -8.602815999999999
      }
    },
    {
      "state" => "Romania",
      "city_code" => "bucharest",
      "city" => "romania",
      "location" => {
        "lat" => 45.943161,
        "lng" => 24.96676
      }
    },
    {
      "state" => "Russian Federation",
      "city_code" => "moscow",
      "city" => "moscow, Russian Federation",
      "location" => {
        "lat" => 55.7427928,
        "lng" => 37.6154009
      }
    },
    {
      "state" => "Russian Federation",
      "city_code" => "stpetersburg",
      "city" => "st petersburg, Russian Federation",
      "location" => {
        "lat" => 60.07623830000001,
        "lng" => 30.1213829
      }
    },
    {
      "state" => "Spain",
      "city_code" => "alicante",
      "city" => "alicante, Spain",
      "location" => {
        "lat" => 38.34521,
        "lng" => -0.4809944999999999
      }
    },
    {
      "state" => "Spain",
      "city_code" => "baleares",
      "city" => "baleares, Spain",
      "location" => {
        "lat" => 39.5341789,
        "lng" => 2.8577105
      }
    },
    {
      "state" => "Spain",
      "city_code" => "barcelona",
      "city" => "barcelona, Spain",
      "location" => {
        "lat" => 41.387917,
        "lng" => 2.1699187
      }
    },
    {
      "state" => "Spain",
      "city_code" => "bilbao",
      "city" => "bilbao, Spain",
      "location" => {
        "lat" => 43.2569629,
        "lng" => -2.9234409
      }
    },
    {
      "state" => "Spain",
      "city_code" => "cadiz",
      "city" => "cadiz, Spain",
      "location" => {
        "lat" => 36.5297156,
        "lng" => -6.2926926
      }
    },
    {
      "state" => "Spain",
      "city_code" => "canarias",
      "city" => "canarias, Spain",
      "location" => {
        "lat" => 28.2915637,
        "lng" => -16.6291304
      }
    },
    {
      "state" => "Spain",
      "city_code" => "granada",
      "city" => "granada, Spain",
      "location" => {
        "lat" => 37.17648740000001,
        "lng" => -3.5979291
      }
    },
    {
      "state" => "Spain",
      "city_code" => "madrid",
      "city" => "madrid, Spain",
      "location" => {
        "lat" => 40.4166909,
        "lng" => -3.700345399999999
      }
    },
    {
      "state" => "Spain",
      "city_code" => "malaga",
      "city" => "malaga, Spain",
      "location" => {
        "lat" => 36.7196484,
        "lng" => -4.420016299999999
      }
    },
    {
      "state" => "Spain",
      "city_code" => "sevilla",
      "city" => "sevilla, Spain",
      "location" => {
        "lat" => 37.38263999999999,
        "lng" => -5.996295099999999
      }
    },
    {
      "state" => "Spain",
      "city_code" => "valencia",
      "city" => "valencia, Spain",
      "location" => {
        "lat" => 39.4702393,
        "lng" => -0.3768049
      }
    },
    {
      "state" => "Sweden",
      "city_code" => "stockholm",
      "city" => "sweden",
      "location" => {
        "lat" => 60.12816100000001,
        "lng" => 18.643501
      }
    },
    {
      "state" => "Switzerland",
      "city_code" => "basel",
      "city" => "basel, Switzerland",
      "location" => {
        "lat" => 47.557421,
        "lng" => 7.592572699999999
      }
    },
    {
      "state" => "Switzerland",
      "city_code" => "bern",
      "city" => "bern, Switzerland",
      "location" => {
        "lat" => 46.9479222,
        "lng" => 7.444608499999999
      }
    },
    {
      "state" => "Switzerland",
      "city_code" => "geneva",
      "city" => "geneva, Switzerland",
      "location" => {
        "lat" => 46.1983922,
        "lng" => 6.142296099999999
      }
    },
    {
      "state" => "Switzerland",
      "city_code" => "lausanne",
      "city" => "lausanne, Switzerland",
      "location" => {
        "lat" => 46.5199617,
        "lng" => 6.633597099999999
      }
    },
    {
      "state" => "Switzerland",
      "city_code" => "zurich",
      "city" => "zurich, Switzerland",
      "location" => {
        "lat" => 47.3686498,
        "lng" => 8.539182499999999
      }
    },
    {
      "state" => "Turkey",
      "city_code" => "istanbul",
      "city" => "turkey",
      "location" => {
        "lat" => 38.963745,
        "lng" => 35.243322
      }
    },
    {
      "state" => "Ukraine",
      "city_code" => "ukraine",
      "city" => "ukraine",
      "location" => {
        "lat" => 48.379433,
        "lng" => 31.16558
      }
    },
    {
      "state" => "United Kingdom",
      "city_code" => "aberdeen",
      "city" => "aberdeen, United Kingdom",
      "location" => {
        "lat" => 57.149717,
        "lng" => -2.094278
      }
    },
    {
      "state" => "United Kingdom",
      "city_code" => "bath",
      "city" => "bath, United Kingdom",
      "location" => {
        "lat" => 51.381062,
        "lng" => -2.358761
      }
    },
    {
      "state" => "United Kingdom",
      "city_code" => "belfast",
      "city" => "belfast, United Kingdom",
      "location" => {
        "lat" => 54.59744329999999,
        "lng" => -5.9340683
      }
    },
    {
      "state" => "United Kingdom",
      "city_code" => "birmingham",
      "city" => "birmingham / west mids, United Kingdom",
      "location" => {
        "lat" => 52.48624299999999,
        "lng" => -1.890401
      }
    },
    {
      "state" => "United Kingdom",
      "city_code" => "brighton",
      "city" => "brighton, United Kingdom",
      "location" => {
        "lat" => 50.82253000000001,
        "lng" => -0.137163
      }
    },
    {
      "state" => "United Kingdom",
      "city_code" => "bristol",
      "city" => "bristol, United Kingdom",
      "location" => {
        "lat" => 51.454513,
        "lng" => -2.58791
      }
    },
    {
      "state" => "United Kingdom",
      "city_code" => "cambridge",
      "city" => "cambridge, UK, United Kingdom",
      "location" => {
        "lat" => 52.205337,
        "lng" => 0.121817
      }
    },
    {
      "state" => "United Kingdom",
      "city_code" => "cardiff",
      "city" => "cardiff / wales, United Kingdom",
      "location" => {
        "lat" => 51.48158100000001,
        "lng" => -3.17909
      }
    },
    {
      "state" => "United Kingdom",
      "city_code" => "coventry",
      "city" => "coventry, United Kingdom",
      "location" => {
        "lat" => 52.406822,
        "lng" => -1.519693
      }
    },
    {
      "state" => "United Kingdom",
      "city_code" => "derby",
      "city" => "derby, United Kingdom",
      "location" => {
        "lat" => 52.9225301,
        "lng" => -1.4746186
      }
    },
    {
      "state" => "United Kingdom",
      "city_code" => "devon",
      "city" => "devon &amp; cornwall, United Kingdom",
      "location" => {
        "lat" => 50.52767129999999,
        "lng" => -3.612957199999999
      }
    },
    {
      "state" => "United Kingdom",
      "city_code" => "dundee",
      "city" => "dundee, United Kingdom",
      "location" => {
        "lat" => 56.462018,
        "lng" => -2.970721
      }
    },
    {
      "state" => "United Kingdom",
      "city_code" => "norwich",
      "city" => "east anglia, United Kingdom",
      "location" => {
        "lat" => 53.4822735,
        "lng" => -2.2585808
      }
    },
    {
      "state" => "United Kingdom",
      "city_code" => "eastmids",
      "city" => "east midlands, United Kingdom",
      "location" => {
        "lat" => 52.8243941,
        "lng" => -1.3485718
      }
    },
    {
      "state" => "United Kingdom",
      "city_code" => "edinburgh",
      "city" => "edinburgh, United Kingdom",
      "location" => {
        "lat" => 55.953252,
        "lng" => -3.188267
      }
    },
    {
      "state" => "United Kingdom",
      "city_code" => "essex",
      "city" => "essex, United Kingdom",
      "location" => {
        "lat" => 51.7659078,
        "lng" => 0.6673665
      }
    },
    {
      "state" => "United Kingdom",
      "city_code" => "glasgow",
      "city" => "glasgow, United Kingdom",
      "location" => {
        "lat" => 55.864237,
        "lng" => -4.251806
      }
    },
    {
      "state" => "United Kingdom",
      "city_code" => "hampshire",
      "city" => "hampshire, United Kingdom",
      "location" => {
        "lat" => 51.0895203,
        "lng" => -1.216844
      }
    },
    {
      "state" => "United Kingdom",
      "city_code" => "kent",
      "city" => "kent, United Kingdom",
      "location" => {
        "lat" => 51.26014499999999,
        "lng" => 0.8442801999999999
      }
    },
    {
      "state" => "United Kingdom",
      "city_code" => "leeds",
      "city" => "leeds, United Kingdom",
      "location" => {
        "lat" => 53.801279,
        "lng" => -1.548567
      }
    },
    {
      "state" => "United Kingdom",
      "city_code" => "liverpool",
      "city" => "liverpool, United Kingdom",
      "location" => {
        "lat" => 53.4083714,
        "lng" => -2.9915726
      }
    },
    {
      "state" => "United Kingdom",
      "city_code" => "london",
      "city" => "london, United Kingdom",
      "location" => {
        "lat" => 51.5073346,
        "lng" => -0.1276831
      }
    },
    {
      "state" => "United Kingdom",
      "city_code" => "manchester",
      "city" => "manchester, United Kingdom",
      "location" => {
        "lat" => 53.479251,
        "lng" => -2.247926
      }
    },
    {
      "state" => "United Kingdom",
      "city_code" => "newcastle",
      "city" => "newcastle / NE england, United Kingdom",
      "location" => {
        "lat" => 54.978252,
        "lng" => -1.61778
      }
    },
    {
      "state" => "United Kingdom",
      "city_code" => "nottingham",
      "city" => "nottingham, United Kingdom",
      "location" => {
        "lat" => 52.95477,
        "lng" => -1.158086
      }
    },
    {
      "state" => "United Kingdom",
      "city_code" => "oxford",
      "city" => "oxford, United Kingdom",
      "location" => {
        "lat" => 51.751724,
        "lng" => -1.255285
      }
    },
    {
      "state" => "United Kingdom",
      "city_code" => "sheffield",
      "city" => "sheffield, United Kingdom",
      "location" => {
        "lat" => 53.38112899999999,
        "lng" => -1.470085
      }
    }]
    
    asia = [{
      "state" => "Bangladesh",
      "city_code" => "bangladesh",
      "city" => "bangladesh",
      "location" => {
        "lat" => 23.684994,
        "lng" => 90.356331
      }
    },
    {
      "state" => "China",
      "city_code" => "beijing",
      "city" => "beijing, China",
      "location" => {
        "lat" => 39.904214,
        "lng" => 116.407413
      }
    },
    {
      "state" => "China",
      "city_code" => "chengdu",
      "city" => "chengdu, China",
      "location" => {
        "lat" => 30.658601,
        "lng" => 104.064856
      }
    },
    {
      "state" => "China",
      "city_code" => "chongqing",
      "city" => "chongqing, China",
      "location" => {
        "lat" => 29.56301,
        "lng" => 106.551557
      }
    },
    {
      "state" => "China",
      "city_code" => "dalian",
      "city" => "dalian, China",
      "location" => {
        "lat" => 38.91400300000001,
        "lng" => 121.614682
      }
    },
    {
      "state" => "China",
      "city_code" => "guangzhou",
      "city" => "guangzhou, China",
      "location" => {
        "lat" => 23.129163,
        "lng" => 113.264435
      }
    },
    {
      "state" => "China",
      "city_code" => "hangzhou",
      "city" => "hangzhou, China",
      "location" => {
        "lat" => 30.274089,
        "lng" => 120.155069
      }
    },
    {
      "state" => "China",
      "city_code" => "nanjing",
      "city" => "nanjing, China",
      "location" => {
        "lat" => 32.060255,
        "lng" => 118.796877
      }
    },
    {
      "state" => "China",
      "city_code" => "shanghai",
      "city" => "shanghai, China",
      "location" => {
        "lat" => 31.230393,
        "lng" => 121.473704
      }
    },
    {
      "state" => "China",
      "city_code" => "shenyang",
      "city" => "shenyang, China",
      "location" => {
        "lat" => 41.80572,
        "lng" => 123.43147
      }
    },
    {
      "state" => "China",
      "city_code" => "shenzhen",
      "city" => "shenzhen, China",
      "location" => {
        "lat" => 22.543099,
        "lng" => 114.057868
      }
    },
    {
      "state" => "China",
      "city_code" => "wuhan",
      "city" => "wuhan, China",
      "location" => {
        "lat" => 30.593087,
        "lng" => 114.305357
      }
    },
    {
      "state" => "China",
      "city_code" => "xian",
      "city" => "xi'an, China",
      "location" => {
        "lat" => 34.264987,
        "lng" => 108.944269
      }
    },
    {
      "state" => "Hong Kong",
      "city_code" => "hongkong",
      "city" => "hong kong",
      "location" => {
        "lat" => 22.396428,
        "lng" => 114.109497
      }
    },
    {
      "state" => "India",
      "city_code" => "ahmedabad",
      "city" => "ahmedabad, India",
      "location" => {
        "lat" => 23.0395677,
        "lng" => 72.56600449999999
      }
    },
    {
      "state" => "India",
      "city_code" => "bangalore",
      "city" => "bangalore, India",
      "location" => {
        "lat" => 12.9715987,
        "lng" => 77.5945627
      }
    },
    {
      "state" => "India",
      "city_code" => "bhubaneswar",
      "city" => "bhubaneswar, India",
      "location" => {
        "lat" => 20.2960587,
        "lng" => 85.8245398
      }
    },
    {
      "state" => "India",
      "city_code" => "chandigarh",
      "city" => "chandigarh, India",
      "location" => {
        "lat" => 30.7333148,
        "lng" => 76.7794179
      }
    },
    {
      "state" => "India",
      "city_code" => "chennai",
      "city" => "chennai (madras), India",
      "location" => {
        "lat" => 12.9956859,
        "lng" => 80.1679758
      }
    },
    {
      "state" => "India",
      "city_code" => "delhi",
      "city" => "delhi, India",
      "location" => {
        "lat" => 28.635308,
        "lng" => 77.22496
      }
    },
    {
      "state" => "India",
      "city_code" => "goa",
      "city" => "goa, India",
      "location" => {
        "lat" => 15.2993265,
        "lng" => 74.12399599999999
      }
    },
    {
      "state" => "India",
      "city_code" => "hyderabad",
      "city" => "hyderabad, India",
      "location" => {
        "lat" => 17.385044,
        "lng" => 78.486671
      }
    },
    {
      "state" => "India",
      "city_code" => "indore",
      "city" => "indore, India",
      "location" => {
        "lat" => 22.7195687,
        "lng" => 75.8577258
      }
    },
    {
      "state" => "India",
      "city_code" => "jaipur",
      "city" => "jaipur, India",
      "location" => {
        "lat" => 26.9124165,
        "lng" => 75.7872879
      }
    },
    {
      "state" => "India",
      "city_code" => "kerala",
      "city" => "kerala, India",
      "location" => {
        "lat" => 10.8505159,
        "lng" => 76.2710833
      }
    },
    {
      "state" => "India",
      "city_code" => "kolkata",
      "city" => "kolkata (calcutta), India",
      "location" => {
        "lat" => 22.60124,
        "lng" => 88.38451599999999
      }
    },
    {
      "state" => "India",
      "city_code" => "lucknow",
      "city" => "lucknow, India",
      "location" => {
        "lat" => 26.8465108,
        "lng" => 80.9466832
      }
    },
    {
      "state" => "India",
      "city_code" => "mumbai",
      "city" => "mumbai, India",
      "location" => {
        "lat" => 19.0759837,
        "lng" => 72.8776559
      }
    },
    {
      "state" => "India",
      "city_code" => "pune",
      "city" => "pune, India",
      "location" => {
        "lat" => 18.5204303,
        "lng" => 73.8567437
      }
    },
    {
      "state" => "India",
      "city_code" => "surat",
      "city" => "surat surat, India",
      "location" => {
        "lat" => 21.195,
        "lng" => 72.81944399999999
      }
    },
    {
      "state" => "Indonesia",
      "city_code" => "jakarta",
      "city" => "indonesia",
      "location" => {
        "lat" => -0.789275,
        "lng" => 113.921327
      }
    },
    {
      "state" => "Iran",
      "city_code" => "tehran",
      "city" => "iran",
      "location" => {
        "lat" => 32.427908,
        "lng" => 53.688046
      }
    },
    {
      "state" => "Iraq",
      "city_code" => "baghdad",
      "city" => "iraq",
      "location" => {
        "lat" => 33.223191,
        "lng" => 43.679291
      }
    },
    {
      "state" => "Israel and Palestine",
      "city_code" => "haifa",
      "city" => "haifa, Israel and Palestine",
      "location" => {
        "lat" => 32.4814111,
        "lng" => 34.994751
      }
    },
    {
      "state" => "Israel and Palestine",
      "city_code" => "jerusalem",
      "city" => "jerusalem, Israel and Palestine",
      "location" => {
        "lat" => 31.768319,
        "lng" => 35.21371
      }
    },
    {
      "state" => "Israel and Palestine",
      "city_code" => "telaviv",
      "city" => "tel aviv, Israel and Palestine",
      "location" => {
        "lat" => 31.789671,
        "lng" => 35.200049
      }
    },
    {
      "state" => "Israel and Palestine",
      "city_code" => "ramallah",
      "city" => "west bank, Israel and Palestine",
      "location" => {
        "lat" => 31.9465703,
        "lng" => 35.3027226
      }
    },
    {
      "state" => "Japan",
      "city_code" => "fukuoka",
      "city" => "fukuoka, Japan",
      "location" => {
        "lat" => 33.5903547,
        "lng" => 130.4017155
      }
    },
    {
      "state" => "Japan",
      "city_code" => "hiroshima",
      "city" => "hiroshima, Japan",
      "location" => {
        "lat" => 34.3852029,
        "lng" => 132.4552927
      }
    },
    {
      "state" => "Japan",
      "city_code" => "nagoya",
      "city" => "nagoya, Japan",
      "location" => {
        "lat" => 35.1814464,
        "lng" => 136.906398
      }
    },
    {
      "state" => "Japan",
      "city_code" => "okinawa",
      "city" => "okinawa, Japan",
      "location" => {
        "lat" => 26.2124013,
        "lng" => 127.6809317
      }
    },
    {
      "state" => "Japan",
      "city_code" => "osaka",
      "city" => "osaka-kobe-kyoto, Japan",
      "location" => {
        "lat" => 35.0116363,
        "lng" => 135.7680294
      }
    },
    {
      "state" => "Japan",
      "city_code" => "sapporo",
      "city" => "sapporo, Japan",
      "location" => {
        "lat" => 43.0620958,
        "lng" => 141.3543763
      }
    },
    {
      "state" => "Japan",
      "city_code" => "sendai",
      "city" => "sendai, Japan",
      "location" => {
        "lat" => 38.268215,
        "lng" => 140.8693558
      }
    },
    {
      "state" => "Japan",
      "city_code" => "tokyo",
      "city" => "tokyo, Japan",
      "location" => {
        "lat" => 35.6894875,
        "lng" => 139.6917064
      }
    },
    {
      "state" => "Korea",
      "city_code" => "seoul",
      "city" => "seoul, Korea",
      "location" => {
        "lat" => 37.566535,
        "lng" => 126.9779692
      }
    },
    {
      "state" => "Kuwait",
      "city_code" => "kuwait",
      "city" => "kuwait",
      "location" => {
        "lat" => 29.31166,
        "lng" => 47.481766
      }
    },
    {
      "state" => "Lebanon",
      "city_code" => "beirut",
      "city" => "beirut, lebanon, Lebanon",
      "location" => {
        "lat" => 33.8886289,
        "lng" => 35.4954794
      }
    },
    {
      "state" => "Malaysia",
      "city_code" => "malaysia",
      "city" => "malaysia",
      "location" => {
        "lat" => 4.210484,
        "lng" => 101.975766
      }
    },
    {
      "state" => "Pakistan",
      "city_code" => "pakistan",
      "city" => "pakistan",
      "location" => {
        "lat" => 30.375321,
        "lng" => 69.34511599999999
      }
    },
    {
      "state" => "Philippines",
      "city_code" => "bacolod",
      "city" => "bacolod, Philippines",
      "location" => {
        "lat" => 10.6407389,
        "lng" => 122.9689565
      }
    },
    {
      "state" => "Philippines",
      "city_code" => "naga",
      "city" => "bicol region, Philippines",
      "location" => {
        "lat" => 13.337672,
        "lng" => 123.5280072
      }
    },
    {
      "state" => "Philippines",
      "city_code" => "cdo",
      "city" => "cagayan de oro, Philippines",
      "location" => {
        "lat" => 8.4542363,
        "lng" => 124.6318977
      }
    },
    {
      "state" => "Philippines",
      "city_code" => "cebu",
      "city" => "cebu, Philippines",
      "location" => {
        "lat" => 10.3156992,
        "lng" => 123.8854366
      }
    },
    {
      "state" => "Philippines",
      "city_code" => "davaocity",
      "city" => "davao city, Philippines",
      "location" => {
        "lat" => 7.190708,
        "lng" => 125.455341
      }
    },
    {
      "state" => "Philippines",
      "city_code" => "iloilo",
      "city" => "iloilo, Philippines",
      "location" => {
        "lat" => 10.7201501,
        "lng" => 122.5621063
      }
    },
    {
      "state" => "Philippines",
      "city_code" => "manila",
      "city" => "manila, Philippines",
      "location" => {
        "lat" => 14.5995124,
        "lng" => 120.9842195
      }
    },
    {
      "state" => "Philippines",
      "city_code" => "pampanga",
      "city" => "pampanga, Philippines",
      "location" => {
        "lat" => 15.079409,
        "lng" => 120.6199895
      }
    },
    {
      "state" => "Philippines",
      "city_code" => "zamboanga",
      "city" => "zamboanga, Philippines",
      "location" => {
        "lat" => 7.024267,
        "lng" => 122.1889035
      }
    },
    {
      "state" => "Singapore",
      "city_code" => "singapore",
      "city" => "singapore",
      "location" => {
        "lat" => 1.352083,
        "lng" => 103.819836
      }
    },
    {
      "state" => "Taiwan",
      "city_code" => "taipei",
      "city" => "taiwan",
      "location" => {
        "lat" => 23.69781,
        "lng" => 120.960515
      }
    },
    {
      "state" => "Thailand",
      "city_code" => "bangkok",
      "city" => "thailand",
      "location" => {
        "lat" => 15.870032,
        "lng" => 100.992541
      }
    },
    {
      "state" => "United Arab Emirates",
      "city_code" => "dubai",
      "city" => "united arab emirates",
      "location" => {
        "lat" => 23.424076,
        "lng" => 53.847818
      }
    },
    {
      "state" => "Vietnam",
      "city_code" => "vietnam",
      "city" => "vietnam",
      "location" => {
        "lat" => 14.058324,
        "lng" => 108.277199
      }
    }]
    
    oceana = [{
      "state" => "Australia",
      "city_code" => "adelaide",
      "city" => "adelaide, Australia",
      "location" => {
        "lat" => -34.92862119999999,
        "lng" => 138.5999594
      }
    },
    {
      "state" => "Australia",
      "city_code" => "brisbane",
      "city" => "brisbane, Australia",
      "location" => {
        "lat" => -27.4710107,
        "lng" => 153.0234489
      }
    },
    {
      "state" => "Australia",
      "city_code" => "cairns",
      "city" => "cairns, Australia",
      "location" => {
        "lat" => -16.923978,
        "lng" => 145.77086
      }
    },
    {
      "state" => "Australia",
      "city_code" => "canberra",
      "city" => "canberra, Australia",
      "location" => {
        "lat" => -35.30823549999999,
        "lng" => 149.1242241
      }
    },
    {
      "state" => "Australia",
      "city_code" => "darwin",
      "city" => "darwin, Australia",
      "location" => {
        "lat" => -12.4628198,
        "lng" => 130.8417694
      }
    },
    {
      "state" => "Australia",
      "city_code" => "goldcoast",
      "city" => "gold coast, Australia",
      "location" => {
        "lat" => -28.0172605,
        "lng" => 153.4256987
      }
    },
    {
      "state" => "Australia",
      "city_code" => "melbourne",
      "city" => "melbourne, Australia",
      "location" => {
        "lat" => -37.8113667,
        "lng" => 144.9718286
      }
    },
    {
      "state" => "Australia",
      "city_code" => "ntl",
      "city" => "newcastle, NSW, Australia",
      "location" => {
        "lat" => -32.932737,
        "lng" => 151.76977
      }
    },
    {
      "state" => "Australia",
      "city_code" => "perth",
      "city" => "perth, Australia",
      "location" => {
        "lat" => -31.932854,
        "lng" => 115.86194
      }
    },
    {
      "state" => "Australia",
      "city_code" => "sydney",
      "city" => "sydney, Australia",
      "location" => {
        "lat" => -33.8674869,
        "lng" => 151.2069902
      }
    },
    {
      "state" => "Australia",
      "city_code" => "hobart",
      "city" => "tasmania, Australia",
      "location" => {
        "lat" => -41.3650419,
        "lng" => 146.6284905
      }
    },
    {
      "state" => "Australia",
      "city_code" => "wollongong",
      "city" => "wollongong, Australia",
      "location" => {
        "lat" => -34.42498399999999,
        "lng" => 150.8931239
      }
    },
    {
      "state" => "New Zealand",
      "city_code" => "auckland",
      "city" => "auckland, New Zealand",
      "location" => {
        "lat" => -36.8484597,
        "lng" => 174.7633315
      }
    },
    {
      "state" => "New Zealand",
      "city_code" => "christchurch",
      "city" => "christchurch, New Zealand",
      "location" => {
        "lat" => -43.5320544,
        "lng" => 172.6362254
      }
    },
    {
      "state" => "New Zealand",
      "city_code" => "dunedin",
      "city" => "dunedin, New Zealand",
      "location" => {
        "lat" => -45.8787605,
        "lng" => 170.5027976
      }
    },
    {
      "state" => "New Zealand",
      "city_code" => "wellington",
      "city" => "wellington, New Zealand",
      "location" => {
        "lat" => -41.2864603,
        "lng" => 174.776236
      }
    }]
    
    south_america = [
    {
      "state" => "Argentina",
      "city_code" => "buenosaires",
      "city" => "buenos aires, Argentina",
      "location" => {
        "lat" => -34.6037232,
        "lng" => -58.3815931
      }
    },
    {
      "state" => "Bolivia",
      "city_code" => "lapaz",
      "city" => "bolivia",
      "location" => {
        "lat" => -16.290154,
        "lng" => -63.58865299999999
      }
    },
    {
      "state" => "Brazil",
      "city_code" => "belohorizonte",
      "city" => "belo horizonte, Brazil",
      "location" => {
        "lat" => -19.9190677,
        "lng" => -43.9385747
      }
    },
    {
      "state" => "Brazil",
      "city_code" => "brasilia",
      "city" => "brasilia, Brazil",
      "location" => {
        "lat" => -15.7801482,
        "lng" => -47.9291698
      }
    },
    {
      "state" => "Brazil",
      "city_code" => "curitiba",
      "city" => "curitiba, Brazil",
      "location" => {
        "lat" => -25.4283563,
        "lng" => -49.2732515
      }
    },
    {
      "state" => "Brazil",
      "city_code" => "fortaleza",
      "city" => "fortaleza, Brazil",
      "location" => {
        "lat" => -3.7183943,
        "lng" => -38.5433948
      }
    },
    {
      "state" => "Brazil",
      "city_code" => "portoalegre",
      "city" => "porto alegre, Brazil",
      "location" => {
        "lat" => -30.0277041,
        "lng" => -51.2287346
      }
    },
    {
      "state" => "Brazil",
      "city_code" => "recife",
      "city" => "recife, Brazil",
      "location" => {
        "lat" => -8.0542775,
        "lng" => -34.8812561
      }
    },
    {
      "state" => "Brazil",
      "city_code" => "rio",
      "city" => "rio de janeiro, Brazil",
      "location" => {
        "lat" => -22.9035393,
        "lng" => -43.2095869
      }
    },
    {
      "state" => "Brazil",
      "city_code" => "salvador",
      "city" => "salvador, bahia, Brazil",
      "location" => {
        "lat" => -12.9703817,
        "lng" => -38.512382
      }
    },
    {
      "state" => "Brazil",
      "city_code" => "saopaulo",
      "city" => "sao paulo, Brazil",
      "location" => {
        "lat" => -23.5489433,
        "lng" => -46.6388182
      }
    },
    {
      "state" => "Chile",
      "city_code" => "santiago",
      "city" => "chile",
      "location" => {
        "lat" => -35.675147,
        "lng" => -71.542969
      }
    },
    {
      "state" => "Colombia",
      "city_code" => "colombia",
      "city" => "colombia",
      "location" => {
        "lat" => 4.570868,
        "lng" => -74.297333
      }
    },
    {
      "state" => "Costa Rica",
      "city_code" => "costarica",
      "city" => "costa rica",
      "location" => {
        "lat" => 9.748916999999999,
        "lng" => -83.753428
      }
    },
    {
      "state" => "Dominican Republic",
      "city_code" => "santodomingo",
      "city" => "dominican republic",
      "location" => {
        "lat" => 18.735693,
        "lng" => -70.162651
      }
    },
    {
      "state" => "Ecuador",
      "city_code" => "quito",
      "city" => "ecuador",
      "location" => {
        "lat" => -1.831239,
        "lng" => -78.18340599999999
      }
    },
    {
      "state" => "El Salvador",
      "city_code" => "elsalvador",
      "city" => "el salvador",
      "location" => {
        "lat" => 13.794185,
        "lng" => -88.89653
      }
    },
    {
      "state" => "Guatemala",
      "city_code" => "guatemala",
      "city" => "guatemala",
      "location" => {
        "lat" => 15.783471,
        "lng" => -90.23075899999999
      }
    },
    {
      "state" => "Mexico",
      "city_code" => "acapulco",
      "city" => "acapulco, Mexico",
      "location" => {
        "lat" => 16.863794,
        "lng" => -99.881614
      }
    },
    {
      "state" => "Mexico",
      "city_code" => "bajasur",
      "city" => "baja california sur, Mexico",
      "location" => {
        "lat" => 26.0444446,
        "lng" => -111.6660725
      }
    },
    {
      "state" => "Mexico",
      "city_code" => "chihuahua",
      "city" => "chihuahua, Mexico",
      "location" => {
        "lat" => 28.630581,
        "lng" => -106.0737
      }
    },
    {
      "state" => "Mexico",
      "city_code" => "juarez",
      "city" => "ciudad juarez, Mexico",
      "location" => {
        "lat" => 31.7311292,
        "lng" => -106.4625624
      }
    },
    {
      "state" => "Mexico",
      "city_code" => "guadalajara",
      "city" => "guadalajara, Mexico",
      "location" => {
        "lat" => 20.67359,
        "lng" => -103.343803
      }
    },
    {
      "state" => "Mexico",
      "city_code" => "guanajuato",
      "city" => "guanajuato, Mexico",
      "location" => {
        "lat" => 20.9170187,
        "lng" => -101.1617356
      }
    },
    {
      "state" => "Mexico",
      "city_code" => "hermosillo",
      "city" => "hermosillo, Mexico",
      "location" => {
        "lat" => 29.0891857,
        "lng" => -110.9613299
      }
    },
    {
      "state" => "Mexico",
      "city_code" => "mazatlan",
      "city" => "mazatlan, Mexico",
      "location" => {
        "lat" => 23.2361111,
        "lng" => -106.4152778
      }
    },
    {
      "state" => "Mexico",
      "city_code" => "mexicocity",
      "city" => "mexico city, Mexico",
      "location" => {
        "lat" => 19.4326077,
        "lng" => -99.133208
      }
    },
    {
      "state" => "Mexico",
      "city_code" => "monterrey",
      "city" => "monterrey, Mexico",
      "location" => {
        "lat" => 25.6732109,
        "lng" => -100.309201
      }
    },
    {
      "state" => "Mexico",
      "city_code" => "oaxaca",
      "city" => "oaxaca, Mexico",
      "location" => {
        "lat" => 17.0833333,
        "lng" => -96.75
      }
    },
    {
      "state" => "Mexico",
      "city_code" => "puebla",
      "city" => "puebla, Mexico",
      "location" => {
        "lat" => 19.0412967,
        "lng" => -98.20619959999999
      }
    },
    {
      "state" => "Mexico",
      "city_code" => "pv",
      "city" => "puerto vallarta, Mexico",
      "location" => {
        "lat" => 20.6220182,
        "lng" => -105.2284566
      }
    },
    {
      "state" => "Mexico",
      "city_code" => "tijuana",
      "city" => "tijuana, Mexico",
      "location" => {
        "lat" => 32.533489,
        "lng" => -117.018204
      }
    },
    {
      "state" => "Mexico",
      "city_code" => "veracruz",
      "city" => "veracruz, Mexico",
      "location" => {
        "lat" => 19.1902778,
        "lng" => -96.1533333
      }
    },
    {
      "state" => "Mexico",
      "city_code" => "yucatan",
      "city" => "yucatan, Mexico",
      "location" => {
        "lat" => 20.7098786,
        "lng" => -89.0943377
      }
    },
    {
      "state" => "Nicaragua",
      "city_code" => "managua",
      "city" => "nicaragua",
      "location" => {
        "lat" => 12.865416,
        "lng" => -85.207229
      }
    },
    {
      "state" => "Panama",
      "city_code" => "panama",
      "city" => "panama",
      "location" => {
        "lat" => 8.537981,
        "lng" => -80.782127
      }
    },
    {
      "state" => "Peru",
      "city_code" => "lima",
      "city" => "peru",
      "location" => {
        "lat" => -9.189967,
        "lng" => -75.015152
      }
    },
    {
      "state" => "Puerto Rico",
      "city_code" => "puertorico",
      "city" => "puerto rico",
      "location" => {
        "lat" => 18.220833,
        "lng" => -66.590149
      }
    },
    {
      "state" => "Uruguay",
      "city_code" => "montevideo",
      "city" => "montevideo, Uruguay",
      "location" => {
        "lat" => -34.8836111,
        "lng" => -56.1819444
      }
    },
    {
      "state" => "Venezuela",
      "city_code" => "caracas",
      "city" => "venezuela",
      "location" => {
        "lat" => 6.42375,
        "lng" => -66.58973
      }
    },
    {
      "state" => "Virgin Islands, U.S.",
      "city_code" => "virgin",
      "city" => "virgin islands, Virgin Islands, U.S.",
      "location" => {
        "lat" => 18.335765,
        "lng" => -64.896335
      }
    }]
    
    africa = 
    [
      {
      "state" => "Egypt",
      "city_code" => "cairo",
      "city" => "egypt",
      "location" => {
        "lat" => 26.820553,
        "lng" => 30.802498
      }
    },
    {
      "state" => "Ethiopia",
      "city_code" => "addisababa",
      "city" => "ethiopia",
      "location" => {
        "lat" => 9.145000000000001,
        "lng" => 40.489673
      }
    },
    {
      "state" => "Ghana",
      "city_code" => "accra",
      "city" => "ghana",
      "location" => {
        "lat" => 7.946527,
        "lng" => -1.023194
      }
    },
    {
      "state" => "Kenya",
      "city_code" => "kenya",
      "city" => "kenya",
      "location" => {
        "lat" => -0.023559,
        "lng" => 37.906193
      }
    },
    {
      "state" => "Morocco",
      "city_code" => "casablanca",
      "city" => "morocco",
      "location" => {
        "lat" => 31.791702,
        "lng" => -7.092619999999999
      }
    },
    {
      "state" => "South Africa",
      "city_code" => "capetown",
      "city" => "cape town, South Africa",
      "location" => {
        "lat" => -33.9248685,
        "lng" => 18.4240553
      }
    },
    {
      "state" => "South Africa",
      "city_code" => "durban",
      "city" => "durban, South Africa",
      "location" => {
        "lat" => -29.857876,
        "lng" => 31.027581
      }
    }, 
    {
      "state" => "South Africa",
      "city_code" => "johannesburg",
      "city" => "johannesburg, South Africa",
      "location" => {
        "lat" => -26.2041028,
        "lng" => 28.0473051
      }
    },
    {
      "state" => "South Africa",
      "city_code" => "pretoria",
      "city" => "pretoria, South Africa",
      "location" => {
        "lat" => -25.73134,
        "lng" => 28.21837
      }
    },
    {
      "state" => "Tunisia",
      "city_code" => "tunis",
      "city" => "tunisia",
      "location" => {
        "lat" => 33.886917,
        "lng" => 9.537499
      }
    }]
    
    case region.downcase
      when "usa"
        return usa
      when "canada"
        return canada
      when "oceana"
        return oceana
      when "europe"
        return europe
      when "asia"
        return asia
      when "south_america"
        return south_america
      when "africa"
        return africa
    end
    
    return nil
  end
  
end