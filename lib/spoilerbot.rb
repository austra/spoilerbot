#ruby

require 'bundler/setup'
require 'sinatra'
require 'nokogiri'
require 'open-uri'
require 'json'
require 'pry'
require 'yaml'
require 'typhoeus'
require 'csv'
require 'twitter'
require 'dotenv'
require 'json'
require 'net/http'
require 'uri'
require 'digest'
require 'xmlstats'
require 'active_support/core_ext/time'
require "coinbase/wallet"

Dotenv.load

module SpoilerBot
  class Web < Sinatra::Base

    def self.get_gist gist_id, gist_title
      request = Typhoeus::Request.new(
        "https://api.github.com/gists/#{gist_id}",
        method: :get,
        headers: { Authorization: "token #{ENV['GIT_TOKEN']}" }
      )
      response = request.run 
      body = JSON.parse(response.body)
      body["files"]["#{gist_title}"]["content"]
    end

    def self.edit_gist content
      request = Typhoeus::Request.new(
        "https://api.github.com/gists/0dd60b11cc9d3da9fdb7e6e19e3540f8",
        method: :patch,
        headers: { Authorization: "token #{ENV['GIT_TOKEN']}" },
        body: {"files" => { "spoilerbot" => { "content" => content }}}.to_json
      )

      response = request.run 
    end

    def self.get_color(type, cost)
      colors = []
      if type.downcase.include? "land"
        colors << "land"
      else 
        cost.map{|m| m.attr('title')}.each do |c|
          colors << c.split(" ")[1]
        end

        #remove generic colorless
        colors = colors - ["Colorless"]
        
        #add back in actual colorless
        if cost.map{|c| c.attr('class')}.join(",").include? "generic"
          colors << "Colorless"
        end

      end  
      return colors.uniq
    end

    def self.get_cmc(cost)
      cmc = []
      cost.each do |c|
        cmc << c.split(" ")[0]
      end
      return cmc.map(&:to_i).reduce(:+).to_s
    end

    def self.mtg_spoiler_load
      # For MTG Salvation, read in and parse spoiler list
      # should probably just use a db and store this stuff....  
      # Otherwise tracking state of viewed cards relies on implementing twitter to store viewed cards
      # or something, which sounds fun anyway, so who needs a db...
      mtg_gist_id = "0dd60b11cc9d3da9fdb7e6e19e3540f8"
      mtg_gist_title = "spoilerbot"
      viewed_cards = get_gist(mtg_gist_id, mtg_gist_title)
      @@viewed_cards = viewed_cards.split(",")
      @@viewed_count = @@viewed_cards.count

      @@cards = []
      mtgsalvation_url = "http://www.mtgsalvation.com/spoilers/filter?SetID=179&Page=0&Color=&Type=&IncludeUnconfirmed=true&CardID=&CardsPerRequest=250&equals=false&clone=%5Bobject+Object%5D"
      doc = Nokogiri::HTML(open(mtgsalvation_url))
      cards = doc.css('.card-flip-wrapper')
      cards.each {|c| @@cards << Hash[
        :name      => c.css(".t-spoiler-header .j-search-html").text.strip,
        :rarity    => c.css("img").first.parent.attr('class').split("-").last,
        :color     => get_color(c.css('.t-spoiler-type').text.strip, c.css('.t-spoiler-mana .mana-icon')),
        :cmc       => get_cmc(c.css('.t-spoiler-mana .mana-icon').map{|m| m.attr('title')}),
        :type      => c.css('.t-spoiler-type').text.strip,
        :image_url => c.css('img').last.attr('src'),
        :rules     => c.css('.j-search-val').last.nil? ? "" : c.css('.j-search-val').last.attr("value"),
        :number    => c.css(".t-spoiler-artist").text.strip[/(\d*)\//,1]
      ]}
      @@cards = @@cards.select{|c| !@@viewed_cards.include? c[:number]}
    end

    before do
      #return 401 unless request["token"] == ENV['SLACK_TOKEN']
    end

    #sample Gatherer request
    #http://gatherer.wizards.com/Pages/Search/Default.aspx?page=0&sort=cn+&output=standard&set=["Battle%20for%20Zendikar"]
    
    configure do
      # card json here: https://market.mashape.com/omgvamp/hearthstone#card-set
      hearthstone_set = "gangs"
      hearthstone_json = File.read('lib/hearthstone_' + hearthstone_set + '.json')
      @@hearthstone_cards = JSON.parse(hearthstone_json)

      set :static_cache_control, [:public, max_age: 60 * 60 * 24 * 365]
      

      pages = []

      @@heroku_url = "http://afternoon-reaches-1103.herokuapp.com"
      expansion = "&set=[%22Battle%20for%20Zendikar%22]"

      base_url = "http://gatherer.wizards.com/Pages/Search/Default.aspx"
      url_options = "?page=0&sort=cn+&output=standard"
      
      # Gatherer Image Url
      #image_url = "http://gatherer.wizards.com/Handlers/Image.ashx?multiverseid=card_id&type=card"
      
      url = base_url + url_options + expansion

      # For Using MtgSalvation
      #
      mtg_spoiler_load

      # For Using Gatherer
      #
      # doc = Nokogiri::HTML(open(url))
      # paging_control = doc.css('.pagingcontrols a')
      # paging_control.each do |page|
      #   pages << page["href"].match(/page=(\d+)/)[1].to_i
      # end

      # pages.uniq.count.times do |i|
      #   url = "http://gatherer.wizards.com/Pages/Search/Default.aspx?page=" + i.to_s + "&sort=cn+&output=standard" + expansion
      #   if i > 0 
      #     doc = Nokogiri::HTML(open(url))
      #   end
      #   card_table = doc.css('.cardItem')
      #   card_table.each {|c| @@cards << Hash[
      #           :name => c.css('.cardTitle').text.strip,
      #           :rarity => c.css('.setVersions img').attr('src').text.split('rarity=')[-1],
      #           :color => c.css('.manaCost img').map{ |i| i['alt'] }.map{ |i| i.length > 1 ? i : "Colorless" }, #["Colorless", "Black"]
      #           :cmc => c.css('.convertedManaCost').text.strip,
      #           :type => c.css('.typeLine').text.strip,
      #           :image_url => c.css('.leftCol img').attr('src').text.gsub("../../",""),
      #           :rules => c.css('.rulesText p').map(&:text).join("\n")
      #   ]}
      # end
      
    end
    
    
    
    def get_random_card(filter)
      cards = @@cards
      cards = cards.select {|card| card[:rarity].downcase == filter[:rarity].downcase} if (filter[:rarity] && !filter[:rarity].empty?)
      cards = cards.select {|card| card[:cmc] == filter[:cmc]} if (filter[:cmc] &&! filter[:cmc].empty?)
      cards = cards.select {|card| card[:type].downcase.include? filter[:type].downcase} if (filter[:type] && !filter[:type].empty?)
      cards = cards.select {|card| card[:rules].downcase.include? filter[:rules]} if (filter[:rules] && !filter[:rules].empty?)
      cards = cards.select {|card| card[:name].downcase.include? filter[:name].downcase} if (filter[:name] && !filter[:name].empty?)
      cards = cards.select {|card| card[:color].map(&:downcase).include? filter[:color].downcase} if (filter[:color] && !filter[:color].empty?)
      cards = cards.select {|card| card[:rules].downcase.include? "transform"} if (filter[:flip] && !filter[:flip].empty?)
      matching_count = cards.count
      card = cards.sample
      
      #store this to gist
      @@viewed_cards << card[:number]
      @@viewed_count = @@viewed_cards.count
      
      SpoilerBot::Web.edit_gist(@@viewed_cards.join(","))

      @@cards.delete(card)

      return card, matching_count
    end

    def reset_viewed
      # reset gist
      SpoilerBot::Web.edit_gist("")
      @@viewed_count = 0
      @@viewed_cards = []
    end

    def get_card_image(card)
      return "http://gatherer.wizards.com/Handlers/Image.ashx?multiverseid=" + card + "&type=card"
    end
    
    def add_scope(params)
      filter = {}
      params.each do |k,v|
        filter[k.to_sym] = v
      end
      filter
    end

    def get_card_url(card)
      image_params = card[:image_url]
      return image_params
      
      # Gatherer
      #base_image_url = "http://gatherer.wizards.com/"
      #return base_image_url + image_params
    end

    def post_message
      filter = add_scope(params)
      card,count = get_random_card(filter)
      card_url = get_card_url(card)
      links = "<#{@@heroku_url}/post|Random Spoiler>"
      text = "<#{card_url}> #{links}"

      url = "https://hooks.slack.com/services/####/######/########"

      response = Typhoeus.post(url, body: {"channel" => "#general", "text" => text}.to_json)
      render text: '', status: :ok
    end
    
    def get_random_hearthstone_card_image
      @@hearthstone_cards.sample["img"]
    end

    def get_death
      deaths = ["A broken heart. Followed quickly by a mace to the skull.", "Accidentally dropped by Hodor.", "Accidentally roll over too far when sleeping in Eyrie Prison.", "Arrow through the jugular.", "Assassinated by shadow demon baby.", "Ax to the face.", "Beheaded at Joffrey's behest.", "Beheaded by Theon.", "Beheaded for deserting the Knights Watch.", "Betrayed by whom you trust most.", "Bored to death by Catelyn.", "Burned at the stake as punishment for tricking Daenerys.", "Cersei tells Jaime she slept with you.", "Choked out by imprisoned Jaime Lannister.", "Chucked into a crazy hole &mdash; a.k.a. &ldquo;the moon door&rdquo; &mdash; by Bronn.", "Contract a disease at Littlefinger's.", "Crushed to death by giant.", "Disemboweled by the Hound.", "Dragged by a horse.", "Dragon lunch.", "Eat a bad horse heart.", "Eaten by direwolf.", "Exposure out in the desert with Daenerys.", "Face pushed in mud until you drown.", "Fall off the Wall.", "Fatal head wound from Tyrion's shield.", "Freeze to death North of the Wall.", "Hanged for disloyalty to throne.", "High cholesterol from a lifetime of eating auroch.", "Hot oil poured on you from above.", "Hugged to death by giant.", "Jaqen H'ghar appears out of nowhere, takes your face, kills you.", "Killed for money by Bronn.", "Knocked off a tower by a flock of ravens.", "Leg axed off by Tyrion.", "Lethal dose of Cersei side-eye.", "Licked to death by aggressive mother direwolf.", "Malnutrition and poor dental hygiene.", "Mercy-smothered by Daenerys.", "Mistaken for Ned Stark, beheaded.", "Molten tin poured into ears.", "Molten gold poured over head.", "OD'd on milk of the poppy.", "On the wrong end of a jousting match.", "Peanut allergy.", "Poisoned. By those you trusted.", "Rat torture: A bucket with a rat in it was fastened to your abdomen. To get out, the rat gnawed through your innards.", "Samwell Tarly accidentally shot you with a crossbow.", "Sat on own dagger.", "Sealed in ice and left to freeze/starve.", "Seduced and stabbed by Osha.", "Sepsis after being gored by a boar.", "Shot by Theon Greyjoy's bow and arrow.", "Sliced in half with Valyrian steel.", "Sniffled to death by Walder Frey's offspring.", "Soul frozen/destroyed by White Walkers.", "Stabbed and set on fire by Jon Snow.", "Stabbed by Arya Stark, for standing in her way. (Served you right.)", "Stabbed in the eye by Jamie Lannister.", "Stabbed to death by ten equally-aggressive armored knights.", "Suffocated underneath sleeping Hodor.", "Syphilis.", "Teased the Hound with a match.", "Throat ripped out by Khal Drogo.", "Throat slit by creepy magician in Q'arth.", "Tortured to death by &ldquo;the tickler.&rdquo;", "Tried to put a funny hat on a direwolf.", "Underestimated Arya's skill with Needle.", "Unseamed from nave to chops. (That's how you died in Macbeth too.)", "Walloped to death with a mace.", "You have died of dysentery. Which you contracted on the Iron Islands."]
      msg = deaths.sample
      msg
    end

    def get_random_song
      version = "#{ENV['VERSION']}"
      client = "#{ENV['CLIENT']}"
      username = "#{ENV['USERNAME']}"
      password = "#{ENV['PASSWORD']}"
      salt = "#{ENV['SALT']}"
      token = Digest::MD5.hexdigest(password + salt)

      location = "#{ENV["SUBSONIC_SERVER"]}/rest/getRandomSongs.view?u=#{username}&t=#{token}&s=#{salt}&v=#{version}&c=#{client}&f=json&size=1"
      url = URI.parse(location)
      req = Net::HTTP::Get.new(url.to_s)
      res = Net::HTTP.start(url.host, url.port) {|http|
        http.request(req)
      }
      res = JSON.parse(res.body)
      song = res["subsonic-response"]["randomSongs"]["song"].first
      song_description = "#{song["artist"].gsub(/[^0-9A-Za-z]/, '')}-#{song["title"].gsub(/[^0-9A-Za-z]/, '')}"
      cover_art = song["coverArt"]
      
      location = "#{ENV["SUBSONIC_SERVER"]}/rest/createShare.view?u=#{username}&t=#{token}&s=#{salt}&v=#{version}&c=#{client}&f=json&id=#{song["id"]}&description=#{song_description}"
      url = URI.parse(location)
      req = Net::HTTP::Get.new(url.to_s)
      res = Net::HTTP.start(url.host, url.port) {|http|
        http.request(req)
      }
      res = JSON.parse(res.body)
      share = res["subsonic-response"]["shares"]["share"].first
      share_url = share["url"]

      "#{song["artist"]} - #{song["title"]}\n#{share_url}"

    end

    def get_random_album
      version = "#{ENV['VERSION']}"
      client = "#{ENV['CLIENT']}"
      username = "#{ENV['USERNAME']}"
      password = "#{ENV['PASSWORD']}"
      salt = "#{ENV['SALT']}"
      token = Digest::MD5.hexdigest(password + salt)

      location = "#{ENV["SUBSONIC_SERVER"]}/rest/getAlbumList.view?u=#{username}&t=#{token}&s=#{salt}&v=#{version}&c=#{client}&f=json&size=1&type=random"
      url = URI.parse(location)
      req = Net::HTTP::Get.new(url.to_s)
      res = Net::HTTP.start(url.host, url.port) {|http|
        http.request(req)
      }
      res = JSON.parse(res.body)

      album = res["subsonic-response"]["albumList"]["album"].first
      album_description = "#{album["artist"].gsub(/[^0-9A-Za-z]/, '')}-#{album["title"].gsub(/[^0-9A-Za-z]/, '')}"

      location = "#{ENV["SUBSONIC_SERVER"]}/rest/createShare.view?u=#{username}&t=#{token}&s=#{salt}&v=#{version}&c=#{client}&f=json&id=#{album["id"]}&description=#{album_description}"
      url = URI.parse(location)
      req = Net::HTTP::Get.new(url.to_s)
      res = Net::HTTP.start(url.host, url.port) {|http|
        http.request(req)
      }
      res = JSON.parse(res.body)
      share = res["subsonic-response"]["shares"]["share"].first
      share_url = share["url"]

      "#{album["artist"]} - #{album["title"]}\n#{share_url}"
    end

    def get_weather
      token = "#{ENV['WUNDERGROUND_TOKEN']}"
      location = "http://api.wunderground.com/api/#{token}/conditions/q/UT/Salt_Lake_City.json"
      url = URI.parse(location)
      req = Net::HTTP::Get.new(url.to_s)
      res = Net::HTTP.start(url.host, url.port) {|http|
        http.request(req)
      }
      res = JSON.parse(res.body)
      image_url = res["current_observation"]["icon_url"]
      temp = res["current_observation"]["temp_f"]
      msg = "#{temp.to_s}\n#{image_url}"
    end

    def get_nba_schedule(team)
      # This is ugly..../
      date = Time.now.strftime("%Y-%m-%d")
      Xmlstats.api_key = "#{ENV['XMLSTATS_TOKEN']}"
      Xmlstats.contact_info = "#{ENV['XMLSTATS_CONTACT']}"
      events = Xmlstats.events(Date.parse(date), :nba)
      msg = ""
      events.each do |event|
        msg << "#{event.start_date_time.in_time_zone("MST").strftime("%l:%M%p").strip} #{event.away_team.full_name} @ #{event.home_team.full_name}\n"
      end
      msg
    end

    def get_nba_scores
      date = (Time.now - 24*60*60).strftime("%Y-%m-%d")
      Xmlstats.api_key = "#{ENV['XMLSTATS_TOKEN']}"
      Xmlstats.contact_info = "#{ENV['XMLSTATS_CONTACT']}"
      events = Xmlstats.events(Date.parse(date), :nba)
      msg = ""
      events.each do |event|
        home_hash = {}
        away_hash = {}
        event_id = event.event_id
        box = Xmlstats.nba_box_score(event_id)
        
        box.away_stats.each do |p|
          away_hash.merge!(p.display_name => {:points => p.points, :rebounds => p.rebounds, :assists => p.assists})
        end
        
        box.home_stats.each do |p|
          home_hash.merge!(p.display_name => {:points => p.points, :rebounds => p.rebounds, :assists => p.assists})
        end
        
        home_top_points = home_hash.sort_by { |k, v| v[:points] }.reverse.first
        home_top_rebounds = home_hash.sort_by { |k, v| v[:rebounds] }.reverse.first
        home_top_assists = home_hash.sort_by { |k, v| v[:assists] }.reverse.first
        home_top_points_msg = "Pts: #{home_top_points[0]}: #{home_top_points[1][:points]}"
        home_top_rebounds_msg = "Reb: #{home_top_rebounds[0]}: #{home_top_rebounds[1][:rebounds]}"
        home_top_assists_msg = "Ast: #{home_top_assists[0]}: #{home_top_assists[1][:assists]}"
        home_top_msg = "#{home_top_points_msg}\n#{home_top_rebounds_msg}\n#{home_top_assists_msg}"

        away_top_points = away_hash.sort_by { |k, v| v[:points] }.reverse.first
        away_top_rebounds = away_hash.sort_by { |k, v| v[:rebounds] }.reverse.first
        away_top_assists = away_hash.sort_by { |k, v| v[:assists] }.reverse.first
        away_top_points_msg = "Pts: #{away_top_points[0]}: #{away_top_points[1][:points]}"
        away_top_rebounds_msg = "Reb: #{away_top_rebounds[0]}: #{away_top_rebounds[1][:rebounds]}"
        away_top_assists_msg = "Ast: #{away_top_assists[0]}: #{away_top_assists[1][:assists]}"
        away_top_msg = "#{away_top_points_msg}\n#{away_top_rebounds_msg}\n#{away_top_assists_msg}"
        
        msg << "@#{event.home_team.full_name} #{event.home_points_scored}\n"
        msg << "#{home_top_msg}\n"
        msg << "#{event.away_team.full_name} #{event.away_points_scored}\n"
        msg << "#{away_top_msg}\n"
        msg << "------------------------------------\n"
      end
      msg
    end

    def get_movie(movie)
      location = "http://www.omdbapi.com/?t=#{movie}&y=&plot=short&r=json"
      encoded_url = URI.encode(location)
      url = URI.parse(encoded_url)
      req = Net::HTTP::Get.new(url.to_s)
      res = Net::HTTP.start(url.host, url.port) {|http|
        http.request(req)
      }
      res = JSON.parse(res.body)

      #poster = "http://img.omdbapi.com/?i=#{res['imdbID']}&apikey=#{ENV['OMDB_KEY']}"

      msg = "#{res['Title']}\n#{res['Plot']}\nRating: #{res['imdbRating']}"
      msg
    end

    def find_flip_card(card)
      @@cards.select{|c| c[:number] == card[:number] && c[:name] != card[:name]}.first
    end

    def twitter
      # will eventually write viewed cards to a tweet, then read them back in
      # to keep state on free heroku
      
      #@@twitter_client.home_timeline.map(&:attrs)
      @@twitter_client.home_timeline.take(5).map(&:text).join("/n")
    end

    def get_google_stock url
      request = Typhoeus::Request.new(
        "#{url}",
        method: :get
      )
      response = request.run 
      body = JSON.parse(response.body[4..-1])
    end

    def get_my_stock
      stock_gist_id = "d4e43b9586ab5d4cb1901ad5cb55e78b"
      stock_gist_title = "stock"
      stocks = SpoilerBot::Web.get_gist(stock_gist_id, stock_gist_title)
      keys = ["ticker","qty","buy_price"]
      my_stocks = CSV.parse(stocks).map {|a| Hash[ keys.zip(a) ] }
      initial_value = my_stocks.map{|s| s["qty"].to_i * s["buy_price"].to_f}.inject(:+)
      tickers = my_stocks.collect{|k,v| k["ticker"]}
      url = "http://www.google.com/finance/info?q=NSE:#{tickers.join(",")}"
      stock_data = get_google_stock url
      current_value = []
      tickers.each do |ticker|
        stock = stock_data.select{|s| s["t"] == ticker.upcase}.first
        price = stock["l"].to_f
        qty = my_stocks.collect{|s| s["qty"] if s["ticker"] == ticker}.compact.first.to_i
        current_value << price*qty
      end

      current_value = current_value.inject(:+)
      return_percent = (current_value - initial_value)/initial_value
      sign = return_percent < 0.0 ? "-" : "+"
      msg = "$#{'%.2f' % current_value} (#{sign}#{'%.2f' % return_percent}%)"
    end

    get "/post" do
      post_message
    end    

    get "/spoiler" do
      filter = add_scope(params)
      @card,@count = get_random_card(filter)
      @card_url = get_card_url(@card)

      haml :spoiler
    end
    
    post "/spoiler" do
      # from slack
      if params[:text] && params[:trigger_word]
        input = params[:text].gsub(params[:trigger_word],"").strip

        @output = case input
        when "coins"
          url = "https://poloniex.com/public?command=returnTicker"
          request = Typhoeus::Request.new(
            "#{url}",
            method: :get
          )
          response = request.run 
          body = JSON.parse(response.body)

          btc_price = body["USDT_BTC"]["last"].to_f
          btc_string = "BTC: #{btc_price}"

          xmr_price = body["USDT_XMR"]["last"].to_f
          xmr_string = "XMR: #{xmr_price}"

          ltc_price = body["USDT_LTC"]["last"].to_f
          ltc_string = "LTC: #{ltc_price}"

          eth_price = body["USDT_ETH"]["last"].to_f
          eth_string = "ETH: #{eth_price}"

          xrp_price = body["USDT_XRP"]["last"].to_f
          xrp_string = "XRP: #{xrp_price}"  

          bcn_price = body["BTC_BCN"]["last"].to_f
          sc_price = body["BTC_SC"]["last"].to_f
          gnt_price = body["BTC_GNT"]["last"].to_f

          ltc = 4 * ltc_price
          eth = 2 * eth_price
          btc = (0.746 + 0.00017405) * btc_price
          xrp = (281.5 + 340.42051720)* xrp_price
          xmr = 2.30494470 * xmr_price
          
          sc = sc_price * btc_price
          sc_total = (92.07848893 * sc_price) * btc_price
          sc_string = "SC: #{sc}"
          
          bcn = bcn_price * btc_price
          bcn_total = (28089.88764044 * bcn_price) * btc_price
          bcn_string = "BCN: #{bcn}"

          gnt = gnt_price * btc_price
          gnt_total = (277.17572524  * gnt_price) * btc_price
          gnt_string = "GNT: #{gnt}"

          gain = ltc+eth+btc+xrp+xmr+bcn_total+sc_total+gnt_total - 2028.93
          "#{ltc_string}\n#{eth_string}\n#{btc_string}\n#{xrp_string}\n#{bcn_string}\n#{xmr_string}\n#{sc_string}\n#{gnt_string}\nNet: #{gain > 0 ? "+" : "-"}#{gain.to_i}"

        when "hearthstone"
          get_random_hearthstone_card_image
        when "song"
          slack_string = get_random_song
        when "album"
          slack_string = get_random_album
        when "How will I die?"
          get_death
        when "my stock"
          get_my_stock
        when "scores"
          get_nba_scores
        when /nba.*/
          get_nba_schedule(input.gsub("nba ", ""))
        when /movie.*/
          get_movie(input.gsub("movie ", ""))
        when "weather"
          get_weather
        when "twitter"
          twitter
        when "reset"
          reset_viewed
          "reset viewed cards"
        when "reload"
          Web.mtg_spoiler_load
          "cards reloaded"
        when "count"
          "#{@@cards.count} / #{@@cards.count + @@viewed_count}"
        else
          @filter = input.split(/ /).inject(Hash.new{|h,k| h[k]=""}) do |h, s|
            k,v = s.split(/=/)
            h[k.to_sym] << v
            h
          end
        end

      # straight to heroku
      else
        @filter = add_scope(params)
      end
      
      if @filter
        @card,@matching_count = get_random_card(@filter)
        @output = get_card_url(@card)
        
        # see if the card has a flip
        @flip_card = find_flip_card(@card)
        @flip_card_url = get_card_url(@flip_card) if @flip_card
        
      end

      status 200
      
      text = ""
      text += "Unseen: #{@@cards.count}, Viewed: #{@@viewed_count} " if @filter
      text += "Matching cards: #{@matching_count}\n" if @matching_count
      text += "#{@output}"
      text += "\n#{@flip_card_url}" if @flip_card

      
      # twitter test output
      if @twitter
        slack_string = @twitter
      else 
        slack_string = "#{text}"
      end
      
      reply = { username: 'spoilerbot', icon_emoji: ':alien:', text: slack_string }
      return reply.to_json
    end
  end
end
