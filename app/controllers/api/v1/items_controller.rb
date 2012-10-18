class Api::V1::ItemsController < ApplicationController
  def show
    @item = Item.find(params[:id])
    @user = User.find(@item.user_id)
    @ret = {}
    
    render :json => {:error => "missing url"}, :status => 500 and return if params[:url].blank?
    link = params[:url]
    
    case params[:source]
    when "ebay"
      @ret = {}
    when "cl"
      options = {
        :user => @user,
        :link => link
      }
      @ret = get_cl_info(options)
    when "oodle"
      @ret = {}
    when "etsy"
      @ret = {}
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
      _ret = {:state => state_name}
      state.parent.next_element.css("li a").children().each do |a|
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
        puts "http://maps.googleapis.com/maps/api/geocode/json?address=#{a}&sensor=false"

        res = Net::HTTP.get(url)
        parsed_json = ActiveSupport::JSON.decode(res)
        location_results = parsed_json["results"]
        _position = {}
        unless location_results.blank?
          location = location_results[0]["geometry"]["location"]
          lat = location["lat"]
          lng = location["lng"]
          _position = {:lat => lat, :lng => lng}
        end
        _ret[:position] = _position
      end
      
      @ret.push(_ret)
    end
    
    
    # find state by lat and long
    # http://maps.googleapis.com/maps/geo?q=37.714224,-112.961452&output=json&sensor=false
    
    render :json => @ret.to_json
  end
  
  def list
    lat = params[:lat]
    long = params[:long]
    
    @all_item = Item.all
    @ret_array = []
    
    case params[:source]
    when "ebay"
      @ret_array.push({})
    when "cl"  
      feed = Feedzirra::Feed.fetch_and_parse("http://sfbay.craigslist.org/search/sss/sby?query=scooter&minAsk=&maxAsk=&hasPic=1&format=rss")
      
      feed.entries.each do |e|
        url = e.url
        @ret_array.push({
          :title => e.title,
          :description => e.summary,
          :posted_at => e.published,
          :url => e.url,
          :source => "cl"
        })
      end
      
    when "oodle"
      @ret_array.push({})
    when "etsy"
      @ret_array.push({})
    end
    
    if params[:key] == "123"
      render :status => 200, :json => @ret_array
    end
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
    phone = /\(?([0-9]{3})\)?[-. ]?([0-9]{3})[-. ]?([0-9]{4})/.match(description).to_s
    phone.gsub!(/[-. ]/, "")
    
    @ret = {
      :id => nil,
      :title => title,
      :description => description,
      :image => image,
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
  
  def cl_city_site_info
    return [{
        "state": "Alabama",
        "city_code": "tuscaloosa",
        "city": "tuscaloosa, Alabama",
        "position": {
            "lat": 33.2098407,
            "lng": -87.56917349999999
        }
    }, {
        "state": "Alaska",
        "city_code": "juneau",
        "city": "southeast alaska, Alaska",
        "position": {
            "lat": 64.2008413,
            "lng": -149.4936733
        }
    }, {
        "state": "Arizona",
        "city_code": "yuma",
        "city": "yuma, Arizona",
        "position": {
            "lat": 32.6926512,
            "lng": -114.6276916
        }
    }, {
        "state": "Arkansas",
        "city_code": "texarkana",
        "city": "texarkana, Arkansas",
        "position": {
            "lat": 33.4417915,
            "lng": -94.0376881
        }
    }, {
        "state": "California",
        "city_code": "yubasutter",
        "city": "yuba-sutter, California",
        "position": {
            "lat": 39.1598915,
            "lng": -121.7527482
        }
    }, {
        "state": "Colorado",
        "city_code": "westslope",
        "city": "western slope, Colorado",
        "position": {
            "lat": 38.480032,
            "lng": -107.8677474
        }
    }, {
        "state": "Connecticut",
        "city_code": "nwct",
        "city": "northwest CT, Connecticut",
        "position": {
            "lat": 41.6032207,
            "lng": -73.087749
        }
    }, {
        "state": "Delaware",
        "city_code": "delaware",
        "city": "delaware",
        "position": {
            "lat": 38.9108325,
            "lng": -75.52766989999999
        }
    }, {
        "state": "District of Columbia",
        "city_code": "washingtondc",
        "city": "washington, District of Columbia",
        "position": {
            "lat": 38.8951118,
            "lng": -77.0363658
        }
    }, {
        "state": "Florida",
        "city_code": "westpalmbeach",
        "city": "west palm beach, Florida",
        "position": {
            "lat": 26.7153424,
            "lng": -80.0533746
        }
    }, {
        "state": "Georgia",
        "city_code": "valdosta",
        "city": "valdosta, Georgia",
        "position": {
            "lat": 30.8327022,
            "lng": -83.2784851
        }
    }, {
        "state": "Hawaii",
        "city_code": "honolulu",
        "city": "hawaii",
        "position": {
            "lat": 19.8967662,
            "lng": -155.5827818
        }
    }, {
        "state": "Idaho",
        "city_code": "twinfalls",
        "city": "twin falls, Idaho",
        "position": {
            "lat": 42.5629668,
            "lng": -114.4608711
        }
    }, {
        "state": "Illinois",
        "city_code": "quincy",
        "city": "western IL, Illinois",
        "position": {
            "lat": 41.3804869,
            "lng": -90.3936722
        }
    }, {
        "state": "Indiana",
        "city_code": "terrehaute",
        "city": "terre haute, Indiana",
        "position": {
            "lat": 39.4667034,
            "lng": -87.41390919999999
        }
    }, {
        "state": "Iowa",
        "city_code": "waterloo",
        "city": "waterloo / cedar falls, Iowa",
        "position": {
            "lat": 42.5102632,
            "lng": -92.3862973
        }
    }, {
        "state": "Kansas",
        "city_code": "wichita",
        "city": "wichita, Kansas",
        "position": {
            "lat": 37.68888889999999,
            "lng": -97.3361111
        }
    }, {
        "state": "Kentucky",
        "city_code": "westky",
        "city": "western KY, Kentucky",
        "position": {
            "lat": 37.6783588,
            "lng": -85.2354349
        }
    }, {
        "state": "Louisiana",
        "city_code": "shreveport",
        "city": "shreveport, Louisiana",
        "position": {
            "lat": 32.5251516,
            "lng": -93.7501789
        }
    }, {
        "state": "Maine",
        "city_code": "maine",
        "city": "maine",
        "position": {
            "lat": 45.253783,
            "lng": -69.4454689
        }
    }, {
        "state": "Maryland",
        "city_code": "westmd",
        "city": "western maryland, Maryland",
        "position": {
            "lat": 39.2922854,
            "lng": -76.66292899999999
        }
    }, {
        "state": "Massachusetts",
        "city_code": "worcester",
        "city": "worcester / central MA, Massachusetts",
        "position": {
            "lat": 42.276553,
            "lng": -71.79969059999999
        }
    }, {
        "state": "Michigan",
        "city_code": "up",
        "city": "upper peninsula, Michigan",
        "position": {
            "lat": 46.9281544,
            "lng": -87.4040189
        }
    }, {
        "state": "Minnesota",
        "city_code": "stcloud",
        "city": "st cloud, Minnesota",
        "position": {}
    }, {
        "state": "Mississippi",
        "city_code": "natchez",
        "city": "southwest MS, Mississippi",
        "position": {
            "lat": 32.3546679,
            "lng": -89.3985283
        }
    }, {
        "state": "Missouri",
        "city_code": "stlouis",
        "city": "st louis, Missouri",
        "position": {
            "lat": 38.6270025,
            "lng": -90.19940419999999
        }
    }, {
        "state": "Montana",
        "city_code": "montana",
        "city": "montana (old), Montana",
        "position": {
            "lat": 48.275851,
            "lng": -111.9260115
        }
    }, {
        "state": "Nebraska",
        "city_code": "scottsbluff",
        "city": "scottsbluff / panhandle, Nebraska",
        "position": {
            "lat": 41.8912395,
            "lng": -103.6756715
        }
    }, {
        "state": "Nevada",
        "city_code": "reno",
        "city": "reno / tahoe, Nevada",
        "position": {
            "lat": 39.5235877,
            "lng": -119.8172037
        }
    }, {
        "state": "New Hampshire",
        "city_code": "nh",
        "city": "new hampshire",
        "position": {
            "lat": 43.1938516,
            "lng": -71.5723953
        }
    }, {
        "state": "New Jersey",
        "city_code": "southjersey",
        "city": "south jersey, New Jersey",
        "position": {
            "lat": 39.9408789,
            "lng": -74.84340259999999
        }
    }, {
        "state": "New Mexico",
        "city_code": "santafe",
        "city": "santa fe / taos, New Mexico",
        "position": {
            "lat": 35.80439,
            "lng": -105.921963
        }
    }, {
        "state": "New York",
        "city_code": "watertown",
        "city": "watertown, New York",
        "position": {
            "lat": 43.9747838,
            "lng": -75.91075649999999
        }
    }, {
        "state": "North Carolina",
        "city_code": "winstonsalem",
        "city": "winston-salem, North Carolina",
        "position": {
            "lat": 36.09985959999999,
            "lng": -80.244216
        }
    }, {
        "state": "North Dakota",
        "city_code": "nd",
        "city": "north dakota",
        "position": {
            "lat": 47.5514926,
            "lng": -101.0020119
        }
    }, {
        "state": "Ohio",
        "city_code": "zanesville",
        "city": "zanesville / cambridge, Ohio",
        "position": {
            "lat": 39.9701029,
            "lng": -82.0093866
        }
    }, {
        "state": "Oklahoma",
        "city_code": "tulsa",
        "city": "tulsa, Oklahoma",
        "position": {
            "lat": 36.1539816,
            "lng": -95.99277500000001
        }
    }, {
        "state": "Oregon",
        "city_code": "salem",
        "city": "salem, Oregon",
        "position": {
            "lat": 44.9428975,
            "lng": -123.0350963
        }
    }, {
        "state": "Pennsylvania",
        "city_code": "york",
        "city": "york, Pennsylvania",
        "position": {
            "lat": 39.9625984,
            "lng": -76.727745
        }
    }, {
        "state": "Rhode Island",
        "city_code": "providence",
        "city": "rhode island",
        "position": {
            "lat": 41.5800945,
            "lng": -71.4774291
        }
    }, {
        "state": "South Carolina",
        "city_code": "myrtlebeach",
        "city": "myrtle beach, South Carolina",
        "position": {
            "lat": 33.6890603,
            "lng": -78.8866943
        }
    }, {
        "state": "South Dakota",
        "city_code": "sd",
        "city": "south dakota",
        "position": {
            "lat": 43.9695148,
            "lng": -99.9018131
        }
    }, {
        "state": "Tennessee",
        "city_code": "tricities",
        "city": "tri-cities, Tennessee",
        "position": {
            "lat": 36.4820692,
            "lng": -82.4089904
        }
    }, {
        "state": "Texas",
        "city_code": "wichitafalls",
        "city": "wichita falls, Texas",
        "position": {
            "lat": 33.9137085,
            "lng": -98.4933873
        }
    }, {
        "state": "Utah",
        "city_code": "stgeorge",
        "city": "st george, Utah",
        "position": {
            "lat": 37.0952778,
            "lng": -113.5780556
        }
    }, {
        "state": "Vermont",
        "city_code": "burlington",
        "city": "vermont",
        "position": {
            "lat": 44.5588028,
            "lng": -72.57784149999999
        }
    }, {
        "state": "Virginia",
        "city_code": "winchester",
        "city": "winchester, Virginia",
        "position": {
            "lat": 39.1856597,
            "lng": -78.1633341
        }
    }, {
        "state": "Washington",
        "city_code": "yakima",
        "city": "yakima, Washington",
        "position": {
            "lat": 46.6020711,
            "lng": -120.5058987
        }
    }, {
        "state": "West Virginia",
        "city_code": "wv",
        "city": "west virginia (old), West Virginia",
        "position": {
            "lat": 37.4315734,
            "lng": -78.6568942
        }
    }, {
        "state": "Wisconsin",
        "city_code": "wausau",
        "city": "wausau, Wisconsin",
        "position": {
            "lat": 44.9591352,
            "lng": -89.6301221
        }
    }, {
        "state": "Wyoming",
        "city_code": "wyoming",
        "city": "wyoming",
        "position": {
            "lat": 43.0759678,
            "lng": -107.2902839
        }
    }, {
        "state": "Territories",
        "city_code": "virgin",
        "city": "U.S. virgin islands, Territories",
        "position": {
            "lat": 18.3204664,
            "lng": -64.9198081
        }
    }, {
        "state": "Alberta",
        "city_code": "reddeer",
        "city": "red deer, Alberta",
        "position": {
            "lat": 52.2681118,
            "lng": -113.8112386
        }
    }, {
        "state": "British Columbia",
        "city_code": "whistler",
        "city": "whistler, British Columbia",
        "position": {
            "lat": 50.1163196,
            "lng": -122.9573563
        }
    }, {
        "state": "Manitoba",
        "city_code": "winnipeg",
        "city": "winnipeg, Manitoba",
        "position": {
            "lat": 49.8997541,
            "lng": -97.1374937
        }
    }, {
        "state": "New Brunswick",
        "city_code": "newbrunswick",
        "city": "new brunswick",
        "position": {
            "lat": 40.4862157,
            "lng": -74.4518188
        }
    }, {
        "state": "Newfoundland and Labrador",
        "city_code": "newfoundland",
        "city": "st john's, Newfoundland and Labrador",
        "position": {
            "lat": 47.5605413,
            "lng": -52.71283150000001
        }
    }, {
        "state": "Northwest Territories",
        "city_code": "yellowknife",
        "city": "yellowknife, Northwest Territories",
        "position": {
            "lat": 62.4539717,
            "lng": -114.3717886
        }
    }, {
        "state": "Nova Scotia",
        "city_code": "halifax",
        "city": "halifax, Nova Scotia",
        "position": {
            "lat": 44.6488625,
            "lng": -63.5753196
        }
    }, {
        "state": "Ontario",
        "city_code": "windsor",
        "city": "windsor, Ontario",
        "position": {
            "lat": 42.3183446,
            "lng": -83.0342423
        }
    }, {
        "state": "Prince Edward Island",
        "city_code": "pei",
        "city": "prince edward island",
        "position": {
            "lat": 46.510712,
            "lng": -63.41681359999999
        }
    }, {
        "state": "Quebec",
        "city_code": "troisrivieres",
        "city": "trois-rivieres, Quebec",
        "position": {
            "lat": 46.3432397,
            "lng": -72.5432834
        }
    }, {
        "state": "Saskatchewan",
        "city_code": "saskatoon",
        "city": "saskatoon, Saskatchewan",
        "position": {}
    }, {
        "state": "Yukon Territory",
        "city_code": "whitehorse",
        "city": "whitehorse, Yukon Territory",
        "position": {
            "lat": 60.7211871,
            "lng": -135.0568449
        }
    }, {
        "state": "Austria",
        "city_code": "vienna",
        "city": "vienna, Austria",
        "position": {
            "lat": 48.2081743,
            "lng": 16.3738189
        }
    }, {
        "state": "Belgium",
        "city_code": "brussels",
        "city": "belgium",
        "position": {
            "lat": 50.503887,
            "lng": 4.469936
        }
    }, {
        "state": "Bulgaria",
        "city_code": "bulgaria",
        "city": "bulgaria",
        "position": {
            "lat": 42.733883,
            "lng": 25.48583
        }
    }, {
        "state": "Croatia",
        "city_code": "zagreb",
        "city": "croatia",
        "position": {
            "lat": 45.7533427,
            "lng": 15.9891256
        }
    }, {
        "state": "Czech Republic",
        "city_code": "prague",
        "city": "prague, Czech Republic",
        "position": {
            "lat": 50.0755381,
            "lng": 14.4378005
        }
    }, {
        "state": "Denmark",
        "city_code": "copenhagen",
        "city": "copenhagen, Denmark",
        "position": {
            "lat": 55.6760968,
            "lng": 12.5683371
        }
    }, {
        "state": "Finland",
        "city_code": "helsinki",
        "city": "finland",
        "position": {
            "lat": 61.92410999999999,
            "lng": 25.748151
        }
    }, {
        "state": "France",
        "city_code": "toulouse",
        "city": "toulouse, France",
        "position": {
            "lat": 43.604652,
            "lng": 1.444209
        }
    }, {
        "state": "Germany",
        "city_code": "stuttgart",
        "city": "stuttgart, Germany",
        "position": {
            "lat": 48.7754181,
            "lng": 9.181758799999999
        }
    }, {
        "state": "Greece",
        "city_code": "athens",
        "city": "greece",
        "position": {
            "lat": 39.074208,
            "lng": 21.824312
        }
    }, {
        "state": "Hungary",
        "city_code": "budapest",
        "city": "budapest, Hungary",
        "position": {
            "lat": 47.4984056,
            "lng": 19.0407578
        }
    }, {
        "state": "Iceland",
        "city_code": "reykjavik",
        "city": "reykjavik, Iceland",
        "position": {
            "lat": 64.13533799999999,
            "lng": -21.89521
        }
    }, {
        "state": "Ireland",
        "city_code": "dublin",
        "city": "dublin, Ireland",
        "position": {
            "lat": 53.3494426,
            "lng": -6.260082499999999
        }
    }, {
        "state": "Italy",
        "city_code": "venice",
        "city": "venice / veneto, Italy",
        "position": {
            "lat": 45.4408474,
            "lng": 12.3155151
        }
    }, {
        "state": "Luxembourg",
        "city_code": "luxembourg",
        "city": "luxembourg",
        "position": {
            "lat": 49.815273,
            "lng": 6.129582999999999
        }
    }, {
        "state": "Netherlands",
        "city_code": "amsterdam",
        "city": "amsterdam / randstad, Netherlands",
        "position": {
            "lat": 52.3683695,
            "lng": 5.207230399999999
        }
    }, {
        "state": "Norway",
        "city_code": "oslo",
        "city": "norway",
        "position": {
            "lat": 60.47202399999999,
            "lng": 8.468945999999999
        }
    }, {
        "state": "Poland",
        "city_code": "warsaw",
        "city": "poland",
        "position": {
            "lat": 51.919438,
            "lng": 19.145136
        }
    }, {
        "state": "Portugal",
        "city_code": "porto",
        "city": "porto, Portugal",
        "position": {
            "lat": 41.1650559,
            "lng": -8.602815999999999
        }
    }, {
        "state": "Romania",
        "city_code": "bucharest",
        "city": "romania",
        "position": {
            "lat": 45.943161,
            "lng": 24.96676
        }
    }, {
        "state": "Russian Federation",
        "city_code": "stpetersburg",
        "city": "st petersburg, Russian Federation",
        "position": {
            "lat": 60.07623830000001,
            "lng": 30.1213829
        }
    }, {
        "state": "Spain",
        "city_code": "valencia",
        "city": "valencia, Spain",
        "position": {
            "lat": 39.4702393,
            "lng": -0.3768049
        }
    }, {
        "state": "Sweden",
        "city_code": "stockholm",
        "city": "sweden",
        "position": {
            "lat": 60.12816100000001,
            "lng": 18.643501
        }
    }, {
        "state": "Switzerland",
        "city_code": "zurich",
        "city": "zurich, Switzerland",
        "position": {
            "lat": 47.3686498,
            "lng": 8.539182499999999
        }
    }, {
        "state": "Turkey",
        "city_code": "istanbul",
        "city": "turkey",
        "position": {
            "lat": 38.963745,
            "lng": 35.243322
        }
    }, {
        "state": "Ukraine",
        "city_code": "ukraine",
        "city": "ukraine",
        "position": {
            "lat": 48.379433,
            "lng": 31.16558
        }
    }, {
        "state": "United Kingdom",
        "city_code": "sheffield",
        "city": "sheffield, United Kingdom",
        "position": {
            "lat": 53.38112899999999,
            "lng": -1.470085
        }
    }, {
        "state": "Bangladesh",
        "city_code": "bangladesh",
        "city": "bangladesh",
        "position": {
            "lat": 23.684994,
            "lng": 90.356331
        }
    }, {
        "state": "China",
        "city_code": "xian",
        "city": "xi'an, China",
        "position": {
            "lat": 34.264987,
            "lng": 108.944269
        }
    }, {
        "state": "Hong Kong",
        "city_code": "hongkong",
        "city": "hong kong",
        "position": {
            "lat": 22.396428,
            "lng": 114.109497
        }
    }, {
        "state": "India",
        "city_code": "surat",
        "city": "surat surat, India",
        "position": {
            "lat": 21.195,
            "lng": 72.81944399999999
        }
    }, {
        "state": "Indonesia",
        "city_code": "jakarta",
        "city": "indonesia",
        "position": {
            "lat": -0.789275,
            "lng": 113.921327
        }
    }, {
        "state": "Iran",
        "city_code": "tehran",
        "city": "iran",
        "position": {
            "lat": 32.427908,
            "lng": 53.688046
        }
    }, {
        "state": "Iraq",
        "city_code": "baghdad",
        "city": "iraq",
        "position": {
            "lat": 33.223191,
            "lng": 43.679291
        }
    }, {
        "state": "Israel and Palestine",
        "city_code": "ramallah",
        "city": "west bank, Israel and Palestine",
        "position": {
            "lat": 31.9465703,
            "lng": 35.3027226
        }
    }, {
        "state": "Japan",
        "city_code": "tokyo",
        "city": "tokyo, Japan",
        "position": {
            "lat": 35.6894875,
            "lng": 139.6917064
        }
    }, {
        "state": "Korea",
        "city_code": "seoul",
        "city": "seoul, Korea",
        "position": {
            "lat": 37.566535,
            "lng": 126.9779692
        }
    }, {
        "state": "Kuwait",
        "city_code": "kuwait",
        "city": "kuwait",
        "position": {
            "lat": 29.31166,
            "lng": 47.481766
        }
    }, {
        "state": "Lebanon",
        "city_code": "beirut",
        "city": "beirut, lebanon, Lebanon",
        "position": {
            "lat": 33.8886289,
            "lng": 35.4954794
        }
    }, {
        "state": "Malaysia",
        "city_code": "malaysia",
        "city": "malaysia",
        "position": {
            "lat": 4.210484,
            "lng": 101.975766
        }
    }, {
        "state": "Pakistan",
        "city_code": "pakistan",
        "city": "pakistan",
        "position": {
            "lat": 30.375321,
            "lng": 69.34511599999999
        }
    }, {
        "state": "Philippines",
        "city_code": "zamboanga",
        "city": "zamboanga, Philippines",
        "position": {
            "lat": 7.024267,
            "lng": 122.1889035
        }
    }, {
        "state": "Singapore",
        "city_code": "singapore",
        "city": "singapore",
        "position": {
            "lat": 1.352083,
            "lng": 103.819836
        }
    }, {
        "state": "Taiwan",
        "city_code": "taipei",
        "city": "taiwan",
        "position": {
            "lat": 23.69781,
            "lng": 120.960515
        }
    }, {
        "state": "Thailand",
        "city_code": "bangkok",
        "city": "thailand",
        "position": {
            "lat": 15.870032,
            "lng": 100.992541
        }
    }, {
        "state": "United Arab Emirates",
        "city_code": "dubai",
        "city": "united arab emirates",
        "position": {
            "lat": 23.424076,
            "lng": 53.847818
        }
    }, {
        "state": "Vietnam",
        "city_code": "vietnam",
        "city": "vietnam",
        "position": {}
    }, {
        "state": "Australia",
        "city_code": "wollongong",
        "city": "wollongong, Australia",
        "position": {}
    }, {
        "state": "New Zealand",
        "city_code": "wellington",
        "city": "wellington, New Zealand",
        "position": {
            "lat": -41.2864603,
            "lng": 174.776236
        }
    }, {
        "state": "Argentina",
        "city_code": "buenosaires",
        "city": "buenos aires, Argentina",
        "position": {
            "lat": -34.6037232,
            "lng": -58.3815931
        }
    }, {
        "state": "Bolivia",
        "city_code": "lapaz",
        "city": "bolivia",
        "position": {
            "lat": -16.290154,
            "lng": -63.58865299999999
        }
    }, {
        "state": "Brazil",
        "city_code": "saopaulo",
        "city": "sao paulo, Brazil",
        "position": {
            "lat": -23.5489433,
            "lng": -46.6388182
        }
    }, {
        "state": "Chile",
        "city_code": "santiago",
        "city": "chile",
        "position": {
            "lat": -35.675147,
            "lng": -71.542969
        }
    }, {
        "state": "Colombia",
        "city_code": "colombia",
        "city": "colombia",
        "position": {
            "lat": 4.570868,
            "lng": -74.297333
        }
    }, {
        "state": "Costa Rica",
        "city_code": "costarica",
        "city": "costa rica",
        "position": {
            "lat": 9.748916999999999,
            "lng": -83.753428
        }
    }, {
        "state": "Dominican Republic",
        "city_code": "santodomingo",
        "city": "dominican republic",
        "position": {
            "lat": 18.735693,
            "lng": -70.162651
        }
    }, {
        "state": "Ecuador",
        "city_code": "quito",
        "city": "ecuador",
        "position": {
            "lat": -1.831239,
            "lng": -78.18340599999999
        }
    }, {
        "state": "El Salvador",
        "city_code": "elsalvador",
        "city": "el salvador",
        "position": {
            "lat": 13.794185,
            "lng": -88.89653
        }
    }, {
        "state": "Guatemala",
        "city_code": "guatemala",
        "city": "guatemala",
        "position": {}
    }, {
        "state": "Mexico",
        "city_code": "yucatan",
        "city": "yucatan, Mexico",
        "position": {
            "lat": 20.7098786,
            "lng": -89.0943377
        }
    }, {
        "state": "Nicaragua",
        "city_code": "managua",
        "city": "nicaragua",
        "position": {
            "lat": 12.865416,
            "lng": -85.207229
        }
    }, {
        "state": "Panama",
        "city_code": "panama",
        "city": "panama",
        "position": {
            "lat": 8.537981,
            "lng": -80.782127
        }
    }, {
        "state": "Peru",
        "city_code": "lima",
        "city": "peru",
        "position": {
            "lat": -9.189967,
            "lng": -75.015152
        }
    }, {
        "state": "Puerto Rico",
        "city_code": "puertorico",
        "city": "puerto rico",
        "position": {
            "lat": 18.220833,
            "lng": -66.590149
        }
    }, {
        "state": "Uruguay",
        "city_code": "montevideo",
        "city": "montevideo, Uruguay",
        "position": {
            "lat": -34.8836111,
            "lng": -56.1819444
        }
    }, {
        "state": "Venezuela",
        "city_code": "caracas",
        "city": "venezuela",
        "position": {
            "lat": 6.42375,
            "lng": -66.58973
        }
    }, {
        "state": "Virgin Islands, U.S.",
        "city_code": "virgin",
        "city": "virgin islands, Virgin Islands, U.S.",
        "position": {
            "lat": 18.335765,
            "lng": -64.896335
        }
    }, {
        "state": "Egypt",
        "city_code": "cairo",
        "city": "egypt",
        "position": {
            "lat": 26.820553,
            "lng": 30.802498
        }
    }, {
        "state": "Ethiopia",
        "city_code": "addisababa",
        "city": "ethiopia",
        "position": {
            "lat": 9.145000000000001,
            "lng": 40.489673
        }
    }, {
        "state": "Ghana",
        "city_code": "accra",
        "city": "ghana",
        "position": {
            "lat": 7.946527,
            "lng": -1.023194
        }
    }, {
        "state": "Kenya",
        "city_code": "kenya",
        "city": "kenya",
        "position": {
            "lat": -0.023559,
            "lng": 37.906193
        }
    }, {
        "state": "Morocco",
        "city_code": "casablanca",
        "city": "morocco",
        "position": {
            "lat": 31.791702,
            "lng": -7.092619999999999
        }
    }, {
        "state": "South Africa",
        "city_code": "pretoria",
        "city": "pretoria, South Africa",
        "position": {}
    }, {
        "state": "Tunisia",
        "city_code": "tunis",
        "city": "tunisia",
        "position": {
            "lat": 33.886917,
            "lng": 9.537499
        }
    }]
  end
  
end