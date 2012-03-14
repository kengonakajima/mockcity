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

require "./char"

package.path = package.path .. ";./deps/lua-msgpack/?.lua;"

require "./deps/lua-msgpack/msgpack" 
require "./deps/lua-mprpc/mprpc"
require "./netemu"

local net = netemu

assert( msgpack and net and mprpc )

rpc = mprpc.create(net,msgpack)

-----------------    

SCRW, SCRH = 1280, 768

ZOOM_INITY = 1000
ZOOM_MINY = 500
ZOOM_MAXY = 500000

CURSOR_MAXY = 2000

CHUNKSZ = 16
CELLUNITSZ = 32

GETRECT_CONCURRENT_NUM = 1

-----------------


math.randomseed(1)

MOAISim.openWindow ( "test", SCRW, SCRH )
MOAIGfxDevice.setClearDepth ( true )

viewport = MOAIViewport.new ()
viewport:setSize ( SCRW, SCRH )
viewport:setScale ( SCRW, SCRH )

fieldLayer = MOAILayer.new()
fieldLayer:setViewport(viewport)
fieldLayer:setSortMode(MOAILayer.SORT_Z_ASCNDING ) 
MOAISim.pushRenderPass(fieldLayer)

objLayer = MOAILayer.new()
objLayer:setViewport(viewport)
objLayer:setSortMode(MOAILayer.SORT_Z_ASCNDING )
MOAISim.pushRenderPass(objLayer)

charLayer = MOAILayer.new()
charLayer:setViewport(viewport)
charLayer:setSortMode(MOAILayer.SORT_Z_ASCNDING )
MOAISim.pushRenderPass(charLayer)

cursorLayer = MOAILayer.new()
cursorLayer:setViewport(viewport)
cursorLayer:setSortMode(MOAILayer.SORT_Y_ASCNDING )
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
charDeck = loadTex( "./images/charbase.png" )


