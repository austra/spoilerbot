#ruby

require 'bundler/setup'
require 'sinatra'
require 'nokogiri'
require 'open-uri'
require 'json'
require 'pry'
require 'yaml'
require 'typhoeus'

module SpoilerBot
  class Web < Sinatra::Base
    
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
      @@cards = []
      mtgsalvation_url = "http://www.mtgsalvation.com/spoilers/filter?SetID=169&Page=0&Color=&Type=&IncludeUnconfirmed=true&CardID=&CardsPerRequest=250&equals=false&clone=%5Bobject+Object%5D"
      doc = Nokogiri::HTML(open(mtgsalvation_url))
      cards = doc.css('.card-flip-wrapper')
      cards.each {|c| @@cards << Hash[
        :name => c.css(".t-spoiler-header .j-search-html").text.strip,
        :rarity => c.css("img").first.parent.attr('class').split("-").last,
        :color => get_color(c.css('.t-spoiler-type').text.strip, c.css('.t-spoiler-mana .mana-icon')),
        :cmc => get_cmc(c.css('.t-spoiler-mana .mana-icon').map{|m| m.attr('title')}),
        :type => c.css('.t-spoiler-type').text.strip,
        :image_url => c.css('img').last.attr('src'),
        :rules => c.css('.j-search-val').last.nil? ? "" : c.css('.j-search-val').last.attr("value")
      ]}

    end

    before do
      #return 401 unless request["token"] == ENV['SLACK_TOKEN']
    end

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
      #image_url = "http://gatherer.wizards.com/Handlers/Image.ashx?multiverseid=card_id&type=card"
      
      url = base_url + url_options + expansion

      # MtgSalvation
      #
      mtg_spoiler_load
      

      # Gatherer
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
      count = cards.count
      card  = cards.sample

      return get_card_url(card,count)
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

    def get_card_url(card,count)
      image_params = card[:image_url]
      return image_params,count
      
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
      if params[:text] && params[:trigger_word]
        input = params[:text].gsub(params[:trigger_word],"").strip
        if input == "hearthstone"
          @card_url = get_random_hearthstone_card_image
        elsif  input == "reload"
          Web.mtg_spoiler_load
          @card_url = "cards reloaded"
        elsif input == "count"
          @card_url = "#{@@cards.count} / 184"
        else
          filter = input.split(/ /).inject(Hash.new{|h,k| h[k]=""}) do |h, s|
            k,v = s.split(/=/)
            h[k.to_sym] << v
            h
          end
          @card_url,@count = get_random_card(filter)
        end
      else
        filter = add_scope(params)
        @card_url,@count = get_random_card(filter)
      end
        
      begin

      rescue => e
        p e.message
        halt
      end

      status 200
      reply = { username: 'spoilerbot', icon_emoji: ':alien:', text: "Matching cards: #{@count}\n#{@card_url}" }
      return reply.to_json
    end
  end
end
