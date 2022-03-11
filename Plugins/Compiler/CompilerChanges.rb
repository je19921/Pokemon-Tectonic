module Compiler
	module_function
	
  def main
    return if !$DEBUG
    begin
      dataFiles = [
         "berry_plants.dat",
         "encounters.dat",
         "form2species.dat",
         "items.dat",
         "map_connections.dat",
         "metadata.dat",
         "moves.dat",
         "phone.dat",
         "regional_dexes.dat",
         "ribbons.dat",
         "shadow_movesets.dat",
         "species.dat",
         "species_eggmoves.dat",
         "species_evolutions.dat",
         "species_metrics.dat",
         "species_movesets.dat",
		 "species_old.dat",
         "tm.dat",
         "town_map.dat",
         "trainer_lists.dat",
         "trainer_types.dat",
         "trainers.dat",
         "types.dat",
		 "policies.dat",
		 "avatars.dat"
      ]
      textFiles = [
         "abilities.txt",
         "berryplants.txt",
         "connections.txt",
         "encounters.txt",
         "items.txt",
         "metadata.txt",
         "moves.txt",
         "phone.txt",
         "pokemon.txt",
		 "pokemon_old.txt",
         "pokemonforms.txt",
         "regionaldexes.txt",
         "ribbons.txt",
         "shadowmoves.txt",
         "townmap.txt",
         "trainerlists.txt",
         "trainers.txt",
         "trainertypes.txt",
         "types.txt",
		 "policies.txt",
		 "avatars.txt"
      ]
      latestDataTime = 0
      latestTextTime = 0
      mustCompile = false
      # Should recompile if new maps were imported
      mustCompile |= import_new_maps
      # If no PBS file, create one and fill it, then recompile
      if !safeIsDirectory?("PBS")
        Dir.mkdir("PBS") rescue nil
        write_all
        mustCompile = true
      end
      # Check data files and PBS files, and recompile if any PBS file was edited
      # more recently than the data files were last created
      dataFiles.each do |filename|
        next if !safeExists?("Data/" + filename)
        begin
          File.open("Data/#{filename}") { |file|
            latestDataTime = [latestDataTime, file.mtime.to_i].max
          }
        rescue SystemCallError
          mustCompile = true
        end
      end
      textFiles.each do |filename|
        next if !safeExists?("PBS/" + filename)
        begin
          File.open("PBS/#{filename}") { |file|
            latestTextTime = [latestTextTime, file.mtime.to_i].max
          }
        rescue SystemCallError
        end
      end
      mustCompile |= (latestTextTime >= latestDataTime)
      # Should recompile if holding Ctrl
      Input.update
      mustCompile = true if Input.press?(Input::CTRL)
      # Delete old data files in preparation for recompiling
      if mustCompile
        for i in 0...dataFiles.length
          begin
            File.delete("Data/#{dataFiles[i]}") if safeExists?("Data/#{dataFiles[i]}")
          rescue SystemCallError
          end
        end
      end
      # Recompile all data
      compile_all(mustCompile) { |msg| pbSetWindowText(msg); echoln(msg) }
    rescue Exception
      e = $!
      raise e if "#{e.class}"=="Reset" || e.is_a?(Reset) || e.is_a?(SystemExit)
      pbPrintException(e)
      for i in 0...dataFiles.length
        begin
          File.delete("Data/#{dataFiles[i]}")
        rescue SystemCallError
        end
      end
      raise Reset.new if e.is_a?(Hangup)
      loop do
        Graphics.update
      end
    end
  end
	
  #=============================================================================
  # Compile all data
  #=============================================================================
  def compile_all(mustCompile)
    FileLineData.clear
    if (!$INEDITOR || Settings::LANGUAGES.length < 2) && safeExists?("Data/messages.dat")
      MessageTypes.loadMessageFile("Data/messages.dat")
    end
    if mustCompile
      echoln _INTL("*** Starting full compile ***")
      echoln ""
      yield(_INTL("Compiling town map data"))
      compile_town_map               # No dependencies
      yield(_INTL("Compiling map connection data"))
      compile_connections            # No dependencies
      yield(_INTL("Compiling phone data"))
      compile_phone
      yield(_INTL("Compiling type data"))
      compile_types                  # No dependencies
      yield(_INTL("Compiling ability data"))
      compile_abilities              # No dependencies
      yield(_INTL("Compiling move data"))
      compile_moves                  # Depends on Type
      yield(_INTL("Compiling item data"))
      compile_items                  # Depends on Move
      yield(_INTL("Compiling berry plant data"))
      compile_berry_plants           # Depends on Item
      yield(_INTL("Compiling Pokémon data"))
      compile_pokemon                # Depends on Move, Item, Type, Ability
      yield(_INTL("Compiling Pokémon forms data"))
      compile_pokemon_forms          # Depends on Species, Move, Item, Type, Ability
      yield(_INTL("Compiling Old Pokémon data"))
      compile_pokemon_old                # Depends on Move, Item, Type, Ability
	  yield(_INTL("Compiling machine data"))
      compile_move_compatibilities   # Depends on Species, Move
      yield(_INTL("Compiling shadow moveset data"))
      compile_shadow_movesets        # Depends on Species, Move
      yield(_INTL("Compiling Regional Dexes"))
      compile_regional_dexes         # Depends on Species
      yield(_INTL("Compiling ribbon data"))
      compile_ribbons                # No dependencies
      yield(_INTL("Compiling encounter data"))
      compile_encounters             # Depends on Species
	  yield(_INTL("Compiling Trainer policy data"))
	  compile_trainer_policies
      yield(_INTL("Compiling Trainer type data"))
      compile_trainer_types          # No dependencies
      yield(_INTL("Compiling Trainer data"))
      compile_trainers               # Depends on Species, Item, Move
      yield(_INTL("Compiling battle Trainer data"))
      compile_trainer_lists          # Depends on TrainerType
	  yield(_INTL("Compiling Avatar battle data"))
	  compile_avatars				 # Depends on Species, Item, Move
      yield(_INTL("Compiling metadata"))
      compile_metadata               # Depends on TrainerType
      yield(_INTL("Compiling animations"))
      compile_animations
      yield(_INTL("Converting events"))
      compile_events
      yield(_INTL("Saving messages"))
      pbSetTextMessages
      MessageTypes.saveMessages
      echoln ""
      echoln _INTL("*** Finished full compile ***")
      echoln ""
      System.reload_cache
    end
    pbSetWindowText(nil)
  end
  
  #=============================================================================
  # Compile Pokémon data
  #=============================================================================
  def compile_pokemon_old(path = "PBS/pokemon_old.txt")
    GameData::SpeciesOld::DATA.clear
    species_names           = []
    species_form_names      = []
    species_categories      = []
    species_pokedex_entries = []
    # Read from PBS file
    File.open(path, "rb") { |f|
      FileLineData.file = path   # For error reporting
      # Read a whole section's lines at once, then run through this code.
      # contents is a hash containing all the XXX=YYY lines in that section, where
      # the keys are the XXX and the values are the YYY (as unprocessed strings).
      schema = GameData::SpeciesOld.schema
      pbEachFileSection(f) { |contents, species_number|
        FileLineData.setSection(species_number, "header", nil)   # For error reporting
        # Raise an error if a species number is invalid or used twice
        if species_number == 0
          raise _INTL("A Pokémon species can't be numbered 0 ({1}).", path)
        elsif GameData::SpeciesOld::DATA[species_number]
          raise _INTL("Species ID number '{1}' is used twice.\r\n{2}", species_number, FileLineData.linereport)
        end
        # Go through schema hash of compilable data and compile this section
        for key in schema.keys
          # Skip empty properties, or raise an error if a required property is
          # empty
          if nil_or_empty?(contents[key])
            if ["Name", "InternalName"].include?(key)
              raise _INTL("The entry {1} is required in {2} section {3}.", key, path, species_number)
            end
            contents[key] = nil
            next
          end
          # Raise an error if a species internal name is used twice
          FileLineData.setSection(species_number, key, contents[key])   # For error reporting
          if GameData::SpeciesOld::DATA[contents["InternalName"].to_sym]
            raise _INTL("Species ID '{1}' is used twice.\r\n{2}", contents["InternalName"], FileLineData.linereport)
          end
          # Compile value for key
          value = pbGetCsvRecord(contents[key], key, schema[key])
          value = nil if value.is_a?(Array) && value.length == 0
          contents[key] = value
          # Sanitise data
          case key
          when "BaseStats", "EffortPoints"
            value_hash = {}
            GameData::Stat.each_main do |s|
              value_hash[s.id] = value[s.pbs_order] if s.pbs_order >= 0
            end
            contents[key] = value_hash
          when "Height", "Weight"
            # Convert height/weight to 1 decimal place and multiply by 10
            value = (value * 10).round
            if value <= 0
              raise _INTL("Value for '{1}' can't be less than or close to 0 (section {2}, {3})", key, species_number, path)
            end
            contents[key] = value
          when "Moves"
            move_array = []
            for i in 0...value.length / 2
              move_array.push([value[i * 2], value[i * 2 + 1], i])
            end
            move_array.sort! { |a, b| (a[0] == b[0]) ? a[2] <=> b[2] : a[0] <=>b [0] }
            move_array.each { |arr| arr.pop }
            contents[key] = move_array
          when "TutorMoves", "EggMoves", "Abilities", "HiddenAbility", "Compatibility"
            contents[key] = [contents[key]] if !contents[key].is_a?(Array)
            contents[key].compact!
          when "Evolutions"
            evo_array = []
            for i in 0...value.length / 3
              evo_array.push([value[i * 3], value[i * 3 + 1], value[i * 3 + 2], false])
            end
            contents[key] = evo_array
          end
        end
        # Construct species hash
        species_symbol = contents["InternalName"].to_sym
        species_hash = {
          :id                    => species_symbol,
          :id_number             => species_number,
          :name                  => contents["Name"],
          :form_name             => contents["FormName"],
          :category              => contents["Kind"],
          :pokedex_entry         => contents["Pokedex"],
          :type1                 => contents["Type1"],
          :type2                 => contents["Type2"],
          :base_stats            => contents["BaseStats"],
          :evs                   => contents["EffortPoints"],
          :base_exp              => contents["BaseEXP"],
          :growth_rate           => contents["GrowthRate"],
          :gender_ratio          => contents["GenderRate"],
          :catch_rate            => contents["Rareness"],
          :happiness             => contents["Happiness"],
          :moves                 => contents["Moves"],
          :tutor_moves           => contents["TutorMoves"],
          :egg_moves             => contents["EggMoves"],
          :abilities             => contents["Abilities"],
          :hidden_abilities      => contents["HiddenAbility"],
          :wild_item_common      => contents["WildItemCommon"],
          :wild_item_uncommon    => contents["WildItemUncommon"],
          :wild_item_rare        => contents["WildItemRare"],
          :egg_groups            => contents["Compatibility"],
          :hatch_steps           => contents["StepsToHatch"],
          :incense               => contents["Incense"],
          :evolutions            => contents["Evolutions"],
          :height                => contents["Height"],
          :weight                => contents["Weight"],
          :color                 => contents["Color"],
          :shape                 => GameData::BodyShape.get(contents["Shape"]).id,
          :habitat               => contents["Habitat"],
          :generation            => contents["Generation"],
          :back_sprite_x         => contents["BattlerPlayerX"],
          :back_sprite_y         => contents["BattlerPlayerY"],
          :front_sprite_x        => contents["BattlerEnemyX"],
          :front_sprite_y        => contents["BattlerEnemyY"],
          :front_sprite_altitude => contents["BattlerAltitude"],
          :shadow_x              => contents["BattlerShadowX"],
          :shadow_size           => contents["BattlerShadowSize"]
        }
        # Add species' data to records
        GameData::SpeciesOld.register(species_hash)
        species_names[species_number]           = species_hash[:name]
        species_form_names[species_number]      = species_hash[:form_name]
        species_categories[species_number]      = species_hash[:category]
        species_pokedex_entries[species_number] = species_hash[:pokedex_entry]
      }
    }
    # Enumerate all evolution species and parameters (this couldn't be done earlier)
    GameData::SpeciesOld.each do |species|
      FileLineData.setSection(species.id_number, "Evolutions", nil)   # For error reporting
      Graphics.update if species.id_number % 200 == 0
      pbSetWindowText(_INTL("Processing {1} evolution line {2}", FileLineData.file, species.id_number)) if species.id_number % 50 == 0
      species.evolutions.each do |evo|
        evo[0] = csvEnumField!(evo[0], :Species, "Evolutions", species.id_number)
        param_type = GameData::Evolution.get(evo[1]).parameter
        if param_type.nil?
          evo[2] = nil
        elsif param_type == Integer
          evo[2] = csvPosInt!(evo[2])
        else
          evo[2] = csvEnumField!(evo[2], param_type, "Evolutions", species.id_number)
        end
      end
    end
    # Add prevolution "evolution" entry for all evolved species
    all_evos = {}
    GameData::SpeciesOld.each do |species|   # Build a hash of prevolutions for each species
      species.evolutions.each do |evo|
        all_evos[evo[0]] = [species.species, evo[1], evo[2], true] if !all_evos[evo[0]]
      end
    end
    GameData::SpeciesOld.each do |species|   # Distribute prevolutions
      species.evolutions.push(all_evos[species.species].clone) if all_evos[species.species]
    end
    # Save all data
    GameData::SpeciesOld.save
    Graphics.update
  end
  
  def compile_trainer_policies(path = "PBS/policies.txt")
	GameData::Policy::DATA.clear
    # Read each line of policies.txt at a time and compile it into a trainer type
    pbCompilerEachCommentedLine(path) { |line, line_no|
	  line = pbGetCsvRecord(line, line_no, [0, "*n"])
      policy_symbol = line[0].to_sym
      if GameData::Policy::DATA[policy_symbol]
        raise _INTL("Trainer policy ID '{1}' is used twice.\r\n{2}", policy_symbol, FileLineData.linereport)
      end
      # Construct trainer type hash
      policy_hash = {
        :id          => policy_symbol,
      }
      # Add trainer policy's data to records
      GameData::Policy.register(policy_hash)
    }
    # Save all data
    GameData::Policy.save
    Graphics.update
  end
  
  def pbEachAvatarFileSection(f)
	pbEachFileSectionEx(f) { |section,name|
      yield section,name if block_given? && name[/^[a-zA-Z0-9]+$/]
    }
  end
  
  def compile_avatars(path = "PBS/avatars.txt")
	GameData::Avatar::DATA.clear
    # Read from PBS file
    File.open("PBS/avatars.txt", "rb") { |f|
		FileLineData.file = "PBS/avatars.txt"   # For error reporting
		# Read a whole section's lines at once, then run through this code.
		# contents is a hash containing all the XXX=YYY lines in that section, where
		# the keys are the XXX and the values are the YYY (as unprocessed strings).
		schema = GameData::Avatar::SCHEMA
		avatar_number = 1
		pbEachAvatarFileSection(f) { |contents, avatar_species|
			FileLineData.setSection(avatar_species, "header", nil)   # For error reporting
			avatar_symbol = avatar_species.to_sym
			
			# Raise an error if a species is invalid or used twice
			if avatar_species == ""
			  raise _INTL("An Avatar entry name can't be blank (PBS/avatars.txt).")
			elsif GameData::Avatar::DATA[avatar_symbol]
			  raise _INTL("Avatar name '{1}' is used twice.\r\n{2}", avatar_species, FileLineData.linereport)
			end
			
			# Go through schema hash of compilable data and compile this section
			for key in schema.keys
				# Skip empty properties, or raise an error if a required property is
				# empty
				if contents[key].nil? || contents[key] == ""
					if ["Turns", "Ability", "Moves", "HPMult"].include?(key)
						raise _INTL("The entry {1} is required in PBS/avatars.txt section {2}.", key, avatar_species)
					end
					contents[key] = nil
					next
				end

				# Compile value for key
				value = pbGetCsvRecord(contents[key], key, schema[key])
				value = nil if value.is_a?(Array) && value.length == 0
				contents[key] = value
			  
			    # Sanitise data
				case key
				when "Moves"
					if contents["Moves"].length > 4
						raise _INTL("The Moves entry has too many moves in PBS/avatars.txt section {2}.", key, avatar_species)
					end
				when "PostPrimeMoves"
					if contents["PostPrimeMoves"].length > 4
						raise _INTL("The Post Prime Moves entry has too many moves in PBS/avatars.txt section {2}.", key, avatar_species)
					end
				end
			end
			
			# Construct avatar hash
			avatar_hash = {
				:id          		=> avatar_symbol,
				:id_number   		=> avatar_number,
				:turns		 		=> contents["Turns"],
				:form		 		=> contents["Form"],
				:moves		 		=> contents["Moves"],
				:post_prime_moves	=> contents["PostPrimeMoves"],
				:ability	 		=> contents["Ability"],
				:item		 		=> contents["Item"],
				:hp_mult	 		=> contents["HPMult"],
				:dmg_mult			=> contents["DMGMult"],
				:size_mult	 		=> contents["SizeMult"],
			}
			avatar_number += 1
			# Add trainer avatar's data to records
			GameData::Avatar.register(avatar_hash)
		}
    }

    # Save all data
    GameData::Avatar.save
    Graphics.update
  end 
  
  #=============================================================================
  # Compile metadata
  #=============================================================================
  def compile_metadata(path = "PBS/metadata.txt")
    GameData::Metadata::DATA.clear
    GameData::MapMetadata::DATA.clear
    # Read from PBS file
    File.open(path, "rb") { |f|
      FileLineData.file = path   # For error reporting
      # Read a whole section's lines at once, then run through this code.
      # contents is a hash containing all the XXX=YYY lines in that section, where
      # the keys are the XXX and the values are the YYY (as unprocessed strings).
      pbEachFileSection(f) { |contents, map_id|
        schema = (map_id == 0) ? GameData::Metadata::SCHEMA : GameData::MapMetadata::SCHEMA
        # Go through schema hash of compilable data and compile this section
        for key in schema.keys
          FileLineData.setSection(map_id, key, contents[key])   # For error reporting
          # Skip empty properties, or raise an error if a required property is
          # empty
          if contents[key].nil?
            if map_id == 0 && ["Home", "PlayerA"].include?(key)
              raise _INTL("The entry {1} is required in {2} section 0.", key, path)
            end
            next
          end
          # Compile value for key
          value = pbGetCsvRecord(contents[key], key, schema[key])
          value = nil if value.is_a?(Array) && value.length == 0
          contents[key] = value
        end
        if map_id == 0   # Global metadata
          # Construct metadata hash
          metadata_hash = {
            :id                 			=> map_id,
            :home               			=> contents["Home"],
            :wild_battle_BGM    			=> contents["WildBattleBGM"],
            :trainer_battle_BGM 			=> contents["TrainerBattleBGM"],
			:avatar_battle_BGM 				=> contents["AvatarBattleBGM"],
			:legendary_avatar_battle_BGM 	=> contents["LegendaryAvatarBattleBGM"],
            :wild_victory_ME    			=> contents["WildVictoryME"],
            :trainer_victory_ME 			=> contents["TrainerVictoryME"],
            :wild_capture_ME    			=> contents["WildCaptureME"],
            :surf_BGM           			=> contents["SurfBGM"],
            :bicycle_BGM        			=> contents["BicycleBGM"],
            :player_A           			=> contents["PlayerA"],
            :player_B           			=> contents["PlayerB"],
            :player_C           			=> contents["PlayerC"],
            :player_D           			=> contents["PlayerD"],
            :player_E           			=> contents["PlayerE"],
            :player_F           			=> contents["PlayerF"],
            :player_G           			=> contents["PlayerG"],
            :player_H           			=> contents["PlayerH"]
          }
          # Add metadata's data to records
          GameData::Metadata.register(metadata_hash)
        else   # Map metadata
          # Construct metadata hash
          metadata_hash = {
            :id                   => map_id,
            :outdoor_map          => contents["Outdoor"],
            :announce_location    => contents["ShowArea"],
            :can_bicycle          => contents["Bicycle"],
            :always_bicycle       => contents["BicycleAlways"],
            :teleport_destination => contents["HealingSpot"],
            :weather              => contents["Weather"],
            :town_map_position    => contents["MapPosition"],
            :dive_map_id          => contents["DiveMap"],
            :dark_map             => contents["DarkMap"],
            :safari_map           => contents["SafariMap"],
            :snap_edges           => contents["SnapEdges"],
            :random_dungeon       => contents["Dungeon"],
            :battle_background    => contents["BattleBack"],
            :wild_battle_BGM      => contents["WildBattleBGM"],
            :trainer_battle_BGM   => contents["TrainerBattleBGM"],
            :wild_victory_ME      => contents["WildVictoryME"],
            :trainer_victory_ME   => contents["TrainerVictoryME"],
            :wild_capture_ME      => contents["WildCaptureME"],
            :town_map_size        => contents["MapSize"],
            :battle_environment   => contents["Environment"]
          }
          # Add metadata's data to records
          GameData::MapMetadata.register(metadata_hash)
        end
      }
    }
    # Save all data
    GameData::Metadata.save
    GameData::MapMetadata.save
    Graphics.update
  end


