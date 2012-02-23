
--local charcodes = ' !\"#$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~あいうえおぁぃぅぇぉかきくけこがぎぐげごさしすせそざじずぜぞたちつてとだぢづでどなにぬねのはひふへほばびぶべぼぱぴぷぺぽまみむめもやゆよゃゅょらりるれろわをん、。アイウエオァィゥェォカキクケコガギグゲゴサシスセソザジズゼゾタチツテトダヂヅデドナニヌネノハヒフヘホバビブベボパピプペポマミムメモヤユヨャュョラリルレロワヲンーッっ　「」'
--   font:loadFromTTF( "images/ipag.ttf", charcodes, 12, 72 )
--font:loadFromTTF( "images/cinecaption227.ttf", charcodes, 16, 72 )


-- now moai three-dee  loadFromTTF is broken 

charcodes = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 .,:;!?()&/-'
font = nil
function ensureFont()
  if not font then 
    font = MOAIFont.new ()
    font:load ( './images/FontVerdana18.png', charcodes )
  end
end

-- convert screen coord to hud view coord
function makeTextBox( x,y, str, width )
  ensureFont()
  local t = MOAITextBox.new()
  t:setString(str)
  t:setFont(font)
  t:setTextSize(font:getScale())
  t:setRect(-SCRW/2,-SCRH/2,SCRW/2,SCRH/2)       -- TODO?
  t:setYFlip(true)
  -- yflipしてる場合、0,0にすると左上で、+xが右、 +yが上、なので
  t:setLoc( x +SCRW/2, y - SCRH/2 )
  t:setColor(1,1,1)

  t.fixedWidth = width
  
  function t:resetLoc(self,x,y)
    self:setLoc( x+SCRW/2, y - SCRH/2 )
  end

  local bgp = MOAIProp2D.new()
  bgp:setDeck( guiDeck )
  bgp:setIndex(25)
  bgp:setColor(0,0,0,0.3)
  hudLayer:insertProp(bgp)
  t.bgProp = bgp
  function t:updateBG()
    if self.fixedWidth then
      local x,y = self:getLoc()
      local th = font:getScale()
      self.bgProp:setLoc(x-SCRW/2 + self.fixedWidth/2,y+SCRH/2 - th/2 )
      self.bgProp:setScl(self.fixedWidth,th)
      print("xxx",x,y, font:getScale())      
    else
      local x1,y1,x2,y2 = self:getStringBounds(1,9999)
      local cx,cy = avg(x1,x2), avg(y1,y2)

      print( "ccccccccc:",cx,cy)
      self.bgProp:setLoc(cx,-cy)
      self.bgProp:setScl((x2-x1),(y2-y1))
    end    
  end
  function t:set(s)
    self:setString(s)
    self:updateBG()
  end
  t:updateBG()
  
  hudLayer:insertProp(t)
  return t
end

