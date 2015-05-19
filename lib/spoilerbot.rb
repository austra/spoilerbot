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

    
    
    configure do
      @@cards = []

      pages = []

      set = "&set=[%22Dragons%20of%20Tarkir%22]"
      base_url = "http://gatherer.wizards.com/Pages/Search/Default.aspx"
      url_options = "?page=0&sort=cn+&output=standard"
      #image_url = "http://gatherer.wizards.com/Handlers/Image.ashx?multiverseid=card_id&type=card"
      
      url = base_url + url_options + set

      doc = Nokogiri::HTML(open(url))

      paging_control = doc.css('.pagingcontrols a')
      paging_control.each do |page|
        pages << page["href"].match(/page=(\d+)/)[1].to_i
      end

      pages.uniq.count.times do |i|
        url = "http://gatherer.wizards.com/Pages/Search/Default.aspx?page=" + i.to_s + "&sort=cn+&output=standard" + set
        if i > 0 
          doc = Nokogiri::HTML(open(url))
        end
        card_table = doc.css('.cardItem')
        @@cards << Hash[card_table.map{|c| [
         :name => c.css('.cardTitle').text.strip,
         :rarity => c.css('.setVersions img').attr('src').text.split('rarity=')[-1],
         :cmc => c.css('.convertedManaCost').text.strip,
         :type => c.css('.typeLine').text.strip,
         :image_url => c.css('.leftCol img').attr('src').text.gsub("../../",""),
         :rules => c.css('.rulesText p').map(&:text).join("\n")]}]
      end
    end

    def get_random_card(rarity, cmc, terms)
      binding.pry
      card = @@cards.sample

      image_params = card[4]
      base_image_url = "http://gatherer.wizards.com/"
      return base_image_url + image_params

    end

    def get_card_image(card)
      return "http://gatherer.wizards.com/Handlers/Image.ashx?multiverseid=" + card + "&type=card"
    end

    

    post "/spoiler" do
      puts params
      pp params
      #sinatra optional params /spoiler/?:p1?/?:p2?
      rarity = params[:rarity] ||= ""
      cmc = params[:cmc] ||= ""
      terms = params[:terms] ||= ""

      @card_url = get_random_card(rarity, cmc, terms)
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
