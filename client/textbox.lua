
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

    function font:includes(kcode)
      for i=1,#charcodes do
        local b = string.byte(charcodes, i )
        if b == kcode then
          return true
        end
      end
      return false
    end
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
  
  function t:resetLoc(x,y)
    self:setLoc( x+SCRW/2, y - SCRH/2 )
  end
  function t:getWorldLoc()
    local x,y = self:getLoc()
    return x-SCRW/2, y+SCRH/2
  end

  local bgp = MOAIProp2D.new()
  bgp:setDeck( guiDeck )
  bgp:setIndex(25)
  bgp:setColor(0,0,0,0.5)
  hudLayer:insertProp(bgp)
  t.bgProp = bgp
  function t:updateBG()
    if self.fixedWidth then
      local x,y = self:getLoc()
      local th = font:getScale()
      self.bgProp:setLoc(x-SCRW/2 + self.fixedWidth/2,y+SCRH/2 - th/2 )
      self.bgProp:setScl(self.fixedWidth,th)
    else
      local x1,y1,x2,y2 = self:getStringBounds(1,9999)
      local cx,cy = avg(x1,x2), avg(y1,y2)
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




function makeChatBox(x,y)
  local t = makeTextBox( x,y, "", 200 )
  t.cursorPos = 1
  t.accumTime = 0
  t.content = ""

  local cur = MOAIProp2D.new()
  cur:setDeck(guiDeck)
  cur:setIndex(26)
  cur:setLoc(0,0)
  local th = font:getScale()
  cur:setScl(th/8,th-3)
  hudLayer:insertProp(cur)
  t.cursorProp = cur
  
  function t:update(dt)
    self.accumTime = self.accumTime + dt
    local flg = int(self.accumTime*5) % 2
    local x,y = self:getWorldLoc()
    local x1,y1,x2,y2 = self:getStringBounds(1,9999)
    local cursorx = x2
    if not x1 then cursorx = x end
    local th = font:getScale()
    
    if flg == 0 then
      self.cursorProp:setLoc(cursorx+3,y-th/2+2)
    else
      self.cursorProp:setLoc(-999999,-9999999)
    end
  end

  function t:receive(kcode)
    if font:includes(kcode) then
      local s = string.char(kcode)
      self.content = self.content .. s
      self:set(self.content)
      self.accumTime = 0
      return true
    end
    return false
  end
  function t:delete()
    self.content = string.sub( self.content, 1, #self.content-1)
    self:set(self.content)
    self.accumTime = 0    
  end

  function t:clean()
    hudLayer:removeProp(self.bgProp)
    hudLayer:removeProp(self)
    hudLayer:removeProp(self.cursorProp)
  end
  
  
  return t
end
