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

Dotenv.load

module SpoilerBot
  class Web < Sinatra::Base

    def self.get_gist
      #0dd60b11cc9d3da9fdb7e6e19e3540f8
      #ENV["GIST"]
      request = Typhoeus::Request.new(
        "https://api.github.com/gists/0dd60b11cc9d3da9fdb7e6e19e3540f8",
        method: :get,
        headers: { Authorization: "token #{ENV['GIT_TOKEN']}" }
      )
      response = request.run 
      binding.pry
      body = JSON.parse(response.body)
      body["files"]["spoilerbot"]["content"]
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
      viewed_cards = get_gist
      @@viewed_cards = viewed_cards.split(",")
      @@viewed_count = @@viewed_cards.count

      @@cards = []
      mtgsalvation_url = "http://www.mtgsalvation.com/spoilers/filter?SetID=172&Page=0&Color=&Type=&IncludeUnconfirmed=true&CardID=&CardsPerRequest=250&equals=false&clone=%5Bobject+Object%5D"
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
      hearthstone_json = File.read('lib/gvg.json')
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
      @@hearthstone_cards["cards"].sample["image_url"]
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
        when "hearthstone"
          get_random_hearthstone_card_image
        when "twitter"
          twitter
        when "reset"
          reset_viewed
          "reset viewed cards"
        when "reload"
          Web.mtg_spoiler_load
          "cards reloaded"
        when "count"
          "#{@@cards.count} / 205"
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
