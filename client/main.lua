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

math.randomseed(1)

SCRW, SCRH = 960, 640

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
      print("ddddddd:", #hdata, #mockdata )
      showhdata = dupArray(mockdata)
      reddata = nil
    else
      showhdata = dupArray(hdata)
    end
    
    local hm = makeHeightMapMesh(CELLUNITSZ, CHUNKSZ+1,CHUNKSZ+1, lightRate, showhdata,tdata, reddata, false )    
    self:setDeck(hm)
    
    if not editmode and mockdata then
      print("TTTTTTTTTTTTTTTT")
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

      print("init mockprop. ",vertx, vertz )
    else
      if self.mockp then self.mockp:setDeck(nil) end
    end    
  end
  
  function p:toggleEditMode(mode)    
    self:updateHeightMap( self.vx, self.vz, mode )
    self.editMode = mode
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
  local baseX, baseY = -SCRW/2 + 50, SCRH/2 - 100
  local x,y = baseX, baseY
  y = y - BUTTONSIZE
  upButton = makeButton( "up", x,y, guiDeck, 4, 49, function(down)
      if down then selectButton(upButton) end      
    end)
  y = y - BUTTONSIZE
  downButton = makeButton( "down", x,y, guiDeck, 5, 50, function(down)
      if down then selectButton(downButton) end
    end)
  y = y - BUTTONSIZE
  flatButton = makeButton( "flat", x,y, guiDeck, 3, 51, function(down)
      if down then selectButton(flatButton) end
    end)
  y = y - BUTTONSIZE  
  clearButton = makeButton( "clear", x,y, guiDeck, 11, 52, function(down)
      if down then selectButton(clearButton) end
    end)

  guiSelectModeCallback = function(b)
    print( "guiSelectModeCallback changed to:", b )
    if b == nil then
      for i,chk in ipairs(chunks) do
        if chk.editMode then
          chk:toggleEditMode(false)
        end
      end
    else
      if lastControlX then
        if b == upButton or b == downButton or b == flatButton then
          setEditModeAroundCursor(lastControlX,lastControlZ)
        end
      end      
    end
  end
end




---------------
-- input

keyState={}
function onKeyboardEvent(k,dn)
  keyState[k] = dn

  processButtonShortcutKey(k,dn)
  
end
MOAIInputMgr.device.keyboard:setCallback( onKeyboardEvent )

lastPointerX,lastPointerY=nil,nil

function onPointerEvent(mousex,mousey)
  lastPointerX, lastPointerY = mousex, mousey
  
end

MOAIInputMgr.device.pointer:setCallback( onPointerEvent )

function onMouseLeftEvent(down)
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

  function updateCallback(x,z)
    local chx, chz = int( x / CHUNKSZ ), int( z / CHUNKSZ )
    for i,chunk in ipairs(chunks) do
      if chunk.chx >= chx-1 and chunk.chx <= chx+1 and chunk.chz >= chz-1 and chunk.chz <= chz+1 then
        chunk.toUpdate = true
      end          
    end        
  end

  if guiSelectedButton == upButton then
    fld:mockMod( x,z,1, updateCallback )
  elseif guiSelectedButton == downButton then
    fld:mockMod( x,z,-1, updateCallback )
  elseif guiSelectedButton == clearButton then
    fld:mockClear(x,z, updateCallback )
  end

  -- check updated chunks
  for i,chunk in ipairs(chunks) do
    if chunk.toUpdate then
      if guiSelectedButton == downButton or guiSelectedButton == upButton or guiSelectedButton == flatButton then
        chunk:toggleEditMode(true)
      else
        chunk:toggleEditMode(false)
      end      
      chunk.toUpdate = false
    end
  end

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

function setEditModeAroundCursor(ctlx,ctlz)
  local chx,chz =int(ctlx/CHUNKSZ), int(ctlz/CHUNKSZ)
  local chk = findChunkByCoord( chx-1,chz-1,chx+1,chz+1, function(chunk)
      if not chunk.editMode then
        chunk:toggleEditMode(true)
      end
    end)
end

---------------------------

-- cam
camera = MOAICamera3D.new ()
local z = camera:getFocalLength ( SCRW )
camera:setLoc ( 0, 1200, 800 )
fieldLayer:setCamera ( camera )

function angle(x,y)
  local l = math.sqrt(x*x+y*y)
  local s = math.acos( x/l)
  s = (s/3.141592653589) * 180
  if y<0 then
    s = 360 - s
  end
  return s
end


cursorProp = makeCursor()
cursorProp:setLoc(0,CELLUNITSZ/2,0)
fieldLayer:insertProp(cursorProp)


----------------
statBox = makeTextBox( -SCRW/2,SCRH/2, "init")
hudLayer:insertProp(statBox)

----------------

initButtons()

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
    while true do
      local t = now()
      -- game status
      frameCnt = frameCnt + 1
      if lastPrintAt < t - 1 then
        lastPrintAt = t
        local x,z = lastControlX or 0, lastControlZ or 0
        local y = fld:get(x,z)
        statBox:setString( "fps:" .. frameCnt .. " x:" .. x .. " y:" .. y .. " z:" .. z .. " chk:" .. #chunks )
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
      
      if keyState[32] then -- space
        if camera.flyUp then 
          cy = cy + 100
          if cy > 7000 then
            cy = 7000
            camera.flyUp = false          
          end
        else
          cy = cy - 100
          if cy < 500 then
            cy = 500
            camera.flyUp = true
          end
        end
      end
      
      if keyState[13] then -- enter
      end

      cz = cy * 0.4
      camera:setLoc( cx, cy, cz )

      -- update cursor
      local px,py,pz, xn,yn,zn = fieldLayer:wndToWorld(lastPointerX,lastPointerY)
--      print("pointer:", px,py,pz, xn,yn,zn )

      local camx,camy,camz = camera:getLoc()

      local editmode = false
      if guiSelectedButton == upButton or guiSelectedButton == downButton or guiSelectedButton == flatButton then
        editmode = true
      end
      
      local ctlx,ctlz = fld:findControlPoint( editmode, camx - scrollX, camy, camz - scrollZ, xn,yn,zn )
      if ctlx and ctlz and ctlx >= 0 and ctlx < fld.width and ctlz >= 0 and ctlz < fld.height then
        lastControlX, lastControlZ = ctlx, ctlz
        cursorProp:setAtGrid(editmode, ctlx,ctlz)

        if editmode then
          setEditModeAroundCursor(ctlx,ctlz)
        end
        
      else
        cursorProp:setLoc(0,-999999,0) -- disappear
      end

  
      coroutine.yield()
    end
  end)

