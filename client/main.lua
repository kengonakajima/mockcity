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
ZOOM_MAXY = 30000

CURSOR_MAXY = 3000

CHUNKSZ = 16

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






CELLUNITSZ = 32

MOCKEPSILON = 1
-- vx,vy : starts from zero, grid coord.
function makeHMProp(vx,vz)
  local p = MOAIProp.new()

  function p:setData( tdata, hdata, mhdata )
    local tot=0
    for i,v in ipairs(hdata) do tot = tot + v end
--    print("hm:setData:", #tdata, #hdata, #mhdata, tot )
    local nElem = ( CHUNKSZ+1 ) * (CHUNKSZ+1) -- rightside and bottomsize require 1 more vertices
    assert( #tdata == nElem )
    assert( #hdata == nElem )
    assert( #mhdata == nElem )

    self.tdata, self.hdata, self.mhdata  = dupArray(tdata), dupArray(hdata), dupArray(mhdata)
    self.reddata = {}
    
    local nmock = 0

    for i =1,#tdata do
      local h, mockh = self.hdata[i], self.mhdata[i]
      if mockh < h then
        nmock = nmock + 1
        self.reddata[i] = true
--        if (outi-1)>=1 then outred[outi - 1] = true end -- left
--        if (outi-w) >= 1 then outred[outi-w] = true end -- up
--        if (outi-w-1) >= 1 then outred[outi-w-1] = true end -- left up
      elseif mockh > h then
        nmock = nmock + 1
      end
    end
    self.validMockNum = nmock
  end
    
  function p:updateHeightMap(editmode)
    local lightRate = 1
    if editmode then lightRate = 0.5 end

    local showhdata, showreddata = self.hdata, self.reddata
    if editmode then
      showhdata = self.mhdata
      showreddata = nil
    end

--    for i,v in ipairs(showhdata) do
--      if showhdata[i] ~= self.mhdata[i] then
--        print( "iii:",i,v, showhdata[i], self.mhdata[i])
--      end      
--    end
    
    local hm = makeHeightMapMesh(CELLUNITSZ, CHUNKSZ+1,CHUNKSZ+1, lightRate, showhdata, self.tdata, showreddata, false )    
    self:setDeck(hm)
    
    if not editmode and self.validMockNum > 0 then
      if not self.mockp then 
        self.mockp = MOAIProp.new()
        fieldLayer:insertProp(self.mockp)
        self.mockp:setLoc( self.vx * CELLUNITSZ, 0 - MOCKEPSILON, self.vz* CELLUNITSZ )        
      end
      
      -- show high places
      
      local mockmesh = makeHeightMapMesh( CELLUNITSZ, CHUNKSZ+1, CHUNKSZ+1,1, self.mhdata, self.tdata, nil, true )
      self.mockp:setDeck(mockmesh )
      self.mockp:setColor(1,1,1,1)
      self.mockp:setCullMode( MOAIProp.CULL_BACK )
      self.mockp:setDepthTest( MOAIProp.DEPTH_TEST_LESS_EQUAL )
    else
      if self.mockp then self.mockp:setDeck(nil) end
    end
    self:setLoc( self:getLoc() )
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
    print("toggleEditMode:",self.vx, self.vz, mode)
    self:updateHeightMap( mode )
    self.editMode = mode
    self:setLoc( self:getLoc() )
  end
  local origsetloc = p.setLoc
  function p:setLoc(x,y,z)
    if self.mockp then
      self.mockp:setLoc(x,y - MOCKEPSILON,z)
    end    
    origsetloc(self,x,y,z)
  end

  function p:poll()
    if self.state == "init" then
      if conn then
--        print("load rect:", self.state, self.vx, self.vz )      
        conn:emit("getFieldRect", {
            x1 = self.vx,
            z1 = self.vz,
            x2 = self.vx + CHUNKSZ + 1,
            z2 =  self.vz + CHUNKSZ + 1 } )
        self.state = "loading"
      end
    end
  end

  p.state = "init"
  p.vx, p.vz = vx,vz

  p:setCullMode( MOAIProp.CULL_BACK )
  p:setDepthTest( MOAIProp.DEPTH_TEST_LESS_EQUAL )
  local x,z = vx * CELLUNITSZ,  vz * CELLUNITSZ 
  p:setLoc(x, 0, z )

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
end


-- log lines
function initLogLines()
  local baseX, baseY = -SCRW/2 + 80, 0
  local maxLogLineNum = 14
  logLines = {}
  for i = 1,maxLogLineNum do
    local x,y = baseX, baseY - i * font:getScale()
    print("xxxx:",x,y)
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
    local yy = ZOOM_MINY * math.pow( 2, i / 16.0 )
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
      if down then camera:retargetYrate( 2 ) end
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
    print("keyhit:", k, chatBox )
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
        print("sssssss:", statBox:getStringBounds( 1,9999))
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
  

  -- no GUI, so on field
  if guiSelectedButton == nil then return end
  
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


function clearAllEditModeChunks()
  for i,chk in ipairs(chunks) do
    if chk.editMode then
      chk:toggleEditMode(false)
    end
  end
end

function chunkIndex(chx,chz)
  return ( chz * CHUNKRANGE + chx ) + 1
end
function getChunk(gridx,gridz)
  local chx,chz = int(gridx/CHUNKSZ), int(gridz/CHUNKSZ)
  return chunks[ chunkIndex(chx,chz) ]
end

chunks={}
CHUNKRANGE = 16
function pollChunks()
  for chz=0,CHUNKRANGE-1 do
    for chx=0,CHUNKRANGE-1 do
      local chind = chunkIndex( chx,chz )
      if not chunks[chind] then
        chunks[chind] = makeHMProp(chx * CHUNKSZ,chz * CHUNKSZ)
      else
        chunks[chind]:poll()
      end
    end
  end
end

function findChunkByCoord(chx1,chz1, chx2,chz2, cb)
  for chx = chx1,chx2 do
    for chz = chz1,chz2 do
      local ch = getChunk( chx*CHUNKSZ, chz*CHUNKSZ )
      if ch then cb(ch)
      end
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
  local loopN = camy / CELLUNITSZ
  local previx,previz
  
  for i=1,loopN*2 do
    x,y,z = x + dirx * CELLUNITSZ, y + diry * CELLUNITSZ, z + dirz * CELLUNITSZ
    local ix, iz = int(x/CELLUNITSZ), int(z/CELLUNITSZ)
    if ix ~= previx or iz ~= previz then
      local h4s = getHeights4( tgt, ix,iz)

      --  print("diffed.",ix,iz, h4s.leftTop, h4s.rightTop, h4s.rightBottom, h4s.leftBottom )
      local ltY,rtY,rbY,lbY = h4s.leftTop * CELLUNITSZ, h4s.rightTop * CELLUNITSZ, h4s.rightBottom * CELLUNITSZ, h4s.leftBottom * CELLUNITSZ
      local ltX,ltZ = ix*CELLUNITSZ, iz*CELLUNITSZ
      local t,u,v = triangleIntersect( camvec, dirvec, vec3(ltX,ltY,ltZ), vec3(ltX+CELLUNITSZ,rtY,ltZ), vec3(ltX+CELLUNITSZ,rbY,ltZ+CELLUNITSZ))
      if t then
--        print("HIT TRIANGLE RIGHT-UP. x,z:", ix,iz)
        return ix,iz
      end
      t,u,v = triangleIntersect( camvec, dirvec, vec3(ltX,ltY,ltZ), vec3(ltX+CELLUNITSZ,rbY,ltZ+CELLUNITSZ), vec3(ltX,lbY,ltZ+CELLUNITSZ))
      if t then
--        print("HIT TRIANGLE LEFT-DOWN. x,z:",ix,iz)
        return ix,iz
      end
    end      
    previx,previz = ix,iz
    if y < 0 then break end
  end
  return nil
end

---------------------------

-- cam
camera = MOAICamera3D.new ()
local z = camera:getFocalLength ( SCRW )
camera:setFarPlane(100000)
camera:setLoc ( 0, ZOOM_MINY, 800 )
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
  print("xxxx:", cx)
  camera:setLoc(cx,toY,cz)
  if zoomSliderTab then zoomSliderTab:update(camera) end
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
  local x,y,z = cursorProp:getLoc()
  if y ~= -999999 then
    cursorProp:setLoc(0,-999999,0)
    return true
  else
    return false
  end  
end


----------------
statBox = makeTextBox( -SCRW/2,SCRH/2, "init")

-- init GUIs

initLogLines()

initButtons()
initZoomSlider()


appendLog( "asdf")
appendLog( "aksdjfalsdkfjka")

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
    conn:on("fieldConf", function(arg)
        print("fieldConf. wh:", arg.width, arg.height )
        fieldWidth, fieldHeight = arg.width, arg.height
      end)
    conn:on("chatNotify", function(arg)
        print("chatNotify. text:", arg.text )
        appendLog( arg.text )
      end)
    conn:on("getFieldRectResult", function(arg)
--        print("getFieldRectResult:", arg.x1,arg.z1,arg.x2,arg.z2, #arg.hdata, #arg.tdata, #arg.mhdata )
        local ch = getChunk(arg.x1,arg.z1)
        assert(ch)
        ch:setData( arg.tdata, arg.hdata, arg.mhdata )
        ch:updateHeightMap(ch.editMode)
        ch.state = "loaded"

      end)
  end)



function getFieldHeight(x,z)
  local ch = getChunk(x,z)
  if ch then return ch:getHeight(x,z) else return nil end
end
function getFieldMockHeight(x,z)
  local ch = getChunk(x,z)
  if ch then return ch:getMockHeight(x,z) else return nil end
end


----------------
scrollX, scrollZ = 0,0
function moveWorld(dx,dz)
  for i,p in ipairs(chunks) do
    local x,y,z = p:getLoc()
    x,z = x+dx, z+dz
    p:setLoc(x,y,z)
  end
  scrollX, scrollZ = scrollX + dx, scrollZ + dz
end



camera.flyUp = false


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
        local y = getFieldHeight(x,z)
        if not y then y = 0 end
        local curmode = "PRESENT"
        if guiSelectedButton and guiSelectedButton.editMode then curmode = "FUTURE" end
        statBox:set( "fps:" .. frameCnt .. " x:" .. x .. " y:" .. y .. " z:" .. z .. " chk:" .. #chunks .. "  " .. curmode )
        frameCnt = 0
      end

      -- update chunks
      pollChunks()
      
      -- cams and moves      
      local cx,cy,cz = camera:getLoc()
      local dy,dz = 0 - cy, 0 - cz -- move world. not camera, because of Moai's bug?
      camera:setRot( 180 - angle(dz,dy), 0, 0 )

      local camSpeed = cy / 50
      if keyState[119] then --w
        moveWorld(0,camSpeed)
      end
      if keyState[115] then --s
        moveWorld(0,-camSpeed)
      end
      if keyState[100] then --d
        moveWorld(-camSpeed,0)
      end
      if keyState[97] then --a
        moveWorld(camSpeed,0)
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
      camera:setLoc( cx, cy, cz )
      if cy ~= prevcy and zoomSliderTab then zoomSliderTab:update(camera) end

      -- update cursor
      if lastPointerX then 
        local px,py,pz, xn,yn,zn = fieldLayer:wndToWorld(lastPointerX,lastPointerY)
--        print("pointer:", px,py,pz, xn,yn,zn, lastPointerX, lastPointerY )

        local camx,camy,camz = camera:getLoc()
        
        local editmode = guiSelectedButton and guiSelectedButton.editMode
        
        if camy < CURSOR_MAXY then
--          local st = os.clock()
          local ctlx,ctlz = findFieldControlPoint( editmode, camx - scrollX, camy, camz - scrollZ, xn,yn,zn )
--          local et = os.clock()
--          print("t:", (et-st))
          if ctlx and ctlz and ctlx >= 0 and ctlx < fieldWidth and ctlz >= 0 and ctlz < fieldHeight then
            lastControlX, lastControlZ = ctlx, ctlz
            cursorProp:setAtGrid(editmode, ctlx,ctlz)

            if editmode then
              setEditModeAroundCursor(ctlx,ctlz, editmode)
            end
          else
            disappearCursor()            
          end
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

      prevTime = t
      coroutine.yield()
    end
  end)

