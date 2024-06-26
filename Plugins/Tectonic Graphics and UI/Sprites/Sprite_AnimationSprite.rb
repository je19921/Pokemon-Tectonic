=begin
A sprite whose sole purpose is to display an animation.  This sprite
can be displayed anywhere on the map and is disposed
automatically when its animation is finished.
Used for grass rustling and so forth.
=end
class AnimationSprite < RPG::Sprite
    def initialize(animID,map,tileX,tileY,viewport=nil,tinting=false,height=3)
      super(viewport)
      @tileX = tileX
      @tileY = tileY
      self.bitmap = Bitmap.new(1, 1)
      self.bitmap.clear
      @map = map
      setCoords
      pbDayNightTint(self) if tinting
      self.animation($data_animations[animID],true,height)
    end
  
    def setCoords
      self.x = ((@tileX * Game_Map::REAL_RES_X - @map.display_x) / Game_Map::X_SUBPIXELS).ceil
      self.x += Game_Map::TILE_WIDTH / 2
      self.y = ((@tileY * Game_Map::REAL_RES_Y - @map.display_y) / Game_Map::Y_SUBPIXELS).ceil
      self.y += Game_Map::TILE_HEIGHT
    end
  
    def dispose
      self.bitmap.dispose
      super
    end
  
    def update
      if !self.disposed?
        setCoords
        super
        self.dispose if !self.effect?
      end
    end
  end
  