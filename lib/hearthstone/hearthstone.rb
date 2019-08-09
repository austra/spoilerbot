module Hearthstone
  class Spoiler
    def self.find_cards(params)
     RBattlenet::Hearthstone::Card.find_cards(params) 
    end
  end
end