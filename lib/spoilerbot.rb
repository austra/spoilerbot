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
      mtgsalvation_url = "http://www.mtgsalvation.com/spoilers/filter?SetID=173&Page=0&Color=&Type=&IncludeUnconfirmed=true&CardID=&CardsPerRequest=250&equals=false&clone=%5Bobject+Object%5D"
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
      #hearthstone_json = File.read('lib/gvg.json')
      #@@hearthstone_cards = JSON.parse(hearthstone_json)
      @@hearthstone_cards = ["https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Ancestral-Guardian-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Garden-Gnome-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Ramkahen-Wildtamer-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Hyena-Alpha-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Naga-Sand-Witch-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Armored-Goon-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Dwarven-Archaeologist-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Spitting-Camel-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Kobold-Sandtrooper-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Quicksand-Elemental-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Vulpera-Scoundrel-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/History-Buff-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Body-Wrapper-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Phalanx-Commander-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Faceless-Lurker-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Wasteland-Scorpid-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Blatant-Decoy-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Pit-Crocolisk-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Living-Monument-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Mischief-Maker-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Sandstorm-Elemental-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Mogu-Fleshshaper-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Vessina-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Totemic-Surge-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Clever-Disguise-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Desert-Hare-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Swarm-of-Locusts-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Octosari-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Subdue-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Unseal-the-Vault-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Golden-Scarab-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Dune-Sculptor-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Crystal-Merchant-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Oasis-Surger-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Ancient-Mysteries-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Worthy-Expedition-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Candletaker-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Bug-Collector-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Neferset-Thrasher-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Serpent-Egg-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Temple-Berserker-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Sandhoof-Waterbearer-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Zephrys-the-Great-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Beaming-Sidekick-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Injured-Tolvir-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Sinister-Deal-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Holy-Ripple-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Penance-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Bazaar-Burglary-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Activate-the-Obelisk-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Wrapped-Golem-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Wretched-Reclaimer-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Khartut-Defender-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/King-Phaoris-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Sahket-Sapper-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Flame-Ward-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Siamat-2-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Conjured-Mirage-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Mortuary-Machine-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Pharaoh-Cat-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Bone-Wraith-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Shadow-of-Death-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Embalming-Ritual-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Tomb-Warden-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Pharaohs-Blessing-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Vilefiend-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Dark-Pharaoh-Tekahn-300x428.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Desert-Spear-300x421.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Livewire-Lance-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Micro-Mummy-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Plague-of-Flames-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Anubisath-Defender-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Overflow-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Hack-the-System-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Colossus-of-the-Moon-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Plague-of-Wrath-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Sunstruck-Henchman-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Grandmummy-2-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Generous-Mummy-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/High-Priest-Amet-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Wasteland-Assassin-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Frightened-Flunky-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Infested-Goblin-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Pressure-Plate-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Into-the-Fray-2-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Diseased-Vulture-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Neferset-Ritualist-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Anubisath-Warbringer-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Mogu-Cultist-300x419.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Tortollan-Pilgrim-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Whirlkick-Master-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Hooked-Scimitar-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Splitting-Axe-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Arcane-Flakmage-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Cloud-Prince-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Anka-the-Buried-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Tip-the-Scales-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Fishflinger-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Bloodsworn-Mercenary-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Hunters-Pack-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/EVIL-Recruiter-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Riftcleaver-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Desert-Obelisk-300x419.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Bazaar-Mugger-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Wild-Bloodstinger-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Scarlet-Webweaver-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Hidden-Oasis-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Murmy-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Making-Mummies-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Expired-Merchant-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Sir-Finley-of-the-Sands-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Elise-the-Enlightened-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Dinotamer-Brann-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Reno-the-Relicologist-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Armagedillo-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Plague-of-Murlocs-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Salhets-Pride-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Sandwasp-Queen-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Brazen-Zealot-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Psychopomp-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Plague-of-Madness-1-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Raid-the-Sky-Temple-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Weaponized-Wasp-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/BEEEES-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Impbalming-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Earthquake-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Corrupt-the-Waters-300x414.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Untapped-Potential-300x387.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Supreme-Archeology-300x387.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Questing-Explorer-300x418.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Restless-Mummy-300x418.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Puzzle-Box-of-Yogg-Saron-300x427.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Plague-of-Death-300x427.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Jar-Dealer-300x418.png", "https://www.hearthstonetopdecks.com/wp-content/uploads/2019/07/Evil-Totem-300x418.png"]

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
      @@hearthstone_cards.sample
    end
    
    def get_random_album
      
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
      song_description = "#{song["artist"].gsub!(/[^0-9A-Za-z]/, '')}-#{song["title"].gsub!(/[^0-9A-Za-z]/, '')}"
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
        when "song"
          slack_string = get_random_song
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