=begin
#THIS IS TO BE BTAVATAR COMPILER CODE
 def compile_btavatars(path = "PBS/btavatars.txt")
	GameData::Avatar::DATA.clear
    # Read from PBS file
    File.open("PBS/btavatars.txt", "rb") { |f|
		FileLineData.file = "PBS/btavatars.txt"   # For error reporting
		# Read a whole section's lines at once, then run through this code.
		# contents is a hash containing all the XXX=YYY lines in that section, where
		# the keys are the XXX and the values are the YYY (as unprocessed strings).
		schema = GameData::Avatar::SCHEMA
		avatar_number = 1
		pbEachAvatarFileSection(f) { |contents, avatar_species|
			FileLineData.setSection(avatar_species, "header", nil)   # For error reporting
			avatar_symbol = avatar_species.to_sym
			
			# Raise an error if a species is invalid or used twice
			if avatar_species == ""
			  raise _INTL("An Avatar entry name can't be blank (PBS/avatars.txt).")
			elsif GameData::Avatar::DATA[avatar_symbol]
			  raise _INTL("Avatar name '{1}' is used twice.\r\n{2}", avatar_species, FileLineData.linereport)
			end
			
			# Go through schema hash of compilable data and compile this section
			for key in schema.keys
				# Skip empty properties, or raise an error if a required property is
				# empty
				if contents[key].nil? || contents[key] == ""
					if ["Turns", "Ability", "Moves", "HPMult"].include?(key)
						raise _INTL("The entry {1} is required in PBS/avatars.txt section {2}.", key, avatar_species)
					end
					contents[key] = nil
					next
				end

				# Compile value for key
				value = pbGetCsvRecord(contents[key], key, schema[key])
				value = nil if value.is_a?(Array) && value.length == 0
				contents[key] = value
			  
			    # Sanitise data
				case key
				when "Moves"
					if contents["Moves"].length > 4
						raise _INTL("The moves entry has too many moves in PBS/avatars.txt section {2}.", key, avatar_species)
					end
				end
			end
			
			# Construct avatar hash
			avatar_hash = {
				:id          => avatar_symbol,
				:id_number   => avatar_number,
				:turns		 => contents["Turns"],
				:form		 => contents["Form"],
				:moves		 => contents["Moves"],
				:ability	 => contents["Ability"],
				:item		 => contents["Item"],
				:hp_mult	 => contents["HPMult"],
				:dmg_mult	 => contents["DMGMult"],
				:size_mult	 => contents["SizeMult"],
			}
			avatar_number += 1
			# Add trainer avatar's data to records
			GameData::Avatar.register(avatar_hash)
		}
    }

    # Save all data
    GameData::Avatar.save
    Graphics.update
  end
