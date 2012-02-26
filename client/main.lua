----------------------------------------------------------------
-- Copyright (c) 2010-2011 Kengo Nakajima.
-- All Rights Reserved. 
-- http://twitter.com/ringo
----------------------------------------------------------------

require "./const"
require "./util"
require "./mesh"

require "./textbox"
require "./gui"
require "./config" 

package.path = package.path .. ";./deps/lua-msgpack/?.lua;"

require "./deps/lua-msgpack/msgpack" 
require "./deps/lua-mprpc/mprpc"
require "./netemu"

local net = netemu

assert( msgpack and net and mprpc )

rpc = mprpc.create(net,msgpack)

-----------------    

SCRW, SCRH = 960, 640

ZOOM_MINY = 500
ZOOM_MAXY = 5000000

CURSOR_MAXY = 2000

CHUNKSZ = 16
CELLUNITSZ = 32


-----------------


math.randomseed(1)

MOAISim.openWindow ( "test", SCRW, SCRH )
MOAIGfxDevice.setClearDepth ( true )

viewport = MOAIViewport.new ()
viewport:setSize ( SCRW, SCRH )
viewport:setScale ( SCRW, SCRH )

fieldLayer = MOAILayer.new()
fieldLayer:setViewport(viewport)
fieldLayer:setSortMode(MOAILayer.SORT_Y_ASCNDING ) -- don't need layer sort
MOAISim.pushRenderPass(fieldLayer)

cursorLayer = MOAILayer.new()
cursorLayer:setViewport(viewport)
cursorLayer:setSortMode(MOAILayer.SORT_Y_ASCNDING ) -- don't need layer sort
MOAISim.pushRenderPass(cursorLayer)


hudLayer = MOAILayer2D.new()
hudLayer:setViewport(viewport)
MOAISim.pushRenderPass(hudLayer)

MOAIUntzSystem.initialize( 44100, 1024 )

clkSound = MOAIUntzSound.new()
clkSound:load( "sounds/clk.wav" )
clkSound:setVolume( 0.4 )
btnSound = MOAIUntzSound.new()
btnSound:load( "sounds/whip.wav" )


guiDeck = loadTileDeck2( "./images/guibase.png", 8,8, 32, 256,256, nil,true)
baseDeck = loadTex( "./images/citybase.png" )
cursorDeck = loadGfxQuad( "./images/cursor.png" )


scrollX, scrollZ = 0,0


-- vx,vy : starts from zero, grid coord.
-- zoomlevel : 1,2,4,8, ..
function makeChunkHeightMapProp(vx,vz,zoomlevel)
  local p = MOAIProp.new()

  p.zoomLevel = zoomlevel
  function p:setData( tdata, hdata, mhdata )
