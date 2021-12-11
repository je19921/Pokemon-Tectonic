class BattleInfoDisplay < SpriteWrapper
	attr_accessor   :battle
	attr_accessor   :selected
	attr_accessor	:individual
	
  def initialize(viewport,z,battle)
	super(viewport)
    self.x = 0
    self.y = 0
	self.battle = battle
	
	@sprites      = {}
    @spriteX      = 0
    @spriteY      = 0
	@selected	  = 0
	@individual   = nil
	@backgroundBitmap  = AnimatedBitmap.new("Graphics/Pictures/Battle/BattleButtonRework/battle_info")
	
	@statusCursorBitmap  = AnimatedBitmap.new("Graphics/Pictures/Battle/BattleButtonRework/cursor_status")
	
	@contents = BitmapWrapper.new(@backgroundBitmap.width,@backgroundBitmap.height)
    self.bitmap  = @contents
	pbSetNarrowFont(self.bitmap)
	
	self.z = z
    refresh
  end
  
  def dispose
    pbDisposeSpriteHash(@sprites)
    @backgroundBitmap.dispose
    super
  end
  
  def visible=(value)
    super
    for i in @sprites
      i[1].visible = value if !i[1].disposed?
    end
  end
  
  def refresh
    self.bitmap.clear
	# Draw background panel
    self.bitmap.blt(0,0,@backgroundBitmap.bitmap,Rect.new(0,0,@backgroundBitmap.width,@backgroundBitmap.height))
	
	if @individual
		drawIndividualBattlerInfo(@individual)
	else
		drawWholeBattleInfo()
	end
  end
  
  def drawWholeBattleInfo()
	base   = Color.new(88,88,80)
    shadow = Color.new(168,184,184)
	textToDraw = []
	
	index = 0.2
	battlerIndex = 0
	@battle.eachSameSideBattler do |b|
		next if !b
		y = 50 * index
		textToDraw.push([b.name,24,y,0,base,shadow])
		cursorX = @selected == battlerIndex ? @statusCursorBitmap.width/2 : 0
		self.bitmap.blt(180,y,@statusCursorBitmap.bitmap,Rect.new(cursorX,0,@statusCursorBitmap.width/2,@statusCursorBitmap.height))
		index += 1
		battlerIndex += 1
	end
	index += 0.2
	@battle.eachOtherSideBattler do |b|
		next if !b
		y = 50 * index
		textToDraw.push([b.name,24,y,0,base,shadow])
		cursorX = @selected == battlerIndex ? @statusCursorBitmap.width/2 : 0
		self.bitmap.blt(180,y,@statusCursorBitmap.bitmap,Rect.new(cursorX,0,@statusCursorBitmap.width/2,@statusCursorBitmap.height))
		index += 1
		battlerIndex += 1
	end
	
	textToDraw.push([_INTL("Weather: {1}",@battle.field.weather),24,320,0,base,shadow])
	textToDraw.push([_INTL("Terrain: {1}",@battle.field.terrain),224,320,0,base,shadow])
	pbDrawTextPositions(self.bitmap,textToDraw)
  end
  
  def drawIndividualBattlerInfo(battler)
	base   = Color.new(88,88,80)
    shadow = Color.new(168,184,184)
	textToDraw = []
	
	battlerName = battler.name
	if battler.pokemon.nicknamed?
		speciesData = GameData::Species.get(battler.species)
		battlerName += " (#{speciesData.real_name})"
	end
	textToDraw.push([battlerName,180,10,0,base,shadow])
	index = 0
	[:ATTACK,:DEFENSE,:SPECIAL_ATTACK,:SPECIAL_DEFENSE,:SPEED,:ACCURACY,:EVASION].each do |stat|
		statData = GameData::Stat.get(stat)
		statName = statData.real_name
		stage = battler.stages[stat]
		textToDraw.push([statName,24,50 + 32 * index,0,base,shadow])
		textToDraw.push([stage.to_s,200,50 + 32 * index,2,base,shadow])
		index += 1
	end
	
	index = 0
	for effect in 0..150
		effectValue = battler.effects[effect]
		next if effectValue.nil? || effectValue == false
		next if effectValue.is_a?(Integer) && effectValue <= 0
		next if effect == PBEffects::ProtectRate && effectValue <= 1
		effectName = labelPbEffect(effect)
		next if effectName.blank?
		effectName += ": " + effectValue.to_s if effectValue.is_a?(Integer) || effectValue.is_a?(String)
		textToDraw.push([effectName,240,50 + 32 * index,0,base,shadow])
		index += 1
	end
	
	pbDrawTextPositions(self.bitmap,textToDraw)
  end
  
  def labelPbEffect(effectNumber)
	return [
		"Aqua Ring",
		"", # Attract
		"",
		"",
		"Bide",
		"",
		"",
		"Burn Up",
		"Charge",
		"", # Choice Band
		"Confusion",
		"",
		"",
		"Curse",
		"", # Dancer
		"",
		"Destiny Bond",
		"",
		"",
		"", # Disable
		"Disabled Move",
		"",
		"Embargo",
		"",
		"Encored Move",
		"",
		"",
		"Flash Fire",
		"",
		"Focus Energy",
		"",
		"",
		"Foresight",
		"Fury Cutter",
		"Gasto Acid",
		"",
		"",
		"Heal Block",
		"",
		"Move Recharge", # hyper beam, etc.
		"",
		"Imprison",
		"Ingrain",
		"",
		"",
		"",
		"Laser Focus",
		"Leech Seed",
		"Lock-On",
		"Locked On To",
		"",
		"",
		"Magnet Rise",
		"Trapped", # Mean look, etc.
		"",
		"Metronome Count",
		"Micle Berry",
		"Minimize",
		"Miracle Eye",
		"",
		"",
		"",
		"Mud Sport",
		"Nightmare",
		"Locked Into Move", # Outrage, etc.
		"",
		"Perish Song",
		"",
		"",
		"",
		"",
		"Black Powder",
		"Power Trick",
		"",
		"",
		"",
		"",
		"Protection Failure", # Protect Rate
		"",
		"",
		"Rage",
		"",
		"Rollout",
		"",
		"",
		"Sky Drop",
		"Slow Start",
		"Smacked Down",
		"",
		"",
		"", # Spotlight
		"Stockpile",
		"",
		"",
		"Substitute",
		"Taunt",
		"Telekenisis",
		"Throat Chopped",
		"Torment",
		"Toxic",
		"Transform",
		"",
		"", # Whirlpool, etc.
		"Trapped By Move",
		"Trapped By User",
		"Truant",
		"2-Turn Attack",
		"",
		"Unburden",
		"Uproar Restless",
		"Water Sport",
		"Weight Added",
		"Drowzy",
		"",
		"",
		"",
		"",
		"No Retreat",
		"",
		"Trapped by Jaws",
		"Trapping With Jaws",
		"Tar Shot",
		"Octolocked",
		"Octolocking",
		"Blundered",
		"",
		"",
		"",
		"",
		"Flinch Protection",
		"Enlightened",
		"Cold Conversion",
		"Creeped Out",
		"Lucky Star",
		"Charmed",
		"",
		"Inured",
		"No Retreat",
		"Nerve Broken",
		"Ice Ball",
		"Roll Out",
		"Protected By Gargantuan",
		"Empowered Moonlight"
	][effectNumber] || ""
  end
  
  def update(frameCounter=0)
    super()
    pbUpdateSpriteHash(@sprites)
  end
end