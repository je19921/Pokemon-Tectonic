#===============================================================================
# Scene class for handling appearance of the screen
#===============================================================================
class MoveLearner_Scene
    VISIBLEMOVES = 4
  
    def pbDisplay(msg,brief=false)
      UIHelper.pbDisplay(@sprites["msgwindow"],msg,brief) { pbUpdate }
    end
  
    def pbConfirm(msg)
      UIHelper.pbConfirm(@sprites["msgwindow"],msg) { pbUpdate }
    end
  
    def pbUpdate
      pbUpdateSpriteHash(@sprites)
    end
  
    def pbStartScene(pokemon,moves)
      @pokemon=pokemon
      @moves=moves
      moveCommands=[]
      moves.each { |m| moveCommands.push(GameData::Move.get(m).name) }
      # Create sprite hash
      @viewport=Viewport.new(0,0,Graphics.width,Graphics.height)
      @viewport.z=99999
      @sprites={}
      bg_path = "Move Tutor/reminderbg"
      bg_path += "_dark" if darkMode?
      addBackgroundPlane(@sprites,"bg",bg_path,@viewport)
      @sprites["pokeicon"]=PokemonIconSprite.new(@pokemon,@viewport)
      @sprites["pokeicon"].setOffset(PictureOrigin::Center)
      @sprites["pokeicon"].x=320
      @sprites["pokeicon"].y=84
      @sprites["background"]=IconSprite.new(0,0,@viewport)
      sel_path = "Graphics/Pictures/Move Tutor/reminderSel"
      sel_path += "_dark" if darkMode?
      @sprites["background"].setBitmap(sel_path)
      @sprites["background"].y=78
      @sprites["background"].src_rect=Rect.new(0,72,258,72)
      @sprites["overlay"]=BitmapSprite.new(Graphics.width,Graphics.height,@viewport)
      pbSetSystemFont(@sprites["overlay"].bitmap)
      @sprites["commands"]=Window_CommandPokemon.new(moveCommands,32)
      @sprites["commands"].height=32*(VISIBLEMOVES+1)
      @sprites["commands"].visible=false
      @sprites["msgwindow"]=Window_AdvancedTextPokemon.new("")
      @sprites["msgwindow"].visible=false
      @sprites["msgwindow"].viewport=@viewport
      @typebitmap=AnimatedBitmap.new(addLanguageSuffix("Graphics/Pictures/types"))
      pbDrawMoveList
      pbDeactivateWindows(@sprites)
      # Fade in all sprites
      pbFadeInAndShow(@sprites) { pbUpdate }
    end
  
    def pbDrawMoveList
      overlay=@sprites["overlay"].bitmap
      overlay.clear
      type1_number = GameData::Type.get(@pokemon.type1).id_number
      type2_number = GameData::Type.get(@pokemon.type2).id_number
      type1rect=Rect.new(0, type1_number * 28, 64, 28)
      type2rect=Rect.new(0, type2_number * 28, 64, 28)
      if @pokemon.type1==@pokemon.type2
        overlay.blt(400,70,@typebitmap.bitmap,type1rect)
      else
        overlay.blt(366,70,@typebitmap.bitmap,type1rect)
        overlay.blt(436,70,@typebitmap.bitmap,type2rect)
      end
      title_base = MessageConfig::DARK_TEXT_MAIN_COLOR
      title_shadow = MessageConfig::DARK_TEXT_SHADOW_COLOR
      textpos=[
         [_INTL("Teach which move?"),16,2,0,title_base,title_shadow]
      ]
      imagepos=[]
      yPos=76
      base = MessageConfig.pbDefaultTextMainColor
      shadow = MessageConfig.pbDefaultTextShadowColor
      for i in 0...VISIBLEMOVES
        moveobject=@moves[@sprites["commands"].top_item+i]
        if moveobject
          moveData=GameData::Move.get(moveobject)
          type_number = GameData::Type.get(moveData.type).id_number
          imagepos.push([addLanguageSuffix("Graphics/Pictures/types"), 12, yPos + 8, 0, type_number * 28, 64, 28])
          textpos.push([moveData.name,80,yPos,0,base,shadow])
          if moveData.total_pp>0
            textpos.push([_INTL("PP"),112,yPos+32,0,base,shadow])
            textpos.push([_INTL("{1}/{1}",moveData.total_pp),230,yPos+32,1,base,shadow])
          else
            textpos.push(["-",80,yPos,0,base,shadow])
            textpos.push(["--",228,yPos+32,1,base,shadow])
          end
        end
        yPos+=64
      end
      sel_path = "Graphics/Pictures/Move Tutor/reminderSel"
      sel_path += "_dark" if darkMode?
      imagepos.push([sel_path,
         0,78+(@sprites["commands"].index-@sprites["commands"].top_item)*64,
         0,0,258,72])
      selMoveData=GameData::Move.get(@moves[@sprites["commands"].index])
      basedamage=selMoveData.base_damage
      category=selMoveData.category
      accuracy=selMoveData.accuracy
      textpos.push([_INTL("CATEGORY"),272,108,0,base,shadow])
      textpos.push([_INTL("POWER"),272,140,0,base,shadow])
      textpos.push([basedamage<=1 ? basedamage==1 ? "???" : "---" : sprintf("%d",basedamage),
            468,140,2,base,shadow])
      textpos.push([_INTL("ACCURACY"),272,172,0,base,shadow])
      textpos.push([accuracy==0 ? "---" : "#{accuracy}%",
            468,172,2,base,shadow])
      pbDrawTextPositions(overlay,textpos)
      imagepos.push(["Graphics/Pictures/category",436,116,0,category*28,64,28])
      if @sprites["commands"].index<@moves.length-1
        imagepos.push(["Graphics/Pictures/Move Tutor/reminderButtons",48,350,0,0,76,32])
      end
      if @sprites["commands"].index>0
        imagepos.push(["Graphics/Pictures/Move Tutor/reminderButtons",134,350,76,0,76,32])
      end
      pbDrawImagePositions(overlay,imagepos)
      drawTextEx(overlay,272,214,230,5,selMoveData.description,
      base,shadow)
    end
  
    # Processes the scene
    def pbChooseMove
      oldcmd=-1
      pbActivateWindow(@sprites,"commands") {
        loop do
          oldcmd=@sprites["commands"].index
          Graphics.update
          Input.update
          pbUpdate
          if @sprites["commands"].index!=oldcmd
            @sprites["background"].x=0
            @sprites["background"].y=78+(@sprites["commands"].index-@sprites["commands"].top_item)*64
            pbDrawMoveList
          end
          if Input.trigger?(Input::BACK)
            return nil
          elsif Input.trigger?(Input::USE)
            return @moves[@sprites["commands"].index]
          end
        end
      }
    end
  
    # End the scene here
    def pbEndScene
      pbFadeOutAndHide(@sprites) { pbUpdate }
      pbDisposeSpriteHash(@sprites)
      @typebitmap.dispose
      @viewport.dispose
    end
  end