-- vx,vy : starts from zero, grid coord.
-- zoomlevel : 1,2,4,8, ..
function makeChunkHeightMapProp(vx,vz,zoomlevel)
  local p = MOAIProp.new()

  p.zoomLevel = zoomlevel
  function p:setData( tdata, hdata, mhdata, objdata )
    local nElem = ( CHUNKSZ+1 ) * (CHUNKSZ+1) -- rightside and bottomsize require 1 more vertices
    assert( #tdata == nElem )
    assert( #hdata == nElem )
    assert( #mhdata == nElem )
    assert( #objdata == nElem )
    self.tdata, self.hdata, self.mhdata, self.objdata  = dupArray(tdata), dupArray(hdata), dupArray(mhdata), dupArray(objdata)
    self.validMockNum = 0
    for i=1,#tdata do if hdata[i] ~= mhdata[i] then self.validMockNum = self.validMockNum + 1 end end
    self.objNum = 0
    for i,v in ipairs(objdata) do if v ~= OBJTYPE.NONE then self.objNum = self.objNum + 1 end end
--    print("setdata: objnum:", self.objNum, "zl:", currentZoomLevel )
  end
    
  function p:updateHeightMap(editmode)
    local lightRate = 1
    if editmode then lightRate = 0.5 end

    -- basic mesh
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

    local hm = makeHeightMapMesh(CELLUNITSZ*self.zoomLevel, CHUNKSZ+1,CHUNKSZ+1, lightRate, showhdata, showtdata, showreddata, false, self.zoomLevel)
    self:setDeck(hm)

    -- mocks
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

    -- objs(fence,tree,building..)
    local objary = {}
    
    if not editmode then --and zoomlevel == 1 then
      for z=0,CHUNKSZ-1 do
        for x=0,CHUNKSZ-1 do
          local ind = x + z*(CHUNKSZ+1)+1
          local t = showtdata[ind]
          local lth,rth,lbh,rbh =  showhdata[ind], showhdata[ind+1], showhdata[ind+(CHUNKSZ+1)], showhdata[ind+(CHUNKSZ+1)+1]
          local maxh, minh = max( max(lth,lbh),max(rth,rbh) ), min( max(lth,lbh),max(rth,rbh) )
          local h = avg( maxh, minh )
            

          if t == CELLTYPE.WOODDEPO then
            local lt = showtdata[ind-1]
            local rt = showtdata[ind+1]
            local ut = showtdata[ind-(CHUNKSZ+1)]
            local dt = showtdata[ind+(CHUNKSZ+1)]
            if lt ~= t then table.insert( objary, {OBJMESHTYPE.FENCE, x,h,z,25,DIR.LEFT } ) end
            if rt ~= t then table.insert( objary, {OBJMESHTYPE.FENCE, x,h,z,25,DIR.RIGHT } ) end
            if dt ~= t then table.insert( objary, {OBJMESHTYPE.FENCE, x,h,z,25,DIR.DOWN } ) end
            if ut ~= t then table.insert( objary, {OBJMESHTYPE.FENCE, x,h,z,25,DIR.UP } ) end
          end
          local o = self.objdata[ind]
          if o == OBJTYPE.TREE then
            table.insert( objary, { OBJMESHTYPE.BOARD, x,h,z, 26 } )
          elseif o == OBJTYPE.CUT_TREE then
            table.insert( objary, { OBJMESHTYPE.BOARD, x,h,z, 26+1 } )
          elseif o == OBJTYPE.RIPE_FRUIT then
            table.insert( objary, { OBJMESHTYPE.BOARD, x,h,z, 26+8 } )
          elseif o == OBJTYPE.EMPTY_FRUIT then
            table.insert( objary, { OBJMESHTYPE.BOARD, x,h,z, 26+8+1 } )            
          end                      
        end
      end
      if #objary > 0 then
        table.sort( objary, function(a,b) return a[1] < b[1] end ) -- sort by meshtype
        
        local p = self.objp
        if not p then
          p = MOAIProp.new()
          self.objp = p
          objLayer:insertProp(p)
        end
        local fm = makeMultiObjMesh(objary,baseDeck )
        p:setDeck(fm)
        p:setScl(zoomlevel,1,zoomlevel)

        p:setColor(1,1,1,1)
        p:setCullMode( MOAIProp.CULL_NONE )
        p:setDepthTest( MOAIProp.DEPTH_TEST_LESS_EQUAL )
--        p:setDepthTest(MOAIProp.DEPTH_TEST_DISABLE )
      end
    end
    
    self:setLoc( self.vx*CELLUNITSZ, 0,self.vz*CELLUNITSZ )
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
    if self.hdata then 
      self:updateHeightMap( mode )
    end    
    self.editMode = mode
    self:setLoc( self:getLoc() )
  end
  local origsetloc = p.setLoc
  function p:setLoc(x,y,z)
    if self.mockp then self.mockp:setLoc(x,y+1,z) end
    if self.objp then self.objp:setLoc(x+CELLUNITSZ/2,y,z+CELLUNITSZ/2) end
    origsetloc(self,x,y,z)
  end

  function p:inWindow(margin)
    local x,y,z = self:getLoc() 
    local winx1,winy1 = fieldLayer:worldToWnd(x,y,z)
    local winx2,winy2 = fieldLayer:worldToWnd(x+CELLUNITSZ*CHUNKSZ*self.zoomLevel, y, z+CELLUNITSZ*CHUNKSZ+self.zoomLevel )
    return (  winx2 >= -margin and winy2 >= -margin and winx1 <= SCRW+margin and winy1 <= SCRH+margin )
  end
          
  function p:poll(counter)
    if self.state == "init" then
      if conn then
--        print("loading rect:", self.state, "xz:", self.vx, self.vz, "zl:", self.zoomLevel, "curzl:", currentZoomLevel  )
        if counter:get() then
          self:sendGetField()
          self.state = "loading"
        end        
      end
    end
  end

  function p:sendGetField()
    conn:emit("getFieldRect", {
        x1 = self.vx,
        z1 = self.vz,
        x2 = self.vx + CHUNKSZ*self.zoomLevel + 1*self.zoomLevel,
        z2 =  self.vz + CHUNKSZ*self.zoomLevel + 1*self.zoomLevel,
        skip = self.zoomLevel
      } )
  end  

  function p:clean()
--    print("chunk clean:",self.zoomLevel,self.vx,self.vz)
    if self.mockp then fieldLayer:removeProp(self.mockp) end
    if self.objp then objLayer:removeProp(self.objp) end
    if self.linep then fieldLayer:removeProp(self.linep) end
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

function getFieldCellCenterLog(x,z,lookatmock)
  local lth,rbh
  if lookatmock then
    lth = getFieldMockHeight(x,z)
    rbh = getFieldMockHeight(x+1,z+1)
  else
    lth = getFieldHeight(x,z)
    rbh = getFieldHeight(x+1,z+1)
  end
  if not lth or not rbh then return nil end
  return x * CELLUNITSZ + CELLUNITSZ/2, avg(lth,rbh) * CELLUNITSZ, z * CELLUNITSZ + CELLUNITSZ/2
end

function getFieldGridLoc(x,z,lookatmock)
  local h
  if lookatmock then
    h = getFieldMockHeight(x,z)
  else
    h = getFieldHeight(x,z)
  end
  
  if h then
    return x * CELLUNITSZ, h*CELLUNITSZ, z * CELLUNITSZ 
  else
    return nil
  end  
end

function makeCursor()
  local p = MOAIProp.new()
  p:setDeck(cursorDeck)
  p:setScl(0.3,0.3,0.3)
  p:setRot(-45,0,0)
--  p:setCullMode( MOAIProp.CULL_BACK)
--  p:setDepthTest( MOAIProp.DEPTH_TEST_LESS_EQUAL )
  function p:setAtGrid(editmode, x,z)
    local xx,yy,zz = getFieldGridLoc( x,z,editmode )
    if xx then
      self:setLoc(xx,yy + CELLUNITSZ/2 - 5, zz )
      self.lastGridX, self.lastGridZ = x,z
    end    
  end

  p:setLoc(0,CELLUNITSZ/2,0)
  cursorLayer:insertProp(p)
  
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

  zoomInButton = makeButton( "zoomIn", x,y, guiDeck, 17, byte("k"), function(self,x,y,down) --k
      if down then camera:retargetYrate( 0.75 ) end
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
        local camx,camy,camz = camera:getLoc()
        if toY > camy then
          camera:retargetYrate(1.3)
        else
          camera:retargetYrate(0.75)
        end
        print("slider:", baseY - y, "toy:", toY, zoom )
      end)
    b.slideIndex = i
    b.flippable = false
    b:setIndex(19)
    table.insert(zoomSliders,b)
  end
  y = y - BUTTONSIZE
  zoomOutButton = makeButton( "zoomOut", x,y, guiDeck, 18, byte("j"), function(self,x,y,down) --j
      if down then camera:retargetYrate( 1.3 ) end
    end)
  zoomOutButton.flippable = false

  -- slider tab will be automatically updated when moving camera.
  zoomSliderTab = makeButton( "sliderTab", baseX,baseY - BUTTONSIZE/2 - 4, guiDeck, nil, nil, nil )
  zoomSliderTab.flippable = false
  zoomSliderTab:setIndex(20)
  zoomSliderTab.baseY = baseY

  function zoomSliderTab:update(cam)
    if not chunkTable then return end
    local centerx,centery,centerz = getCameraCenterGrid()
    if not centerx then return end
    
    local xx,yy = self:getLoc()
    local x,y,z = cam:getLoc()
    local dcamy = y - centery * CELLUNITSZ
    for i,v in ipairs(zoomTable) do      
      if v >= dcamy then
        
        self:setLoc(xx,self.baseY - BUTTONSIZE/2 - 4 - i )
        break
      end
    end
    if dcamy >= ZOOM_MAXY then
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
--    print("keyhit:", k, "chatbox:", chatBox )
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
        if lastControlX then
          conn:emit( "debugPutChar", { x=lastControlX,z=lastControlZ } )
          trySendGetChars()
        end        
      end
      if k == 109 then --m
        if lastControlX then
          conn:emit( "debugSetCellType", { x=lastControlX,z=lastControlZ,t= CELLTYPE.WOODDEPO } )
        end        
      end
      if k == 110 then --n
        if lastControlX then

        end
      end
      if k == 113 then --q

      end      
      if k == 117 then --u
        if lastControlX then
          conn:emit("debugModifyLand", {x=lastControlX, z=lastControlZ, mod=1 } )
        end
      end
     
    end
  end

  if not hit then
    keyState[k] = dn
  end
end

MOAIInputMgr.device.keyboard:setCallback( onKeyboardEvent )

lastPointerX,lastPointerY=0,0

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
  

  if not chunkTable then return end

  local camx,camy,camz = camera:getLoc()
  local centerx,centery,centerz = getCameraCenterGrid()
  
  local dcamy = camy
  if centery then
    dcamy = camy - centery*CELLUNITSZ
  end
  
  -- move camera
  if guiSelectedButton == nil or dcamy > CURSOR_MAXY then
    print( "movecam", lastControlX, lastControlZ)
    seekWorldLoc( lastControlX * CELLUNITSZ, lastControlZ * CELLUNITSZ, 0.5 )
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
function ChunkTable(absW,absH,absElev)
  local ct = {
    absWidth = absW,
    absHeight = absH,
    absMaxElevation = absElev,
    getRectCounter = Counter(GETRECT_CONCURRENT_NUM)
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

  
  -- centerx, centerz :grid
  function ct:poll(zoomlevel, centergx, centergz )
    local centerx, centerz = centergx, centergz
    if not centergx then centerx, centerz = self.lastCenterX, self.lastCenterZ end
    if centergx then self.lastCenterX, self.lastCenterZ = centergx,centergy end

    if not centerx or not centerz then return end

    centerx, centerz = centerx * CELLUNITSZ, centerz * CELLUNITSZ

    
    local r = 4
    local centerChunkX, centerChunkZ = int(centerx/CELLUNITSZ/CHUNKSZ/zoomlevel), int(centerz/CELLUNITSZ/CHUNKSZ/zoomlevel)

    for dchz=-r,r do
      for dchx=-r,r do
        local chx,chz = centerChunkX + dchx, centerChunkZ + dchz
        if self:ind(zoomlevel, chx, chz ) then
          local ch = self:getChunk(zoomlevel, chx,chz )
          if targetingZoomLevel and zoomlevel ~= targetingZoomLevel then
          elseif not ch then
            -- check center of the chunk
            local gridx,gridz = chx * CHUNKSZ * zoomlevel, chz * CHUNKSZ * zoomlevel
            --          local x,y,z = gridx * CELLUNITSZ, 0, gridz * CELLUNITSZ
            local x,y,z = gridx * CELLUNITSZ, 0, gridz * CELLUNITSZ 
            local wx1,wy1 = fieldLayer:worldToWnd(x,y,z)
            local wx2,wy2 = fieldLayer:worldToWnd(x + CHUNKSZ*CELLUNITSZ*zoomlevel,y,z+CHUNKSZ*CELLUNITSZ*zoomlevel)
            --          print("aaa:",wx1,wy1,wx2,wy2)
            if wx2>0 and wy2>0 and wx1<SCRW and wy1<SCRH then
              ch = makeChunkHeightMapProp(gridx,gridz,zoomlevel)
              self:setChunk( zoomlevel, chx,chz, ch )
              --            print("pollChunks: alloc chk:", zoomlevel, chx, chz, gridx,gridz, ch )
            end          
          end
        end
      end
    end
    local outed = 0
    self:scanAll( function(ch)
        if not ch:inWindow(300) and ch.state == "loaded" then
          ch:clean()
        end
         ch:poll(self.getRectCounter)
      end)
    
    -- widest
    local szDiff = r * CHUNKSZ * zoomlevel
    self.minGridX, self.minGridZ = centergx - szDiff, centergz - szDiff
    self.maxGridX, self.maxGridZ = centergx + szDiff, centergz + szDiff
    
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



-- x,z: grid
function getFieldHeight(x,z)
  local ch = chunkTable:getGrid(currentZoomLevel,x,z)
--  print("getFieldHeight: ch:", ch, x,z,currentZoomLevel )
  if ch then return ch:getHeight(x,z) else return nil end
end
function getFieldMockHeight(x,z)
  local ch = chunkTable:getGrid(currentZoomLevel,x,z)
  if ch then return ch:getMockHeight(x,z) else return nil end
end

function moveWorldLoc(dx,dz)
  local x,y,z = camera:getLoc()
  seekWorldLoc(x + dx, z + dz, 0.1)
end
function seekWorldLoc(x,z,second)
  local _,y,_ = camera:getLoc()
--  z = y * 0.4
  camera:seekLoc(x,y,z, second, MOAIEaseType.LINEAR )
end
function setWorldLoc(x,z)
  local _,y,_ = camera:getLoc()
  z = z + y * 0.4
  camera:setLoc(x,y,z)
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
  local out = false
  if x <0 or z < 0 or x >= chunkTable.absWidth or z >= chunkTable.absHeight then out = true end
  local ah = f(x,z)
  local bh = f(x+1,z) 
  local ch = f(x+1,z+1) 
  local dh = f(x,z+1)
  local hasNil = false
  if not ah or not bh or not ch or not dh then hasNil = true end
  return { leftTop = ah or 0, rightTop = bh or 0 , rightBottom = ch or 0 , leftBottom = dh or 0 , out = out, hasNil = hasNil }
end  


function findFieldControlPoint( editmode, camx,camy,camz, dirx,diry,dirz )
--  print("findFieldControlPoint: cam:",camx,camy,camz, " dir:", dirx,diry,dirz)
  local tgt = getFieldHeight
  if editmode then tgt = getFieldMockHeight end
    

  local camvec, dirvec = vec3(camx,camy,camz), vec3(dirx,diry,dirz)
  local unit = CELLUNITSZ * currentZoomLevel 
  
  local loopN = camy / unit
  local previx,previz

  for i=1,loopN*2 do
    local x,y,z = camx + dirx * unit * i, camy + diry * unit * i, camz + dirz * unit * i
    local ix, iy, iz = int(x/unit), int(y/unit), int(z/unit)
    if ix ~= previx or iz ~= previz then
      local h4s = getHeights4( tgt, ix * currentZoomLevel,iz*currentZoomLevel)
--      print("diffed. unit:",unit, "ixyz:",ix,iy,iz, "h4:", h4s.leftTop, h4s.rightTop, h4s.rightBottom, h4s.leftBottom, "out:", h4s.out )      
      if h4s.out then
        return nil
      end
      
      local ltY,rtY,rbY,lbY = h4s.leftTop * CELLUNITSZ, h4s.rightTop * CELLUNITSZ, h4s.rightBottom * CELLUNITSZ, h4s.leftBottom * CELLUNITSZ
      local ltX,ltZ = ix*unit, iz*unit

--      print( "cam:",vec3toIntString(camvec), "dir:",vec3toString(dirvec), "0:",vec3toIntString(vec3(ltX,ltY,ltZ)), "1:",vec3toIntString(vec3(ltX+unit,rtY,ltZ)), "2:",vec3toIntString(vec3(ltX+unit,rbY,ltZ+unit)))
    
      local t,u,v = triangleIntersect( camvec, dirvec, vec3(ltX,ltY,ltZ), vec3(ltX+unit,rtY,ltZ), vec3(ltX+unit,rbY,ltZ+unit))
      
      if t then
--        print("HIT TRIANGLE RIGHT-UP. x,y,z:", ix,iy,iz, "loop:", i )
        if iy*currentZoomLevel > chunkTable.absMaxElevation then
          print("over MAXELEVATION!:", iy*currentZoomLevel )
          iy = 0
        end
        return ix*currentZoomLevel,iy*currentZoomLevel,iz*currentZoomLevel
      end
      t,u,v = triangleIntersect( camvec, dirvec, vec3(ltX,ltY,ltZ), vec3(ltX+unit,rbY,ltZ+unit), vec3(ltX,lbY,ltZ+unit))
      if t then
--        print("HIT TRIANGLE LEFT-DOWN. x,y,z:",ix,iy,iz, "loop:", i, "h4:", h4s.leftTop )
        if iy*currentZoomLevel > chunkTable.absMaxElevation then
          print("over MAXELEVATION!:", iy*currentZoomLevel, chunkTable.absMaxElevation )
          iy = 0
        end
        return ix*currentZoomLevel,iy*currentZoomLevel,iz*currentZoomLevel
      end
    end      
    if y < 0 then
      local h = tgt(ix*currentZoomLevel,iz*currentZoomLevel)
      return previx*currentZoomLevel,h, previz*currentZoomLevel
    end
    previx,previy,previz = ix,iy,iz    
  end
  -- cannot reach polygon..
--      local h4s = getHeights4( tgt, ix * currentZoomLevel,iz*currentZoomLevel)
  local x,z = int(camx/CELLUNITSZ),int(camz/CELLUNITSZ)
  local h4s = getHeights4( tgt, x,z )
  print("OUT5:cannot reach polygon:", x,z, h4s.leftTop, h4s.leftBottom, h4s.rightTop,h4s.rightBottom )
  local retH = h4s.leftTop
  if h4s.hasNil then retH = chunkTable.absMaxElevation end
  return x,retH,z
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
camera:setNearPlane( 20 ) -- for precision
camera:setLoc ( 0, ZOOM_INITY, 800 )
camera.flyUp = false

fieldLayer:setCamera ( camera )
objLayer:setCamera( camera )
charLayer:setCamera( camera )
cursorLayer:setCamera ( camera )

function dyToZoomLevel(dy)
  if dy < 4000 then
    return 1
  elseif dy < 8000 then
    return 2
  elseif dy < 16000 then
    return 4
  elseif dy < 32000 then
    return 8
  elseif dy < 64000 then
    return 16
  elseif dy < 128000 then
    return 32
  elseif dy < 256000 then
    return 64
  else
    return 128
  end  
end

function camera:retargetYrate(yrate)

  local cx,cy,cz = camera:getLoc()
  local centerx,centery,centerz = getCameraCenterGrid()

  local toY
  if not centery then centery = 0 end 
  if centery == 0 then
    if yrate > 1 then
      toY = cy * 1.5
    elseif yrate < 1 then
      toY = cy * 0.75
    end
  else
    centery = centery * CELLUNITSZ
    local dcamy = cy - centery
    if yrate > 1 then
      toY = centery + dcamy * yrate
    elseif yrate < 1 then
      toY = centery + dcamy * yrate
    end
  end

  print("yr:",yrate, "toY:",toY, "centery:",centery )

  local dcamy = toY - centery
  
  if dcamy < ZOOM_MINY then
    toY = centery + ZOOM_MINY
  end
  if toY > ZOOM_MAXY then
    toY = ZOOM_MAXY
  end

  local curcentery = centery
  if not curcentery then
    local x,y,z = getCameraCenterGrid()
    curcentery = y * CELLUNITSZ
  end
  if not curcentery then curcentery = 0 end
    
  targetingZoomLevel = dyToZoomLevel(toY - curcentery)

  camera:seekLoc(cx,toY,cz,0.5)  
  if zoomSliderTab then zoomSliderTab:update(camera) end

end

function getCameraCenterGrid()
  if not chunkTable then return nil end
  local camx,camy,camz = camera:getLoc()  
  local px,py,pz, xn,yn,zn = fieldLayer:wndToWorld(SCRW/2,SCRH/2)
  local x,y,z = findFieldControlPoint( editmode, camx,camy,camz, xn,yn,zn)
--  print("getCameraCenterGrid: cam:", string.format("%.4f,%.4f,%.4f",camx,camy,camz), "dir:", string.format("%.4f,%.4f,%.4f",xn,yn,zn), "result:", x,y,z)

  return x,y,z
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




-- cursor

cursorProp = makeCursor()

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
--        print("pong.givenTime:",rtt)
        conn.lastRtt = rtt
        
      end)
    conn:on("fieldConf", function(arg)
        print("fieldConf. wh:", arg.width, arg.height, arg.elevation )
        chunkTable = ChunkTable(arg.width, arg.height, arg.elevation )
      end)
    conn:on("chatNotify", function(arg)
        print("chatNotify. text:", arg.text )
        appendLog( arg.text )
      end)
    conn:on("getFieldRectResult", function(arg) -- gfrr
        chunkTable.getRectCounter:put()
        
--        print("getFieldRectResult:", arg.x1,arg.z1,arg.x2,arg.z2, "skp:", arg.skip )
        print("getFieldRectResult:", arg.x1,arg.z1,arg.x2,arg.z2, chunkTable.getRectCounter.n )
        if arg.chars then
          for i,ch in ipairs(arg.chars) do
            for k,v in pairs(ch) do
              print("char: kv:",k,v)
            end          
          end
        end
        
--        for i,wp in ipairs(arg.waypoints) do
--          print("wp: ", wp.x, wp.z )
--          makeDebugRod( wp.x * CELLUNITSZ, wp.y * CELLUNITSZ, wp.z * CELLUNITSZ )
        --        end
        local linep
        if currentZoomLevel == 1 then
          linep = makeDebugLineProp( arg.waylinks) 
        end
        
        -- ignore data that is too late
        if arg.skip < currentZoomLevel/2 then return end
        if arg.skip > currentZoomLevel*2 then return end
        
        local ch = chunkTable:getGrid(arg.skip, arg.x1,arg.z1)
        if not ch then return end
        
        ch.zoomLevel = arg.skip
        ch:setData( arg.tdata, arg.hdata, arg.mhdata, arg.objdata )
        ch:updateHeightMap(ch.editMode)
        ch.state = "loaded"
        ch.linep = linep
        
        -- clean lower level 4 chunks when load finished
        local chx,chz = int(arg.x1/CHUNKSZ/arg.skip), int(arg.z1/CHUNKSZ/arg.skip)
        if arg.skip > 1 then
          for dx=0,1 do
            for dz=0,1 do
              local lowchx, lowchz = chx*2+dx,chz*2+dz
              local ch = chunkTable:getChunk(arg.skip/2,lowchx,lowchz)
              if ch then
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
    conn:on("getCharsRectResult", function(arg)
--        print("############ getCharsRectResult:",arg.x1,arg.z1,arg.x2,arg.z2, #arg.data )
        for i,v in ipairs(arg.data) do
          local ch = charIDs[v.id]
          if not ch then
            ch = makeChar(v.id, v.posx, v.posy, v.posz, charDeck, 1 )
          end
          if ch then
            ch:moveToGrid(v.posx,v.posy,v.posz,v.state)
          end          
        end        
      end)
    conn:on("cameraPos", function(arg)
        setWorldLoc(  arg.x * CELLUNITSZ,  arg.z * CELLUNITSZ )
      end)
    conn:on("fieldChangeNotify", function(arg)
        appendLog( "chg:" .. arg.x .. "," .. arg.z )
        local chk = chunkTable:getGrid(currentZoomLevel,arg.x,arg.z)
        chk:sendGetField()
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
function trySendGetChars()
  if chunkTable and conn then
--    print("minmax:", chunkTable.minGridX, chunkTable.minGridZ, chunkTable.maxGridX, chunkTable.maxGridZ )
    conn:emit("getCharsRect", { x1=chunkTable.minGridX, z1=chunkTable.minGridZ, x2=chunkTable.maxGridX, z2=chunkTable.maxGridZ } )
  end
end

function makeDebugBullet(x,y,z, dx,dy,dz)
  local p = MOAIProp.new()
  p:setDeck(cursorProp)
  p:setScl(0.3,0.3,0.3)
  p:setDeck(cursorDeck)
  p:setLoc(x + 100 *dx,y + 100*dy,z+100*dz)
  p:moveLoc(dx*1000,dy*1000,dz*1000,1,MOAIEaseType.LINEAR)
  fieldLayer:insertProp(p)
  return p
end
function makeDebugRod(x,y,z)
  local p = MOAIProp.new()
  p:setDeck(cursorProp)
  p:setScl(0.3,0.3,0.3)
  p:setDeck(cursorDeck)
  p:setLoc(x,y,z)
  fieldLayer:insertProp(p)
  return p
end
function makeDebugLineProp(lines)
  local debugDiff = 1 -- todo: moai's bug? can't draw line if y is same..
  local t = {}
  for i,v in ipairs(lines) do
    t[i] = { x1 = v.fromx, y1 = v.fromy + debugDiff, z1 = v.fromz, x2 = v.tox, y2 = v.toy, z2 = v.toz }
  end
  local mesh = makeMultiLineMesh(t,0,1,1)
  local p = MOAIProp.new()
  p:setDeck(mesh)
  p:setLoc(x1,y1,z1)
  p:setBlendMode ( MOAIProp2D.GL_SRC_ALPHA, MOAIProp2D.GL_ONE_MINUS_SRC_ALPHA )
  p:setColor(1,1,1,0.15)
  fieldLayer:insertProp(p)
  return p  
end


---------------------


th = MOAICoroutine.new()
th:run(function()
    local xrot,frameCnt = 0,0
    local lastSecondlyAt = 0
    local prevTime = 0
    while true do
      local t = now()
      local dt = t - prevTime


      
      -- game status
      frameCnt = frameCnt + 1
      if lastSecondlyAt < t - 1 then
        lastSecondlyAt = t
        local x,z = lastControlX or 0, lastControlZ or 0
        local y = nil
        if chunkTable then y = getFieldHeight(x,z) end
        if not y then y = 0 end
        local curmode = "PRESENT"
        if guiSelectedButton and guiSelectedButton.editMode then curmode = "FUTURE" end
        
        local chknum, chnum = 0,0
        if chunkTable then chknum = chunkTable:numList() end
        if chars then chnum = #chars end
        local rtt = -1
        if conn and conn.lastRtt then rtt = conn.lastRtt * 1000 end
        local cx,cy,cz = camera:getLoc()        
        local s = string.format("fps:%d zoom:%d cur:%d,%d,%d cam:%d,%d,%d chk:%d ch:%d rtt:%dms [%s]",frameCnt, currentZoomLevel, x,y,z, cx,cy,cz, chknum, chnum, rtt, curmode)
        statBox:set(s)
        frameCnt = 0

        -- secondly network
        trySendPing(s)
        trySendGetChars()

      end

      -- alloc/clean/update chunks
      if chunkTable then
        local centerx,centery,centerz = getCameraCenterGrid()
        if not centerx then
          centerx,centery,centerz = camera:getLoc()
          centerx,centery,centerz = centerx/CELLUNITSZ,centery/CELLUNITSZ,centerz/CELLUNITSZ
        end
        
        chunkTable:poll( currentZoomLevel, centerx,centerz )
      end
      
      -- update chars
      pollChars(t)
      
      -- cams and moves      
      camera:setRot( -70, 0, 0 )      -- -90 to see vertical downward


      if keyState[101] then --e
      end
      
      if keyState[13] then -- enter
      end

      -- update cursor
      if chunkTable then
        
        local camx,camy,camz = camera:getLoc()
        local centerx,centery,centerz = getCameraCenterGrid()

        
        if lastPointerX and centerx then
      
          local dcamy = camy - centery * CELLUNITSZ
          if dcamy < ZOOM_MINY then
            dcamy = ZOOM_MINY
            camy = centery*CELLUNITSZ + dcamy
            camera:setLoc( camx, camy, camz )
          end
          if dcamy > ZOOM_MAXY then
            dcamy = ZOOM_MAXY
            camy = centery*CELLUNITSZ + dcamy
            camera:setLoc( camx, camy, camz )
          end


          local camSpeed = dcamy / 50
          if keyState[119] then --w
            moveWorldLoc(0,-camSpeed)
          end
          if keyState[115] then --s
            moveWorldLoc(0,camSpeed)
          end
          if keyState[100] then --d
            moveWorldLoc(camSpeed,0)
          end
          if keyState[97] then --a
            moveWorldLoc(-camSpeed,0)
          end

          
          if zoomSliderTab then zoomSliderTab:update(camera) end
      
          local px,py,pz, xn,yn,zn = fieldLayer:wndToWorld(lastPointerX,lastPointerY)
          --          print(string.format( "pointer:  %.4f,%.4f,%.4f  %d,%d  %.4f,%.4f,%.4f  %.4f,%.4f,%.4f", xn,yn,zn, lastPointerX, lastPointerY, camx,camy,camz, px,py,pz ))
          local editmode = guiSelectedButton and guiSelectedButton.editMode

          --        local st = os.clock()
          local ctlx,ctly,ctlz = findFieldControlPoint( editmode, camx, camy, camz, xn,yn,zn )
          --        local et = os.clock()
          --        print("t:", (et-st), "ctl:",ctlx,ctlz)

          if ctlx and ctlz and ctlx >= 0 and ctlx < chunkTable.absWidth and ctlz >= 0 and ctlz < chunkTable.absHeight then
            lastControlX, lastControlZ = ctlx, ctlz

            if dcamy < CURSOR_MAXY then
              if lastControlX then
                cursorProp:setAtGrid(editmode, lastControlX, lastControlZ)
              end          
              appearCursor()
              if editmode then setEditModeAroundCursor(lastControlX,lastControlZ, editmode)  end
            else
              disappearCursor()
              clearAllEditModeChunks()
              if guiSelectedButton then
                guiSelectedButton.selected = false
                guiSelectedButton = nil
                updateButtonBGs()
              end
            end

            -- adjust zoom level

--            print("dcamy:", dcamy, "camy:", camy, "center:", centery, centerx, centerz )
            setZoomLevel( dyToZoomLevel(dcamy) )
          end        
        end
      end
    

      -- chat
      if chatBox then chatBox:update(dt) end
      
      -- network
      if conn then
        local onePollTimeout = 0.05
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

      prevTime = t
      coroutine.yield()
    end
  end)

