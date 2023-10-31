ABILITY_MASS_RENAME_1 = [
    :SEALORD,
    :DUNEPREDATOR,
    :DAWNBURST,
    :SWARMIMPACT,
    :PLAYVICTIM,
    :ALLYCUSHION,
    :AQUASNEAK,
    :WARMTHCYCLE,
    :BALANCEOFPOWER,
    :SHARPNESS,
    :FROSTSONG,
    :WINDY,
    :CLEAVING,
    :SUPERSTITIOUS,
    :INFINITESOURCE,
    :DRAGONSCALES,
    :TOTALMIRROR,
    :MORPHINGGUARD,
    :EROSIONCYCLE,
    :NINJUTSU,
    :SELFMENDING,
    :ODDAURA,
    :PUZZLINGAURA,
    :QUALITYAURA,
    :WHIRLER,
    :AQUAPROPULSION,
    :WINDBUFFER,
    :HONORAURA,
    :SEASURVIVOR,
    :JASPERCHARGE,
    :PLASMABALL,
    :KLUMSYKINESIS,
    :PROVING,
    :ENERGYDRAIN,
    :OVERACTING,
    :WELLSUPPLIED,
    :EXTREMEENERGY,
    :DULL,
    :GRAVITATIONAL,
    :WILLBREAK,
    :GUARDBREAK,
    :GROWUP,
    :HEARTENINGAROMA,
    :GREEDYGUTS,
    :GRASSYSPIRIT,
    :WINTERWISDOM,
    :POLARHUNTER,
    :TRICKSTER,
    :TAIGATRECKER,
    :CRAGTERROR,
    :SANDDEMON,
    :SANDDRILLING,
    :WEAKSPIRIT,
    :HARSHTRAINING,
    :LUNARCLEANSING,
    :MOONBUBBLE,
    :METALCOVER,
    :VIBRATIONAL,
    :GENERATOR,
    :TOXICCLOUD,
    :WEREWOLF,
    :NIGHTLIGHT,
    :MENDINGTONES,
    :CALAMITY,
    :TOTALGRASP,
    :TIMESTRETCH,
    :LOCOMOTION,
    :SANDSTRENGTH,
    :LUNARLOYALTY,
    :BLIZZBOXER,
    :ENERGYUP,
    :POWERUP,
    :ACCLIMATIZE,
    :BATTERYBREAK,
    :PRECHARGED,
    :SUPERFIST,
    :RESONANCE,
    :SHATTERING,
    :HEALINGHOPE,
    :SNORING,
    :PITTING,
    :TOXICSPIRIT,
    :CREEPINGSTRENGTH,
    :ROYALVOICE,
    :SHRIEKING,
    :SMOKEREFLEX,
    :EVOARMOR,
    :DIGGINGFIST,
    :ALOOF,
    :RUSTYANCHOR,
    :RAMMINGSPEED,
    :APATHETIC,
    :PAINPRESENCE,
    :PAINDELAY,
    :ENGORGE,
    :SLEEPSNARE,
    :TENDRILTRAP,
    :SKYHAZARD,
    :LEGSTRENGTH,
    :QUICKKICKS,
    :RUSHED,
    :MALINGERING,
    :CAUTIONARY,
    :POURINGHEART,
    :ADAMANTITE,
    # etc...
]

SaveData.register_conversion(:move_renaming_0) do
    game_version '3.0.4'
    display_title '3.0.4 ability renames'
    to_all do |save_data|
        silentlyFixBrokenAbilitiesInList(save_data,ABILITY_MASS_RENAME_1)
    end
end

def silentlyFixBrokenAbilitiesInList(save_data,abilityList)
    eachPokemonInSave(save_data) do |pokemon,_location|
      next unless abilityList.include?(pokemon.ability_id)
      pokemon.recalculateAbilityFromIndex
    end
end