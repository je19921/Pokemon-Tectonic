#===============================================================================
# Increases the user's Attack by 1 step.
#===============================================================================
class PokeBattle_Move_5D8 < PokeBattle_StatUpMove
    def initialize(battle, move)
        super
        @statUp = [:ATTACK, 1]
    end
end

#===============================================================================
# Increases the user's Attack by 2 step.
#===============================================================================
class PokeBattle_Move_01C < PokeBattle_StatUpMove
    def initialize(battle, move)
        super
        @statUp = [:ATTACK, 2]
    end
end

#===============================================================================
# Increases the user's Attack by 3 steps.
#===============================================================================
class PokeBattle_Move_5D9 < PokeBattle_StatUpMove
    def initialize(battle, move)
        super
        @statUp = [:ATTACK, 3]
    end
end

#===============================================================================
# Increases the user's Attack by 4 steps. (Swords Dance)
#===============================================================================
class PokeBattle_Move_02E < PokeBattle_StatUpMove
    def initialize(battle, move)
        super
        @statUp = [:ATTACK, 4]
    end
end

# Empowered Swords Dance
class PokeBattle_Move_633 < PokeBattle_Move_02E
    include EmpoweredMove

    def pbEffectGeneral(user)
        super
        # TODO
        transformType(user, :STEEL)
    end
end

#===============================================================================
# Increases the user's Attack by 5 steps.
#===============================================================================
class PokeBattle_Move_RaiseAttack5 < PokeBattle_StatUpMove
    def initialize(battle, move)
        super
        @statUp = [:ATTACK, 5]
    end
end

#===============================================================================
# Increases the user's Defense by 1 step.
#===============================================================================
class PokeBattle_Move_5DA < PokeBattle_StatUpMove
    def initialize(battle, move)
        super
        @statUp = [:DEFENSE, 1]
    end
end

#===============================================================================
# Increases the user's Defense by 2 steps.
#===============================================================================
class PokeBattle_Move_01D < PokeBattle_StatUpMove
    def initialize(battle, move)
        super
        @statUp = [:DEFENSE, 2]
    end
end

#===============================================================================
# Increases the user's Defense by 3 steps.
#===============================================================================
class PokeBattle_Move_5DB < PokeBattle_StatUpMove
    def initialize(battle, move)
        super
        @statUp = [:DEFENSE, 3]
    end
end

#===============================================================================
# Increases the user's Defense by 4 steps. (Barrier, Iron Defense)
#===============================================================================
class PokeBattle_Move_02F < PokeBattle_StatUpMove
    def initialize(battle, move)
        super
        @statUp = [:DEFENSE, 4]
    end
end

# Empowered Iron Defense
class PokeBattle_Move_625 < PokeBattle_Move_02F
    include EmpoweredMove

    def pbEffectGeneral(user)
        super
        user.addAbility(:FILTER,true)
        transformType(user, :STEEL)
    end
end

#===============================================================================
# Increases the user's Defense by 5 steps. (Cotton Guard)
#===============================================================================
class PokeBattle_Move_038 < PokeBattle_StatUpMove
    def initialize(battle, move)
        super
        @statUp = [:DEFENSE, 5]
    end	
end

#===============================================================================
# Increases the user's Speed by 1 step.
#===============================================================================
class PokeBattle_Move_5E0 < PokeBattle_StatUpMove
    def initialize(battle, move)
        super
        @statUp = [:SPEED, 1]
    end
end

#===============================================================================
# Increases the user's Speed by 2 steps.
#===============================================================================
class PokeBattle_Move_01F < PokeBattle_StatUpMove
    def initialize(battle, move)
        super
        @statUp = [:SPEED, 2]
    end
end

#===============================================================================
# Increases the user's Speed by 3 steps.
#===============================================================================
class PokeBattle_Move_5E1 < PokeBattle_StatUpMove
    def initialize(battle, move)
        super
        @statUp = [:SPEED, 3]
    end
end