end
=end
  #=============================================================================
  # Compile trainer type data
  #=============================================================================
  def compile_trainer_types(path = "PBS/trainertypes.txt")
    GameData::TrainerType::DATA.clear
    tr_type_names = []
    # Read each line of trainertypes.txt at a time and compile it into a trainer type
    pbCompilerEachCommentedLine(path) { |line, line_no|
      line = pbGetCsvRecord(line, line_no, [0, "unsUSSSeUS",
        nil, nil, nil, nil, nil, nil, nil, {
        "Male"   => 0, "M" => 0, "0" => 0,
        "Female" => 1, "F" => 1, "1" => 1,
        "Mixed"  => 2, "X" => 2, "2" => 2, "" => 2
        }, nil, nil]
      )
      type_number = line[0]
      type_symbol = line[1].to_sym
      if GameData::TrainerType::DATA[type_number]
        raise _INTL("Trainer type ID number '{1}' is used twice.\r\n{2}", type_number, FileLineData.linereport)
      elsif GameData::TrainerType::DATA[type_symbol]
        raise _INTL("Trainer type ID '{1}' is used twice.\r\n{2}", type_symbol, FileLineData.linereport)
      end
	  policies_array = []
	  if line[9]
		  policies_string_array = line[9].gsub!('[','').gsub!(']','').split(',')
		  policies_string_array.each do |policy_string|
			policies_array.push(policy_string.to_sym)
		  end
	  end
      # Construct trainer type hash
      type_hash = {
        :id_number   => type_number,
        :id          => type_symbol,
        :name        => line[2],
        :base_money  => line[3],
        :battle_BGM  => line[4],
        :victory_ME  => line[5],
        :intro_ME    => line[6],
        :gender      => line[7],
        :skill_level => line[8],
        :policies    => policies_array,
      }
      # Add trainer type's data to records
      GameData::TrainerType.register(type_hash)
      tr_type_names[type_number] = type_hash[:name]
    }
    # Save all data
    GameData::TrainerType.save
    MessageTypes.setMessages(MessageTypes::TrainerTypes, tr_type_names)
    Graphics.update
  end

  #=============================================================================
  # Compile Pokémon data
  #=============================================================================
  def compile_pokemon
    GameData::Species::DATA.clear
    species_names           = []
    species_form_names      = []
    species_categories      = []
    species_pokedex_entries = []
    # Read from PBS file
    File.open("PBS/pokemon.txt", "rb") { |f|
      FileLineData.file = "PBS/pokemon.txt"   # For error reporting
      # Read a whole section's lines at once, then run through this code.
      # contents is a hash containing all the XXX=YYY lines in that section, where
      # the keys are the XXX and the values are the YYY (as unprocessed strings).
      schema = GameData::Species.schema
      pbEachFileSection(f) { |contents, species_number|
        FileLineData.setSection(species_number, "header", nil)   # For error reporting
        # Raise an error if a species number is invalid or used twice
        if species_number == 0
          raise _INTL("A Pokémon species can't be numbered 0 (PBS/pokemon.txt).")
        elsif GameData::Species::DATA[species_number]
          raise _INTL("Species ID number '{1}' is used twice.\r\n{2}", species_number, FileLineData.linereport)
        end
        # Go through schema hash of compilable data and compile this section
        for key in schema.keys
          # Skip empty properties, or raise an error if a required property is
          # empty
          if contents[key].nil? || contents[key] == ""
            if ["Name", "InternalName"].include?(key)
              raise _INTL("The entry {1} is required in PBS/pokemon.txt section {2}.", key, species_number)
            end
            contents[key] = nil
            next
          end
          # Raise an error if a species internal name is used twice
          FileLineData.setSection(species_number, key, contents[key])   # For error reporting
          if GameData::Species::DATA[contents["InternalName"].to_sym]
            raise _INTL("Species ID '{1}' is used twice.\r\n{2}", contents["InternalName"], FileLineData.linereport)
          end
          # Compile value for key
          value = pbGetCsvRecord(contents[key], key, schema[key])
          value = nil if value.is_a?(Array) && value.length == 0
          contents[key] = value
          # Sanitise data
          case key
          when "BaseStats", "EffortPoints"
            value_hash = {}
            GameData::Stat.each_main do |s|
              value_hash[s.id] = value[s.pbs_order] if s.pbs_order >= 0
            end
            contents[key] = value_hash
          when "Height", "Weight"
            # Convert height/weight to 1 decimal place and multiply by 10
            value = (value * 10).round
            if value <= 0
              raise _INTL("Value for '{1}' can't be less than or close to 0 (section {2}, PBS/pokemon.txt)", key, species_number)
            end
            contents[key] = value
          when "Moves"
            move_array = []
            for i in 0...value.length / 2
              move_array.push([value[i * 2], value[i * 2 + 1], i])
            end
            move_array.sort! { |a, b| (a[0] == b[0]) ? a[2] <=> b[2] : a[0] <=>b [0] }
            move_array.each { |arr| arr.pop }
            contents[key] = move_array
          when "TutorMoves", "EggMoves", "Abilities", "HiddenAbility", "Compatibility"
            contents[key] = [contents[key]] if !contents[key].is_a?(Array)
            contents[key].compact!
          when "Evolutions"
            evo_array = []
            for i in 0...value.length / 3
              evo_array.push([value[i * 3], value[i * 3 + 1], value[i * 3 + 2], false])
            end
            contents[key] = evo_array
          end
        end
        # Construct species hash
        species_symbol = contents["InternalName"].to_sym
        species_hash = {
          :id                    => species_symbol,
          :id_number             => species_number,
          :name                  => contents["Name"],
          :form_name             => contents["FormName"],
          :category              => contents["Kind"],
          :pokedex_entry         => contents["Pokedex"],
          :type1                 => contents["Type1"],
          :type2                 => contents["Type2"],
          :base_stats            => contents["BaseStats"],
          :evs                   => contents["EffortPoints"],
          :base_exp              => contents["BaseEXP"],
          :growth_rate           => contents["GrowthRate"],
          :gender_ratio          => contents["GenderRate"],
          :catch_rate            => contents["Rareness"],
          :happiness             => contents["Happiness"],
          :moves                 => contents["Moves"],
          :tutor_moves           => contents["TutorMoves"],
          :egg_moves             => contents["EggMoves"],
          :abilities             => contents["Abilities"],
          :hidden_abilities      => contents["HiddenAbility"],
          :wild_item_common      => contents["WildItemCommon"],
          :wild_item_uncommon    => contents["WildItemUncommon"],
          :wild_item_rare        => contents["WildItemRare"],
          :egg_groups            => contents["Compatibility"],
          :hatch_steps           => contents["StepsToHatch"],
          :incense               => contents["Incense"],
          :evolutions            => contents["Evolutions"],
          :height                => contents["Height"],
          :weight                => contents["Weight"],
          :color                 => contents["Color"],
          :shape                 => GameData::BodyShape.get(contents["Shape"]).id,
          :habitat               => contents["Habitat"],
          :generation            => contents["Generation"],
          :back_sprite_x         => contents["BattlerPlayerX"],
          :back_sprite_y         => contents["BattlerPlayerY"],
          :front_sprite_x        => contents["BattlerEnemyX"],
          :front_sprite_y        => contents["BattlerEnemyY"],
          :front_sprite_altitude => contents["BattlerAltitude"],
          :shadow_x              => contents["BattlerShadowX"],
          :shadow_size           => contents["BattlerShadowSize"]
        }
        # Add species' data to records
        GameData::Species.register(species_hash)
        species_names[species_number]           = species_hash[:name]
        species_form_names[species_number]      = species_hash[:form_name]
        species_categories[species_number]      = species_hash[:category]
        species_pokedex_entries[species_number] = species_hash[:pokedex_entry]
      }
    }
    # Enumerate all evolution species and parameters (this couldn't be done earlier)
    GameData::Species.each do |species|
      FileLineData.setSection(species.id_number, "Evolutions", nil)   # For error reporting
      Graphics.update if species.id_number % 200 == 0
      pbSetWindowText(_INTL("Processing {1} evolution line {2}", FileLineData.file, species.id_number)) if species.id_number % 50 == 0
      species.evolutions.each do |evo|
        evo[0] = csvEnumField!(evo[0], :Species, "Evolutions", species.id_number)
        param_type = GameData::Evolution.get(evo[1]).parameter
        if param_type.nil?
          evo[2] = nil
        elsif param_type == Integer
          evo[2] = csvPosInt!(evo[2])
        else
          evo[2] = csvEnumField!(evo[2], param_type, "Evolutions", species.id_number)
        end
      end
    end
    # Add prevolution "evolution" entry for all evolved species
    all_evos = {}
    GameData::Species.each do |species|   # Build a hash of prevolutions for each species
      #next if all_evos[species.species]
      species.evolutions.each do |evo|
        all_evos[evo[0]] = [species.species, evo[1], evo[2], true] #if !all_evos[evo[0]]
      end
    end
    GameData::Species.each do |species|   # Distribute prevolutions
      species.evolutions.push(all_evos[species.species].clone) if all_evos[species.species]
    end
	
    # Save all data
    GameData::Species.save
    MessageTypes.setMessages(MessageTypes::Species, species_names)
    MessageTypes.setMessages(MessageTypes::FormNames, species_form_names)
    MessageTypes.setMessages(MessageTypes::Kinds, species_categories)
    MessageTypes.setMessages(MessageTypes::Entries, species_pokedex_entries)
    Graphics.update
  end
  
  #=============================================================================
  # Compile individual trainer data
  #=============================================================================
  def compile_trainers(path = "PBS/trainers.txt")
    schema = GameData::Trainer::SCHEMA
    max_level = GameData::GrowthRate.max_level
    trainer_names             = []
    trainer_lose_texts        = []
    trainer_hash              = nil
    trainer_id                = -1
    current_pkmn              = nil
    old_format_current_line   = 0
    old_format_expected_lines = 0
    # Read each line of trainers.txt at a time and compile it as a trainer property
    pbCompilerEachPreppedLine(path) { |line, line_no|
      if line[/^\s*\[\s*(.+)\s*\]\s*$/]
        # New section [trainer_type, name] or [trainer_type, name, version]
        if trainer_hash
          if old_format_current_line > 0
            raise _INTL("Previous trainer not defined with as many Pokémon as expected.\r\n{1}", FileLineData.linereport)
          end
          if !current_pkmn
            raise _INTL("Started new trainer while previous trainer has no Pokémon.\r\n{1}", FileLineData.linereport)
          end
          # Add trainer's data to records
          trainer_hash[:id] = [trainer_hash[:trainer_type], trainer_hash[:name], trainer_hash[:version]]
          GameData::Trainer.register(trainer_hash)
        end
        trainer_id += 1
        line_data = pbGetCsvRecord($~[1], line_no, [0, "esU", :TrainerType])
        # Construct trainer hash
        trainer_hash = {
          :id_number    => trainer_id,
          :trainer_type => line_data[0],
          :name         => line_data[1],
          :version      => line_data[2] || 0,
          :pokemon      => [],
		  :policies		=> []
        }
        current_pkmn = nil
        trainer_names[trainer_id] = trainer_hash[:name]
      elsif line[/^\s*(\w+)\s*=\s*(.*)$/]
        # XXX=YYY lines
        if !trainer_hash
          raise _INTL("Expected a section at the beginning of the file.\r\n{1}", FileLineData.linereport)
        end
        property_name = $~[1]
        line_schema = schema[property_name]
        next if !line_schema
        property_value = pbGetCsvRecord($~[2], line_no, line_schema)
        # Error checking in XXX=YYY lines
        case property_name
        when "Items"
          property_value = [property_value] if !property_value.is_a?(Array)
          property_value.compact!
        when "Pokemon"
          if property_value[1] > max_level
            raise _INTL("Bad level: {1} (must be 1-{2}).\r\n{3}", property_value[1], max_level, FileLineData.linereport)
          end
        when "Name"
          if property_value.length > Pokemon::MAX_NAME_SIZE
            raise _INTL("Bad nickname: {1} (must be 1-{2} characters).\r\n{3}", property_value, Pokemon::MAX_NAME_SIZE, FileLineData.linereport)
          end
        when "Moves"
          property_value = [property_value] if !property_value.is_a?(Array)
          property_value.uniq!
          property_value.compact!
        when "IV"
          property_value = [property_value] if !property_value.is_a?(Array)
          property_value.compact!
          property_value.each do |iv|
            next if iv <= Pokemon::IV_STAT_LIMIT
            raise _INTL("Bad IV: {1} (must be 0-{2}).\r\n{3}", iv, Pokemon::IV_STAT_LIMIT, FileLineData.linereport)
          end
        when "EV"
          property_value = [property_value] if !property_value.is_a?(Array)
          property_value.compact!
          property_value.each do |ev|
            next if ev <= Pokemon::EV_STAT_LIMIT
            raise _INTL("Bad EV: {1} (must be 0-{2}).\r\n{3}", ev, Pokemon::EV_STAT_LIMIT, FileLineData.linereport)
          end
          ev_total = 0
          GameData::Stat.each_main do |s|
            next if s.pbs_order < 0
            ev_total += (property_value[s.pbs_order] || property_value[0])
          end
          if ev_total > Pokemon::EV_LIMIT
            raise _INTL("Total EVs are greater than allowed ({1}).\r\n{2}", Pokemon::EV_LIMIT, FileLineData.linereport)
          end
        when "Happiness"
          if property_value > 255
            raise _INTL("Bad happiness: {1} (must be 0-255).\r\n{2}", property_value, FileLineData.linereport)
          end
        end
        # Record XXX=YYY setting
        case property_name
        when "Items", "LoseText","Policies"
          trainer_hash[line_schema[0]] = property_value
          trainer_lose_texts[trainer_id] = property_value if property_name == "LoseText"
        when "Pokemon"
          current_pkmn = {
            :species => property_value[0],
            :level   => property_value[1]
          }
		  # The default ability index for a given species of a given trainer should be chaotic, but not random
		  current_pkmn[:ability_index] = (trainer_hash[:name] + current_pkmn[:species].to_s).hash % 2
		  trainer_hash[line_schema[0]].push(current_pkmn)
        else
          if !current_pkmn
            raise _INTL("Pokémon hasn't been defined yet!\r\n{1}", FileLineData.linereport)
          end
          case property_name
          when "Ability"
            if property_value[/^\d+$/]
              current_pkmn[:ability_index] = property_value.to_i
            elsif !GameData::Ability.exists?(property_value.to_sym)
              raise _INTL("Value {1} isn't a defined Ability.\r\n{2}", property_value, FileLineData.linereport)
            else
              current_pkmn[line_schema[0]] = property_value.to_sym
            end
          when "IV", "EV"
            value_hash = {}
            GameData::Stat.each_main do |s|
              next if s.pbs_order < 0
              value_hash[s.id] = property_value[s.pbs_order] || property_value[0]
            end
            current_pkmn[line_schema[0]] = value_hash
          when "Ball"
            if property_value[/^\d+$/]
              current_pkmn[line_schema[0]] = pbBallTypeToItem(property_value.to_i).id
            elsif !GameData::Item.exists?(property_value.to_sym) ||
               !GameData::Item.get(property_value.to_sym).is_poke_ball?
              raise _INTL("Value {1} isn't a defined Poké Ball.\r\n{2}", property_value, FileLineData.linereport)
            else
              current_pkmn[line_schema[0]] = property_value.to_sym
            end
          else
            current_pkmn[line_schema[0]] = property_value
          end
        end
      else
        # Old format - backwards compatibility is SUCH fun!
        if old_format_current_line == 0   # Started an old trainer section
          if trainer_hash
            if !current_pkmn
              raise _INTL("Started new trainer while previous trainer has no Pokémon.\r\n{1}", FileLineData.linereport)
            end
            # Add trainer's data to records
            trainer_hash[:id] = [trainer_hash[:trainer_type], trainer_hash[:name], trainer_hash[:version]]
            GameData::Trainer.register(trainer_hash)
          end
          trainer_id += 1
          old_format_expected_lines = 3
          # Construct trainer hash
          trainer_hash = {
            :id_number    => trainer_id,
            :trainer_type => nil,
            :name         => nil,
            :version      => 0,
            :pokemon      => []
          }
          current_pkmn = nil
        end
        # Evaluate line and add to hash
        old_format_current_line += 1
        case old_format_current_line
        when 1   # Trainer type
          line_data = pbGetCsvRecord(line, line_no, [0, "e", :TrainerType])
          trainer_hash[:trainer_type] = line_data
        when 2   # Trainer name, version number
          line_data = pbGetCsvRecord(line, line_no, [0, "sU"])
          line_data = [line_data] if !line_data.is_a?(Array)
          trainer_hash[:name]    = line_data[0]
          trainer_hash[:version] = line_data[1] if line_data[1]
          trainer_names[trainer_hash[:id_number]] = line_data[0]
        when 3   # Number of Pokémon, items
          line_data = pbGetCsvRecord(line, line_no,
             [0, "vEEEEEEEE", nil, :Item, :Item, :Item, :Item, :Item, :Item, :Item, :Item])
          line_data = [line_data] if !line_data.is_a?(Array)
          line_data.compact!
          old_format_expected_lines += line_data[0]
          line_data.shift
          trainer_hash[:items] = line_data if line_data.length > 0
        else   # Pokémon lines
          line_data = pbGetCsvRecord(line, line_no,
             [0, "evEEEEEUEUBEUUSBU", :Species, nil, :Item, :Move, :Move, :Move, :Move, nil,
                                      {"M" => 0, "m" => 0, "Male" => 0, "male" => 0, "0" => 0,
                                      "F" => 1, "f" => 1, "Female" => 1, "female" => 1, "1" => 1},
                                      nil, nil, :Nature, nil, nil, nil, nil, nil])
          current_pkmn = {
            :species => line_data[0]
          }
          trainer_hash[:pokemon].push(current_pkmn)
          # Error checking in properties
          line_data.each_with_index do |value, i|
            next if value.nil?
            case i
            when 1   # Level
              if value > max_level
                raise _INTL("Bad level: {1} (must be 1-{2}).\r\n{3}", value, max_level, FileLineData.linereport)
              end
            when 12   # IV
              if value > Pokemon::IV_STAT_LIMIT
                raise _INTL("Bad IV: {1} (must be 0-{2}).\r\n{3}", value, Pokemon::IV_STAT_LIMIT, FileLineData.linereport)
              end
            when 13   # Happiness
              if value > 255
                raise _INTL("Bad happiness: {1} (must be 0-255).\r\n{2}", value, FileLineData.linereport)
              end
            when 14   # Nickname
              if value.length > Pokemon::MAX_NAME_SIZE
                raise _INTL("Bad nickname: {1} (must be 1-{2} characters).\r\n{3}", value, Pokemon::MAX_NAME_SIZE, FileLineData.linereport)
              end
            end
          end
          # Write all line data to hash
          moves = [line_data[3], line_data[4], line_data[5], line_data[6]]
          moves.uniq!.compact!
          ivs = {}
          if line_data[12]
            GameData::Stat.each_main do |s|
              ivs[s.id] = line_data[12] if s.pbs_order >= 0
            end
          end
          current_pkmn[:level]         = line_data[1]
          current_pkmn[:item]          = line_data[2] if line_data[2]
          current_pkmn[:moves]         = moves if moves.length > 0
          current_pkmn[:ability_index] = line_data[7] if line_data[7]
          current_pkmn[:gender]        = line_data[8] if line_data[8]
          current_pkmn[:form]          = line_data[9] if line_data[9]
          current_pkmn[:shininess]     = line_data[10] if line_data[10]
          current_pkmn[:nature]        = line_data[11] if line_data[11]
          current_pkmn[:iv]            = ivs if ivs.length > 0
          current_pkmn[:happiness]     = line_data[13] if line_data[13]
          current_pkmn[:name]          = line_data[14] if line_data[14] && !line_data[14].empty?
          current_pkmn[:shadowness]    = line_data[15] if line_data[15]
          current_pkmn[:poke_ball]     = line_data[16] if line_data[16]
          # Check if this is the last expected Pokémon
          old_format_current_line = 0 if old_format_current_line >= old_format_expected_lines
        end
      end
    }
    if old_format_current_line > 0
      raise _INTL("Unexpected end of file, last trainer not defined with as many Pokémon as expected.\r\n{1}", FileLineData.linereport)
    end
    # Add last trainer's data to records
    if trainer_hash
      trainer_hash[:id] = [trainer_hash[:trainer_type], trainer_hash[:name], trainer_hash[:version]]
      GameData::Trainer.register(trainer_hash)
    end
    # Save all data
    GameData::Trainer.save
    MessageTypes.setMessagesAsHash(MessageTypes::TrainerNames, trainer_names)
    MessageTypes.setMessagesAsHash(MessageTypes::TrainerLoseText, trainer_lose_texts)
    Graphics.update
  end
  
    #=============================================================================
  # Compile metadata
  #=============================================================================
  def compile_metadata(path = "PBS/metadata.txt")
    GameData::Metadata::DATA.clear
    GameData::MapMetadata::DATA.clear
    # Read from PBS file
    File.open(path, "rb") { |f|
      FileLineData.file = path   # For error reporting
      # Read a whole section's lines at once, then run through this code.
      # contents is a hash containing all the XXX=YYY lines in that section, where
      # the keys are the XXX and the values are the YYY (as unprocessed strings).
      pbEachFileSection(f) { |contents, map_id|
        schema = (map_id == 0) ? GameData::Metadata::SCHEMA : GameData::MapMetadata::SCHEMA
        # Go through schema hash of compilable data and compile this section
        for key in schema.keys
          FileLineData.setSection(map_id, key, contents[key])   # For error reporting
          # Skip empty properties, or raise an error if a required property is
          # empty
          if contents[key].nil?
            if map_id == 0 && ["Home", "PlayerA"].include?(key)
              raise _INTL("The entry {1} is required in {2} section 0.", key, path)
            end
            next
          end
          # Compile value for key
          value = pbGetCsvRecord(contents[key], key, schema[key])
          value = nil if value.is_a?(Array) && value.length == 0
          contents[key] = value
        end
        if map_id == 0   # Global metadata
          # Construct metadata hash
          metadata_hash = {
            :id                 => map_id,
            :home               => contents["Home"],
            :wild_battle_BGM    => contents["WildBattleBGM"],
            :trainer_battle_BGM => contents["TrainerBattleBGM"],
            :wild_victory_ME    => contents["WildVictoryME"],
            :trainer_victory_ME => contents["TrainerVictoryME"],
            :wild_capture_ME    => contents["WildCaptureME"],
            :surf_BGM           => contents["SurfBGM"],
            :bicycle_BGM        => contents["BicycleBGM"],
            :player_A           => contents["PlayerA"],
            :player_B           => contents["PlayerB"],
            :player_C           => contents["PlayerC"],
            :player_D           => contents["PlayerD"],
            :player_E           => contents["PlayerE"],
            :player_F           => contents["PlayerF"],
            :player_G           => contents["PlayerG"],
            :player_H           => contents["PlayerH"]
          }
          # Add metadata's data to records
          GameData::Metadata.register(metadata_hash)
        else   # Map metadata
          # Construct metadata hash
          metadata_hash = {
            :id                   => map_id,
            :outdoor_map          => contents["Outdoor"],
            :announce_location    => contents["ShowArea"],
            :can_bicycle          => contents["Bicycle"],
            :always_bicycle       => contents["BicycleAlways"],
            :teleport_destination => contents["HealingSpot"],
            :weather              => contents["Weather"],
            :town_map_position    => contents["MapPosition"],
            :dive_map_id          => contents["DiveMap"],
            :dark_map             => contents["DarkMap"],
            :safari_map           => contents["SafariMap"],
            :snap_edges           => contents["SnapEdges"],
            :random_dungeon       => contents["Dungeon"],
            :battle_background    => contents["BattleBack"],
            :wild_battle_BGM      => contents["WildBattleBGM"],
            :trainer_battle_BGM   => contents["TrainerBattleBGM"],
            :wild_victory_ME      => contents["WildVictoryME"],
            :trainer_victory_ME   => contents["TrainerVictoryME"],
            :wild_capture_ME      => contents["WildCaptureME"],
            :town_map_size        => contents["MapSize"],
            :battle_environment   => contents["Environment"],
			:teleport_blocked	  => contents["TeleportBlocked"]
          }
          # Add metadata's data to records
          GameData::MapMetadata.register(metadata_hash)
        end
      }
    }
    # Save all data
    GameData::Metadata.save
    GameData::MapMetadata.save
    Graphics.update
  end
  
  #=============================================================================
  # Main compiler method for events
  #=============================================================================
  def compile_events
    mapData = MapData.new
    t = Time.now.to_i
    Graphics.update
    trainerChecker = TrainerChecker.new
    for id in mapData.mapinfos.keys.sort
      changed = false
      map = mapData.getMap(id)
      next if !map || !mapData.mapinfos[id]
	  mapName = mapData.mapinfos[id].name
      pbSetWindowText(_INTL("Processing map {1} ({2})",id,mapName))
      for key in map.events.keys
        if Time.now.to_i-t>=5
          Graphics.update
          t = Time.now.to_i
        end
        newevent = convert_to_trainer_event(map.events[key],trainerChecker)
        if newevent
          map.events[key] = newevent
          changed = true
        end
        newevent = convert_to_item_event(map.events[key])
        if newevent
          map.events[key] = newevent
          changed = true
        end
		newevent = convert_chasm_style_trainers(map.events[key])
        if newevent
          map.events[key] = newevent
          changed = true
        end
		newevent = convert_avatars(map.events[key])
        if newevent
          map.events[key] = newevent
          changed = true
        end
		newevent = convert_placeholder_pokemon(map.events[key])
        if newevent
          map.events[key] = newevent
          changed = true
        end
		newevent = convert_overworld_pokemon(map.events[key])
        if newevent
          map.events[key] = newevent
          changed = true
        end
		newevent = change_overworld_placeholders(map.events[key])
		if newevent
          map.events[key] = newevent
          changed = true
        end
        changed = true if fix_event_name(map.events[key])
        newevent = fix_event_use(map.events[key],id,mapData)
        if newevent
          map.events[key] = newevent
          changed = true
        end
      end
      if Time.now.to_i-t>=5
        Graphics.update
        t = Time.now.to_i
      end
      changed = true if check_counters(map,id,mapData)
      if changed
        mapData.saveMap(id)
        mapData.saveTilesets
      end
    end
    changed = false
    Graphics.update
    commonEvents = load_data("Data/CommonEvents.rxdata")
    pbSetWindowText(_INTL("Processing common events"))
    for key in 0...commonEvents.length
      newevent = fix_event_use(commonEvents[key],0,mapData)
      if newevent
        commonEvents[key] = newevent
        changed = true
      end
    end
    save_data(commonEvents,"Data/CommonEvents.rxdata") if changed
  end
  
  #=============================================================================
  # Convert events using the PHT command into fully fledged trainers
  #=============================================================================
  def convert_chasm_style_trainers(event)
	return nil if !event || event.pages.length==0
	match = event.name.match(/PHT\(([_a-zA-Z0-9]+),([_a-zA-Z]+),([0-9]+)\)/)
	return nil if !match
	ret = RPG::Event.new(event.x,event.y)
	ret.name = "resettrainer(4)"
	ret.id   = event.id
	ret.pages = []
	trainerTypeName = match[1]
	return nil if !trainerTypeName || trainerTypeName == ""
	trainerName = match[2]
	trainerMaxLevel = match[3]
	ret.pages = [3]
	
	# Create the first page, where the battle happens
	firstPage = RPG::Event::Page.new
	ret.pages[0] = firstPage
	firstPage.graphic.character_name = trainerTypeName
	firstPage.trigger = 2   # On event touch
	firstPage.list = []
	push_script(firstPage.list,"pbTrainerIntro(:#{trainerTypeName})")
	push_script(firstPage.list,"pbNoticePlayer(get_self)")
	push_text(firstPage.list,"Dialogue here.")
	
	push_branch(firstPage.list,"pbTrainerBattle(:#{trainerTypeName},\"#{trainerName}\")")
	push_branch(firstPage.list,"$game_switches[94]",1)
	push_text(firstPage.list,"Dialogue here.",2)
	push_script(firstPage.list,"perfectTrainer(#{trainerMaxLevel})",2)
	push_else(firstPage.list,2)
	push_text(firstPage.list,"Dialogue here.",2)
	push_script(firstPage.list,"defeatTrainer",2)
    push_branch_end(firstPage.list,2)
    push_branch_end(firstPage.list,1)
	
	push_script(firstPage.list,"pbTrainerEnd")
	push_end(firstPage.list)
	
	# Create the second page, which has a talkable action-button graphic
	secondPage = RPG::Event::Page.new
	ret.pages[1] = secondPage
	secondPage.graphic.character_name = trainerTypeName
	secondPage.condition.self_switch_valid = true
	secondPage.condition.self_switch_ch = "A"
	secondPage.list = []
	push_text(secondPage.list,"Dialogue here.")
	push_end(secondPage.list)
	
	# Create the third page, which has no functionality and no graphic
	thirdPage = RPG::Event::Page.new
	ret.pages[2] = thirdPage
	thirdPage.condition.self_switch_valid = true
	thirdPage.condition.self_switch_ch = "D"
	thirdPage.list = []
	push_end(thirdPage.list)
	
	return ret
  end
  
  #=============================================================================
  # Convert events using the PHA name command into fully fledged avatars
  #=============================================================================
  def convert_avatars(event)
	return nil if !event || event.pages.length==0
	match = event.name.match(/.*PHA\(([_a-zA-Z0-9]+),([0-9]+)(?:,([_a-zA-Z]+))?(?:,([_a-zA-Z0-9]+))?(?:,([0-9]+))?\).*/)
	return nil if !match
	ret = RPG::Event.new(event.x,event.y)
	ret.name = "size(2,2)trainer(4)"
	ret.id   = event.id
	ret.pages = []
	avatarSpecies = match[1]
	legendary = isLegendary(avatarSpecies)
	return nil if !avatarSpecies || avatarSpecies == ""
	level = match[2]
	directionText = match[3]
	item = match[4] || nil
	itemCount = match[5].to_i || 0
	
	direction = Down
	if !directionText.nil?
		case directionText.downcase
		when "left"
			direction = Left
		when "right"
			direction = Right
		when "up"
			direction = Up
		else
			direction = Down
		end
	end
	
	# Create the needed graphics
	overworldBitmap = AnimatedBitmap.new('Graphics/Characters/Followers/' + avatarSpecies)
	copiedOverworldBitmap = overworldBitmap.copy
	bossifiedOverworld = increaseSize(copiedOverworldBitmap.bitmap)
	bossifiedOverworld.to_file('Graphics/Characters/zAvatar_' + avatarSpecies + '.png')
	
	# Create the needed graphics
	battlebitmap = AnimatedBitmap.new('Graphics/Pokemon/Front/' + avatarSpecies)
	copiedBattleBitmap = battlebitmap.copy
	bossifiedBattle = bossify(copiedBattleBitmap.bitmap)
	bossifiedBattle.to_file('Graphics/Pokemon/Avatars/' + avatarSpecies + '.png')
	
	# Set up the pages
	
	ret.pages = [2]
	# Create the first page, where the battle happens
	firstPage = RPG::Event::Page.new
	ret.pages[0] = firstPage
	firstPage.graphic.character_name = "zAvatar_#{avatarSpecies}"
	firstPage.graphic.opacity = 180
	firstPage.graphic.direction = direction
	firstPage.trigger = 2   # On event touch
	firstPage.step_anime = true # Animate while still
	firstPage.list = []
	push_script(firstPage.list,"pbNoticePlayer(get_self)")
	push_script(firstPage.list,"introduceAvatar(:#{avatarSpecies})")
	push_branch(firstPage.list,"pb#{legendary ? "Big" : "Small"}AvatarBattle([:#{avatarSpecies},#{level}])")
	if item.nil?
		push_script(firstPage.list,"defeatBoss",1)
	else
		if itemCount > 1
			push_script(firstPage.list,"defeatBoss(:#{item},#{itemCount})",1)
		else
			push_script(firstPage.list,"defeatBoss(:#{item})",1)
		end
	end
    push_branch_end(firstPage.list,1)
	push_end(firstPage.list)
	
	# Create the second page, which has nothing
	secondPage = RPG::Event::Page.new
	ret.pages[1] = secondPage
	secondPage.condition.self_switch_valid = true
	secondPage.condition.self_switch_ch = "A"
	
	return ret
  end
  
  def increaseSize(bitmap,scaleFactor=1.3)
	  copiedBitmap = Bitmap.new(bitmap.width*scaleFactor,bitmap.height*scaleFactor)
	  for x in 0..copiedBitmap.width
		for y in 0..copiedBitmap.height
		  color = bitmap.get_pixel(x/scaleFactor,y/scaleFactor)
		  copiedBitmap.set_pixel(x,y,color)
		end
	  end
	  return copiedBitmap
  end
  
  def bossify(bitmap,scaleFactor = 1.3)
	  copiedBitmap = Bitmap.new(bitmap.width*scaleFactor,bitmap.height*scaleFactor)
	  for x in 0..copiedBitmap.width
		for y in 0..copiedBitmap.height
		  color = bitmap.get_pixel(x/scaleFactor,y/scaleFactor)
		  color.alpha   = [color.alpha,140].min
		  color.red     = [color.red + 50,255].min
		  color.blue    = [color.blue + 50,255].min
		  copiedBitmap.set_pixel(x,y,color)
		end
	  end
	  return copiedBitmap
  end
  
  #=============================================================================
  # Convert events using the PHP name command into fully fledged overworld pokemon
  #=============================================================================
  def convert_placeholder_pokemon(event)
	return nil if !event || event.pages.length==0
	match = event.name.match(/.*PHP\(([a-zA-Z0-9]+)(?:_([0-9]*))?(?:,([_a-zA-Z]+))?.*/)
	return nil if !match
	species = match[1]
	return if !species
	species = species.upcase
	form	= match[2]
	form = 0 if !form || form == ""
	speciesData = GameData::Species.get(species.to_sym)
	return if !speciesData
	directionText = match[3]
	direction = Down
	if !directionText.nil?
		case directionText.downcase
		when "left"
			direction = Left
		when "right"
			direction = Right
		when "up"
			direction = Up
		else
			direction = Down
		end
	end
	
	echoln("Converting event: #{species},#{form},#{direction}")
	
	ret = RPG::Event.new(event.x,event.y)
	ret.name = "resetfollower"
	ret.id   = event.id
	ret.pages = [3]
	
	# Create the first page, where the cry happens
	firstPage = RPG::Event::Page.new
	ret.pages[0] = firstPage
	fileName = species
	fileName += "_" + form.to_s if form != 0
	firstPage.graphic.character_name = "Followers/#{fileName}"
	firstPage.graphic.direction = direction
	firstPage.step_anime = true # Animate while still
	firstPage.trigger = 0 # Action button
	firstPage.list = []
	push_script(firstPage.list,sprintf("Pokemon.play_cry(:%s, %d)",speciesData.id,form))
	push_script(firstPage.list,sprintf("pbMessage(\"#{speciesData.real_name} cries out!\")",))
	push_end(firstPage.list)
	
	# Create the second page, which has nothing
	secondPage = RPG::Event::Page.new
	ret.pages[1] = secondPage
	secondPage.condition.self_switch_valid = true
	secondPage.condition.self_switch_ch = "A"
	
	# Create the third page, which has nothing
	thirdPage = RPG::Event::Page.new
	ret.pages[2] = thirdPage
	thirdPage.condition.self_switch_valid = true
	thirdPage.condition.self_switch_ch = "D"
	
	return ret
  end
  
  #=============================================================================
  # Convert events using the overworld name command to use the correct graphic.
  #=============================================================================
  def convert_overworld_pokemon(event)
	return nil if !event || event.pages.length==0
	match = event.name.match(/(.*)?overworld\(([a-zA-Z0-9]+)\)(.*)?/)
	return nil if !match
	nameStuff = match[1] || ""
	nameStuff += match[3] || ""
	nameStuff += match[2] || ""
	species = match[2]
	return nil if !species
	
	event.name = nameStuff
	event.pages.each do |page|
		next if page.graphic.character_name != "00Overworld Placeholder"
		page.graphic.character_name = "Followers/#{species}" 
	end
	
	return event
  end
  
  def change_overworld_placeholders(event)
	return nil if !event || event.pages.length==0
	return nil unless event.name.downcase.include?("boxplaceholder")
	
	return nil
	#event.pages.each do |page|
	#	page.move_type = 1
	#end
	
	return event
  end
end

module GameData
	def self.load_all
		echo("Loading all game data.")
		Type.load
		Ability.load
		Move.load
		Item.load
		BerryPlant.load
		Species.load
		SpeciesOld.load
		Ribbon.load
		Encounter.load
		TrainerType.load
		Trainer.load
		Metadata.load
		MapMetadata.load
		Policy.load
		Avatar.load
	end
end

module Compiler
	module_function

  #=============================================================================
  # Save Pokémon data to PBS file
  #=============================================================================
  def write_pokemon
    File.open("PBS/pokemon.txt", "wb") { |f|
      add_PBS_header_to_file(f)
      GameData::Species.each do |species|
        next if species.form != 0
        pbSetWindowText(_INTL("Writing species {1}...", species.id_number))
        Graphics.update if species.id_number % 50 == 0
        f.write("\#-------------------------------\r\n")
        f.write(sprintf("[%d]\r\n", species.id_number))
        f.write(sprintf("Name = %s\r\n", species.real_name))
        f.write(sprintf("InternalName = %s\r\n", species.species))
        f.write(sprintf("Type1 = %s\r\n", species.type1))
        f.write(sprintf("Type2 = %s\r\n", species.type2)) if species.type2 != species.type1
        stats_array = []
        evs_array = []
		total = 0
        GameData::Stat.each_main do |s|
          next if s.pbs_order < 0
          stats_array[s.pbs_order] = species.base_stats[s.id]
          evs_array[s.pbs_order] = species.evs[s.id]
		  total += species.base_stats[s.id]
        end
		f.write(sprintf("# HP, Attack, Defense, Speed, Sp. Atk, Sp. Def\r\n", total))
        f.write(sprintf("BaseStats = %s\r\n", stats_array.join(",")))
		f.write(sprintf("# Total = %s\r\n", total))
        f.write(sprintf("GenderRate = %s\r\n", species.gender_ratio))
        f.write(sprintf("GrowthRate = %s\r\n", species.growth_rate))
        f.write(sprintf("BaseEXP = %d\r\n", species.base_exp))
        f.write(sprintf("EffortPoints = %s\r\n", evs_array.join(",")))
        f.write(sprintf("Rareness = %d\r\n", species.catch_rate))
        f.write(sprintf("Happiness = %d\r\n", species.happiness))
        if species.abilities.length > 0
          f.write(sprintf("Abilities = %s\r\n", species.abilities.join(",")))
        end
        if species.hidden_abilities.length > 0
          f.write(sprintf("HiddenAbility = %s\r\n", species.hidden_abilities.join(",")))
        end
        if species.moves.length > 0
          f.write(sprintf("Moves = %s\r\n", species.moves.join(",")))
        end
        if species.tutor_moves.length > 0
          f.write(sprintf("TutorMoves = %s\r\n", species.tutor_moves.join(",")))
        end
        if species.egg_moves.length > 0
          f.write(sprintf("EggMoves = %s\r\n", species.egg_moves.join(",")))
        end
        if species.egg_groups.length > 0
          f.write(sprintf("Compatibility = %s\r\n", species.egg_groups.join(",")))
        end
        f.write(sprintf("StepsToHatch = %d\r\n", species.hatch_steps))
        f.write(sprintf("Height = %.1f\r\n", species.height / 10.0))
        f.write(sprintf("Weight = %.1f\r\n", species.weight / 10.0))
        f.write(sprintf("Color = %s\r\n", species.color))
        f.write(sprintf("Shape = %s\r\n", species.shape))
        f.write(sprintf("Habitat = %s\r\n", species.habitat)) if species.habitat != :None
        f.write(sprintf("Kind = %s\r\n", species.real_category))
        f.write(sprintf("Pokedex = %s\r\n", species.real_pokedex_entry))
        f.write(sprintf("FormName = %s\r\n", species.real_form_name)) if species.real_form_name && !species.real_form_name.empty?
        f.write(sprintf("Generation = %d\r\n", species.generation)) if species.generation != 0
        f.write(sprintf("WildItemCommon = %s\r\n", species.wild_item_common)) if species.wild_item_common
        f.write(sprintf("WildItemUncommon = %s\r\n", species.wild_item_uncommon)) if species.wild_item_uncommon
        f.write(sprintf("WildItemRare = %s\r\n", species.wild_item_rare)) if species.wild_item_rare
        f.write(sprintf("BattlerPlayerX = %d\r\n", species.back_sprite_x))
        f.write(sprintf("BattlerPlayerY = %d\r\n", species.back_sprite_y))
        f.write(sprintf("BattlerEnemyX = %d\r\n", species.front_sprite_x))
        f.write(sprintf("BattlerEnemyY = %d\r\n", species.front_sprite_y))
        f.write(sprintf("BattlerAltitude = %d\r\n", species.front_sprite_altitude)) if species.front_sprite_altitude != 0
        f.write(sprintf("BattlerShadowX = %d\r\n", species.shadow_x))
        f.write(sprintf("BattlerShadowSize = %d\r\n", species.shadow_size))
        if species.evolutions.any? { |evo| !evo[3] }
          f.write("Evolutions = ")
          need_comma = false
          species.evolutions.each do |evo|
            next if evo[3]   # Skip prevolution entries
            f.write(",") if need_comma
            need_comma = true
            evo_type_data = GameData::Evolution.get(evo[1])
            param_type = evo_type_data.parameter
            f.write(sprintf("%s,%s,", evo[0], evo_type_data.id.to_s))
            if !param_type.nil?
              if !GameData.const_defined?(param_type.to_sym) && param_type.is_a?(Symbol)
                f.write(getConstantName(param_type, evo[2]))
              else
                f.write(evo[2].to_s)
              end
            end
          end
          f.write("\r\n")
        end
        f.write(sprintf("Incense = %s\r\n", species.incense)) if species.incense
      end
    }
    pbSetWindowText(nil)
    Graphics.update
  end
  
  #=============================================================================
  # Save trainer type data to PBS file
  #=============================================================================
  def write_trainer_types
    File.open("PBS/trainertypes.txt", "wb") { |f|
      add_PBS_header_to_file(f)
      f.write("\#-------------------------------\r\n")
      GameData::TrainerType.each do |t|
		policiesString = ""
		if t.policies
		  policiesString += "["
		  t.policies.each_with_index do |policy_symbol,index|
			policiesString += policy_symbol.to_s
			policiesString += "," if index < t.policies.length - 1
		  end
		  policiesString += "]"
        end
	  
        f.write(sprintf("%d,%s,%s,%d,%s,%s,%s,%s,%s,%s,%s\r\n",
          t.id_number,
          csvQuote(t.id.to_s),
          csvQuote(t.real_name),
          t.base_money,
          csvQuote(t.battle_BGM),
          csvQuote(t.victory_ME),
          csvQuote(t.intro_ME),
          ["Male", "Female", "Mixed"][t.gender],
          (t.skill_level == t.base_money) ? "" : t.skill_level.to_s,
          csvQuote(t.skill_code),
		  policiesString
        ))
      end
    }
    Graphics.update
  end

  #=============================================================================
  # Save individual trainer data to PBS file
  #=============================================================================
  def write_trainers
    File.open("PBS/trainers.txt", "wb") { |f|
      add_PBS_header_to_file(f)
      GameData::Trainer.each do |trainer|
        pbSetWindowText(_INTL("Writing trainer {1}...", trainer.id_number))
        Graphics.update if trainer.id_number % 50 == 0
        f.write("\#-------------------------------\r\n")
        if trainer.version > 0
          f.write(sprintf("[%s,%s,%d]\r\n", trainer.trainer_type, trainer.real_name, trainer.version))
        else
          f.write(sprintf("[%s,%s]\r\n", trainer.trainer_type, trainer.real_name))
        end
		if trainer.policies && trainer.policies.length > 0
		  policiesString = ""
		  trainer.policies.each_with_index do |policy_symbol,index|
			policiesString += policy_symbol.to_s
			policiesString += "," if index < trainer.policies.length - 1
		  end
          f.write(sprintf("Policies = %s\r\n", policiesString))
        end
        f.write(sprintf("Items = %s\r\n", trainer.items.join(","))) if trainer.items.length > 0
        trainer.pokemon.each do |pkmn|
          f.write(sprintf("Pokemon = %s,%d\r\n", pkmn[:species], pkmn[:level]))
          f.write(sprintf("    Name = %s\r\n", pkmn[:name])) if pkmn[:name] && !pkmn[:name].empty?
          f.write(sprintf("    Form = %d\r\n", pkmn[:form])) if pkmn[:form] && pkmn[:form] > 0
          f.write(sprintf("    Gender = %s\r\n", (pkmn[:gender] == 1) ? "female" : "male")) if pkmn[:gender]
          f.write("    Shiny = yes\r\n") if pkmn[:shininess]
          f.write("    Shadow = yes\r\n") if pkmn[:shadowness]
          f.write(sprintf("    Moves = %s\r\n", pkmn[:moves].join(","))) if pkmn[:moves] && pkmn[:moves].length > 0
          f.write(sprintf("    Ability = %s\r\n", pkmn[:ability])) if pkmn[:ability]
          f.write(sprintf("    AbilityIndex = %d\r\n", pkmn[:ability_index])) if pkmn[:ability_index]
          f.write(sprintf("    Item = %s\r\n", pkmn[:item])) if pkmn[:item]
          f.write(sprintf("    Nature = %s\r\n", pkmn[:nature])) if pkmn[:nature]
          ivs_array = []
          evs_array = []
          GameData::Stat.each_main do |s|
            next if s.pbs_order < 0
            ivs_array[s.pbs_order] = pkmn[:iv][s.id] if pkmn[:iv]
            evs_array[s.pbs_order] = pkmn[:ev][s.id] if pkmn[:ev]
          end
          f.write(sprintf("    IV = %s\r\n", ivs_array.join(","))) if pkmn[:iv]
          f.write(sprintf("    EV = %s\r\n", evs_array.join(","))) if pkmn[:ev]
          f.write(sprintf("    Happiness = %d\r\n", pkmn[:happiness])) if pkmn[:happiness]
          f.write(sprintf("    Ball = %s\r\n", pkmn[:poke_ball])) if pkmn[:poke_ball]
        end
      end
    }
    pbSetWindowText(nil)
    Graphics.update
  end
end