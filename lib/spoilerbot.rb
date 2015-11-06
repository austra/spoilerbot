#ruby

require 'bundler/setup'
require 'sinatra'
require 'nokogiri'
require 'open-uri'
require 'json'
require 'pry'
require 'yaml'

module SpoilerBot
  class Web < Sinatra::Base

    before do
      #return 401 unless request["token"] == ENV['SLACK_TOKEN']
    end

    
    #http://gatherer.wizards.com/Pages/Search/Default.aspx?page=0&sort=cn+&output=standard&set=["Battle%20for%20Zendikar"]
    configure do
      @@cards = []

      pages = []

      expansion = "&set=[%22Battle%20for%20Zendikar%22]"

      base_url = "http://gatherer.wizards.com/Pages/Search/Default.aspx"
      url_options = "?page=0&sort=cn+&output=standard"
      #image_url = "http://gatherer.wizards.com/Handlers/Image.ashx?multiverseid=card_id&type=card"
      
      url = base_url + url_options + expansion

      doc = Nokogiri::HTML(open(url))

      paging_control = doc.css('.pagingcontrols a')
      paging_control.each do |page|
        pages << page["href"].match(/page=(\d+)/)[1].to_i
      end

      pages.uniq.count.times do |i|
        url = "http://gatherer.wizards.com/Pages/Search/Default.aspx?page=" + i.to_s + "&sort=cn+&output=standard" + expansion
        if i > 0 
          doc = Nokogiri::HTML(open(url))
        end
        card_table = doc.css('.cardItem')
        card_table.each {|c| @@cards << Hash[
                :name => c.css('.cardTitle').text.strip,
                :rarity => c.css('.setVersions img').attr('src').text.split('rarity=')[-1],:cmc => c.css('.convertedManaCost').text.strip,
                :type => c.css('.typeLine').text.strip,
                :image_url => c.css('.leftCol img').attr('src').text.gsub("../../",""),
                :rules => c.css('.rulesText p').map(&:text).join("\n")
        ]}
      end
    end

    def get_random_card(filter)
      cards = @@cards
      cards = cards.select {|card| card[:rarity].downcase == filter[:rarity].downcase} if (filter[:rarity] && !filter[:rarity].empty?)
      cards = cards.select {|card| card[:cmc] == filter[:cmc]} if (filter[:cmc] &&! filter[:cmc].empty?)
      cards = cards.select {|card| card[:type].downcase.include? filter[:type].downcase} if (filter[:type] && !filter[:type].empty?)
      cards = cards.select {|card| card[:rules].include? rules} if (filter[:rules] && !filter[:rules].empty?)
      cards = cards.select {|card| card[:name].downcase.include? filter[:name].downcase} if (filter[:name] && !filter[:name].empty?)
      card  = cards.sample

      return card
      
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
      base_image_url = "http://gatherer.wizards.com/"
      return base_image_url + image_params

    end

    get "/spoiler" do
      filter = add_scope(params)
      @card = get_random_card(filter)
      @card_url = get_card_url(@card)

      haml :spoiler
    end

    post "/spoiler" do
      if params[:text] && params[:trigger_word]
        input = params[:text].gsub(params[:trigger_word],"").strip
        filter = input.split(/ /).inject(Hash.new{|h,k| h[k]=""}) do |h, s|
          k,v = s.split(/=/)
          h[k.to_sym] << v
          h
        end

      else
        filter = add_scope(params)
      end

      @card = get_random_card(filter)
      @card_url = get_card_url(@card)
      begin

      rescue => e
        p e.message
        halt
      end

      status 200
      reply = { username: 'spoilerbot', icon_emoji: ':alien:', text: @card_url }
      return reply.to_json
    end
  end
end
