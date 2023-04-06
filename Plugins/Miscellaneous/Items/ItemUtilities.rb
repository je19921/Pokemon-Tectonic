#===============================================================================
# Give an item to a Pokémon to hold, and take a held item from a Pokémon
#===============================================================================
def pbGiveItemToPokemon(item,pkmn,scene)
    newitemname = GameData::Item.get(item).name
    if pkmn.egg?
      scene.pbDisplay(_INTL("Eggs can't hold items."))
      return false
    end

    # If they don't have an item, just give them it
    unless pkmn.hasItem?
        moveItemFromBagToPokemon(item,pkmn,scene)
        return true
    end

    # If the pokemon can have multiple items due to an ability, check for legality thereof
    if pkmn.canHaveMultipleItems?
        if pkmn.canHaveItem?(item, true)
            moveItemFromBagToPokemon(item,pkmn,scene)
            return true
        elsif scene.pbConfirm(_INTL("Swap its items with the #{newitemname}?"))
            pbTakeItemsFromPokemon(pkmn)
            moveItemFromBagToPokemon(item,pkmn,scene) unless pkmn.hasItem?
            return true
        end
    # Otherwise, allow the player to swap the one held item for another
    else
        alreadyHoldingAlert(pkmn,pkmn.firstItem,scene)
        if scene.pbConfirm(_INTL("Would you like to switch the two items?"))
            $PokemonBag.pbDeleteItem(item)
            if !$PokemonBag.pbStoreItem(pkmn.firstItem)
                raise _INTL("Could't re-store deleted item in Bag somehow") unless $PokemonBag.pbStoreItem(item)
                scene.pbDisplay(_INTL("The Bag is full. The Pokémon's item could not be removed."))
            else
                pkmn.setItems(item)
                scene.pbDisplay(_INTL("Took the {1} from {2} and gave it the {3}.",getItemName(pkmn.firstItem),pkmn.name,newitemname))
                return true
            end
        end
    end
    return false
end

def moveItemFromBagToPokemon(item,pkmn,scene = nil)
    $PokemonBag.pbDeleteItem(item)
    pkmn.giveItem(item)
    scene&.pbDisplay(_INTL("{1} is now holding the {2}.",pkmn.name,getItemName(item)))
end

def alreadyHoldingAlert(pkmn,itemID,scene)
    itemName = getItemName(itemID)
    if itemID == :LEFTOVERS
        scene.pbDisplay(_INTL("{1} is already holding some {2}.",pkmn.name,itemName))
    elsif itemName.starts_with_vowel?
        scene.pbDisplay(_INTL("{1} is already holding an {2}.",pkmn.name,itemName))
    else
        scene.pbDisplay(_INTL("{1} is already holding a {2}.",pkmn.name,itemName))
    end
end

def pbTakeOneItemFromPokemon(pkmn)
    if pkmn.items.empty?
        pbMessage(_INTL("{1} isn't holding anything.", pkmn.name))
        return false
    end

    commands = []
    pkmn.items.each do |item|
        commands.push(getItemName(item))
    end
    
    commands[commandCancel = commands.length] = _INTL("Cancel")

    selection = pbMessage(_INTL("Take which item?"),commands,commandCancel+1)

    return false if selection == commandCancel

    selectedItem = pkmn.items[selection]
    if !$PokemonBag.pbCanStore?(selectedItem)
        pbMessage(_INTL("The Bag is full. The Pokémon's {1} could not be removed.",getItemName(item)))
        return false
    else
        $PokemonBag.pbStoreItem(selectedItem)
        pbMessage(_INTL("Received the {1} from {2}.", getItemName(selectedItem), pkmn.name))
        pkmn.removeItem(selectedItem)
        return true
    end
end

def pbTakeItemsFromPokemon(pkmn)
    if pkmn.items.empty?
        pbMessage(_INTL("{1} isn't holding anything.", pkmn.name))
        return 0
    end

    itemsTaken = 0
    itemsToRemove = []
    pkmn.items.each do |item|
        if !$PokemonBag.pbCanStore?(item)
            pbMessage(_INTL("The Bag is full. The Pokémon's {1} could not be removed.",getItemName(item)))
        else
            $PokemonBag.pbStoreItem(item)
            pbMessage(_INTL("Received the {1} from {2}.", getItemName(item), pkmn.name))
            itemsToRemove.push(item)
            itemsTaken += 1
        end
    end
    itemsToRemove.each do |itemToRemove|
        pkmn.removeItem(itemToRemove)
    end
    return itemsTaken
end