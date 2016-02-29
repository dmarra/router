require 'sinatra/base'
require 'tilt/erb'
require 'rest-client'
require 'csv'
require 'gistance'

# get all campaign offices
CAMPAIGN_CSV = RestClient.get('http://d2bq2yf31lju3q.cloudfront.net/d/campaign-offices.csv')
ALL_OFFICES = CSV.new(CAMPAIGN_CSV, headers: true, header_converters: :symbol)
ALL_OFFICES = ALL_OFFICES.to_a.map {|row| row.to_hash }.freeze

class Router < Sinatra::Base
  Gistance.configure do |c|
    c.api_key = 'AIzaSyDO757jP_0OhC_0yDWDbb1q6_or9Vdyf1I'
    c.units = 'imperial'
  end

  configure do
    set :views, './views'
  end

  get '/' do
    # get current location
    # NOTE: should we use the zip code they enter? 
    #       what if they sigfn up from someplace that is not home?
    @current_location = RestClient.get("http://geoip.nekudo.com/api/#{request.ip}")
    @current_location = JSON.parse(@current_location)['location']

    # get campaign office distance
    @all_offices = ALL_OFFICES.dup 

    # there is a max size to a request. our list is large enough that
    # we need to split this request into chunks. 60 seems to work; 99
    # was too high.     
    @distances = Array.new  
    index = 0
    @all_offices.each_slice(60).with_index do |sub_list, i|
      @origins = Array.new

      sub_list.each_with_index do |office, j|        
        @origins.push("#{office[:lat]},#{office[:lon]}")
      end

      distance_matrix = Gistance.distance_matrix(
        destinations: ["#{@current_location['latitude']},#{@current_location['longitude']}"],
        origins: @origins
      )    

      # add results to array of distances for sorting              
      distance_matrix.rows.each do |row|
        row.elements.each do |element|       
          @distances.push({:index => index ,:distance => element.distance.value})
          index += 1
        end
      end     
    end 

    # sort by closest
    @distances.sort_by! do |distance|
      distance[:distance].to_i
    end
     
    # tada!
    @nearest_office = @all_offices[@distances.first[:index]]   
    
    erb :index
  end

  get '/get/:zip' do
    zip = params[:zip]
    url = "https://go.berniesanders.com/page/event/search_results?orderby=zip_radius&zip_radius%5b0%5d=#{zip}&zip_radius%5b1%5d=60&country=US&radius_unit=mi&name=carpool&format=json"
    @all_carpools = JSON.parse(RestClient.get(url))
    @all_carpools['results'].sort_by! { |v| v['distance'].to_i }
    erb :get
  end
end