#===============================================================================
# Increases the user's Speed by 4 steps. (Agility, Rock Polish)
#===============================================================================
class PokeBattle_Move_030 < PokeBattle_StatUpMove
    def initialize(battle, move)
        super
        @statUp = [:SPEED, 4]
    end

    def getEffectScore(user, target)
        score = super
        score += 40 if user.hasActiveAbilityAI?(:STAMPEDE)
        return score
    end
end

# Empowered Rock Polish
class PokeBattle_Move_61B < PokeBattle_Move_030
    include EmpoweredMove

    def pbEffectGeneral(user)
        super
        user.applyEffect(:ExtraTurns, 2)
        transformType(user, :ROCK)
    end
end

#===============================================================================
# The user's Speed raises 4 steps, and it gains the Flying-type. (Mach Flight)
#===============================================================================
class PokeBattle_Move_58C < PokeBattle_Move_030
    def pbMoveFailed?(user, targets, show_message)
        return false if GameData::Type.exists?(:FLYING) && !user.pbHasType?(:FLYING) && user.canChangeType?
        super
    end

    def pbEffectGeneral(user)
        super
        user.applyEffect(:Type3, :FLYING)
    end
end

#===============================================================================
# Increases the user's Speed by 5 steps.
#===============================================================================
class PokeBattle_Move_RaiseSpeed5 < PokeBattle_StatUpMove
    def initialize(battle, move)
        super
        @statUp = [:SPEED, 5]
    end

    def getEffectScore(user, target)
        score = super
        score += 50 if user.hasActiveAbilityAI?(:STAMPEDE)
        return score
    end
end

#===============================================================================
# Increases the user's Sp. Atk by 1 step.
#===============================================================================
class PokeBattle_Move_5DC < PokeBattle_StatUpMove
    def initialize(battle, move)
        super
        @statUp = [:SPECIAL_ATTACK, 1]
    end
end

#===============================================================================
# Increases the user's Sp. Atk by 2 step.
#===============================================================================
class PokeBattle_Move_020 < PokeBattle_StatUpMove
    def initialize(battle, move)
        super
        @statUp = [:SPECIAL_ATTACK, 2]
    end
end

#===============================================================================
# Increases the user's Sp. Atk by 3 steps.
#===============================================================================
class PokeBattle_Move_5DD < PokeBattle_StatUpMove
    def initialize(battle, move)
        super
        @statUp = [:SPECIAL_ATTACK, 3]
    end
end

#===============================================================================
# Increases the user's Special Attack by 4 steps. (Dream Dance)
#===============================================================================
class PokeBattle_Move_032 < PokeBattle_StatUpMove
    def initialize(battle, move)
        super
        @statUp = [:SPECIAL_ATTACK, 4]
    end
end

# Empowered Dream Dance
class PokeBattle_Move_632 < PokeBattle_Move_032
    include EmpoweredMove

    def pbEffectGeneral(user)
        super
        # TODO
        transformType(user, :FAIRY)
    end
end

#===============================================================================
# Increases the user's Special Attack by 5 steps. (Tail Glow)
#===============================================================================
class PokeBattle_Move_039 < PokeBattle_StatUpMove
    def initialize(battle, move)
        super
        @statUp = [:SPECIAL_ATTACK, 5]
    end
end

#===============================================================================
# Increases the user's Sp. Def by 1 step.
#===============================================================================
class PokeBattle_Move_5DE < PokeBattle_StatUpMove
    def initialize(battle, move)
        super
        @statUp = [:SPECIAL_DEFENSE, 1]
    end
end

#===============================================================================
# Increases the user's Sp. Def by 2 steps.
#===============================================================================
class PokeBattle_Move_RaiseSpDef5 < PokeBattle_StatUpMove
    def initialize(battle, move)
        super
        @statUp = [:SPECIAL_DEFENSE, 3]
    end
end

#===============================================================================
# Increases the user's Sp. Def by 3 steps.
#===============================================================================
class PokeBattle_Move_5DF < PokeBattle_StatUpMove
    def initialize(battle, move)
        super
        @statUp = [:SPECIAL_DEFENSE, 3]
    end
end

