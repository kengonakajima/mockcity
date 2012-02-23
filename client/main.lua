----------------------------------------------------------------
-- Copyright (c) 2010-2011 Kengo Nakajima.
-- All Rights Reserved. 
-- http://twitter.com/ringo
----------------------------------------------------------------

require "./const"
require "./util"
require "./mesh"
require "./field"
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





xpcall(function()
    fld = Field(256,256)
    fld:generate()
    print("generated")
  end, errorHandler)

CHUNKSZ = 16
CELLUNITSZ = 32

MOCKEPSILON = 2
-- vx,vy : starts from zero, grid coord.
function makeHMProp(vx,vz)
  local p = MOAIProp.new()
  function p:updateHeightMap(vertx,vertz,editmode)
--    print("updateHeightMap: editmode:", vertx, vertz, editmode )
    local lightRate = 1
    if editmode then lightRate = 0.5 end
    local hdata, tdata, mockdata, reddata = fld:getRect( vertx, vertz, CHUNKSZ+1, CHUNKSZ+1 )
    local showhdata ={}
    if editmode and mockdata then
      showhdata = dupArray(mockdata)
      reddata = nil
    else
      showhdata = dupArray(hdata)
    end
    
    local hm = makeHeightMapMesh(CELLUNITSZ, CHUNKSZ+1,CHUNKSZ+1, lightRate, showhdata,tdata, reddata, false )    
    self:setDeck(hm)
    
    if not editmode and mockdata then
      if not self.mockp then 
        self.mockp = MOAIProp.new()
        fieldLayer:insertProp(self.mockp)
        self.mockp:setLoc( vertx * CELLUNITSZ, 0 - MOCKEPSILON, vertz * CELLUNITSZ )        
      end
      
      -- show high places
--      for i,v in ipairs(mockdata) do
--        if v ~= showhdata[i] then print("diff:",i,mockdata[i] ) end
--      end
      
      local mockmesh = makeHeightMapMesh( CELLUNITSZ, CHUNKSZ+1, CHUNKSZ+1,1, mockdata, tdata, nil, true )
      self.mockp:setDeck(mockmesh )
      self.mockp:setColor(1,1,1,1)
      self.mockp:setCullMode( MOAIProp.CULL_BACK )
      self.mockp:setDepthTest( MOAIProp.DEPTH_TEST_LESS_EQUAL )

--      print("init mockprop. ",vertx, vertz )
    else
      if self.mockp then self.mockp:setDeck(nil) end
    end    
  end
  
  function p:toggleEditMode(mode)    
    self:updateHeightMap( self.vx, self.vz, mode )
    self.editMode = mode
    moveWorld(0,0)
  end
  local origsetloc = p.setLoc
  function p:setLoc(x,y,z)
    if self.mockp then
      self.mockp:setLoc(x,y - MOCKEPSILON,z)
    end    
    origsetloc(self,x,y,z)
  end

  p.vx, p.vz = vx,vz
  p:updateHeightMap(vx,vz,false)
  p:setCullMode( MOAIProp.CULL_BACK )
  p:setDepthTest( MOAIProp.DEPTH_TEST_LESS_EQUAL )
  local x,z = vx * CELLUNITSZ,  vz * CELLUNITSZ 
  p:setLoc(x, 0, z )
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
    local tgt = fld.heights
    if editmode then tgt = fld.mockHeights end
    local h = fld:targetGet( tgt, x,z )
    local yy = h * CELLUNITSZ
    self:setLoc(xx + scrollX,yy + CELLUNITSZ/2 - 5, zz + scrollZ)
    self.lastGridX, self.lastGridZ = x,z
  end 
  return p
end

