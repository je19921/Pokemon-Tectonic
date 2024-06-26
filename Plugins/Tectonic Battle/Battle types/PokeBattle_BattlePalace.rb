#===============================================================================
#
#===============================================================================
class PokeBattle_BattlePalace < PokeBattle_Battle
  # Percentage chances of choosing attack, defense, support moves
  @@BattlePalaceUsualTable = {
    :HARDY   => [61,  7, 32],
    :LONELY  => [20, 25, 55],
    :BRAVE   => [70, 15, 15],
    :ADAMANT => [38, 31, 31],
    :NAUGHTY => [20, 70, 10],
    :BOLD    => [30, 20, 50],
    :DOCILE  => [56, 22, 22],
    :RELAXED => [25, 15, 60],
    :IMPISH  => [69,  6, 25],
    :LAX     => [35, 10, 55],
    :TIMID   => [62, 10, 28],
    :HASTY   => [58, 37,  5],
    :SERIOUS => [34, 11, 55],
    :JOLLY   => [35,  5, 60],
    :NAIVE   => [56, 22, 22],
    :MODEST  => [35, 45, 20],
    :MILD    => [44, 50,  6],
    :QUIET   => [56, 22, 22],
    :BASHFUL => [30, 58, 12],
    :RASH    => [30, 13, 57],
    :CALM    => [40, 50, 10],
    :GENTLE  => [18, 70, 12],
    :SASSY   => [88,  6,  6],
    :CAREFUL => [42, 50,  8],
    :QUIRKY  => [56, 22, 22]
  }
  @@BattlePalacePinchTable = {
    :HARDY   => [61,  7, 32],
    :LONELY  => [84,  8,  8],
    :BRAVE   => [32, 60,  8],
    :ADAMANT => [70, 15, 15],
    :NAUGHTY => [70, 22,  8],
    :BOLD    => [32, 58, 10],
    :DOCILE  => [56, 22, 22],
    :RELAXED => [75, 15, 10],
    :IMPISH  => [28, 55, 17],
    :LAX     => [29,  6, 65],
    :TIMID   => [30, 20, 50],
    :HASTY   => [88,  6,  6],
    :SERIOUS => [29, 11, 60],
    :JOLLY   => [35, 60,  5],
    :NAIVE   => [56, 22, 22],
    :MODEST  => [34, 60,  6],
    :MILD    => [34,  6, 60],
    :QUIET   => [56, 22, 22],
    :BASHFUL => [30, 58, 12],
    :RASH    => [27,  6, 67],
    :CALM    => [25, 62, 13],
    :GENTLE  => [90,  5,  5],
    :SASSY   => [22, 20, 58],
    :CAREFUL => [42,  5, 53],
    :QUIRKY  => [56, 22, 22]
  }

  def initialize(*arg)
    super
    @justswitched          = [false,false,false,false]
    @battleAI.battlePalace = true
  end

  def pbMoveCategory(move)
    if move.target == :User || move.function == "MultiTurnAttackBideThenReturnDoubleDamage"   # Bide
      return 1
    elsif move.statusMove? ||
       move.function == "CounterPhysicalDamage" || move.function == "CounterSpecialDamage"   # Counter, Mirror Coat
      return 2
    else
      return 0
    end
  end

  # Different implementation of pbCanChooseMove, ignores Imprison/Torment/Taunt/Disable/Encore
  def pbCanChooseMovePartial?(idxPokemon,idxMove)
    thispkmn = @battlers[idxPokemon]
    thismove = thispkmn.moves[idxMove]
    return false if !thismove
    return false if thismove.pp<=0
    if thispkmn.effectActive?(:ChoiceBand) && thismove.id != thispkmn.getMove(:ChoieBand).id
       thispkmn.hasActiveItem?(:CHOICEBAND)
      return false
    end
    # though incorrect, just for convenience (actually checks Torment later)
    if thispkmn.effectActive?(:Torment) && thispkmn.lastMoveUsed
      return false if thismove.id==thispkmn.lastMoveUsed
    end
    return true
  end

  def pbRegisterMove(idxBattler,idxMove,_showMessages=true)
    this_battler = @battlers[idxBattler]
    if idxMove==-2
      @choices[idxBattler][0] = :UseMove    # "Use move"
      @choices[idxBattler][1] = -2          # "Incapable of using its power..."
      @choices[idxBattler][2] = @struggle
      @choices[idxBattler][3] = -1
    else
      @choices[idxBattler][0] = :UseMove                      # "Use move"
      @choices[idxBattler][1] = idxMove                       # Index of move to be used
      @choices[idxBattler][2] = this_battler.moves[idxMove]   # PokeBattle_Move object
      @choices[idxBattler][3] = -1                            # No target chosen yet
    end
  end

  def pbAutoFightMenu(idxBattler)
    this_battler = @battlers[idxBattler]
    nature = this_battler.nature.id
    randnum = @battleAI.pbAIRandom(100)
    category = 0
    atkpercent = 0
    defpercent = 0
    if !this_battler.effectActive?(:Pinch)
      atkpercent = @@BattlePalacePinchTable[nature][0]
      defpercent = atkpercent+@@BattlePalacePinchTable[nature][1]
    else
      atkpercent = @@BattlePalaceUsualTable[nature][0]
      defpercent = atkpercent+@@BattlePalaceUsualTable[nature][1]
    end
    if randnum<atkpercent
      category = 0
    elsif randnum<atkpercent+defpercent
      category = 1
    else
      category = 2
    end
    moves = []
    for i in 0...this_battler.moves.length
      next if !pbCanChooseMovePartial?(idxBattler,i)
      next if pbMoveCategory(this_battler.moves[i])!=category
      moves[moves.length] = i
    end
    if moves.length==0
      # No moves of selected category
      pbRegisterMove(idxBattler,-2)
    else
      chosenmove = moves[@battleAI.pbAIRandom(moves.length)]
      pbRegisterMove(idxBattler,chosenmove)
    end
    return true
  end

  def pbPinchChange(battler)
    return if !battler || battler.fainted?
    return if battler.effectActive?(:Pinch) || battler.status == :SLEEP
    return if battler.hp > battler.totalhp / 2
    nature = battler.nature.id
    battler.applyEffect(:Pinch)
    case nature
    when :QUIET, :BASHFUL, :NAIVE, :QUIRKY, :HARDY, :DOCILE, :SERIOUS
      pbDisplay(_INTL("{1} is eager for more!", battler.pbThis))
    when :CAREFUL, :RASH, :LAX, :SASSY, :MILD, :TIMID
      pbDisplay(_INTL("{1} began growling deeply!", battler.pbThis))
    when :GENTLE, :ADAMANT, :HASTY, :LONELY, :RELAXED, :NAUGHTY
      pbDisplay(_INTL("A glint appears in {1}'s eyes!", battler.pbThis(true)))
    when :JOLLY, :BOLD, :BRAVE, :CALM, :IMPISH, :MODEST
      pbDisplay(_INTL("{1} is getting into position!", battler.pbThis))
    end
  end

  def pbEndOfRoundPhase
    super
    return if @decision != 0
    eachBattler { |b| pbPinchChange(b) }
  end
end