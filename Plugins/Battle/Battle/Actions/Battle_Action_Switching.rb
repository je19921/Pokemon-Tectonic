class PokeBattle_Battle
    #=============================================================================
    # Choosing Pokémon to switch
    #=============================================================================
    # Checks whether the replacement Pokémon (at party index idxParty) can enter
    # battle.
    # NOTE: Messages are only shown while in the party screen when choosing a
    #       command for the next round.
    def pbCanSwitchLax?(idxBattler, idxParty, partyScene = nil)
        return true if idxParty < 0
        party = pbParty(idxBattler)
        return false if idxParty >= party.length
        return false unless party[idxParty]
        if party[idxParty].egg?
            partyScene.pbDisplay(_INTL("An Egg can't battle!")) if partyScene
            return false
        end
        unless pbIsOwner?(idxBattler, idxParty)
            owner = pbGetOwnerFromPartyIndex(idxBattler, idxParty)
            if partyScene
                partyScene.pbDisplay(_INTL("You can't switch {1}'s Pokémon with one of yours!",
                  owner.name))
            end
            return false
        end
        if party[idxParty].fainted?
            if partyScene
                if party[idxParty].afraid?
                    partyScene.pbDisplay(_INTL("{1} is too afraid to battle!", party[idxParty].name))
                else
                    partyScene.pbDisplay(_INTL("{1} has no energy left to battle!", party[idxParty].name))
                end
            end
            return false
        end
        if pbFindBattler(idxParty, idxBattler)
            if partyScene
                partyScene.pbDisplay(_INTL("{1} is already in battle!",
                   party[idxParty].name))
            end
            return false
        end
        return true
    end

    # Check whether the currently active Pokémon (at battler index idxBattler) can
    # switch out (and that its replacement at party index idxParty can switch in).
    # NOTE: Messages are only shown while in the party screen when choosing a
    #       command for the next round.
    def pbCanSwitch?(idxBattler, idxParty = -1, partyScene = nil)
        if @battlers[idxBattler].boss?
            partyScene.pbDisplay(_INTL("Avatars can't be switched out!")) if partyScene
            return false
        end
        # Check whether party Pokémon can switch in
        return false unless pbCanSwitchLax?(idxBattler, idxParty, partyScene)
        # Make sure another battler isn't already choosing to switch to the party
        # Pokémon
        eachSameSideBattler(idxBattler) do |b|
            next if choices[b.index][0] != :SwitchOut || choices[b.index][1] != idxParty
            if partyScene
                partyScene.pbDisplay(_INTL("{1} has already been selected.",
                   pbParty(idxBattler)[idxParty].name))
            end
            return false
        end
        return true if @battlers[idxBattler].fainted?
        return !pbIsTrapped?(idxBattler, partyScene)
    end

    def pbIsTrapped?(idxBattler, partyScene = nil)
        battler = @battlers[idxBattler]
        
        # Ability effects that allow switching no matter what
        battler.eachActiveAbility do |ability|
            return false if BattleHandlers.triggerCertainSwitchingUserAbility(ability, battler, self, false)
        end
        # Item effects that allow switching no matter what
        battler.eachActiveItem do |item|
            return false if BattleHandlers.triggerCertainSwitchingUserItem(item, battler, self)
        end

        # Other certain trapping effects
        battler.eachEffectAllLocations(true) do |_effect, _value, data|
            next unless data.trapping?
            partyScene.pbDisplay(_INTL("{1} can't be switched out!", battler.pbThis)) if partyScene
            return true
        end

        # Trapping abilities/items
        eachOtherSideBattler(idxBattler) do |b|
            b.eachActiveAbility do |ability|
                if BattleHandlers.triggerTrappingTargetAbility(ability, battler, b, self)
                    if partyScene
                        partyScene.pbDisplay(_INTL("{1}'s {2} prevents switching!",
                            b.pbThis, getAbilityName(ability)))
                    end
                    return true
                end
            end
        end
        eachOtherSideBattler(idxBattler) do |b|
            b.eachActiveItem do |item|
                if BattleHandlers.triggerTrappingTargetItem(item, battler, b, self)
                    if partyScene
                        partyScene.pbDisplay(_INTL("{1}'s {2} prevents switching!",
                           b.pbThis, getItemName(item)))
                    end
                    return true
                end
            end
        end
        return false
    end

    def pbCanChooseNonActive?(idxBattler)
        pbParty(idxBattler).each_with_index do |_pkmn, i|
            return true if pbCanSwitchLax?(idxBattler, i)
        end
        return false
    end

    def pbRegisterSwitch(idxBattler, idxParty)
        return false unless pbCanSwitch?(idxBattler, idxParty)
        @choices[idxBattler][0] = :SwitchOut
        @choices[idxBattler][1] = idxParty # Party index of Pokémon to switch in
        @choices[idxBattler][2] = nil
        return true
    end

    #=============================================================================
    # Open the party screen and potentially pick a replacement Pokémon (or AI
    # chooses replacement)
    #=============================================================================
    # Open party screen and potentially choose a Pokémon to switch with. Used in
    # all instances where the party screen is opened.
    def pbPartyScreen(idxBattler, checkLaxOnly = false, canCancel = false, shouldRegister = false)
        ret = -1
        @scene.pbPartyScreen(idxBattler, canCancel) do |idxParty, partyScene|
            if checkLaxOnly
                next false unless pbCanSwitchLax?(idxBattler, idxParty, partyScene)
            elsif !pbCanSwitch?(idxBattler, idxParty, partyScene)
                next false
            end
            next false if shouldRegister && (idxParty < 0 || !pbRegisterSwitch(idxBattler, idxParty))
            ret = idxParty
            next true
        end
        return ret
    end

    # For choosing a replacement Pokémon when prompted in the middle of other
    # things happening (U-turn, Baton Pass, in def pbSwitch).
    def pbSwitchInBetween(idxBattler, checkLaxOnly = false, canCancel = false)
        return pbPartyScreen(idxBattler, checkLaxOnly, canCancel) if pbOwnedByPlayer?(idxBattler)
        return @battleAI.pbDefaultChooseNewEnemy(idxBattler, pbParty(idxBattler))
    end

    def triggeredSwitchOut(idxBattler, ability: nil)
        battler = @battlers[idxBattler]
        return false unless pbCanSwitch?(idxBattler) # Battler can't switch out
        return false unless pbCanChooseNonActive?(idxBattler) # No Pokémon can switch in
        if ability
            pbShowAbilitySplash(battler, ability)
            pbHideAbilitySplash(battler)
        end
        pbDisplay(_INTL("{1} went back to {2}!",
            battler.pbThis, pbGetOwnerName(idxBattler)))
        if endOfRound # Just switch out
            @scene.pbRecall(idxBattler) unless battler.fainted?
            battler.pbAbilitiesOnSwitchOut # Inc. primordial weather check
            return true
        end
        newPkmn = pbGetReplacementPokemonIndex(idxBattler) # Owner chooses
        return false if newPkmn < 0 # Shouldn't ever do this
        pbRecallAndReplace(idxBattler, newPkmn)
        pbClearChoice(idxBattler) # Replacement Pokémon does nothing this round
        return true
    end

    #=============================================================================
    # Switching Pokémon
    #=============================================================================
    # General switching method that checks if any Pokémon need to be sent out and,
    # if so, does. Called at the end of each round.
    def pbEORSwitch(favorDraws = false)
        return if @decision > 0 && !favorDraws
        return if @decision == 5 && favorDraws
        pbJudge
        return if @decision > 0
        # Check through each fainted battler to see if that spot can be filled.
        switched = []
        loop do
            switched.clear
            @battlers.each do |b|
                next if !b || !b.fainted?
                idxBattler = b.index
                next unless pbCanChooseNonActive?(idxBattler)
                if !pbOwnedByPlayer?(idxBattler) # Opponent/ally is switching in
                    next if wildBattle? && opposes?(idxBattler) # Wild Pokémon can't switch
                    idxPartyNew = pbSwitchInBetween(idxBattler)
                    pbRecallAndReplace(idxBattler, idxPartyNew)
                    switched.push(idxBattler)
                elsif trainerBattle? || bossBattle? # Player switches in in a trainer battle or boss battle
                    idxPlayerPartyNew = pbGetReplacementPokemonIndex(idxBattler) # Owner chooses
                    pbRecallAndReplace(idxBattler, idxPlayerPartyNew)
                    switched.push(idxBattler)
                else # Player's Pokémon has fainted in a wild battle
                    switch = false
                    if !bossBattle? && !pbDisplayConfirm(_INTL("Use next Pokémon?"))
                        switch = (pbRun(idxBattler, true) <= 0)
                    else
                        switch = true
                    end
                    if switch
                        idxPlayerPartyNew = pbGetReplacementPokemonIndex(idxBattler) # Owner chooses
                        pbRecallAndReplace(idxBattler, idxPlayerPartyNew)
                        switched.push(idxBattler)
                    end
                end
            end
            break if switched.length == 0
            pbPriority(true).each do |b|
                b.pbEffectsOnSwitchIn(true) if switched.include?(b.index)
            end
        end
    end

    def pbGetReplacementPokemonIndex(idxBattler, random = false)
        if random || @autoTesting
            return -1 unless pbCanSwitch?(idxBattler) # Can battler switch out?
            choices = [] # Find all Pokémon that can switch in
            eachInTeamFromBattlerIndex(idxBattler) do |_pkmn, i|
                choices.push(i) if pbCanSwitchLax?(idxBattler, i)
            end
            return -1 if choices.length == 0
            return choices[pbRandom(choices.length)]
        else
            return -1 unless pbCanChooseNonActive?(idxBattler)
            return pbSwitchInBetween(idxBattler, true)
        end
    end

    # Actually performs the recalling and sending out in all situations.
    def pbRecallAndReplace(idxBattler, idxParty, randomReplacement = false, batonPass = false)
        @scene.pbRecall(idxBattler) if !@battlers[idxBattler].fainted? && !@autoTesting
        @battlers[idxBattler].pbAbilitiesOnSwitchOut # Inc. primordial weather check
        @scene.pbShowPartyLineup(idxBattler & 1) if pbSideSize(idxBattler) == 1 && !@autoTesting
        pbMessagesOnReplace(idxBattler, idxParty) unless randomReplacement
        pbReplace(idxBattler, idxParty, batonPass)
    end

    def pbMessageOnRecall(battler)
        if battler.pbOwnedByPlayer?
            if battler.hp <= battler.totalhp / 4
                pbDisplayBrief(_INTL("Good job, {1}! Come back!", battler.name))
            elsif battler.hp <= battler.totalhp / 2
                pbDisplayBrief(_INTL("OK, {1}! Come back!", battler.name))
            elsif battler.turnCount >= 5
                pbDisplayBrief(_INTL("{1}, that's enough! Come back!", battler.name))
            elsif battler.turnCount >= 2
                pbDisplayBrief(_INTL("{1}, come back!", battler.name))
            else
                pbDisplayBrief(_INTL("{1}, switch out! Come back!", battler.name))
            end
        else
            owner = pbGetOwnerName(battler.index)
            pbDisplayBrief(_INTL("{1} withdrew {2}!", owner, battler.name))
        end
    end

    # Only called from def pbRecallAndReplace and Battle Arena's def pbSwitch.
    def pbMessagesOnReplace(idxBattler, idxParty)
        party = pbParty(idxBattler)
        newPkmnName = party[idxParty].name
        if party[idxParty].ability == :ILLUSION
            new_index = pbLastInTeam(idxBattler)
            newPkmnName = party[new_index].name if new_index >= 0 && new_index != idxParty
        end
        if pbOwnedByPlayer?(idxBattler)
            opposing = @battlers[idxBattler].pbDirectOpposing
            if opposing.fainted? || opposing.hp == opposing.totalhp
                pbDisplayBrief(_INTL("You're in charge, {1}!", newPkmnName))
            elsif opposing.hp >= opposing.totalhp / 2
                pbDisplayBrief(_INTL("Go for it, {1}!", newPkmnName))
            elsif opposing.hp >= opposing.totalhp / 4
                pbDisplayBrief(_INTL("Just a little more! Hang in there, {1}!", newPkmnName))
            else
                pbDisplayBrief(_INTL("Your opponent's weak! Get 'em, {1}!", newPkmnName))
            end
        else
            owner = pbGetOwnerFromBattlerIndex(idxBattler)
            pbDisplayBrief(_INTL("{1} sent out {2}!", owner.full_name, newPkmnName))
        end
    end

    # Only called from def pbRecallAndReplace above and Battle Arena's def
    # pbSwitch.
    def pbReplace(idxBattler, idxParty, batonPass = false)
        party = pbParty(idxBattler)
        idxPartyOld = @battlers[idxBattler].pokemonIndex
        # Initialise the new Pokémon
        @battlers[idxBattler].pbInitialize(party[idxParty], idxParty, batonPass)
        # Reorder the party for this battle
        partyOrder = pbPartyOrder(idxBattler)
        partyOrder[idxParty], partyOrder[idxPartyOld] = partyOrder[idxPartyOld], partyOrder[idxParty]
        # Send out the new Pokémon
        pbSendOut([[idxBattler, party[idxParty]]])
        pbCalculatePriority(false, [idxBattler]) if Settings::RECALCULATE_TURN_ORDER_AFTER_SPEED_CHANGES
        if @battlers[idxBattler].boss?
            scene.deleteDataBoxes
            scene.createDataBoxes
            eachBattler do |b|
                databox = scene.sprites["dataBox_#{b.index}"]
                databox.visible = true
            end
        end
    end

    # Called from def pbReplace above and at the start of battle.
    # sendOuts is an array; each element is itself an array: [idxBattler,pkmn]
    def pbSendOut(sendOuts, startBattle = false)
        sendOuts.each { |b| @peer.pbOnEnteringBattle(self, b[1]) }
        @scene.pbSendOutBattlers(sendOuts, startBattle) unless @autoTesting
        sendOuts.each do |b|
            @scene.pbResetMoveIndex(b[0])
            pbSetSeen(@battlers[b[0]])
            @usedInBattle[b[0] & 1][b[0] / 2] = true
        end
    end

    #=============================================================================
    # Effects upon a Pokémon entering battle
    #=============================================================================
    # Called at the start of battle only.
    def pbOnActiveAll
        # Neutralizing Gas activates before anything.
        pbPriorityNeutralizingGas
        # Weather-inducing abilities, Trace, Imposter, etc.
        pbCalculatePriority(true)
        pbPriority(true).each do |b|
            b.pbEffectsOnSwitchIn(true)
            triggerBattlerEnterDialogue(b)
        end
        pbCalculatePriority
        # Check forms are correct
        eachBattler { |b| b.pbCheckForm }
    end

    # Called at the start of battle only; Neutralizing Gas activates before anything.
    def pbPriorityNeutralizingGas
        eachBattler do |b|
            next if !b || b.fainted?
            if b.hasActiveNeutralizingGas?
                BattleHandlers.triggerAbilityOnSwitchIn(:NEUTRALIZINGGAS, b, self)
                return
            end
        end
    end

    def getTypedHazardHPRatio(hazardType, type1, type2 = nil, type3 = nil)
        eff = Effectiveness.calculate(hazardType, type1, type2, type3)
        effectivenessMult = eff.to_f / Effectiveness::NORMAL_EFFECTIVE
        return effectivenessMult / 8.0
    end

    # Called when a Pokémon switches in (entry effects, entry hazards).
    def pbOnActiveOne(battler)
        return false if battler.fainted?

        # Trigger enter the field curses
        curses.each do |curse|
            triggerBattlerEnterCurseEffect(curse, battler, self)
        end

        # Record money-doubling effect of Amulet Coin/Luck Incense
        @field.applyEffect(:AmuletCoin) if !battler.opposes? && battler.hasItem?(%i[AMULETCOIN LUCKINCENSE])

        # Record money-doubling effect of Fortune ability
        @field.applyEffect(:Fortune) if !battler.opposes? && battler.hasActiveAbility?(:FORTUNE)

        # Record money-doubling effect of Bliss ability
        @field.applyEffect(:Bliss) if !battler.opposes? && battler.hasActiveAbility?(:BLISS)

        # Reset poison ticking up
        battler.resetStatusCount(:POISON)

        # Update battlers' participants (who will gain Exp/EVs when a battler faints)
        eachBattler { |b| b.pbUpdateParticipants }

        # Note its switching in this turn
        battler.applyEffect(:SwitchedIn)

        # Perform procs from battlers entering into a position
        position = @positions[battler.index]
        position.eachEffect(true) do |effect, _value, data|
            position.battlerEntry(effect) if data.has_entry_proc?
        end

        # Perform procs from battlers entering into a side
        side = @sides[battler.index % 2]
        side.eachEffect(true) do |effect, _value, data|
            side.battlerEntry(effect, battler.index % 2) if data.has_entry_proc?
        end

        # Type applying spike hazards
        unless battler.airborne?
            battler.pbOwnSide.eachEffect(true) do |effect, _value, data|
                next unless data.is_status_hazard?
                hazardInfo = data.type_applying_hazard
                status = hazardInfo[:status]

                if hazardInfo[:absorb_proc].call(battler)
                    battler.pbOwnSide.disableEffect(effect)
                    pbDisplay(_INTL("{1} absorbed the {2}!", battler.pbThis, data.real_name))
                elsif battler.pbCanInflictStatus?(status, nil, false) && !battler.ignoresHazards? && !battler.immuneToHazards?
                    if battler.pbOwnSide.countEffect(effect) >= 2
                        battler.pbInflictStatus(status)
                    elsif battler.takesIndirectDamage?
                        pbDisplay(_INTL("{1} was hurt by the thin layer of {2}!", battler.pbThis, data.real_name))
                        if battler.applyFractionalDamage(1.0 / 16.0, true, false, true)
                            return pbOnActiveOne(battler) # For replacement battler
                        end
                    end
                end
            end
        end

        unless battler.ignoresHazards?
            # Stealth Rock
            if battler.pbOwnSide.effectActive?(:StealthRock) && battler.takesIndirectDamage? && !battler.immuneToHazards? && GameData::Type.exists?(:ROCK)
                bTypes = battler.pbTypes(true)
                getTypedHazardHPRatio = getTypedHazardHPRatio(:ROCK, bTypes[0], bTypes[1], bTypes[2])
                if getTypedHazardHPRatio > 0
                    pbDisplay(_INTL("Pointed stones dug into {1}!", battler.pbThis(true)))
                    if battler.applyFractionalDamage(getTypedHazardHPRatio, true, false, true)
                        return pbOnActiveOne(battler) # For replacement battler
                    end
                end
            end

            # Feather Ward
            if battler.pbOwnSide.effectActive?(:FeatherWard) && battler.takesIndirectDamage? && !battler.immuneToHazards? && GameData::Type.exists?(:STEEL)
                bTypes = battler.pbTypes(true)
                getTypedHazardHPRatio = getTypedHazardHPRatio(:STEEL, bTypes[0], bTypes[1], bTypes[2])
                if getTypedHazardHPRatio > 0
                    pbDisplay(_INTL("Sharp feathers dug into {1}!", battler.pbThis(true)))
                    if battler.applyFractionalDamage(getTypedHazardHPRatio, true, false, true)
                        return pbOnActiveOne(battler) # For replacement battler
                    end
                end
            end

            # Ground-based hazards
            if !battler.fainted? && !battler.immuneToHazards? && !battler.airborne?
                # Spikes
                if battler.pbOwnSide.effectActive?(:Spikes) && battler.takesIndirectDamage?
                    spikesIndex = battler.pbOwnSide.countEffect(:Spikes) - 1
                    spikesDiv = [8, 4][spikesIndex]
                    # spikesDiv = [8,6,4][spikesIndex]
                    spikesHPRatio = 1.0 / spikesDiv.to_f
                    layerLabel = ["layer", "2 layers", "3 layers"][spikesIndex]
                    pbDisplay(_INTL("{1} is hurt by the {2} of spikes!", battler.pbThis, layerLabel))
                    battler.pbItemHPHealCheck
                    if battler.applyFractionalDamage(spikesHPRatio, true, false, true)
                        return pbOnActiveOne(battler) # For replacement battler
                    end
                end

                # Sticky Web
                if battler.pbOwnSide.effectActive?(:StickyWeb)
                    pbDisplay(_INTL("{1} was caught in a sticky web!", battler.pbThis))
                    battler.pbItemStatRestoreCheck if battler.tryLowerStat(:SPEED, nil, increment: 2)
                end
            end
        end

        # None, currently
        eachOtherSideBattler(battler.index) do |enemy|
            enemy.eachActiveAbility do |ability|
                BattleHandlers.triggerAbilityOnEnemySwitchIn(ability, battler, enemy, self)
            end
        end

        # Battler faints if it is knocked out because of an entry hazard above
        if battler.fainted?
            battler.pbFaint
            pbGainExp
            pbJudge
            return false
        end

        battler.pbCheckForm
        triggerBattlerEnterDialogue(battler)
        return true
    end
end