--    print("hm:setData:", #tdata, #hdata, #mhdata, tot )
    local nElem = ( CHUNKSZ+1 ) * (CHUNKSZ+1) -- rightside and bottomsize require 1 more vertices
    assert( #tdata == nElem )
    assert( #hdata == nElem )
    assert( #mhdata == nElem )
    self.tdata, self.hdata, self.mhdata  = dupArray(tdata), dupArray(hdata), dupArray(mhdata)
    self.validMockNum = 0
    for i =1,#tdata do if hdata[i] ~= mhdata[i] then self.validMockNum = self.validMockNum + 1 end end
  end
    
  function p:updateHeightMap(editmode)
    local lightRate = 1
    if editmode then lightRate = 0.5 end

    local showhdata = self.hdata
    if editmode then
      showhdata = self.mhdata
    end

    local showreddata = {}
    if not editmode then -- imcomplete on chunk border! TODO:refactor.
      for i=1,#self.hdata do showreddata[i] = false end
      for z=0,CHUNKSZ-1 do
        for x=0,CHUNKSZ-1 do
          local ind = x + z*(CHUNKSZ+1) + 1
          if self.mhdata[ind] < self.hdata[ind] then
            showreddata[ind] = true
            if ind - 1 >= 1 then
              showreddata[ ind - 1 ] = true
            end
            if ind - (CHUNKSZ+1) >= 1 then
              showreddata[ ind - (CHUNKSZ+1) ] = true
            end
            if ind - (CHUNKSZ+1) - 1 >= 1 then
              showreddata[ ind - (CHUNKSZ+1) - 1] = true
            end          
          end
        end
      end
    end
    
--    for i,v in ipairs(showhdata) do
--      if showhdata[i] ~= self.mhdata[i] then
--        print( "iii:",i,v, showhdata[i], self.mhdata[i])
--      end      
--    end

    local showtdata
    if not editmode then
      showtdata = self.tdata
    else
      showtdata = {} -- incomplete on chunk border. TODO:refactor!
      for i,v in ipairs(self.tdata) do showtdata[i]=v end
      for z=0,CHUNKSZ-1 do
        for x=0,CHUNKSZ-1 do
          local ind = x + z*(CHUNKSZ+1) + 1
--          if self.mhdata[ind]~=self.hdata[ind] then
--            print("k:",x,z,showtdata[ind],showhdata[ind],showtdata[ind-1],showhdata[ind-1])
--          end          
          if showhdata[ind] > 0 then
            if self.tdata[ind] == CELLTYPE.WATER then
              showtdata[ind] = CELLTYPE.SAND
            end
            if ind - 1 >= 1 and showhdata[ind-1] == 0 and showtdata[ind-1] == CELLTYPE.WATER then
              showtdata[ ind-1 ] = CELLTYPE.SAND
            end
            if ind - (CHUNKSZ+1) >= 1 and showhdata[ind-(CHUNKSZ+1)] == 0 and showtdata[ind-(CHUNKSZ+1)] == CELLTYPE.WATER then
              showtdata[ ind - (CHUNKSZ+1) ] = CELLTYPE.SAND
            end
            if ind - (CHUNKSZ+1) - 1 >= 1 and showhdata[ind-(CHUNKSZ+1)-1] == 0 and showtdata[ind-(CHUNKSZ+1)-1] == CELLTYPE.WATER then
              showtdata[ ind - (CHUNKSZ+1) - 1] = CELLTYPE.SAND
            end
          end          
        end
      end
    end
    

    local hm = makeHeightMapMesh(CELLUNITSZ*self.zoomLevel, CHUNKSZ+1,CHUNKSZ+1, lightRate, showhdata, showtdata, showreddata, false, self.zoomLevel )    
    self:setDeck(hm)
    
    if not editmode and self.validMockNum > 0 then
      if not self.mockp then 
        self.mockp = MOAIProp.new()
        fieldLayer:insertProp(self.mockp)
        self.mockp:setLoc( self.vx * CELLUNITSZ*zoomlevel, 1, self.vz* CELLUNITSZ *zoomlevel )        
      end
      
      -- show high places
      local omitdata = {}
      for i=1,#self.hdata do omitdata[i]=false end

      for z=0,CHUNKSZ-1 do
        for x=0,CHUNKSZ-1 do
          local ind = x + z*(CHUNKSZ+1) + 1
          if showreddata[ind] then
            omitdata[ind] = true
          elseif self.hdata[ind] == self.mhdata[ind] and self.hdata[ind+1] == self.mhdata[ind+1] and self.hdata[ind +(CHUNKSZ+1)] == self.mhdata[ind + (CHUNKSZ+1)] and self.hdata[ind + (CHUNKSZ+1)+1] == self.mhdata[ind + (CHUNKSZ+1)+1] then
            omitdata[ind] = true
          end
        end
      end
      
      local mockmesh = makeHeightMapMesh( CELLUNITSZ*self.zoomLevel, CHUNKSZ+1, CHUNKSZ+1,1, self.mhdata, self.tdata, omitdata, true, self.zoomLevel )
      self.mockp:setDeck(mockmesh )
      self.mockp:setColor(1,1,1,1)
      self.mockp:setCullMode( MOAIProp.CULL_BACK )
      self.mockp:setDepthTest( MOAIProp.DEPTH_TEST_LESS_EQUAL )
    else
      if self.mockp then self.mockp:setDeck(nil) end
    end
    self:setLoc( self.vx*CELLUNITSZ+scrollX, 0,self.vz*CELLUNITSZ+scrollZ )
  end

  function p:dataIndex(modx,modz)
    return modx + modz * ( CHUNKSZ + 1 ) + 1    
  end
  
  function p:getHeight(worldx,worldz)
    if not self.hdata then return nil end
    local modx,modz = worldx % CHUNKSZ, worldz % CHUNKSZ
    return self.hdata[ self:dataIndex(modx,modz)]
  end
  function p:getMockHeight(worldx,worldz)
    if not self.mhdata then return nil end
    local modx,modz = worldx % CHUNKSZ, worldz % CHUNKSZ
    return self.mhdata[ self:dataIndex(modx,modz)]
  end
      
  function p:toggleEditMode(mode)
--    print("toggleEditMode:",self.vx, self.vz, mode)
    if self.hdata then 
      self:updateHeightMap( mode )
    end    
    self.editMode = mode
    self:setLoc( self:getLoc() )
  end
  local origsetloc = p.setLoc
  function p:setLoc(x,y,z)
    if self.mockp then
      self.mockp:setLoc(x,y+1,z)
    end    
    origsetloc(self,x,y,z)
  end

  function p:inWindow(margin)
    local x,y,z = self:getLoc() 
    local winx1,winy1 = fieldLayer:worldToWnd(x,y,z)
    local winx2,winy2 = fieldLayer:worldToWnd(x+CELLUNITSZ*CHUNKSZ*self.zoomLevel, y, z+CELLUNITSZ*CHUNKSZ+self.zoomLevel )
    return (  winx2 >= -margin and winy2 >= -margin and winx1 <= SCRW+margin and winy1 <= SCRH+margin )
  end
          
  function p:poll()
    if self.state == "init" then
      if conn then
        print("loading rect:", self.state, "xz:", self.vx, self.vz, "zl:", self.zoomLevel )      
        conn:emit("getFieldRect", {
            x1 = self.vx,
            z1 = self.vz,
            x2 = self.vx + CHUNKSZ*self.zoomLevel + 1*self.zoomLevel,
            z2 =  self.vz + CHUNKSZ*self.zoomLevel + 1*self.zoomLevel,
            skip = self.zoomLevel
          } )
          self.state = "loading"
      end
    end
  end

  function p:clean()
    print("chunk clean:",self.zoomLevel,self.vx,self.vz)
    if self.mockp then fieldLayer:removeProp(self.mockp) end
    fieldLayer:removeProp(self)
    chunkTable:remove( self.zoomLevel, int(self.vx/CHUNKSZ/self.zoomLevel), int(self.vz/CHUNKSZ/self.zoomLevel) )
  end
  

  p.state = "init"
  p.vx, p.vz = vx,vz

  p:setCullMode( MOAIProp.CULL_BACK )
  p:setDepthTest( MOAIProp.DEPTH_TEST_LESS_EQUAL )
  p:setLoc(vx*CELLUNITSZ*zoomlevel, 0, vz*CELLUNITSZ*zoomlevel )

  fieldLayer:insertProp(p)
  return p
end

function makeCursor()
  local p = MOAIProp.new()
  p:setDeck(cursorDeck)
  p:setScl(0.3,0.3,0.3)
  p:setRot(-45,0,0)
--  p:setCullMode( MOAIProp.CULL_BACK)
--  p:setDepthTest( MOAIProp.DEPTH_TEST_LESS_EQUAL )
  function p:setAtGrid(editmode, x,z)
    local xx,zz = x * CELLUNITSZ, z * CELLUNITSZ
    local h = getFieldHeight(x,z)
    if editmode then h = getFieldMockHeight(x,z) end
    if h then
      local yy = h * CELLUNITSZ
      self:setLoc(xx + scrollX,yy + CELLUNITSZ/2 - 5, zz + scrollZ)
      self.lastGridX, self.lastGridZ = x,z
    end    
  end 
  return p
end

-- init all tools
function initButtons()
  local baseX, baseY = -SCRW/2 + 50, SCRH/2 - 360
  local x,y = baseX, baseY

  upButton = makeButton( "up", x,y, guiDeck, 4, byte("1"), function(self,x,y,down)
      if down then selectButton(upButton) end      
    end)
  upButton.editMode = true
  y = y - BUTTONSIZE
  downButton = makeButton( "down", x,y, guiDeck, 5, byte("2"), function(self,x,y,down)
      if down then selectButton(downButton) end
    end)
  downButton.editMode = true
  y = y - BUTTONSIZE
  flatButton = makeButton( "flat", x,y, guiDeck, 3, byte("3"), function(self,x,y,down)
      if down then selectButton(flatButton) end
    end)
  flatButton.editMode = true  
  y = y - BUTTONSIZE  
  clearButton = makeButton( "clear", x,y, guiDeck, 11, byte("4"), function(self,x,y,down)
      if down then selectButton(clearButton) end
    end)
  clearButton.editMode = false
  guiSelectModeCallback = function(b)
    clearAllEditModeChunks()
    if b then btnSound:play() end
    if b then
      if not lastControlX then
        lastControlX, lastControlZ = 0,0
      end      
      setEditModeAroundCursor(lastControlX,lastControlZ, b.editMode)
    end
  end
  editButtons = { upButton, downButton, flatButton, clearButton }
end
function toggleEditButtonsAvailable(flag)
  for i,v in ipairs(editButtons) do
    v:setAvailable(flag)
  end  
end



-- log lines
function initLogLines()
  local baseX, baseY = -SCRW/2 + 80, 0
  local maxLogLineNum = 14
  logLines = {}
  for i = 1,maxLogLineNum do
    local x,y = baseX, baseY - i * font:getScale()
    local line = makeTextBox(x,y, "" )
    table.insert( logLines, line )
  end  
end
function appendLog(s)
  for i=1,#logLines-1 do -- up, younger number
    logLines[i]:set( logLines[i+1]:getString() )
  end
  logLines[ #logLines ]:set(s)
end



-- zoom slider
function initZoomSlider()
  local baseX, baseY = -SCRW/2 + 50, SCRH/2 - 80
  local x,y = baseX, baseY

  zoomInButton = makeButton( "zoomIn", x,y, guiDeck, 17, byte("k"), function(self,x,y,down)
      if down then camera:retargetYrate( 0.5 ) end
    end)
  zoomInButton.flippable = false

  zoomTable={}
  for i=1,128 do
    local yy = ZOOM_MINY * math.pow( 2, i / 10.0 )
    if yy < ZOOM_MINY then yy = ZOOM_MINY end
    if yy > ZOOM_MAXY then yy = ZOOM_MAXY end    
    zoomTable[i] = yy
  end
  
  zoomSliders = {}  
  for i=1,4 do
    y = y - BUTTONSIZE
    local b = makeButton( "zoomSlider"..i, x,y, guiDeck, nil, nil, function(self,x,y,down)
        local clickH = baseY - y - 16 -- 0 ~ 128
        if clickH < 1 then clickH = 1 end
        if clickH > 128 then clickH = 128 end
        local toY = zoomTable[ clickH ]
        camera:retargetY(toY)
        print("slider:", baseY - y, "toy:", toY, zoom )
      end)
    b.slideIndex = i
    b.flippable = false
    b:setIndex(19)
    table.insert(zoomSliders,b)
  end
  y = y - BUTTONSIZE
  zoomOutButton = makeButton( "zoomOut", x,y, guiDeck, 18, byte("j"), function(self,x,y,down)
      if down then camera:retargetYrate( 1.5 ) end
    end)
  zoomOutButton.flippable = false

  -- slider tab will be automatically updated when moving camera.
  zoomSliderTab = makeButton( "sliderTab", baseX,baseY - BUTTONSIZE/2 - 4, guiDeck, nil, nil, nil )
  zoomSliderTab.flippable = false
  zoomSliderTab:setIndex(20)
  zoomSliderTab.baseY = baseY

  function zoomSliderTab:update(cam)
    local xx,yy = self:getLoc()
    local x,y,z = cam:getLoc()
    for i,v in ipairs(zoomTable) do      
      if v >= y then
        
        self:setLoc(xx,self.baseY - BUTTONSIZE/2 - 4 - i )
        break
      end
    end
    if y == ZOOM_MAXY then
      local bx,by = zoomOutButton:getLoc()
      self:setLoc(xx,by+BUTTONSIZE - BUTTONSIZE/2+4)
    end    
  end
end


-- chat
function startChatMode()
  if not chatBox then chatBox = makeChatBox(-SCRW/2 + 80,-SCRH/2+40) end
end
function endChatMode(toSend)
  if chatBox then
    if toSend and conn then
      conn:emit("chat", { text = chatBox.content } )
    end
    chatBox:clean()
    chatBox=nil
  end  
end



---------------

function modMock(x,z,dh)
  if conn then
    conn:emit("modifyMock", { x=x,z=z,mod=dh,unit=CHUNKSZ } )
  end  
end

-- input

keyState={}
function onKeyboardEvent(k,dn)
  
  local hit = processButtonShortcutKey(k,dn)

  if not hit and dn then
    print("keyhit:", k, "chatbox:", chatBox )
    if k == 13 then -- start chat
      if chatBox then
        endChatMode(true)
      else
        startChatMode()
      end      
    end

    if chatBox then
      if chatBox:receive(k) then
        hit = true
      end
      if k == 127 then -- delete
        chatBox:delete()
      end      
    else
      if k == 108 then --l
        setZoomLevel( currentZoomLevel * 2 )
      end
      if k == 109 then --m
        local nz = int( currentZoomLevel / 2 )
        if nz < 1 then nz = 1 end
        setZoomLevel(nz)
      end
      if k == 110 then --n
        chunkTable:dump()
      end
     
    end
  end

  if not hit then
    keyState[k] = dn
  end
end

MOAIInputMgr.device.keyboard:setCallback( onKeyboardEvent )

lastPointerX,lastPointerY=nil,nil

function onMouseLeftDrag(mousex,mousey)
  local x,z = cursorProp.lastGridX, cursorProp.lastGridZ
  local modH = 0
  if guiSelectedButton == flatButton then
    local h = getFieldMockHeight(x,z)
    local dh = h - flatButton.heightToSet
    if dh == 0 then
      modH = 0
    elseif dh > 0 then
      modH = -1
    elseif dh < 0 then
      modH = 1
    end
  elseif guiSelectedButton == upButton then
    modH = 1
  elseif guiSelectedButton == downButton then
    modH = -1
  elseif guiSelectedButton == clearButton then
    local realh, mockh = getFieldHeight(x,z), getFieldMockHeight(x,z)
    if realh > mockh then
      modH = 1
    elseif realh < mockh then
      modH = -1
    end      
  end
  if modH ~= 0 then
    modMock(x,z,modH)
    clkSound:play()
  end  
  cursorProp:setAtGrid(true,x,z)     
end

function onPointerEvent(mousex,mousey)
  lastPointerX, lastPointerY = mousex, mousey
  if currentMouseLeftDown then
    onMouseLeftDrag(mousex,mousey)
  end  
end

MOAIInputMgr.device.pointer:setCallback( onPointerEvent )

function updateCallback(x,z)
  local chx, chz = int( x / CHUNKSZ ), int( z / CHUNKSZ )
  for i,chunk in ipairs(chunks) do
    if chunk.chx >= chx-1 and chunk.chx <= chx+1 and chunk.chz >= chz-1 and chunk.chz <= chz+1 then
      chunk.toUpdate = true
    end          
  end        
end

function updateAllChunks()
  -- check updated chunks
  for i,chunk in ipairs(chunks) do
    if chunk.toUpdate then
      if guiSelectedButton then
        chunk:toggleEditMode( guiSelectedButton.editMode )
      end      
      chunk.toUpdate = false
    end
  end
end

  
currentMouseLeftDown = nil
function onMouseLeftEvent(down)
  currentMouseLeftDown = down

  -- click events
  if not down then return end
  if not lastPointerX then return end

  -- GUIs are always 1st priority
  local wx,wy = hudLayer:wndToWorld(lastPointerX,lastPointerY)
  if processButtonMouseEvent(wx,wy,down) then
    return
  end
  


  local camx,camy,camz = camera:getLoc()
  -- move camera
  if guiSelectedButton == nil or camy > CURSOR_MAXY then
    print( "movecam", lastControlX, lastControlZ)
    seekWorldLoc( - lastControlX * CELLUNITSZ, - lastControlZ * CELLUNITSZ, 0.5 )
    return
  end
  -- edit on field, with cursor.  
  if not cursorProp or not cursorProp.lastGridX then return end
  local curx,cury,curz = cursorProp:getLoc()
  if cury < 0 then return end
  
  local x,z = cursorProp.lastGridX, cursorProp.lastGridZ

  if guiSelectedButton then
    if guiSelectedButton == upButton then
      modMock( x,z,1)
    elseif guiSelectedButton == downButton then
      modMock( x,z,-1)
    elseif guiSelectedButton == clearButton then
      local realh, mockh = getFieldHeight(x,z), getFieldMockHeight(x,z)
      local modH = 0
      if realh > mockh then
        modH = 1
      elseif realh < mockh then
        modH = -1
      end
      if modH ~= 0 then modMock(x,z,modH) end
    elseif guiSelectedButton == flatButton then
      flatButton.heightToSet = getFieldMockHeight(x,z)
    end
    clkSound:play()
  end
  
  cursorProp:setAtGrid( true, x,z )
end

MOAIInputMgr.device.mouseLeft:setCallback( onMouseLeftEvent )

----------------
-- chunk table
function ChunkTable(absW,absH)
  local ct = {
    absWidth = absW,
    absHeight = absH
  }
  ct.list = {} 
  ct.zoomary = {}  -- array of arrays of chunks. ch = [zoomlevel][x + z*w]
  local zoomlevels = { 1,2,4,8,16,32,64,128,256,512,1024,2048,4096,8192,16384 }
  for i,v in ipairs(zoomlevels) do
    ct.zoomary[v] = {}
  end
  
  -- zoomlevel: 1,2,4,8,16,...
  function ct:ind(zoomlevel, chx,chz)
    local chunksz = CHUNKSZ * zoomlevel
    local numHorizontalChunk = int(self.absWidth / chunksz)
    local numVerticalChunk = int(self.absHeight / chunksz)
    
    if chx < 0 or chz < 0 or chx >= numHorizontalChunk or chz >= numVerticalChunk then
      return nil
    end    
    return (chx + chz * numHorizontalChunk)+1    
  end
  
  function ct:setChunk(zoomlevel, chx,chz, ch)
    local t = self.zoomary[zoomlevel]
    assert(t)
    local i = self:ind(zoomlevel, chx,chz )
    if t[i] then
      local r = self:clearList(t[i])
      assert(r)
    end    
    t[i] = ch
    table.insert( self.list, ch )
  end
  function ct:getChunk(zoomlevel, chx,chz)
    local i = self:ind(zoomlevel,chx,chz)
    local t = self.zoomary[zoomlevel]
    assert(t)
    return t[i]
  end
  
  function ct:getGrid(zoomlevel, gridx,gridz)
    local chx,chz = int(gridx/CHUNKSZ/zoomlevel), int(gridz/CHUNKSZ/zoomlevel)
    local i = self:ind(zoomlevel,chx,chz)
    local t = self.zoomary[zoomlevel]
    assert(t)
    return t[i]
  end  
  function ct:remove(zoomlevel, chx,chz )
    local t = self.zoomary[zoomlevel]
    assert(t)
    local i = self:ind(zoomlevel, chx,chz)
    self:clearList(t[i])
    t[i] = nil
  end    
  function ct:clearList(ch)
    assert(ch)
    for i,v in ipairs( self.list ) do
      if v == ch then
        table.remove( self.list, i )
        return true
      end
    end
    return false
  end  
  function ct:scanAll(cb)
    for i,ch in ipairs( self.list) do
      cb(ch)
    end    
  end
  function ct:numList()
    return #self.list
  end
  function ct:dump()
    for i,v in ipairs(self.list) do
      print("chunk:list:",i, v.zoomLevel, v.vx, v.vz )
    end    
  end
  
  return ct
end


function clearAllEditModeChunks()
  chunkTable:scanAll( function(chk)
      if chk.editMode then
        chk:toggleEditMode(false)
      end
    end)
end


function pollChunks(zoomlevel, centerx, centerz )
  if not chunkTable then return end

  local r = 6
  local centerChunkX, centerChunkZ = int(centerx/CELLUNITSZ/CHUNKSZ/zoomlevel), int(centerz/CELLUNITSZ/CHUNKSZ/zoomlevel)

  for dchz=-r,r do
    for dchx=-r,r do
      local chx,chz = centerChunkX + dchx, centerChunkZ + dchz
      if chunkTable:ind(zoomlevel, chx, chz ) then
        local ch = chunkTable:getChunk(zoomlevel, chx,chz )
        if not ch then
          -- check center of the chunk
          local gridx,gridz = chx * CHUNKSZ * zoomlevel, chz * CHUNKSZ * zoomlevel
--          local x,y,z = gridx * CELLUNITSZ, 0, gridz * CELLUNITSZ
          local x,y,z = gridx * CELLUNITSZ + scrollX, 0, gridz * CELLUNITSZ + scrollZ
          local wx1,wy1 = fieldLayer:worldToWnd(x,y,z)
          local wx2,wy2 = fieldLayer:worldToWnd(x + CHUNKSZ*CELLUNITSZ*zoomlevel,y,z+CHUNKSZ*CELLUNITSZ*zoomlevel)
--          print("aaa:",wx1,wy1,wx2,wy2)
          if wx2>0 and wy2>0 and wx1<SCRW and wy1<SCRH then
            ch = makeChunkHeightMapProp(gridx,gridz,zoomlevel)
            chunkTable:setChunk( zoomlevel, chx,chz, ch )
            print("pollChunks: alloc chk:", zoomlevel, chx, chz, gridx,gridz, ch )
          end          
        end
      end
    end
  end
  local outed = 0
  chunkTable:scanAll( function(ch)
      if not ch:inWindow(300) and ch.state == "loaded" then
        ch:clean()
      end
      ch:poll()
    end)
end

function getFieldHeight(x,z)
  local ch = chunkTable:getGrid(1,x,z)
  if ch then return ch:getHeight(x,z) else return nil end
end
function getFieldMockHeight(x,z)
  local ch = chunkTable:getGrid(1,x,z)
  if ch then return ch:getMockHeight(x,z) else return nil end
end

function moveWorldLoc(dx,dz)
  seekWorldLoc(scrollX + dx, scrollZ + dz, 0.1)
end
function seekWorldLoc(x,z,second)
  if not seekerProp then
    seekerProp = MOAIProp.new()
  end
--  seekerProp:setLoc(scrollX,0,scrollZ)
  seekerProp:seekLoc(x,0,z, second, MOAIEaseType.LINEAR )
end
function setWorldLoc(x,z)
  scrollX, scrollZ = x,z
  seekerProp:setLoc(x,0,z)
  if chunkTable then
    chunkTable:scanAll( function(ch)
        ch:setLoc(ch.vx * CELLUNITSZ + scrollX, 0, ch.vz * CELLUNITSZ + scrollZ )
      end)
  end  
end
function updateWorldLoc()
  if seekerProp then
    local x,y,z = seekerProp:getLoc()
    setWorldLoc(x,z)
  end
end      

      

function findChunkByCoord(chx1,chz1, chx2,chz2, cb)
  for chx = chx1,chx2 do
    for chz = chz1,chz2 do
      local ch = chunkTable:getGrid( 1, chx*CHUNKSZ, chz*CHUNKSZ )
      if ch then cb(ch) end
    end
  end
end

function setEditModeAroundCursor(ctlx,ctlz,mode)
  local chx,chz =int(ctlx/CHUNKSZ), int(ctlz/CHUNKSZ)
  local chk = findChunkByCoord( chx-1,chz-1,chx+1,chz+1, function(chunk)
      if not chunk.editMode then
        chunk:toggleEditMode(mode)
      end
    end)
end

-- return 4 verts from LT
function getHeights4(f, x,z)    
  local ah = f(x,z) or 0
  local bh = f(x+1,z) or 0
  local ch = f(x+1,z+1) or 0
  local dh = f(x,z+1) or 0
  return { leftTop=ah, rightTop=bh, rightBottom=ch, leftBottom=dh }    
end  


function findFieldControlPoint( editmode, camx,camy,camz, dirx,diry,dirz )

  local tgt = getFieldHeight
  if editmode then tgt = getFieldMockHeight end
    
  local x,y,z = camx,camy,camz
  local camvec, dirvec = vec3(camx,camy,camz), vec3(dirx,diry,dirz)
  local unit = CELLUNITSZ * currentZoomLevel
  
  local loopN = camy / unit
  local previx,previz
  
  for i=1,loopN*2 do
    x,y,z = x + dirx * unit, y + diry * unit, z + dirz * unit
    local ix, iz = int(x/unit), int(z/unit)
    if ix ~= previx or iz ~= previz then
      local h4s = getHeights4( tgt, ix,iz)

      --  print("diffed.",ix,iz, h4s.leftTop, h4s.rightTop, h4s.rightBottom, h4s.leftBottom )
      local ltY,rtY,rbY,lbY = h4s.leftTop * unit, h4s.rightTop * unit, h4s.rightBottom * unit, h4s.leftBottom * unit
      local ltX,ltZ = ix*unit, iz*unit
      local t,u,v = triangleIntersect( camvec, dirvec, vec3(ltX,ltY,ltZ), vec3(ltX+unit,rtY,ltZ), vec3(ltX+unit,rbY,ltZ+unit))
      if t then
--        print("HIT TRIANGLE RIGHT-UP. x,z:", ix,iz)
        return ix*currentZoomLevel,iz*currentZoomLevel
      end
      t,u,v = triangleIntersect( camvec, dirvec, vec3(ltX,ltY,ltZ), vec3(ltX+unit,rbY,ltZ+unit), vec3(ltX,lbY,ltZ+unit))
      if t then
--        print("HIT TRIANGLE LEFT-DOWN. x,z:",ix,iz)
        return ix*currentZoomLevel,iz*currentZoomLevel
      end
    end      
    previx,previz = ix,iz
    if y < 0 then break end
  end
  return nil
end


-- level: 1,2,4,8, ..
currentZoomLevel = 1
function setZoomLevel(level)
  currentZoomLevel = level
  
end





---------------------------

-- cam
camera = MOAICamera3D.new ()
local z = camera:getFocalLength ( SCRW )
camera:setFarPlane( ZOOM_MAXY*2 )
camera:setLoc ( 0, ZOOM_MINY, 800 )
camera.flyUp = false

fieldLayer:setCamera ( camera )
cursorLayer:setCamera ( camera )

function camera:retargetYrate(yrate)
  local cx,cy,cz = camera:getLoc()
  local toY = cy * yrate
  camera:retargetY(toY)
end
function camera:retargetY(toY)  
  local cx,cy,cz = self:getLoc()
  if toY < ZOOM_MINY then
    toY = ZOOM_MINY
  elseif toY > ZOOM_MAXY then
    toY = ZOOM_MAXY
  end
  cz = toY * 0.4
--  camera:setLoc(cx,toY,cz)
  print("SSSSSSSSSSSSSSSSSSSSSSSS:", toY)
  camera:seekLoc(cx,toY,cz,0.5)  
  if zoomSliderTab then zoomSliderTab:update(camera) end
  moveWorldLoc(0,0)
end
        
function angle(x,y)
  local l = math.sqrt(x*x+y*y)
  local s = math.acos( x/l)
  s = (s/3.141592653589) * 180
  if y<0 then
    s = 360 - s
  end
  return s
end

camera:retargetY( ZOOM_MINY )


-- cursor

cursorProp = makeCursor()
cursorProp:setLoc(0,CELLUNITSZ/2,0)
cursorLayer:insertProp(cursorProp)

function disappearCursor()
  if not cursorProp then return false end

  toggleEditButtonsAvailable(false)
  local x,y,z = cursorProp:getLoc()
  if y ~= -999999 then
    cursorProp:setLoc(0,-999999,0)
    return true
  else
    return false
  end  
end
function appearCursor()
  toggleEditButtonsAvailable(true)
end



----------------
statBox = makeTextBox( -SCRW/2,SCRH/2, "init")

-- init GUIs

initLogLines()

initButtons()
initZoomSlider()


appendLog( "Welcome to MockCity.")
appendLog( "WASD key to move camera" )
appendLog( "ENTER to start chat")
appendLog( "/nick NAME to set your nickname" )

-- network

conn = rpc:connect( SERVER_ADDR, SERVER_PORT )
assert(conn)
conn.doLog = true

function conn:sendLog(...)
  local s = table.concat({...},"")
  print( "sendLog:", s, conn )
  self:emit( "putLog", { text=s } )
end

conn:on("complete", function()
    print("connected to server")
    conn:sendLog( "complete" )
    conn:on("hello", function(arg)
        print("server revision:", arg.revision )
      end)
    conn:on("pong", function(arg)
        local rtt = now() - arg.givenTime
        print("pong.givenTime:",rtt)
        conn.lastRtt = rtt
        
      end)
    conn:on("fieldConf", function(arg)
        print("fieldConf. wh:", arg.width, arg.height )
        chunkTable = ChunkTable(arg.width, arg.height)
      end)
    conn:on("chatNotify", function(arg)
        print("chatNotify. text:", arg.text )
        appendLog( arg.text )
      end)
    conn:on("getFieldRectResult", function(arg)
        local ss = ""
        if arg.hdata then
          ss = "ndata:".. #arg.hdata .. #arg.tdata .. #arg.mhdata
        end        
        print("getFieldRectResult:", arg.x1,arg.z1,arg.x2,arg.z2, "skp:", arg.skip, ss )
        -- ignore data that is too late
        if arg.skip < currentZoomLevel/2 or arg.skip > currentZoomLevel*2 then
          print("data is too late")
          return
        end
        
        local ch = chunkTable:getGrid(arg.skip, arg.x1,arg.z1)
        if not ch then
          print("no chunk, ignore data")
          return
        end
        
        ch.zoomLevel = arg.skip
        ch:setData( arg.tdata, arg.hdata, arg.mhdata )
        ch:updateHeightMap(ch.editMode)
        ch.state = "loaded"
        -- clean lower level 4 chunks when load finished
        local chx,chz = int(arg.x1/CHUNKSZ/arg.skip), int(arg.z1/CHUNKSZ/arg.skip)
        if arg.skip > 1 then
          for dx=0,1 do
            for dz=0,1 do
              local lowchx, lowchz = chx*2+dx,chz*2+dz
              local ch = chunkTable:getChunk(arg.skip/2,lowchx,lowchz)
              if ch then
                print("cleaning lower chunks:", lowchx,lowchz)
                ch:clean()
              end
            end
          end
        end
        -- clean higher level 1 chunks when 4 load finished
        local ch2x,ch2z = int(arg.x1/CHUNKSZ/arg.skip/2), int(arg.z1/CHUNKSZ/arg.skip/2)
        local ch = chunkTable:getChunk(arg.skip*2,ch2x,ch2z)
        if ch then ch:clean() end
        -- clean every far levels
        chunkTable:scanAll( function(ch)
            if ch.zoomLevel < int(arg.skip/2) or ch.zoomLevel > int(arg.skip*2) then
              ch:clean()
            end
          end)
      end)
    conn:on("cameraPos", function(arg)
        setWorldLoc( - arg.x * CELLUNITSZ, - arg.z * CELLUNITSZ )
      end)
  end)

function trySendPing(s)
  if not lastPingAt then lastPingAt = 0 end
  local t = now()
  if conn and lastPingAt <t - 5 then
    conn:emit("ping",{status=s,time=t})
    lastPingAt = t
  end  
end


---------------------


th = MOAICoroutine.new()
th:run(function()
    local xrot,frameCnt = 0,0
    local lastPrintAt = 0
    local prevTime = 0
    while true do
      local t = now()
      local dt = t - prevTime
      
      -- game status
      frameCnt = frameCnt + 1
      if lastPrintAt < t - 1 then
        lastPrintAt = t
        local x,z = lastControlX or 0, lastControlZ or 0
        local y = nil
        if chunkTable then y = getFieldHeight(x,z) end
        if not y then y = 0 end
        local curmode = "PRESENT"
        if guiSelectedButton and guiSelectedButton.editMode then curmode = "FUTURE" end
        local camx,camy,camz = camera:getLoc()
        local chknum = 0
        if chunkTable then chknum = chunkTable:numList() end
        local rtt = -1
        if conn and conn.lastRtt then rtt = conn.lastRtt * 1000 end
        local s = string.format("fps:%d zoom:%d cur:%d,%d,%d cam:%d scr:%d,%d chk:%d rtt:%dms [%s]",frameCnt, currentZoomLevel, x,y,z,camy, -scrollX,-scrollZ, chknum, rtt, curmode)
        statBox:set(s)
        trySendPing(s)
        frameCnt = 0
      end

      -- alloc/clean/update chunks
      pollChunks( currentZoomLevel, -scrollX, -scrollZ)
      
      -- cams and moves      
      local cx,cy,cz = camera:getLoc()
      local dy,dz = 0 - cy, 0 - cz -- move world. not camera, because of Moai's bug?
      camera:setRot( 180 - angle(dz,dy), 0, 0 )

      local camSpeed = cy / 50
      if keyState[119] then --w
        moveWorldLoc(0,camSpeed)
      end
      if keyState[115] then --s
        moveWorldLoc(0,-camSpeed)
      end
      if keyState[100] then --d
        moveWorldLoc(-camSpeed,0)
      end
      if keyState[97] then --a
        moveWorldLoc(camSpeed,0)
      end
      if keyState[101] then --e
      end

      local prevcy = cy
      if keyState[32] then -- space
        if camera.flyUp then 
          cy = cy + 100
          if cy > ZOOM_MAXY then
            cy = ZOOM_MAXY
            camera.flyUp = false          
          end
        else
          cy = cy - 100
          if cy < ZOOM_MINY then
            cy = ZOOM_MINY
            camera.flyUp = true
          end
        end
      end
      
      if keyState[13] then -- enter
      end


      cz = cy * 0.4

      if cy < ZOOM_MINY then cy = ZOOM_MINY end
      if cy > ZOOM_MAXY then cy = ZOOM_MAXY end
      camera:setLoc( cx, cy, cz )
      
      if cy ~= prevcy and zoomSliderTab then zoomSliderTab:update(camera) end

      -- update cursor
      local camx,camy,camz = camera:getLoc()
      
      if lastPointerX then 
        local px,py,pz, xn,yn,zn = fieldLayer:wndToWorld(lastPointerX,lastPointerY)
--        print("pointer:", px,py,pz, xn,yn,zn, lastPointerX, lastPointerY )
        local editmode = guiSelectedButton and guiSelectedButton.editMode

--        local st = os.clock()
        local ctlx,ctlz = findFieldControlPoint( editmode, camx - scrollX, camy, camz - scrollZ, xn,yn,zn )
--        local et = os.clock()
--        print("t:", (et-st), "ctl:",ctlx,ctlz)

        if ctlx and ctlz and ctlx >= 0 and ctlx < chunkTable.absWidth and ctlz >= 0 and ctlz < chunkTable.absHeight then
          lastControlX, lastControlZ = ctlx, ctlz
        end
        if camy < CURSOR_MAXY and ctlx and ctlz then          
          cursorProp:setAtGrid(editmode, ctlx,ctlz)
          appearCursor()
          if editmode then setEditModeAroundCursor(ctlx,ctlz, editmode)  end
        else
          disappearCursor()
          clearAllEditModeChunks()
          if guiSelectedButton then
            guiSelectedButton.selected = false
            guiSelectedButton = nil
            updateButtonBGs()
          end
        end
      end

      -- adjust zoom level
      if chunkTable then
        if camy < 4000 then
          setZoomLevel(1)
        elseif camy < 8000 then
          setZoomLevel(2)
        elseif camy < 16000 then
          setZoomLevel(4)          
        elseif camy < 32000 then
          setZoomLevel(8)
        elseif camy < 64000 then
          setZoomLevel(16)
        elseif camy < 128000 then
          setZoomLevel(32)
        elseif camy < 256000 then
          setZoomLevel(64)
        else
          setZoomLevel(128)
        end
      end


      -- chat
      if chatBox then chatBox:update(dt) end
      
      -- network
      if conn then
        local onePollTimeout = 0.01
        conn.pollStartAt = t
        conn:poll()
        local ret = conn:pollMessage( function()
            local nt = MOAISim.getDeviceTime()
            if  nt < ( conn.pollStartAt + onePollTimeout ) then
              return true
            else
              return false
            end
          end)
        assert(ret)
      end

      --
      updateWorldLoc()

      prevTime = t
      coroutine.yield()
    end
  end)

