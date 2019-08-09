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
require 'rbattlenet'

require_relative './hearthstone/hearthstone.rb'

Dotenv.load

module SpoilerBot
  class Web < Sinatra::Base

    before do
      #return 401 unless request["token"] == ENV['SLACK_TOKEN']
    end

    configure do
      set :static_cache_control, [:public, max_age: 60 * 60 * 24 * 365]

      pages = []

      @@heroku_url = "http://afternoon-reaches-1103.herokuapp.com"
      RBattlenet.authenticate(client_id: ENV['BLIZZARD_CLIENT_ID'], client_secret: ENV['BLIZZARD_CLIENT_SECRET'])
      RBattlenet.set_region(region: "us", locale: "en_us")
    end
    
    def add_scope(params)
      filter = {}
      params.each do |k,v|
        filter[k.to_sym] = v
      end
      filter
    end

    def self.post_message(text)
      url  = ENV['SLACK_WEBHOOK_URL']
      
      response = Typhoeus.post(url, body: {"channel" => "#general", "text" => text}.to_json)
    end
    
    def find_hearthstone_cards(params)
      params = add_scope(params)
      cards = Hearthstone::Spoiler.find_cards(params)
      cards["cards"].sample["image"]
    end

    def get_death
      # AI!!!
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

    def twitter
      #get top tweets?
      # @@twitter_client.home_timeline.take(5).map(&:text).join("/n")
    end

    get "/post" do
      post_message
    end    

    get "/spoiler" do
      haml :spoiler
    end
    
    post "/spoiler" do
      puts params

      # from slack
      if params[:text] && params[:trigger_word]
        input = params[:text].gsub(params[:trigger_word],"").strip.downcase

        @output = case input
        when /hearthstone.*/
          input = input.gsub("hearthstone ", "")
          input = "set=rise of shadows" if input.empty?
          
          if input == "help"
            help  = "Available Filters: set, class, mana_cost, attack health, collectible, rarity, type, minion_type, keyword, text_filter, sort, order, page, page_size"
            help += "\n`spoiler hearthstone set=rise of shadows rarity=legendary"
            return help
          end
          current_key = ""
          search_criteria = input.split.each_with_object(Hash.new()) do |str, search_criteria|
            if str.include?("=")
              search_criteria[str.split("=")[0]] = str.split("=")[1]
              current_key = str.split("=")[0]
            else
              if current_key == "set"
                search_criteria[current_key] = search_criteria[current_key] + "-" + str
              else
                search_criteria[current_key] = search_criteria[current_key] + " " + str
              end
            end
          end

          find_hearthstone_cards(search_criteria)
        when "song"
          get_random_song
        when "album"
          get_random_album
        when "how will i die?"
          get_death
        when "twitter"
          twitter
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
      
      status 200
      
      text = ""
      text += "#{@output}"

      # twitter test output
      # if @twitter
      #   slack_string = @twitter
      # else 
      #   slack_string = "#{text}"
      # end
      
      reply = { username: 'spoilerbot', icon_emoji: ':alien:', text: text }
      return reply.to_json
    end
  end
end
