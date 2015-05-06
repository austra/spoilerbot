#ruby

require 'bundler/setup'
require 'sinatra'
require 'nokogiri'
require 'open-uri'
require 'json'
require 'pry'

module SpoilerBot
  class Web < Sinatra::Base

    before do
      #return 401 unless request["token"] == ENV['SLACK_TOKEN']
    end

    @@card_ids = []

    def get_cards_from_gatherer
      pages = []

      #image_url = "http://gatherer.wizards.com/Handlers/Image.ashx?multiverseid=card_id&type=card"
      #base_url = "http://gatherer.wizards.com/Pages/Search/Default.aspx"
      #url_options = "?page=0&sort=cn+&output=checklist&set=%5B%22Dragons%20of%20Tarkir%22%5D"
      url = "http://gatherer.wizards.com/Pages/Search/Default.aspx?page=0&sort=cn+&output=checklist&set=%5B%22Dragons%20of%20Tarkir%22%5D"
      doc = Nokogiri::HTML(open(url))

      paging_control = doc.css('.pagingcontrols a')
      paging_control.each do |page|
        pages << page["href"].match(/page=(\d+)/)[1].to_i
      end

      pages.uniq.count.times do |i|
        url = "http://gatherer.wizards.com/Pages/Search/Default.aspx?page=" + i.to_s + "0&sort=cn+&output=checklist&set=%5B%22Dragons%20of%20Tarkir%22%5D"
        doc = Nokogiri::HTML(open(url))
        links = doc.css('.name a')
        
        links.each do |link|
          @@card_ids << link["href"].partition('=').last
        end
      end
    end

    def get_random_card
      return @@card_ids.sample
    end

    def get_card_image(card)
      return "http://gatherer.wizards.com/Handlers/Image.ashx?multiverseid=" + card + "&type=card"
    end

    post "/spoiler" do
      get_cards_from_gatherer
      card = get_random_card
      @card_url = get_card_image(card)
      begin

      rescue => e
        p e.message
        halt
      end
      status 200
      reply = { username: 'spoilerbot', icon_emoji: ':ryan:', text: @card_url }
      return reply.to_json
    end
  end
end
