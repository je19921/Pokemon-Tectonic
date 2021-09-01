# Eruption
PokeBattle_AI::BossSpeciesUseMoveCodeIfAndOnlyIf.add([:GROUDON,"08B"],
	proc { |species,move,user,target|
		next @battle.turnCount == 0
	}
)

# Eruption
PokeBattle_AI::BossSpeciesUseMoveCodeIfAndOnlyIf.add([:GROUDON,"08B"],
	proc { |species,move,user,target|
		next @battle.turnCount == 0
	}
)

PokeBattle_AI::BossSpeciesRequireMove.add(:GROUDON,
	proc { |species,move,user,target|
		next true if move.id == :PRECIPICEBLADES && $game_variables[95] == 1
	}
)

PokeBattle_AI::BossSpeciesRejectMove.add(:GROUDON,
	proc { |species,move,user,target|
		next true if move.id == :PRECIPICEBLADES && $game_variables[95] != 1
	}
)

PokeBattle_AI::BossDecidedOnMove.add(:GROUDON,
	proc { |species,move,user,target|
		if move.function == "08B"
			user.battle.pbDisplay(_INTL("The avatar is clearly preparing a massive opening attack!"))
		elsif move.id == :PRECIPICEBLADES
			user.battle.pbDisplay(_INTL("The avatar is gathering energy for a massive attack!"))
		end
	}
)

PokeBattle_AI::BossBeginTurn.add(:GROUDON,
	proc { |species,battler|
		turnCount = battler.battle.turnCount
		if turnCount == 0
			$game_variables[95] = 1
		elsif turnCount % 3 == 0 && @turnCount > 0
			$game_variables[95] = 1
		else
			$game_variables[95] = 3
		end
	}
)