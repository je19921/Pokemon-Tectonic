MAX_HAPPINESS = 255

#===============================================================================
# Instances of this class are individual Pokémon.
# The player's party Pokémon are stored in the array $Trainer.party.
#===============================================================================
class Pokemon
    # @return [Symbol] this Pokémon's species
    attr_reader   :species
    # If defined, this Pokémon's form will be this value even if a MultipleForms
    # handler tries to say otherwise.
    # @return [Integer, nil] this Pokémon's form
    attr_accessor :forced_form
    # If defined, is the time (in Integer form) when this Pokémon's form was set.
    # @return [Integer, nil] the time this Pokémon's form was set
    attr_accessor :time_form_set
    # @return [Integer] the current experience points
    attr_reader   :exp
    # @return [Integer] the number of steps until this Pokémon hatches, 0 if this Pokémon is not an egg
    attr_accessor :steps_to_hatch
    # @return [Integer] the current HP
    attr_reader   :hp
    # @return [Symbol] this Pokémon's current status (see GameData::Status)
    attr_reader   :status
    # @return [Integer] sleep count / toxic flag / 0:
    #   sleep (number of rounds before waking up), toxic (0 = regular poison, 1 = toxic)
    attr_accessor :statusCount
    # This Pokémon's shininess (true, false, nil). Is recalculated if made nil.
    # @param value [Boolean, nil] whether this Pokémon is shiny
    attr_writer   :shiny
    # @return [Array<Pokemon::Move>] the moves known by this Pokémon
    attr_accessor :moves
    # @return [Array<Integer>] the IDs of moves known by this Pokémon when it was obtained
    attr_accessor :first_moves
    # @return [Array<Symbol>] an array of ribbons owned by this Pokémon
    attr_accessor :ribbons
    # @return [Integer] contest stats
    attr_accessor :cool, :beauty, :cute, :smart, :tough, :sheen
    # @return [Integer] this Pokémon's current happiness (an integer between 0 and 255)
    attr_accessor :happiness
    # @return [Symbol] the item ID of the Poké Ball this Pokémon is in
    attr_accessor :poke_ball
    # @return [Integer] this Pokémon's markings, one bit per marking
    attr_accessor :markings
    # @return [Hash<Integer>] a hash of IV values for HP, Atk, Def, Speed, Sp. Atk and Sp. Def
    attr_accessor :iv
    # An array of booleans indicating whether a stat is made to have maximum IVs
    # (for Hyper Training). Set like @ivMaxed[:ATTACK] = true
    # @return [Hash<Boolean>] a hash of booleans that max each IV value
    attr_accessor :ivMaxed
    # @return [Hash<Integer>] this Pokémon's effort values
    attr_accessor :ev
    # @return [Integer] calculated stats
    attr_reader   :totalhp, :attack, :defense, :spatk, :spdef, :speed
    # @return [Owner] this Pokémon's owner
    attr_reader   :owner
    # @return [Integer] the manner this Pokémon was obtained:
    #   0 (met), 1 (as egg), 2 (traded), 4 (fateful encounter)
    attr_accessor :obtain_method
    # @return [Integer] the ID of the map this Pokémon was obtained in
    attr_accessor :obtain_map
    # Describes the manner this Pokémon was obtained. If left undefined,
    # the obtain map's name is used.
    # @return [String] the obtain text
    attr_accessor :obtain_text
    # @return [Integer] the level of this Pokémon when it was obtained
    attr_accessor :obtain_level
    # If this Pokémon hatched from an egg, returns the map ID where the hatching happened.
    # Otherwise returns 0.
    # @return [Integer] the map ID where egg was hatched (0 by default)
    attr_accessor :hatched_map
    # Another Pokémon which has been fused with this Pokémon (or nil if there is none).
    # Currently only used by Kyurem, to record a fused Reshiram or Zekrom.
    # @return [Pokemon, nil] the Pokémon fused into this one (nil if there is none)
    attr_accessor :fused
    # @return [Integer] this Pokémon's personal ID
    attr_accessor :personalID

    attr_accessor :boss
    attr_accessor :hpMult
    attr_accessor :dmgMult
    attr_accessor :dmgResist
    attr_accessor :battlingStreak
    attr_accessor :extraMovesPerTurn
    attr_accessor :bossType
    attr_accessor :itemTypeChosen
    attr_accessor :shiny_variant
    attr_reader :afraid
  
    # Max total IVs
    IV_STAT_LIMIT = 31
    # Max total EVs
    EV_LIMIT      = 50
    # Max EVs that a single stat can have
    EV_STAT_LIMIT = 20
    # Maximum length a Pokémon's nickname can be
    MAX_NAME_SIZE = 10
    # Maximum number of moves a Pokémon can know at once
    MAX_MOVES     = 4
    # How much the pokemon's hue can vary (+/-1)
    HUE_SHIFT_RANGE = 20
    # How much the pokemon's shade can vary (+/-1)
    SHADE_SHIFT_RANGE = 80
  
    def self.play_cry(species, form = 0, volume = 90, pitch = 100)
      GameData::Species.play_cry_from_species(species, form, volume, pitch)
    end
  
    def play_cry(volume = 90, pitch = nil)
      GameData::Species.play_cry_from_pokemon(self, volume, pitch)
    end
  
    def inspect
      str = super.chop
      str << format(' %s Lv.%s>', @species, @level.to_s || '???')
      return str
    end
  
    def species_data
      return GameData::Species.get_species_form(@species, form_simple)
    end
  
    #=============================================================================
    # Species and form
    #=============================================================================
  
    # Changes the Pokémon's species and re-calculates its statistics.
    # @param species_id [Integer] id of the species to change this Pokémon to
    def species=(species_id)
      new_species_data = GameData::Species.get(species_id)
      return if @species == new_species_data.species
      @species     = new_species_data.species
      @form        = new_species_data.form if new_species_data.form != 0
      @forced_form = nil
      @level       = nil   # In case growth rate is different for the new species
      @ability     = nil
      calc_stats
    end
  
    # @param check_species [Integer, Symbol, String] id of the species to check for
    # @return [Boolean] whether this Pokémon is of the specified species
    def isSpecies?(check_species)
      return @species == check_species || (GameData::Species.exists?(check_species) &&
                                          @species == GameData::Species.get(check_species).species)
    end
  
    def form
      return @forced_form if !@forced_form.nil?
      return @form if $game_temp.in_battle
      calc_form = MultipleForms.call("getForm", self)
      self.form = calc_form if calc_form != nil && calc_form != @form
      return @form
    end
  
    def form_simple
      return @forced_form || @form
    end
  
    def form=(value)
      oldForm = @form
      @form = value
      @ability = nil
      MultipleForms.call("onSetForm", self, value, oldForm)
      calc_stats
      $Trainer.pokedex.register(self) if $Trainer
    end
  
    # The same as def form=, but yields to a given block in the middle so that a
    # message about the form changing can be shown before calling "onSetForm"
    # which may have its own messages, e.g. learning a move.
    def setForm(value)
      oldForm = @form
      @form = value
      @ability = nil
      yield if block_given?
      MultipleForms.call("onSetForm", self, value, oldForm)
      calc_stats
      $Trainer.pokedex.register(self)
    end
  
    def form_simple=(value)
      @form = value
      calc_stats
    end
  
    #=============================================================================
    # Level
    #=============================================================================
  
    # @return [Integer] this Pokémon's level
    def level
      @level = growth_rate.level_from_exp(@exp) if !@level
      return @level
    end
  
    # Sets this Pokémon's level. The given level must be between 1 and the
    # maximum level (defined in {GameData::GrowthRate}).
    # @param value [Integer] new level (between 1 and the maximum level)
    def level=(value)
      if value < 1 || value > GameData::GrowthRate.max_level
        raise ArgumentError.new(_INTL("The level number ({1}) is invalid.", value))
      end
      @exp = growth_rate.minimum_exp_for_level(value)
      @level = value
    end
  
    # Sets this Pokémon's Exp. Points.
    # @param value [Integer] new experience points
    def exp=(value)
      @exp = value
      @level = nil
    end
  
    # @return [Boolean] whether this Pokémon is an egg
    def egg?
      return @steps_to_hatch > 0
    end
  
    # @return [GameData::GrowthRate] this Pokémon's growth rate
    def growth_rate
      return GameData::GrowthRate.get(species_data.growth_rate)
    end
  
    # @return [Integer] this Pokémon's base Experience value
    def base_exp
      return species_data.base_exp
    end
  
    # @return [Float] a number between 0 and 1 indicating how much of the current level's
    #   Exp this Pokémon has
    def exp_fraction
      lvl = self.level
      return 0.0 if lvl >= GameData::GrowthRate.max_level
      g_rate = growth_rate
      start_exp = g_rate.minimum_exp_for_level(lvl)
      end_exp   = g_rate.minimum_exp_for_level(lvl + 1)
      return (@exp - start_exp).to_f / (end_exp - start_exp)
    end

    def onHotStreak?
      return @battlingStreak >= 2
    end
  
    #=============================================================================
    # Status
    #=============================================================================
  
    # Sets the Pokémon's health.
    # @param value [Integer] new HP value
    def hp=(value)
      @hp = value.clamp(0, @totalhp)
      heal_status if @hp == 0
    end
  
    # Sets this Pokémon's status. See {GameData::Status} for all possible status effects.
    # @param value [Integer, Symbol, String] status to set
    def status=(value)
      return if !able?
      new_status = GameData::Status.try_get(value)
      if !new_status
        raise ArgumentError, _INTL('Attempted to set {1} as Pokémon status', value.class.name)
      end
      @status = new_status.id
    end
  
    # @return [Boolean] whether the Pokémon is not fainted and not an egg
    def able?
      return !egg? && @hp > 0
    end
  
    # @return [Boolean] whether the Pokémon is fainted
    def fainted?
      return !egg? && @hp <= 0 || @afraid
    end
  
    # Heals all HP of this Pokémon.
    def heal_HP
      return if egg?
      @hp = @totalhp
    end

	# Heals this Pokemon's HP by an amount
    def healBy(amount)
        return if egg?
        @hp += amount
        @hp = @totalhp if @hp > @totalhp
    end

    # Heals this Pokemon's HP by a fraction of its maximum
    def healByFraction(fraction)
        healBy((@totalhp * fraction).ceil)
    end
  
    # Heals the status problem of this Pokémon.
    def heal_status
      return if egg?
      @status      = :NONE
      @statusCount = 0
    end
  
    # Restores all PP of this Pokémon. If a move index is given, restores the PP
    # of the move in that index.
    # @param move_index [Integer] index of the move to heal (-1 if all moves
    #   should be healed)
    def heal_PP(move_index = -1)
      return if egg?
      if move_index >= 0
        @moves[move_index].pp = @moves[move_index].total_pp
      else
        @moves.each { |m| m.pp = m.total_pp }
      end
    end
  
    # Heals all HP, PP, and status problems of this Pokémon.
    def heal
      return if egg?
      heal_HP
      heal_status
      heal_PP
      @afraid = false
    end

    def afraid?
      return @afraid
    end

    def becomeAfraid
      @afraid = true
      @status = :NONE
      @statusCount = 0
    end

    def removeFear(battle = nil)
      @afraid = false
      @hp = (@totalhp / 2).floor
      message = _INTL("#{name} is no longer Afraid. It was restored to half health!")
      if battle
        battle.pbDisplay(message)
      else
        pbMessage(message)
      end
    end
  
    #=============================================================================
    # Types
    #=============================================================================
  
    # @return [Symbol] this Pokémon's first type
    def type1
      return species_data.type1
    end
  
    # @return [Symbol] this Pokémon's second type, or the first type if none is defined
    def type2
      sp_data = species_data
      return sp_data.type2 || sp_data.type1
    end
  
    # @return [Array<Symbol>] an array of this Pokémon's types
    def types
      sp_data = species_data
      ret = [sp_data.type1]
      ret.push(sp_data.type2) if sp_data.type2 && sp_data.type2 != sp_data.type1
      return ret
    end
  
    # @param type [Symbol, String, Integer] type to check
    # @return [Boolean] whether this Pokémon has the specified type
    def hasType?(type)
      type = GameData::Type.get(type).id
      return self.types.include?(type)
    end
  
    #=============================================================================
    # Gender
    #=============================================================================
  
    # @return [0, 1, 2] this Pokémon's gender (0 = male, 1 = female, 2 = genderless)
    def gender
      return 2 if boss?
      unless @gender
          gender_ratio = species_data.gender_ratio
          case gender_ratio
          when :AlwaysMale   then @gender = 0
          when :AlwaysFemale then @gender = 1
          when :Genderless   then @gender = 2
          else
              female_chance = GameData::GenderRatio.get(gender_ratio).female_chance
              @gender = ((@personalID & 0xFF) < female_chance) ? 1 : 0
          end
      end
      return @gender
    end

    # Sets this Pokémon's gender to a particular gender (if possible).
    # @param value [0, 1] new gender (0 = male, 1 = female)
    def gender=(value)
      return if singleGendered?
      @gender = value if value.nil? || value == 0 || value == 1
    end
  
    # Makes this Pokémon male.
    def makeMale; self.gender = 0; end
  
    # Makes this Pokémon female.
    def makeFemale; self.gender = 1; end
  
    # @return [Boolean] whether this Pokémon is male
    def male?; return self.gender == 0; end
  
    # @return [Boolean] whether this Pokémon is female
    def female?; return self.gender == 1; end
  
    # @return [Boolean] whether this Pokémon is genderless
    def genderless?; return self.gender == 2; end
  
    # @return [Boolean] whether this Pokémon species is restricted to only ever being one
    #   gender (or genderless)
    def singleGendered?
      gender_ratio = species_data.gender_ratio
      return [:AlwaysMale, :AlwaysFemale, :Genderless].include?(gender_ratio)
    end
  
    #=============================================================================
    # Shininess
    #=============================================================================
  
    # @return [Boolean] whether this Pokémon is shiny (differently colored)
    def shiny?
      if @shiny.nil?
        a = @personalID ^ @owner.id
        b = a & 0xFFFF
        c = (a >> 16) & 0xFFFF
        d = b ^ c
        @shiny = d < Settings::SHINY_POKEMON_CHANCE
      end
      return @shiny
    end
  
    #=============================================================================
    # Ability
    #=============================================================================
  
    # @return [Integer] the index of this Pokémon's ability
    def ability_index
      @ability_index = (@personalID & 1) if !@ability_index
      return @ability_index
    end

    # The index of this Pokémon's ability (0, 1 are natural abilities, 2+ are
    # hidden abilities)as defined for its species/form. An ability may not be
    # defined at this index. Is recalculated (as 0 or 1) if made nil.
    # @param value [Integer, nil] forced ability index (nil if none is set)
    def ability_index=(value)
      @ability_index = value
      recalculateAbilityFromIndex
      removeInvalidItems
    end
  
    # @return [GameData::Ability, nil] an Ability object corresponding to this Pokémon's ability
    def ability
      return GameData::Ability.try_get(ability_id)
    end
  
    # @return [Symbol, nil] the ability symbol of this Pokémon's ability
    def ability_id
      recalculateAbilityFromIndex if @ability.nil?
      return @ability
    end

    def recalculateAbilityFromIndex
      sp_data = species_data
      abil_index = ability_index
      if abil_index >= 2   # Hidden ability
        @ability = sp_data.hidden_abilities[abil_index - 2]
      else
        @ability = sp_data.abilities[abil_index] || sp_data.abilities[0]
      end
    end
  
    def ability=(value)
      return if value && !GameData::Ability.exists?(value)
      if value.nil?
        recalculateAbilityFromIndex
        removeInvalidItems
      else
        @ability = GameData::Ability.get(value).id
        removeInvalidItems
      end
    end
  
    # Returns whether this Pokémon has a particular ability. If no value
    # is given, returns whether this Pokémon has an ability set.
    # @param check_ability [Symbol, GameData::Ability, Integer, nil] ability ID to check
    # @return [Boolean] whether this Pokémon has a particular ability or
    #   an ability at all
    def hasAbility?(check_ability = nil)
      current_ability = self.ability
      return !current_ability.nil? if check_ability.nil?
      return current_ability == check_ability
    end
  
    # @return [Boolean] whether this Pokémon has a hidden ability
    def hasHiddenAbility?
      return ability_index >= 2
    end
  
    # @return [Array<Array<Symbol,Integer>>] the abilities this Pokémon's species can have,
    #   where every element is [ability ID, ability index]
    def getAbilityList
      ret = []
      sp_data = species_data
      sp_data.abilities.each_with_index { |a, i| ret.push([a, i]) if a }
      sp_data.hidden_abilities.each_with_index { |a, i| ret.push([a, i + 2]) if a }
      return ret
    end

	  def addExtraAbility(ability)
        @extraAbilities.push(ability) unless @extraAbilities.include?(ability)
    end

    def extraAbilities
        @extraAbilities = [] if @extraAbilities.nil?
        return @extraAbilities
    end
  
    #=============================================================================
    # Nature
    #=============================================================================
  
    # @return [GameData::Nature, nil] a Nature object corresponding to this Pokémon's nature
    def nature
      @nature = GameData::Nature.get(0).id # ALWAYS RETURN NEUTRAL
      return GameData::Nature.try_get(@nature)
    end
  
    def nature_id
      return @nature
    end
  
    # Sets this Pokémon's nature to a particular nature.
    # @param value [Symbol, String, Integer, nil] nature to change to
    def nature=(value)
      return if value && !GameData::Nature.exists?(value)
      @nature = (value) ? GameData::Nature.get(value).id : value
      calc_stats if !@nature_for_stats
    end
  
    # Returns the calculated nature, taking into account things that change its
    # stat-altering effect (i.e. Gen 8 mints). Only used for calculating stats.
    # @return [GameData::Nature, nil] this Pokémon's calculated nature
    def nature_for_stats
      return GameData::Nature.try_get(@nature_for_stats) if @nature_for_stats
      return self.nature
    end
  
    def nature_for_stats_id
      return @nature_for_stats
    end
  
    # If defined, this Pokémon's nature is considered to be this when calculating stats.
    # @param value [Integer, nil] ID of the nature to use for calculating stats
    def nature_for_stats=(value)
      return if value && !GameData::Nature.exists?(value)
      @nature_for_stats = (value) ? GameData::Nature.get(value).id : value
      calc_stats
    end
  
    # Returns whether this Pokémon has a particular nature. If no value is given,
    # returns whether this Pokémon has a nature set.
    # @param check_nature [Integer] nature ID to check
    # @return [Boolean] whether this Pokémon has a particular nature or a nature
    #   at all
    def hasNature?(check_nature = nil)
      return !@nature_id.nil? if check_nature.nil?
      return self.nature == check_nature
    end
  
    #=============================================================================
    # Items
    #============================================================================
    def items
      if @items.nil?
        @items = []
        @items.push(@item) if @item
      end
      @items.compact!
      return @items
    end

    def itemCount
      return items.length
    end

    def itemCountD(uppercase = false)
      if items.length <= 1
          return uppercase ? "Item" : "item"
      else
          return uppercase ? "Items" : "items"
      end
    end

    def itemsName
      itemName = ""
      items.each_with_index do |item, index|
        itemName += ", " unless index == 0
        itemName += getItemName(item)
      end
      return itemName
    end

    def firstItem
      return nil if items.empty?
      return items[0]
    end

    def firstItemData
      return GameData::Item.try_get(firstItem)
    end
  
    # Gives an item to this Pokémon to hold.
    # @param value [Symbol, GameData::Item, Integer, nil] ID of the item to give
    #   to this Pokémon
    def setItems(value)
      @items = value.is_a?(Array) ? value : [value]
    end

    def giveItem(value)
      items.push(value)
    end

    def removeItem(item)
      itemIndex = items.index(item)
      unless itemIndex
          raise _INTL("Error: Asked to remove item #{item} from Pokemon #{name}, but it doesn't have that item")
      end
      items.delete_at(itemIndex)
    end

    def removeItems
      @items = []
    end
  
    # Returns whether this Pokémon is holding an item. If an item id is passed,
    # returns whether the Pokémon is holding that item.
    # @param check_item [Symbol, GameData::Item, Integer] item ID to check
    # @return [Boolean] whether the Pokémon is holding the specified item or
    #   an item at all
    def hasItem?(check_item = nil)
      return !@items.empty? if check_item.nil?
      return items.include?(check_item)
    end
  
    # @return [Array<Symbol>] the items this species can be found holding in the wild
    def wildHoldItems
      sp_data = species_data
      return [sp_data.wild_item_common, sp_data.wild_item_uncommon, sp_data.wild_item_rare]
    end
    
    # The type chosen for items like Memory Set or Prismatic Plate which can be
    # customized depending on the pokemon
    def itemTypeChosen
        @itemTypeChosen = :NORMAL if @itemTypeChosen.nil?
        return @itemTypeChosen
    end

    def canSetItemType?
        return true if hasItem?(:MEMORYSET)
        return true if hasItem?(:PRISMATICPLATE)
        return true if hasItem?(:CRYSTALVEIL)
        return false
    end

    def canHaveMultipleItems?(inBattle = false)
      return true if @ability == :STICKYFINGERS && inBattle
      return GameData::Ability::MULTI_ITEM_ABILITIES.include?(@ability)
    end

	  def canHaveItem?(itemCheck = nil, showMessages = false)
        return true if firstItem.nil?
        return false unless canHaveMultipleItems?
        return true if itemCheck.nil?
        theoreticalItems = items.clone.push(itemCheck)
        return legalItems?(theoreticalItems, showMessages)
    end

    def legalItems?(itemSet, showMessages = false)
      if itemSet.include?(:CRYSTALVEIL) && hasAbility?(:WONDERGUARD)
        pbMessage(_INTL("#{name} can't hold a #{getItemName(:CRYSTALVEIL)}!")) if showMessages
        return false
      end
      return true unless itemSet.length > 1

      # Item set contains duplicates
      if itemSet.length != itemSet.uniq.length
        pbMessage(_INTL("#{name} can't hold two of the same item!")) if showMessages
        return false
      end

      if GameData::Ability::MULTI_ITEM_ABILITIES.include?(@ability) && itemSet.length > 2
        pbMessage(_INTL("#{name} can't hold more than two items!")) if showMessages
        return false
      end

      # All That Glitters
      if @ability == :ALLTHATGLITTERS
          allGems = true
          itemSet.each do |item|
              next if GameData::Item.get(item).is_gem?
              allGems = false
              break
          end
          unless allGems
              pbMessage(_INTL("For #{name} to have two items, both must be Gems!")) if showMessages
              return false
          end
          return true
      end

      # Berry Bunch
      if @ability == :BERRYBUNCH
          allBerries = true
          itemSet.each do |item|
              next if GameData::Item.get(item).is_berry?
              allBerries = false
              break
          end
          unless allBerries
              pbMessage(_INTL("For #{name} to have two items, both must be Berries!")) if showMessages
              return false
          end
          return true
      end

      # Herbalist
      if @ability == :HERBALIST
        allHerbs = true
        itemSet.each do |item|
            next if HERB_ITEMS.include?(item)
            allHerbs = false
            break
        end
        unless allHerbs
            pbMessage(_INTL("For #{name} to have two items, both must be Herbs!")) if showMessages
            return false
        end
        return true
      end

      # Fashionable
      if @ability == :FASHIONABLE
          clothingCount = 0
          itemSet.each do |item|
              next unless CLOTHING_ITEMS.include?(item)
              clothingCount += 1
          end
          if clothingCount == 0
              pbMessage(_INTL("For #{name} to have two items, at least one must be Clothing!")) if showMessages
              return false
          end
          if clothingCount > 1
              pbMessage(_INTL("For #{name} to have two items, only one can be Clothing!")) if showMessages
              return false
          end
          return true
      end

      # Klumsy Kinesis
      return true if @ability == :KLUMSYKINESIS
    end

    def removeInvalidItems
        return unless items
        return if legalItems?(items, ownedByPlayer?)
        if ownedByPlayer?
          pbMessage(_INTL("#{name} is no longer allowed to hold its current items."))
          if boss?
            removeItems
          else
            pbTakeItemsFromPokemon(self)
          end
        else
          removeItems
        end
    end

    def hasMultipleItems?
        return items.length > 1
    end
  
    #=============================================================================
    # Moves
    #=============================================================================
  
    # @return [Integer] the number of moves known by the Pokémon
    def numMoves
      return @moves.length
    end
  
    # @param move_id [Symbol, String, Integer] ID of the move to check
    # @return [Boolean] whether the Pokémon knows the given move
    def hasMove?(move_id)
      move_data = GameData::Move.try_get(move_id)
      return false if !move_data
      return @moves.any? { |m| m.id == move_data.id }
    end
  
    # Returns the list of moves this Pokémon can learn by levelling up.
    # @return [Array<Array<Integer,Symbol>>] this Pokémon's move list, where every element is [level, move ID]
    def getMoveList
      return species_data.moves
    end
  
    # Reset the pokemon's moveset to what a wild pokemon would have at the given level
    def reset_moves(assignedLevel=-1,forceSignatures=false)
      if assignedLevel == -1
        assignedLevel = self.level
      end
      # Find all level-up moves that self could have learned
      moveset = self.getMoveList
      knowable_moves = []
      signature_moves = []
      moveset.each { |m| 
        moveID = m[1]
        moveData = GameData::Move.get(moveID)
        # Forces signature moves if they're learnable by the pokemon's level
        if moveData.is_signature? && forceSignatures && m[0] <= self.level
          signature_moves.push(moveID)
        # Allows other moves only if they're learnable by the given level (which is still usually the pokemon's level)
        elsif m[0] <= assignedLevel
          knowable_moves.push(moveID)
        end
      }
      # Remove duplicates (retaining the latest copy of each move)
      knowable_moves = knowable_moves.concat(signature_moves)
      knowable_moves = knowable_moves.reverse
      knowable_moves |= []
      knowable_moves = knowable_moves.reverse
      # Add all moves
      @moves.clear
      first_move_index = knowable_moves.length - MAX_MOVES
      first_move_index = 0 if first_move_index < 0
      for i in first_move_index...knowable_moves.length
        @moves.push(Pokemon::Move.new(knowable_moves[i]))
      end
    end
  
    # Silently learns the given move. Will erase the first known move if it has to.
    # @param move_id [Symbol, String, Integer] ID of the move to learn
    def learn_move(move_id, ignoreMax = false)
      move_data = GameData::Move.try_get(move_id)
      return unless move_data
      # Check if self already knows the move; if so, move it to the end of the array
      @moves.each_with_index do |m, i|
          next if m.id != move_data.id
          @moves.push(m)
          @moves.delete_at(i)
          return
      end
      # Move is not already known; learn it
      @moves.push(Pokemon::Move.new(move_data.id))
      # Delete the first known move if self now knows more moves than it should
      @moves.shift if numMoves > MAX_MOVES && !ignoreMax
  end
  
    # Deletes the given move from the Pokémon.
    # @param move_id [Symbol, String, Integer] ID of the move to delete
    def forget_move(move_id)
      move_data = GameData::Move.try_get(move_id)
      return if !move_data
      @moves.delete_if { |m| m.id == move_data.id }
    end
  
    # Deletes the move at the given index from the Pokémon.
    # @param index [Integer] index of the move to be deleted
    def forget_move_at_index(index)
      @moves.delete_at(index)
    end
  
    # Deletes all moves from the Pokémon.
    def forget_all_moves
      @moves.clear
    end
  
    # Copies currently known moves into a separate array, for Move Relearner.
    def record_first_moves
      clear_first_moves
      @moves.each { |m| @first_moves.push(m.id) }
    end
  
    # Adds a move to this Pokémon's first moves.
    # @param move_id [Symbol, String, Integer] ID of the move to add
    def add_first_move(move_id)
      move_data = GameData::Move.try_get(move_id)
      @first_moves.push(move_data.id) if move_data && !@first_moves.include?(move_data.id)
    end
  
    # Removes a move from this Pokémon's first moves.
    # @param move_id [Symbol, String, Integer] ID of the move to remove
    def remove_first_move(move_id)
      move_data = GameData::Move.try_get(move_id)
      @first_moves.delete(move_data.id) if move_data
    end
  
    # Clears this Pokémon's first moves.
    def clear_first_moves
      @first_moves.clear
    end
  
    # @param move_id [Symbol, String, Integer] ID of the move to check
    # @return [Boolean] whether the Pokémon is compatible with the given move
    def compatible_with_move?(move_id)
      move_data = GameData::Move.try_get(move_id)
      return false if move_data.nil?
      return learnable_moves.include?(move_data.id)
    end

    # def can_relearn_move?
    #   return false if egg?
    #   this_level = self.level
    #   getMoveList.each { |m| return true if m[0] <= this_level && !hasMove?(m[1]) }
    #   @first_moves.each { |m| return true if !pkmn.hasMove?(m) }
    #   return false
    # end
  
    #=============================================================================
    # Ribbons
    #=============================================================================
  
    # @return [Integer] the number of ribbons this Pokémon has
    def numRibbons
      return @ribbons.length
    end
  
    # @param ribbon [Symbol, String, GameData::Ribbon, Integer] ribbon ID to check for
    # @return [Boolean] whether this Pokémon has the specified ribbon
    def hasRibbon?(ribbon)
      ribbon_data = GameData::Ribbon.try_get(ribbon)
      return ribbon_data && @ribbons.include?(ribbon_data.id)
    end
  
    # Gives a ribbon to this Pokémon.
    # @param ribbon [Symbol, String, GameData::Ribbon, Integer] ID of the ribbon to give
    def giveRibbon(ribbon)
      ribbon_data = GameData::Ribbon.try_get(ribbon)
      return if !ribbon_data || @ribbons.include?(ribbon_data.id)
      @ribbons.push(ribbon_data.id)
    end
  
    # Replaces one ribbon with the next one along, if possible. If none of the
    # given ribbons are owned, give the first one.
    # @return [Symbol, nil] ID of the ribbon that was gained
    def upgradeRibbon(*arg)
      for i in 0...arg.length - 1
        this_ribbon_data = GameData::Ribbon.try_get(i)
        next if !this_ribbon_data
        for j in 0...@ribbons.length
          next if @ribbons[j] != this_ribbon_data.id
          next_ribbon_data = GameData::Ribbon.try_get(arg[i + 1])
          next if !next_ribbon_data
          @ribbons[j] = next_ribbon_data.id
          return @ribbons[j]
        end
      end
      first_ribbon_data = GameData::Ribbon.try_get(arg[0])
      last_ribbon_data = GameData::Ribbon.try_get(arg[arg.length - 1])
      if first_ribbon_data && last_ribbon_data && !hasRibbon?(last_ribbon_data.id)
        giveRibbon(first_ribbon_data.id)
        return first_ribbon_data.id
      end
      return nil
    end
  
    # Removes the specified ribbon from this Pokémon.
    # @param ribbon [Symbol, String, GameData::Ribbon, Integer] ID of the ribbon to remove
    def takeRibbon(ribbon)
      ribbon_data = GameData::Ribbon.try_get(ribbon)
      return if !ribbon_data
      for i in 0...@ribbons.length
        next if @ribbons[i] != ribbon_data.id
        @ribbons[i] = nil
        @ribbons.compact!
        break
      end
    end
  
    # Removes all ribbons from this Pokémon.
    def clearAllRibbons
      @ribbons.clear
    end
  
    #=============================================================================
    # Ownership, obtained information
    #=============================================================================
  
    # Changes this Pokémon's owner.
    # @param new_owner [Owner] the owner to change to
    def owner=(new_owner)
      validate new_owner => Owner
      @owner = new_owner
    end
  
    # @param trainer [Player, NPCTrainer] the trainer to compare to the original trainer
    # @return [Boolean] whether the given trainer is not this Pokémon's original trainer
    def foreign?(trainer)
      return @owner.id != trainer.id || @owner.name != trainer.name
    end
  
    # @return [Time] the time when this Pokémon was obtained
    def timeReceived
      return Time.at(@timeReceived)
    end
  
    # Sets the time when this Pokémon was obtained.
    # @param value [Integer, Time, #to_i] time in seconds since Unix epoch
    def timeReceived=(value)
      @timeReceived = value.to_i
    end
  
    # @return [Time] the time when this Pokémon hatched
    def timeEggHatched
      return (obtain_method == 1) ? Time.at(@timeEggHatched) : nil
    end
  
    # Sets the time when this Pokémon hatched.
    # @param value [Integer, Time, #to_i] time in seconds since Unix epoch
    def timeEggHatched=(value)
      @timeEggHatched = value.to_i
    end
  
    #=============================================================================
    # Other
    #=============================================================================
  
    # @return [String] the name of this Pokémon
    def name
      return (nicknamed?) ? @name : speciesName
    end
  
    # @param value [String] the nickname of this Pokémon
    def name=(value)
      value = nil if !value || value.empty? || value == speciesName
      @name = value
    end
  
    # @return [Boolean] whether this Pokémon has been nicknamed
    def nicknamed?
      return @name && !@name.empty?
    end
  
    # @return [String] the species name of this Pokémon
    def speciesName
      return species_data.name
    end
  
    # @return [Integer] the height of this Pokémon in decimetres (0.1 metres)
    def height
      return species_data.height
    end
  
    # @return [Integer] the weight of this Pokémon in hectograms (0.1 kilograms)
    def weight
      return species_data.weight
    end
  
    # @return [Hash<Integer>] the EV yield of this Pokémon (a hash with six key/value pairs)
    def evYield
      this_evs = species_data.evs
      ret = {}
      GameData::Stat.each_main { |s| ret[s.id] = this_evs[s.id] }
      return ret
    end

    #=============================================================================
    # Happiness, traits, and likes/dislikes
    #=============================================================================
  
    PERSONALITY_THRESHOLD_ONE = 50
    PERSONALITY_THRESHOLD_TWO = 150
    PERSONALITY_THRESHOLD_THREE = 200
    PERSONALITY_THRESHOLD_FOUR = 255

    attr_writer :Trait1
    attr_writer :Trait2
    attr_writer :Trait3
    attr_writer :Like
    attr_writer :Dislike

    TRAITS =
    [
      "Abrasive",
      "Absentminded",
      "Adorable",
      "Adventurous",
      "Aggressive",
      "Allocentric",
      "Amiable",
      "Alert",
      "Aloof",
      "Ambitious",
      "Anxious",
      "Apathetic",
      "Artistic",
      "Ascetic",
      "Athletic",
      "Boastful",
      "Bossy",
      "Brooding",
      "Callous",
      "Caring",
      "Careless",
      "Chatterbox",
      "Cheerful",
      "Clever",
      "Clumsy",
      "Collector",
      "Composed",
      "Compassionate",
      "Conciliatory",
      "Confident",
      "Conformist",
      "Considerate",
      "Courageous",
      "Courteous",
      "Curious",
      "Cowardly",
      "Cynical",
      "Debonair",
      "Decadent",
      "Deceitful",
      "Dedicated",
      "Dignified",
      "Disciplined",
      "Dramatic",
      "Dull",
      "Earnest",
      "Elegant",
      "Energetic",
      "Enigmatic",
      "Esthetic",
      "Fickle",
      "Forgetful",
      "Forthright",
      "Fretful",
      "Friendly",
      "Frugal",
      "Funny",
      "Gallant",
      "Generous",
      "Go-getter",
      "Gracious",
      "Gullible",
      "High-minded",
      "Honest",
      "Hopeful",
      "Humble",
      "Imaginative",
      "Impressionable",
      "Independent",
      "Innocent",
      "Intense",
      "Inviting",
      "Irritable",
      "Judgey",
      "Kind",
      "Kleptomaniac",
      "Leaderly",
      "Logical",
      "Lucky",
      "Loyal",
      "Magnanimous",
      "Masochistic",
      "Meek",
      "Melancholic",
      "Meticulous",
      "Money-minded",
      "Obnoxious",
      "Observant",
      "Open Book",
      "Optimistic",
      "Partier",
      "Patient",
      "Pedantic",
      "Petty",
      "Petulant",
      "Perfectionist",
      "Persistent",
      "Pompous",
      "Practical",
      "Pretentious",
      "Profound",
      "Protective",
      "Reflective",
      "Reliable",
      "Reserved",
      "Rogueish",
      "Rowdy",
      "Sadistic",
      "Sarcastic",
      "Sardonic",
      "Secretive",
      "Sedentary",
      "Self-conscious",
      "Self-effacing",
      "Selfless",
      "Sentimental",
      "Showy",
      "Shy",
      "Slob",
      "Snide",
      "Sociable",
      "Spontaneous",
      "Steadfast",
      "Stoic",
      "Studious",
      "Subtle",
      "Superstitious",
      "Sweettooth",
      "Sycophant",
      "Teacherly",
      "Tidy",
      "Tinkerer",
      "Trusting",
      "Urbane",
      "Vindictive",
      "Whimsical",
      "Witty"
    ]

    def trait1
      return nil if @happiness < PERSONALITY_THRESHOLD_ONE
      while @Trait1.nil? || @Trait1 == @Trait2 || @Trait1 == @Trait3
        @Trait1 = TRAITS.sample
      end
      return @Trait1
    end
      
    def trait2
        return nil if @happiness < PERSONALITY_THRESHOLD_TWO
      while @Trait2.nil? || @Trait2 == @Trait1 || @Trait2 == @Trait3
        @Trait2 = TRAITS.sample
      end
      return @Trait2
    end
      
    def trait3
      return nil if @happiness < PERSONALITY_THRESHOLD_THREE
      while @Trait3.nil? || @Trait3 == @Trait1 || @Trait3 == @Trait2
        @Trait3 = TRAITS.sample
      end
      return @Trait3
    end
	
	  LIKES = [
				"Scary Movies",
				"Berries",
				"Beach Walks",
				"Swimming",
				"Stories",
				"Camping",
				"Breezes",
				"Beach Trips",
				"Comedy Movies",
				"EDM",
				"Introspection",
				"Spicy Food",
				"Soda",
				"Hiking",
				"Paintings",
				"People Watching",
				"Bike Rides",
				"Languages",
				"Fishing",
				"Gardening",
				"Dumpster Diving",
				"Judo",
				"Shopping",
				"Fashion",
				"Jogging",
				"Card Games",
				"Video Games",
				"Computers",
				"Math",
				"Chemistry",
				"Documentaries",
				"History",
				"Rainy Days",
				"Tightropes",
				"Astronomy",
				"Horoscopes",
				"Tree Climbing",
				"Meditation",
				"Acrobatics",
				"Cakes",
				"Ice Cream",
				"Expensive Food",
				"Cooking",
				"Baking",
				"Action Movies",
				"Lo-Fi",
				"Rock Music",
				"Rocks",
				"Snow",
				"Exercise",
				"Marathons",
				"Weightlifting",
				"Heavy Metal",
				"Coffee",
				"Iced Lattes",
				"Hot Cocao",
				"Chocolate Milk",
				"Flowers",
				"Avant-garde",
				"Novelty",
				"Routines",
				"Yoga",
				"The Occult",
				"Skiing",
				"Plays",
				"Fireworks",
				"Salsa",
				"Naps",
				"Pizza",
				"Jigsaw Puzzles",
				"Firemaking",
				"Following You",
				"Taking Pictures",
				"Attention",
				"Being Spoiled",
				"Parkour",
				"Destruction",
				"Pottery",
				"Weaving",
				"Reality TV",
				"Tournament Arcs",
				"Competition",
				"Banter",
				"Cleaning",
				"Milkshakes",
				"Chess",
				"Sewers",
				"Silence",
				"Opera",
				"Fencing",
				"Woodworking",
				"Dolls",
				"Drawing",
				"Jewelry",
				"Origami",
				"Poetry",
				"Coding",
				"Tarot",
				"Surfing",
				"Dancing",
				"Skiing",
				"Gymnastics",
				"Skating",
				"Photography",
				"Streams",
				"Singing",
				"Bowling",
				"Graffiti",
				"Magic Tricks",
				"Juggling",
				"Skydiving",
				"Bungee Jumping",
				"Salads",
				"Lemonade",
				"Puns",
				"Mushrooms",
				"Punk Rock",
				"Opera",
				"Knitting",
				"Data Analytics",
				"Cartography",
				"Acting",
				"Sewing",
				"Carpentry",
				"Glassblowing",
				"Art",
				"Literature",
				"Writing",
				"Paintings",
				"Architecture",
				"Reading",
				"Football",
				"Gambling",
				"Chaos",
				"Hugs",
				"Cartoons",
				"Comics",
				"Donuts",
				"Fresh Water",
				"Neon Lights",
				"Geology",
				"Rock Collecting",
				"Gemstones",
				"Vaporwave",
				"Trains",
				"Acroyoga",
				"Aquascaping",
				"Beatboxing",
				"Bonsai",
				"Campanology",
				"Board Games",
				"Art Restoration",
				"Breadmaking",
				"Journaling",
				"Scrapbooking",
				"Theorycrafting",
				"Cheesemaking",
				"Conlanging",
				"Cosplaying",
				"Cryptography",
				"Crosswords",
				"Sudoku",
				"Decorating",
				"DJing",
				"Electronics",
				"Engraving",
				"Fantasy Sports",
				"Embroidery",
				"Tea Ceremonies",
				"Hacking",
				"Hairstyling",
				"Cosmology",
				"Lapidary",
				"Lock Picking",
				"Philately",
				"Postcrossing",
				"Proverbs",
				"Pyrography",
				"Editing",
				"Puppetry",
				"Quilling",
				"Quilting",
				"Jump Rope",
				"Soapmaking",
				"Speedrunning",
				"Spreadsheets",
				"Tarot",
				"Tattoos",
				"Wargaming",
				"Watch Making",
				"Yo-yoing",
				"Beachcombing",
				"BMX",
				"Croquet",
				"Basketball",
				"Spelunking",
				"Foraging",
				"Geocaching",
				"LARPing",
				"Kites",
				"Meteorology",
				"Museums",
				"Sledding",
				"Survivalism",
				"Stone Skipping",
				"Ping-pong",
				"Topiary",
				"Tourism",
				"Volleyball",
				"Archaeology",
				"Botany",
				"Biology",
				"Mycology",
				"Aerospace",
				"Social Studies",
				"Philosophy",
				"Action Figures",
				"Pins",
				"Perfumes",
				"Sneakers",
				"Antiques",
				"Rock Balancing",
				"Seashells",
				"Air Hockey",
				"Backgammon",
				"Badminton",
				"Billiards",
				"Bridges",
				"Color Guard",
				"Curling",
				"Go",
				"Word Games",
				"Mahjong",
				"Marbles",
				"Pinball",
				"Shogi",
				"Speedcubing",
				"Baseball",
				"Disc Golf",
				"Golf",
				"Figure Skating",
				"Lacrosse",
				"Skateboarding",
				"Longboarding",
				"Pickleball",
				"Monster Trucks",
				"Roller Derby",
				"Rugby",
				"Softball",
				"Triathlons",
				"Microscopy",
				"SWLing",
				"Wailord Watching",
				"ASMR",
				"Selfies",
				"Boba",
				"Arson",
				"Hacking",
				"Going Fast",
				"Tax Evasion",
				"Investing",
				"Stocks",
				"Power Tools",
				"Machines",
				"Heavy Machinery",
				"Radios",
				"Classical Music",
				"Anime",
				"Rom-coms",
				"Camp Style",
				"Cabaret",
				"Typewriters",
				"Techwear",
				"Rap",
				"Hip Hop",
				"Jazz",
				"Ballet",
				"Tennis",
				"Racecars",
				"Drift Phonk",
				"Breakcore",
				"Podcasts",
				"Crime Stories",
				"Dubstep",
				"Disco",
				"Castles",
				"Cafes",
				"Tea",
				"Circuit Boards",
				"Retro Items",
				"E-textiles",
				"RGB Lights",
				"Social Media",
				"Light Festivals",
				"Carnivals",
				"Parades",
				"Tattoos",
				"Hype",
				"Sandwiches",
				"Nature",
				"Ponds",
				"Waterfalls",
				"White Noise",
				"Calm Music",
				"Massage Chairs"
			]

    def like
      return nil if @happiness < PERSONALITY_THRESHOLD_FOUR
      while @Like.nil? || @Like == @Dislike
        @Like = LIKES.sample
      end
      return @Like
    end
	
	  DISLIKES = [
					"Scary Movies",
					"Petting",
					"Loud Noises",
					"Smalltalk",
					"Directions",
					"Introspection",
					"Sour Food",
					"Bitter Coffee",
					"Sweet Coffee",
					"The Vet",
					"Pollen",
					"Tight Spaces",
					"Crowds",
					"Commuting",
					"Hiking",
					"Idleness",
					"Sad Stories",
					"Heights",
					"Storms",
					"Hot Days",
					"Cold Days",
					"The Dark",
					"Thunder",
					"Defeatists",
					"Babies",
					"Forests",
					"Sand",
					"Exercise",
					"Babysitting",
					"Loud Cars",
					"Responsibility",
					"Cleaning",
					"Spicy Food",
					"Soda",
					"Loud Music",
					"Cooking",
					"Snow",
					"Exercise",
					"Routines",
					"Fireworks",
					"Attention",
					"Being Spoiled",
					"Slow Internet",
					"Loud Eaters",
					"Chalkboards",
					"Open Ocean",
					"Boats",
					"Chores",
					"Snitches",
					"Authority",
					"Mornings",
					"Change",
					"Dieting",
					"Introductions",
					"Silence",
					"Eye Contact",
					"Vandalism",
					"Wastefulness",
					"Homework",
					"Small Spaces",
					"Clowns",
					"Being Tickled",
					"One-uppers",
					"Ads",
					"Mayonnaise",
					"Reality TV",
					"Avocados",
					"Tomatos",
					"Pineapples",
					"Cilantro",
					"Mustard",
					"Celebrities",
					"Peanut Butter",
					"B-O",
					"Jelly",
					"Dentists",
					"Open Spaces",
					"The Abraporter",
					"Isolation",
					"Needles",
					"Mirrors",
					"Cemeteries",
					"Embarrassment",
					"Airplanes",
					"Weight Gain",
					"Medicine",
					"Being Watched",
					"Public Speaking",
					"Balloons",
					"Peanut Butter",
					"Cinnamon",
					"Cilantro",
					"Okra",
					"Pickles",
					"Turnips",
					"Waking Up",
					"Copyright",
					"Taxes",
					"Nerds",
					"Pop Music",
					"Anime",
					"Exams",
					"Mondays"
				]

    def dislike
      return nil if happiness < PERSONALITY_THRESHOLD_FOUR
      while @Dislike.nil? || @Dislike == @Like
        @Dislike = DISLIKES.sample
      end
      return @Dislike
    end
    
    # Changes the happiness of this Pokémon depending on what happened to change it.
    # @param method [String] the happiness changing method (e.g. 'walking')
    def changeHappiness(method)
      @happiness = @happiness.clamp(0, MAX_HAPPINESS)

      gain = 0
      case method
      when "walking"
        gain = 1
      when "levelup"
        gain = 3
      when "evolution"
        gain = 15
      when "groom"
        gain = 8
      when "machine", "battleitem"
        gain = 1
      end

      if gain > 0
        gain = gain * 2 if @poke_ball == :LUXURYBALL
        gain = gain * 2 if hasItem?(:SOOTHEBELL)
      end

      prevHappiness = @happiness
      @happiness = (@happiness + gain).clamp(0, MAX_HAPPINESS)
      actualGain = @happiness - prevHappiness

      #echoln("Changing #{name}'s happiness by #{actualGain}") if actualGain != 0

      return if $PokemonSystem.show_trait_unlocks == 1
      
      traitUnlocked = nil
      likeUnlocked = nil
      dislikeUnlocked = nil
      ordinal = ""
      if prevHappiness < PERSONALITY_THRESHOLD_ONE && @happiness >= PERSONALITY_THRESHOLD_ONE
        traitUnlocked = trait1
        ordinal = "first"
      elsif prevHappiness < PERSONALITY_THRESHOLD_TWO && @happiness >= PERSONALITY_THRESHOLD_TWO
        traitUnlocked = trait2
        ordinal = "second"
      elsif prevHappiness < PERSONALITY_THRESHOLD_THREE && @happiness >= PERSONALITY_THRESHOLD_THREE
        traitUnlocked = trait3
        ordinal = "final"
      elsif prevHappiness < PERSONALITY_THRESHOLD_FOUR && @happiness >= PERSONALITY_THRESHOLD_FOUR
        likeUnlocked = like
        dislikeUnlocked = dislike
      end
      
      if !traitUnlocked.nil?
        msgwindow = pbCreateMessageWindow
        pbMessageDisplay(msgwindow,_INTL("\\wm{1} is happy enough to show off its {2} trait: {3}!\\me[Egg get]\\wtnp[80]\1",name,ordinal,traitUnlocked))
        pbDisposeMessageWindow(msgwindow)
      elsif !likeUnlocked.nil? && !dislikeUnlocked.nil?
        msgwindow = pbCreateMessageWindow
        pbMessageDisplay(msgwindow,_INTL("\\wm{1} is at maximum happiness! It loves you so much!\1",name))
        pbMessageDisplay(msgwindow,_INTL("\\wm{1} reveals that it likes {2} and that it dislikes {3}!\\me[Egg get]\\wtnp[100]\1",name,likeUnlocked,dislikeUnlocked))
        pbDisposeMessageWindow(msgwindow)
      end
    end
  
    #=============================================================================
    # Evolution checks
    #=============================================================================
    # Checks whether this Pokemon can evolve because of levelling up.
    # @return [Symbol, nil] the ID of the species to evolve into
    def check_evolution_on_level_up
      return check_evolution_internal { |pkmn, new_species, method, parameter|
        success = GameData::Evolution.get(method).call_level_up(pkmn, parameter)
        next (success) ? new_species : nil
      }
    end
  
    # Checks whether this Pokemon can evolve because of using an item on it.
    # @param item_used [Symbol, GameData::Item, nil] the item being used
    # @return [Symbol, nil] the ID of the species to evolve into
    def check_evolution_on_use_item(item_used)
      return check_evolution_internal { |pkmn, new_species, method, parameter|
        success = GameData::Evolution.get(method).call_use_item(pkmn, parameter, item_used)
        next (success) ? new_species : nil
      }
    end
  
    # Checks whether this Pokemon can evolve because of being traded.
    # @param other_pkmn [Pokemon] the other Pokémon involved in the trade
    # @return [Symbol, nil] the ID of the species to evolve into
    def check_evolution_on_trade(other_pkmn)
      return check_evolution_internal { |pkmn, new_species, method, parameter|
        success = GameData::Evolution.get(method).call_on_trade(pkmn, parameter, other_pkmn)
        next (success) ? new_species : nil
      }
    end
  
    # Called after this Pokémon evolves, to remove its held item (if the evolution
    # required it to have a held item) or duplicate this Pokémon (Shedinja only).
    # @param new_species [Pokemon] the species that this Pokémon evolved into
    def action_after_evolution(new_species)
      species_data.get_evolutions(true).each do |evo|   # [new_species, method, parameter]
        break if GameData::Evolution.get(evo[1]).call_after_evolution(self, evo[0], evo[2], new_species)
      end
    end
  
    # The core method that performs evolution checks. Needs a block given to it,
    # which will provide either a GameData::Species ID (the species to evolve
    # into) or nil (keep checking).
    # @return [Symbol, nil] the ID of the species to evolve into
    def check_evolution_internal
      return nil if egg?
      return nil if hasItem?(:EVERSTONE)
      return nil if hasItem?(:EVIOLITE)
      return nil if hasAbility?(:BATTLEBOND)
      species_data.get_evolutions(true).each do |evo| # [new_species, method, parameter, boolean]
          next if evo[3] # Prevolution
          ret = yield self, evo[0], evo[1], evo[2] # pkmn, new_species, method, parameter
          return ret if ret
      end
      return nil
  end
  
    #=============================================================================
    # Stat calculations
    #=============================================================================
  
    # @return [Hash<Integer>] this Pokémon's base stats, a hash with six key/value pairs
    def baseStats
      this_base_stats = species_data.base_stats
      ret = {}
      GameData::Stat.each_main { |s| ret[s.id] = this_base_stats[s.id] }
      return ret
    end
  
    # Returns this Pokémon's effective IVs, taking into account Hyper Training.
    # Only used for calculating stats.
    # @return [Hash<Integer>] hash containing this Pokémon's effective IVs
    def calcIV
      this_ivs = self.iv
      ret = {}
      GameData::Stat.each_main do |s|
        ret[s.id] = (@ivMaxed[s.id]) ? IV_STAT_LIMIT : this_ivs[s.id]
      end
      return ret
    end
  
    # @return [Integer] the maximum HP of this Pokémon
    def calcHP(base, level, iv, ev)
      return 1 if base == 1   # For Shedinja
      return ((base * 2 + iv + (ev / 4)) * level / 100).floor + level + 10
    end
  
    # @return [Integer] the specified stat of this Pokémon (not used for total HP)
    def calcStat(base, level, iv, ev, nat)
      return ((((base * 2 + iv + (ev / 4)) * level / 100).floor + 5) * nat / 100).floor
    end
  
    # Recalculates this Pokémon's stats.
    def calc_stats
        base_stats = baseStats
        this_level = level
        this_IV    = calcIV
        # Calculate stats
        stats = {}
        stylish = hasAbility?(:STYLISH)
        GameData::Stat.each_main do |s|
            if s.id == :HP
                hpValue = calcHPGlobal(base_stats[s.id], this_level, @ev[s.id], stylish)
                stats[s.id] = (hpValue * hpMult).ceil
            elsif (s.id == :ATTACK) || (s.id == :SPECIAL_ATTACK)
                stats[s.id] = calcStatGlobal(base_stats[s.id], this_level, @ev[s.id], stylish)
            else
                stats[s.id] = calcStatGlobal(base_stats[s.id], this_level, @ev[s.id], stylish)
            end
        end
        hpDiff = @totalhp - @hp
        @totalhp = stats[:HP]
        @hp      = (fainted? ? 0 : (@totalhp - hpDiff))
        @attack  = stats[:ATTACK]
        @defense = stats[:DEFENSE]
        @spatk   = stats[:SPECIAL_ATTACK]
        @spdef   = stats[:SPECIAL_DEFENSE]
        @speed   = stats[:SPEED]
    end

    #=============================================================================
    # Boss pokemon
    #=============================================================================
    def boss?
      return boss
    end

    #=============================================================================
    # Color shifting
    #=============================================================================
    def shiny_variant?
      return shiny_variant
    end

    def colorShiftID
        colorShiftID = 0
        if ownedByPlayer? # Owned by the player
            colorShiftID = @personalID ^ @owner.id
        else
            @owner.name.each_byte do |byte|
                colorShiftID += byte.to_i
            end
            name().each_byte do |byte|
                colorShiftID += byte.to_i
            end
        end
        return colorShiftID
    end

    def hueShift
        id = colorShiftID()
        shift = 0
        if HUE_SHIFT_RANGE > 0 && id != 0
            shift = (-(HUE_SHIFT_RANGE/2.0) + (id % HUE_SHIFT_RANGE)).round
        end
        #echoln("#{name()}'s hue is shifted by #{shift} from ID #{id}")
        return shift
    end

    def shadeShift
        id = colorShiftID()
        shift = 0
        if SHADE_SHIFT_RANGE > 0 && id != 0
            shift = (-(SHADE_SHIFT_RANGE/2.0) + ((id ^ 65970697) % SHADE_SHIFT_RANGE)).round
        end
        #echoln("#{name()}'s shade is shifted by #{shift} from ID #{id}")
        return shift
    end
  
    #=============================================================================
    # Pokémon creation
    #=============================================================================
  
    # Creates a copy of this Pokémon and returns it.
    # @return [Pokemon] a copy of this Pokémon
    def clone
      ret = super
      ret.iv          = {}
      ret.ivMaxed     = {}
      ret.ev          = {}
      GameData::Stat.each_main do |s|
        ret.iv[s.id]      = @iv[s.id]
        ret.ivMaxed[s.id] = @ivMaxed[s.id]
        ret.ev[s.id]      = @ev[s.id]
      end
      ret.moves       = []
      @moves.each_with_index { |m, i| ret.moves[i] = m.clone }
      ret.first_moves = @first_moves.clone
      ret.owner       = @owner.clone
      ret.ribbons     = @ribbons.clone
      return ret
    end
  
    # Creates a new Pokémon object.
    # @param species [Symbol, String, Integer] Pokémon species
    # @param level [Integer] Pokémon level
    # @param owner [Owner, Player, NPCTrainer] Pokémon owner (the player by default)
    # @param withMoves [TrueClass, FalseClass] whether the Pokémon should have moves
    # @param rechech_form [TrueClass, FalseClass] whether to auto-check the form
    def initialize(species, level, owner = $Trainer, withMoves = true, recheck_form = true)
      species_data = GameData::Species.get(species)
      @species          = species_data.species
      @form             = species_data.form
      @forced_form      = nil
      @time_form_set    = nil
      self.level        = level
      @steps_to_hatch   = 0
      heal_status
      @gender           = nil
      @shiny            = nil
      @ability_index    = nil
      @ability          = nil
      @extraAbilities   = []
      @nature           = nil
      @nature_for_stats = nil
      @items            = []
      @moves            = []
      reset_moves if withMoves
      @first_moves      = []
      @ribbons          = []
      @cool             = 0
      @beauty           = 0
      @cute             = 0
      @smart            = 0
      @tough            = 0
      @sheen            = 0
      @name             = nil
      @happiness        = species_data.happiness
      @poke_ball        = :POKEBALL
      @markings         = 0
      @iv               = {}
      @ivMaxed          = {}
      @ev               = {}
      GameData::Stat.each_main do |s|
          @iv[s.id] = 0
          @ev[s.id] = DEFAULT_STYLE_VALUE
      end
      if owner.is_a?(Owner)
          @owner = owner
      elsif owner.is_a?(Player) || owner.is_a?(NPCTrainer)
          @owner = Owner.new_from_trainer(owner)
      else
          @owner = Owner.new(0, "", 2, 2)
      end
      @obtain_method    = 0 # Met
      @obtain_method    = 4 if $game_switches && $game_switches[Settings::FATEFUL_ENCOUNTER_SWITCH]
      @obtain_map       = $game_map ? $game_map.map_id : 0
      @obtain_text      = nil
      @obtain_level     = level
      @hatched_map      = 0
      @timeReceived     = Time.now.to_i
      @timeEggHatched   = nil
      @fused            = nil
      @personalID       = rand(2**16) | rand(2**16) << 16
      @hp               = 1
      @totalhp          = 1
      @hpMult = 1
      @dmgMult = 1
      @dmgResist = 0
      @extraMovesPerTurn = 0
      @battlingStreak = 0
      @bossType = nil
      calc_stats
      if @form == 0 && recheck_form
          f = MultipleForms.call("getFormOnCreation", self)
          if f
              self.form = f
              reset_moves if withMoves
          end
      end
  end

  def shadowPokemon?
    return false
  end
end