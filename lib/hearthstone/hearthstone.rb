module Hearthstone
  class Spoiler
    def self.find_cards(params)
     puts params
     RBattlenet::Hearthstone::Card.find_cards(params) 
    end
  end
end