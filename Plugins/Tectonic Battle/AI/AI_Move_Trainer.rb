class PokeBattle_AI
    def pbChooseMovesTrainer(idxBattler, choices)
        user = @battle.battlers[idxBattler]
        owner = @battle.pbGetOwnerFromBattlerIndex(user.index)
        policies = owner.policies || []

        # Log the available choices
        logMoveChoices(user, choices)

        # If there are valid choices, pick among them
        if choices.length > 0
            # Determine the most preferred move
            sortedChoices = choices.sort_by { |choice| -choice[1] }
            preferredChoice = sortedChoices[0]
            PBDebug.log("[AI] #{user.pbThis} (#{user.index}) thinks #{user.moves[preferredChoice[0]].name} is the highest rated choice")
            unless preferredChoice.nil?
                @battle.pbRegisterMove(idxBattler, preferredChoice[0], false)
                @battle.pbRegisterTarget(idxBattler, preferredChoice[2]) if preferredChoice[2] >= 0
            end
        else # If there are no calculated choices, create a list of the choices all scored the same, to be chosen between randomly later on
            PBDebug.log("[AI] #{user.pbThis} (#{user.index}) scored no moves above a zero, resetting all choices to default")
            user.eachMoveWithIndex do |m, i|
                next unless @battle.pbCanChooseMove?(user, i, false)
                next if m.empoweredMove?
                choices.push([i, 100, -1]) # Move index, score, target
            end
            if choices.length == 0 # No moves are physically possible to use; use Struggle
                @battle.pbAutoChooseMove(user.index)
            end
        end

        # if there is somehow still no choice, randomly choose a move from the choices and register it
        if @battle.choices[idxBattler][2].nil?
            echoln("All AI protocols have failed or fallen through, picking at random.")
            randomChoice = choices.sample
            @battle.pbRegisterMove(idxBattler, randomChoice[0], false)
            @battle.pbRegisterTarget(idxBattler, randomChoice[2]) if randomChoice[2] >= 0
        end

        # Log the result
        if @battle.choices[idxBattler][2]
            user.lastMoveChosen = @battle.choices[idxBattler][2].id
            PBDebug.log("[AI] #{user.pbThis} (#{user.index}) will use #{@battle.choices[idxBattler][2].name}")
        end
    end

    # Returns an array filled with each move that has a target worth using against
    # Giving also the best target to use the move against and the score of doing so
    def pbGetBestTrainerMoveChoices(user, opposingBattler: nil, killInfoArray: [])
        choices = []
        bestKillInfo = nil
        user.eachAIKnownMoveWithIndex do |move, i|
            next unless @battle.pbCanChooseMove?(user, i, false)
            targets = []
            targets.push(opposingBattler) if opposingBattler
            newChoice,killInfo = pbEvaluateMoveTrainer(user, move, targets: targets, killInfoArray: killInfoArray)
            
            # If the move would kill the opposing battler, mark as such
            # But only if its better than any kill seen thus far
            if killInfo && opposingBattler
                if bestKillInfo
                    if killInfo.priority > bestKillInfo.priority
                        bestKillInfo = killInfo
                    elsif killInfo.priority == bestKillInfo.priority && killInfo.speed > bestKillInfo.speed
                        bestKillInfo = killInfo
                    elsif killInfo.score == bestKillInfo.score
                        bestKillInfo = killInfo
                    end
                else
                    bestKillInfo = killInfo
                end
            end
            # Push a new array of [moveIndex,moveScore,targetIndex]
            # where targetIndex could be -1 for anything thats not single target
            choices.push([i].concat(newChoice)) if newChoice
        end
        return choices,bestKillInfo
    end

    def pbEvaluateMoveTrainer(user, move, targets: [], killInfoArray: [])
        policies = user.ownersPolicies
        target_data = move.pbTarget(user)
        newChoice = nil
        ignoreGeneralEffectScores = !targets.empty?
        killInfo = nil
        if target_data.num_targets > 1
            # If move affects multiple battlers and you don't choose a particular one
            totalScore = 0
            if targets.empty?
                @battle.eachBattler do |b|
                    next unless @battle.pbMoveCanTarget?(user.index, b.index, target_data)
                    targets.push(b)
                end
            end
            targets.each do |b|
                score,targetKillInfo = pbGetMoveScore(move, user, b, policies, targets.length, ignoreGeneralEffectScores, killInfoArray)
                if user.opposes?(b)
                    totalScore += score
                    killInfo = targetKillInfo
                else
                    next if policies.include?(:EQ_PROTECT) && b.canChooseProtect?
                    totalScore -= score
                end
            end
            newChoice = [totalScore, -1] if totalScore > 0
        elsif target_data.num_targets == 0
            if targets.empty?
                # If move has no targets, affects the user, a side or the whole field
                score,targetKillInfo = pbGetMoveScore(move, user, user, policies, 0, ignoreGeneralEffectScores, killInfoArray)
                newChoice = [score, -1] if score > 0
            end
        else
            # If move affects one battler and you have to choose which one
            scoresAndTargets = []
            if targets.empty?
                @battle.eachBattler do |b|
                    next unless @battle.pbMoveCanTarget?(user.index, b.index, target_data)
                    next if target_data.targets_foe && !user.opposes?(b)
                    score,targetKillInfo = pbGetMoveScore(move, user, b, policies, 1, ignoreGeneralEffectScores, killInfoArray)
                    scoresAndTargets.push([score, b.index, nil]) if score > 0
                end
            else
                targets.each do |b|
                    next unless @battle.pbMoveCanTarget?(user.index, b.index, target_data)
                    next if target_data.targets_foe && !user.opposes?(b)
                    score,targetKillInfo = pbGetMoveScore(move, user, b, policies, 1, ignoreGeneralEffectScores, killInfoArray)
                    scoresAndTargets.push([score, b.index, targetKillInfo]) if score > 0
                end
            end
            if scoresAndTargets.length > 0
                # Get the one best target for the move
                scoresAndTargets.sort! { |a, b| b[0] <=> a[0] }
                bestTargetChoice = scoresAndTargets[0]
                newChoice = [bestTargetChoice[0], bestTargetChoice[1]]
                killInfo = bestTargetChoice[2]
            end
        end
        return newChoice,killInfo
    end

    #=============================================================================
    # Get a score for the given move being used against the given target
    # Threat array is an array of entries like so: [Foe that can kill, move that kills, their speed, priority of the killing move]
    #=============================================================================
    def pbGetMoveScore(move, user, target, policies = [], numTargets = 1, ignoreGeneralEffectScores = false, killInfoArray = [])
        scoringKey = [move.id, user.personalID, target.personalID, numTargets, ignoreGeneralEffectScores, killInfoArray]
        if @precalculatedChoices.key?(scoringKey)
            precalcedScore,precalcedKillInfo = @precalculatedChoices[scoringKey]
            if precalcedKillInfo
                echoln("[MOVE SCORING] Score for #{user.pbThis(true)}'s #{move.id} against target #{target.pbThis(true)} already calced this round: #{precalcedScore} (will faint the target)")
            else
                echoln("[MOVE SCORING] Score for #{user.pbThis(true)}'s #{move.id} against target #{target.pbThis(true)} already calced this round: #{precalcedScore}")
            end
            return precalcedScore,precalcedKillInfo
        end

        echoln("[MOVE SCORING] Scoring #{user.pbThis(true)}'s #{move.id} against target #{target.pbThis(true)}:")
        
        move.calculated_category = move.calculateCategory(user, [target])
        move.calcType = move.pbCalcType(user)

        if aiPredictsFailure?(move, user, target, false)
            @precalculatedChoices[scoringKey] = 0
            return 0,nil
        end
        
        switchPredicted = @battle.aiPredictsSwitch?(user,target.index,true)

        # DAMAGE SCORE AND HIT TRIGGERS SCORE
        damageDealt = 0
        damageScore = 0
        triggersScore = 0
        willFaint = false
        damagingMove = move.damagingMove?(true)
        if damagingMove
            # Adjust the score based on the move dealing damage
            # and perhaps a percent chance to actually benefit from its effect score
            begin
                damageScore,damageDealt,willFaint = pbGetMoveScoreDamage(move, user, target, numTargets)
            rescue StandardError => exception
                pbPrintException($!) if $DEBUG
            end

            numHits = move.numberOfHits(user, [target], true).ceil

            # Account for triggered abilities of the user
            begin
                scoreModifierUserAbility = 0
                user.eachAIKnownActiveAbility do |ability|
                    scoreModifierUserAbility += 
                        BattleHandlers.triggerUserAbilityOnHitAI(ability, user, target, move, @battle, numHits)
                end
                triggersScore += scoreModifierUserAbility
                echoln("\t[MOVE SCORING] #{user.pbThis}'s #{numHits} hits adjusts the score by #{scoreModifierUserAbility} due to the user's abilities") if scoreModifierUserAbility != 0
            rescue StandardError => exception
                pbPrintException($!) if $DEBUG
            end

            # Account for the triggered abilities of the target
            if user.activatesTargetAbilities?(true)
                begin
                    scoreModifierTargetAbility = 0
                    target.eachAIKnownActiveAbility do |ability|
                        scoreModifierTargetAbility += 
                            BattleHandlers.triggerTargetAbilityOnHitAI(ability, user, target, move, @battle, numHits)
                    end
                    triggersScore += scoreModifierTargetAbility
                    echoln("\t[MOVE SCORING] #{numHits} hits adjusts the score by #{scoreModifierTargetAbility} due to the target's abilities") if scoreModifierTargetAbility != 0
                rescue StandardError => exception
                    pbPrintException($!) if $DEBUG
                end
            end

            # Account for the items of the target
            unless user.hasActiveItem?(:PROXYFIST)
                begin
                    scoreModifierTargetItem = 0
                    target.eachActiveItem do |item|
                        scoreModifierTargetItem += 
                            BattleHandlers.triggerTargetItemOnHitAI(item, user, target, move, @battle, numHits)
                    end
                    triggersScore += scoreModifierTargetItem
                    echoln("\t[MOVE SCORING] #{numHits} hits adjusts the score by #{scoreModifierTargetItem} due to the target's items") if scoreModifierTargetItem != 0
                rescue StandardError => exception
                    pbPrintException($!) if $DEBUG
                end
            end
            triggersScore = triggersScore.floor
        end

        # EFFECT SCORING
        effectScore = 0
        begin
            regularEffectScore = 0
            regularEffectScore += move.getEffectScore(user, target) unless ignoreGeneralEffectScores
            faintEffectScore = 0
            targetAffectingEffectScore = 0
            if willFaint
                faintEffectScore = move.getFaintEffectScore(user, target)
            elsif !target.substituted? || move.ignoresSubstitute?(user)
                targetAffectingEffectScore = move.getTargetAffectingEffectScore(user, target)
            end
            damageBasedEffectScore = move.getDamageBasedEffectScore(user, target, damageDealt)
            effectScore += regularEffectScore
            effectScore += faintEffectScore
            effectScore += targetAffectingEffectScore
            effectScore += damageBasedEffectScore
        rescue StandardError => e
            echoln("FAILURE IN THE SCORING SYSTEM FOR MOVE #{move.id} #{move.function}")
            effectScore = 0
            raise e if @battle.autoTesting
        end

        # Modify the effect score by the move's additional effect chance if it has one
        if move.randomEffect?
            type = pbRoughType(move, user)
            realProcChance = move.pbAdditionalEffectChance(user, target, type, 0, true)
            realProcChance = 0 unless move.canApplyRandomAddedEffects?(user,target,false,true)
            factor = (realProcChance / 100.0)
            echoln("\t[MOVE SCORING] #{user.pbThis} multiplies #{move.id}'s effect score of #{effectScore} by #{factor} based on effect chance")
            effectScore *= factor
        end
        effectScore = effectScore.floor

        # Combine
        score = damageScore + triggersScore + effectScore
        if damagingMove
            echoln("\t[MOVE SCORING] Main total score #{score} from a damage score of #{damageScore}, an effect score of #{effectScore}, and a triggers score of #{triggersScore}")
        else
            echoln("\t[MOVE SCORING] Main total score #{score} from an effect score of #{effectScore}, and a triggers score of #{triggersScore}")
        end

        # ! All score changes from this point forward must be multiplicative !

        # Pick a good move for the Choice items
        if !damagingMove && (user.hasActiveItem?(CHOICE_LOCKING_ITEMS) || user.hasActiveAbilityAI?(CHOICE_LOCKING_ABILITIES))
            echoln("\t[MOVE SCORING] Score is halved: Don't choice-lock into a status move.")
            score /= 2
        end

        # Account for accuracy of move
        accuracy = pbRoughAccuracy(move, user, target)
        score *= accuracy / 100.0

        if accuracy < 100
            echoln("\t[MOVE SCORING] Predicted accuracy: #{accuracy}")
        end

        # If they might kill us this turn, rate this move much less unless it will go before the target
        if !switchPredicted && !killInfoArray.empty?
            killInfoArray.each do |killInfo|
                next if userMovesFirst?(move, user, target, killInfo: killInfo)
                echoln("\t[MOVE SCORING] Halving score since #{killInfo.user.pbThis(true)} may kill it this turn with #{killInfo.move.id} beforehand")
                score *= 0.5
            end
        end

        # Account for some abilities
        score = getMultiplicativeAbilityScore(score, move, user, target)

        # Final adjustments t score
        score = score.to_i
        score = 0 if score < 0
        echoln("\t[MOVE SCORING] Final score for #{user.pbThis}'s #{move.id} against target #{target.pbThis(true)}: #{score}")
        
        # Create kill info
        if willFaint
            killInfo = KillInfo.new(user,move,user.pbSpeed(true),@battle.getMovePriority(move, user, [target], true), score)
        else
            killInfo = nil
        end
        
        @precalculatedChoices[scoringKey] = [score,killInfo]
        return score,killInfo
    end

    def getMultiplicativeAbilityScore(score, move, user, target)
        if move.danceMove?
            dancerBonus = 1.0
            user.eachOther do |b|
                next unless b.hasActiveAbilityAI?(:DANCER)
                if b.opposes?(user)
                    dancerBonus -= 0.8
                else
                    dancerBonus += 0.8
                end
            end
            score *= dancerBonus
        end

        if move.soundMove?
            dancerBonus = 1.0
            user.eachOther do |b|
                next unless b.hasActiveAbilityAI?(:ECHO)
                if b.opposes?(user)
                    dancerBonus -= 0.8
                else
                    dancerBonus += 0.8
                end
            end
            score *= dancerBonus
        end

        return score
    end

    #=============================================================================
    # Add to a move's score based on how much damage it will deal (as a percentage
    # of the target's current HP)
    #=============================================================================
    def pbGetMoveScoreDamage(move, user, target, numTargets = 1)
        realDamage,damagePercentage = getDamageAnalysisAI(move, user, target, numTargets)

        # Adjust score
        willFaint = false
        if realDamage >= target.hp
            realDamage = target.hp
            damageScore = 250
            willFaint = true
        else
            # Only care about KO thresholds
            if damagePercentage >= 50
                damageScore = 150 + (damagePercentage - 50)
            elsif damagePercentage >= 33
                damageScore = 100 + (damagePercentage - 33)
            else
                damageScore = 50 + damagePercentage
            end
        end
        damageScore *= 0.7 if target.allyHasRedirectionMove?
        damageScore = damageScore.floor

        return damageScore,realDamage,willFaint
    end

    def getDamageAnalysisAI(move, user, target, numTargets = 1)
        # Calculate how much damage the move will do (roughly)
        realDamage = pbTotalDamageAI(move, user, target, numTargets)

        if playerTribalBonus.hasTribeBonus?(:DECEIVER)
            realDamage *= 1.5
            echoln("\t[MOVE SCORING] #{user.pbThis} is overestimating its damage by 50 percent due to the deceiver tribal bonus")
        end

        # Convert damage to percentage of target's remaining HP
        damagePercentage = realDamage * 100.0 / target.totalhp

        if realDamage >= target.hp
            echoln("\t[MOVE SCORING] #{user.pbThis} thinks that move #{move.id} will deal #{realDamage} damage to #{target.pbThis(true)}, fainting it")
        else
            healthChange,eotDamagePercent = passingTurnBattlerHealthChange(target,@battle)
            realDamage += healthChange
            damagePercentage += eotDamagePercent
            echoln("\t[MOVE SCORING] #{user.pbThis} thinks that move #{move.id} will deal #{realDamage} damage -- #{damagePercentage.round(1)} percent of #{target.pbThis(true)}'s HP.")
            echoln("\t[MOVE SCORING] Additionally, target's HP will change #{eotDamagePercent} percent EOT.") unless eotDamagePercent == 0
        end

        return realDamage,damagePercentage
    end
end
