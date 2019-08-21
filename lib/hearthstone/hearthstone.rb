module Hearthstone
  class Spoiler
    def self.find_cards(params)
      RBattlenet::Hearthstone::Card.find_cards(params) 
    end

    def self.find_deck(deckcode)
      RBattlenet::Hearthstone::Deck.find_deck(deckcode: deckcode)
    end
  end
end