#===============================================================================
# Increases the user's Special Defense by 4 steps. (Amnesia)
#===============================================================================
class PokeBattle_Move_033 < PokeBattle_StatUpMove
    def initialize(battle, move)
        super
        @statUp = [:SPECIAL_DEFENSE, 4]
    end
end

# Empowered Amnesia
class PokeBattle_Move_626 < PokeBattle_Move_033
    include EmpoweredMove

    def pbEffectGeneral(user)
        super
        user.addAbility(:UNAWARE,true)
        transformType(user, :PSYCHIC)
    end
end

#===============================================================================
# Increases the user's Sp. Def by 5 steps. (Mucus Armor)
#===============================================================================
class PokeBattle_Move_57B < PokeBattle_StatUpMove
    def initialize(battle, move)
        super
        @statUp = [:SPECIAL_DEFENSE, 5]
    end	
end

#===============================================================================
# Increases the user's critical hit rate. (Starfall)
#===============================================================================
class PokeBattle_Move_520 < PokeBattle_Move
    def pbEffectGeneral(user)
        user.applyEffect(:LuckyStar)
    end

    def getEffectScore(user, _target)
        if user.effectActive?(:LuckyStar)
            return 0
        else
            return getCriticalRateBuffEffectScore(user)
        end
    end
end

#===============================================================================
# Increases the user's critical hit rate by 2 stages. (Focus Energy)
#===============================================================================
class PokeBattle_Move_023 < PokeBattle_Move
    def pbMoveFailed?(user, _targets, show_message)
        if user.effectAtMax?(:FocusEnergy)
            @battle.pbDisplay(_INTL("But it failed, since it cannot get any more pumped!")) if show_message
            return true
        end
        return false
    end

    def pbEffectGeneral(user)
        user.incrementEffect(:FocusEnergy, 2)
    end

    def getEffectScore(user, _target)
        return getCriticalRateBuffEffectScore(user, 2)
    end
end

#===============================================================================
# Maximizes accuracy. (Aim True)
#===============================================================================
class PokeBattle_Move_501 < PokeBattle_Move
    def pbMoveFailed?(user, _targets, show_message)
        return !user.pbCanRaiseStatStep?(:ACCURACY, user, self, show_message)
    end

    def pbEffectGeneral(user)
        user.pbMaximizeStatStep(:ACCURACY, user, self)
    end

    def getEffectScore(user, _target)
        score = 60
        score -= (user.steps[:ACCURACY] - 6) * 10
        score += 20 if user.hasInaccurateMove?
        score += 40 if user.hasLowAccuracyMove?
        return score
    end
end

#===============================================================================
# If the move misses, the user gains Accuracy. (Rockapult)
#===============================================================================
class PokeBattle_Move_51F < PokeBattle_Move
    # This method is called if a move fails to hit all of its targets
    def pbCrashDamage(user)
        return unless user.tryRaiseStat(:ACCURACY, user, move: self)
        @battle.pbDisplay(_INTL("{1} adjusted its aim!", user.pbThis))
    end

    def getEffectScore(user, _target)
        return getMultiStatUpEffectScore([:ACCURACY, 1], user, user) * 0.5
    end
end

#===============================================================================
# Changes Category based on which will deal more damage. (Everhone)
# Raises the stat that wasn't selected to be used.
#===============================================================================
class PokeBattle_Move_5C1 < PokeBattle_Move
    def initialize(battle, move)
        super
        @calculated_category = 1
    end

    def calculateCategory(user, targets)
        return selectBestCategory(user, targets[0])
    end

    def pbAdditionalEffect(user, _target)
        if @calculated_category == 0
            return user.tryRaiseStat(:SPECIAL_ATTACK, user, increment: 1, move: self)
        else
            return user.tryRaiseStat(:ATTACK, user, increment: 1, move: self)
        end
    end

    def getEffectScore(user, target)
        expectedCategory = selectBestCategory(user, target)
        if expectedCategory == 0
            return getMultiStatUpEffectScore([:SPECIAL_ATTACK, 1], user, user)
        else
            return getMultiStatUpEffectScore([:ATTACK, 1], user, user)
        end
    end
end