-- init all tools
function initButtons()
  local baseX, baseY = -SCRW/2 + 50, SCRH/2 - 360
  local x,y = baseX, baseY

  upButton = makeButton( "up", x,y, guiDeck, 4, 49, function(self,x,y,down)
      if down and lastControlX then selectButton(upButton) end      
    end)
  upButton.editMode = true
  y = y - BUTTONSIZE
  downButton = makeButton( "down", x,y, guiDeck, 5, 50, function(self,x,y,down)
      if down and lastControlX then selectButton(downButton) end
    end)
  downButton.editMode = true
  y = y - BUTTONSIZE
  flatButton = makeButton( "flat", x,y, guiDeck, 3, 51, function(self,x,y,down)
      if down and lastControlX then selectButton(flatButton) end
    end)
  flatButton.editMode = true  
  y = y - BUTTONSIZE  
  clearButton = makeButton( "clear", x,y, guiDeck, 11, 52, function(self,x,y,down)
      if down and lastControlX then selectButton(clearButton) end
    end)
  clearButton.editMode = false
  guiSelectModeCallback = function(b)
    clearAllEditModeChunks()
    if b then btnSound:play() end
    if b and lastControlX then
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

  zoomInButton = makeButton( "zoomIn", x,y, guiDeck, 17, byte("j"), function(self,x,y,down)
      print("zin")
      camera:retargetYrate( 0.5 )
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
  zoomOutButton = makeButton( "zoomOut", x,y, guiDeck, 18, byte("k"), function(self,x,y,down)
      camera:retargetYrate( 2 )
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
    local h = fld:targetGet( fld.mockHeights, x,z )
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
    local realh = fld:get(x,z)
    local mockh = fld:targetGet(fld.mockHeights,x,z)
    if realh > mockh then
      modH = 1
    elseif realh < mockh then
      modH = -1
    end      
  end
  if modH ~= 0 then
    fld:mockMod(x,z,modH,updateCallback)
    clkSound:play()
    updateAllChunks()
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
      fld:mockMod( x,z,1, updateCallback )
    elseif guiSelectedButton == downButton then
      fld:mockMod( x,z,-1, updateCallback )
    elseif guiSelectedButton == clearButton then
      fld:mockClear(x,z, updateCallback )
    elseif guiSelectedButton == flatButton then
      flatButton.heightToSet = fld:targetGet( fld.mockHeights, x,z)
    end
    clkSound:play()
  end
  
  updateAllChunks()
  cursorProp:setAtGrid( true, x,z )
end

MOAIInputMgr.device.mouseLeft:setCallback( onMouseLeftEvent )



---------------------------

---------------------------

function updateChunk(chx,chz)
  local p = makeHMProp(chx*CHUNKSZ,chz*CHUNKSZ)

  fieldLayer:insertProp(p)
  p.chx, p.chz = chx, chz
  table.insert(chunks,p)
  return p
end

function clearAllEditModeChunks()
  for i,chk in ipairs(chunks) do
    if chk.editMode then
      chk:toggleEditMode(false)
    end
  end
end



chunks={}
CHUNKRANGE = 16
for chz=0,CHUNKRANGE-1 do
  for chx=0,CHUNKRANGE-1 do
    updateChunk(chx,chz)
  end
end

function findChunkByCoord(chx1,chz1, chx2,chz2, cb)
  for i,v in ipairs(chunks) do
    if v.chx >= chx1 and v.chx <= chx2 and v.chz >= chz1 and v.chz <= chz2 then
      if cb then
        cb(v)
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

---------------------------

-- cam
camera = MOAICamera3D.new ()
local z = camera:getFocalLength ( SCRW )
camera:setFarPlane(100000)
camera:setLoc ( 0, ZOOM_MINY, 800 )
fieldLayer:setCamera ( camera )

function camera:retargetYrate(yrate)
  local cx,cy,cz = camera:getLoc()
  local toY = cy * yrate
  camera:retargetY(toY)
end
function camera:retargetY(toY)
  if toY < ZOOM_MINY then
    toY = ZOOM_MINY
  elseif toY > ZOOM_MAXY then
    toY = ZOOM_MAXY
  end
  print("toY:",toY)
  cz = toY * 0.4
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
fieldLayer:insertProp(cursorProp)

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
    conn:on("chatNotify", function(arg)
        print("chatNotify. text:", arg.text )
        appendLog( arg.text )
      end)
  end)



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

moveWorld(-20*CELLUNITSZ, -20*CELLUNITSZ)

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
        local y = fld:get(x,z)
        local curmode = "PRESENT"
        if guiSelectedButton and guiSelectedButton.editMode then curmode = "FUTURE" end
        statBox:set( "fps:" .. frameCnt .. " x:" .. x .. " y:" .. y .. " z:" .. z .. " chk:" .. #chunks .. "  " .. curmode )
        frameCnt = 0
      end

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
          local ctlx,ctlz = fld:findControlPoint( editmode, camx - scrollX, camy, camz - scrollZ, xn,yn,zn )
--          local et = os.clock()
--          print("t:", (et-st))
          if ctlx and ctlz and ctlx >= 0 and ctlx < fld.width and ctlz >= 0 and ctlz < fld.height then
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
        conn:poll()
        conn:pollMessage( function()
            return true
          end)
        
      end

      prevTime = t
      coroutine.yield()
    end
  end)

