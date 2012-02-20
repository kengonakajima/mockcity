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


DARKMODELIGHTRATE = 0.6



fld = Field(256,256)
fld:generate()

CHUNKSZ = 16
CELLUNITSZ = 32

MOCKEPSILON = 2
-- vx,vy : starts from zero, grid coord.
function makeHMProp(vx,vz)
  local p = MOAIProp.new()
  function p:updateHeightMap(vertx,vertz,lightRate)
    if not lightRate then lightRate = 1 end
    local hdata, tdata, mockdata, reddata = fld:getRect( vertx, vertz, CHUNKSZ+1, CHUNKSZ+1 )
--    local reddata = {}
--    for i,v in ipairs(hdata) do reddata[i] = false end      
    -- show where to digg
--    if mockdata then
--      for i,v in ipairs(mockdata) do
--        if v < hdata[i] then
--          reddata[i] = true
--        end        
--      end
--    end

    local hm = makeHeightMapMesh(CELLUNITSZ, CHUNKSZ+1,CHUNKSZ+1, lightRate, hdata,tdata, reddata, false )    
    self:setDeck(hm)
    if mockdata then
      if not self.mockp then
        self.mockp = MOAIProp.new()
        -- show high places        
        local mockmesh = makeHeightMapMesh( CELLUNITSZ, CHUNKSZ+1, CHUNKSZ+1,1, mockdata, tdata, nil, true )
        self.mockp:setDeck(mockmesh )
        self.mockp:setColor(1,1,1,1)
        self.mockp:setCullMode( MOAIProp.CULL_BACK )
        self.mockp:setDepthTest( MOAIProp.DEPTH_TEST_LESS_EQUAL )
        self.mockp:setLoc( vertx * CELLUNITSZ, 0 - MOCKEPSILON, vertz * CELLUNITSZ )        
        fieldLayer:insertProp(self.mockp)

        print("init mockprop. ",vertx, vertz )
      end
    end    
  end
  function p:updateLightRate(lightRate)
    self:updateHeightMap( self.vx, self.vz, lightRate )
  end
  local origsetloc = p.setLoc
  function p:setLoc(x,y,z)
    if self.mockp then
      self.mockp:setLoc(x,y - MOCKEPSILON,z)
    end    
    origsetloc(self,x,y,z)
  end

  p.vx, p.vz = vx,vz
  p:updateHeightMap(vx,vz,1.0)
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
  function p:setAtGrid(x,z)
    local xx,zz = x * CELLUNITSZ, z * CELLUNITSZ
    local h,t = fld:get( x,z )
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
  upButton = makeButton( "up", x,y, guiDeck, 4, 50, function(down)
      selectButton(upButton)
      print("up")
    end)
  y = y - BUTTONSIZE
  downButton = makeButton( "down", x,y, guiDeck, 5, 51, function(down)
      selectButton(downButton)
      print("down")
    end)

  guiSelectModeCallback = function(b)
    print( "guiSelectModeCallback changed to:", b )
    if b == nil then
      for i,chk in ipairs(chunks) do
        if chk.darkMode then
          chk:updateLightRate(1)
          chk.darkMode = false
        end
      end
    else
      setDarkAroundCursor(lastControlX,lastControlZ)
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
  if processButtonMouseEvent(wx,wy) then
    return
  end
  

  -- no GUI, so on field
  if guiSelectedButton == nil then return end
  
  if not cursorProp or not cursorProp.lastGridX then return end
  local curx,cury,curz = cursorProp:getLoc()
  if cury < 0 then return end
  
  local x,z = cursorProp.lastGridX, cursorProp.lastGridZ
  print( "landUp:", x,z )

  function updateCallback(x,z)
    local chx, chz = int( x / CHUNKSZ ), int( z / CHUNKSZ )
    for i,chunk in ipairs(chunks) do
      if chunk.chx >= chx-1 and chunk.chx <= chx+1 and chunk.chz >= chz-1 and chunk.chz <= chz+1 then
        chunk.toUpdate = true
      end          
    end        
  end

  if guiSelectedButton == upButton then
    fld:landMod( x,z,1, updateCallback )
  elseif guiSelectedButton == downButton then
    fld:landMod( x,z,-1, updateCallback )
  end

  -- check updated chunks
  for i,chunk in ipairs(chunks) do
    if chunk.toUpdate then
      chunk:updateHeightMap( chunk.chx * CHUNKSZ, chunk.chz * CHUNKSZ )
      chunk.toUpdate = false
      chunk:updateLightRate(DARKMODELIGHTRATE)
      chunk.darkMode = true
    end
  end

  cursorProp:setAtGrid( x,z )
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

function setDarkAroundCursor(ctlx,ctlz)
  local chx,chz =int(ctlx/CHUNKSZ), int(ctlz/CHUNKSZ)
  local chk = findChunkByCoord( chx-1,chz-1,chx+1,chz+1, function(chunk)
      if not chunk.darkMode then
        chunk:updateLightRate(DARKMODELIGHTRATE)
        chunk.darkMode = true
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
        statBox:setString( "fps:" .. frameCnt .. " x:" .. (lastControlX or 0) .. " y:" .. (lastControlZ or 0) .. " chk:" .. #chunks )
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

      local ctlx,ctlz = fld:findControlPoint( camx - scrollX, camy, camz - scrollZ, xn,yn,zn )
      if ctlx and ctlz and ctlx >= 0 and ctlx < fld.width and ctlz >= 0 and ctlz < fld.height then
        lastControlX, lastControlZ = ctlx, ctlz
        cursorProp:setAtGrid(ctlx,ctlz)

        if guiSelectedButton then
          setDarkAroundCursor(ctlx,ctlz)
        end
        
      else
        cursorProp:setLoc(0,-999999,0) -- disappear
      end

  
      coroutine.yield()
    end
  end)

