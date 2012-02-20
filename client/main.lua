----------------------------------------------------------------
-- Copyright (c) 2010-2011 Kengo Nakajima.
-- All Rights Reserved. 
-- http://twitter.com/ringo
----------------------------------------------------------------

require "./util"
require "./mesh"
require "./field"
require "./textbox"

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

hudLayer:setColor(1,1,1,1)


baseDeck = loadTex( "./images/citybase.png" )
cursorDeck = loadGfxQuad( "./images/cursor.png" )



CELLTYPE={
  NOTHING = 1,
  GRASS = 2,
  SAND = 3,
  WATER = 4
}


fld = Field(256,256)
fld:generate()

CHUNKSZ = 16
CELLUNITSZ = 32
-- vx,vy : starts from zero, grid coord.
function makeHMProp(vx,vz)
  local sz = CELLUNITSZ
  local w,h = CHUNKSZ+1,CHUNKSZ+1
  local hdata, tdata = fld:getRect( vx, vz, w, h )

  local hm = makeHeightMapMesh(sz,w,h,hdata,tdata )

  local p = MOAIProp.new()
  p:setDeck(hm)
  p:setCullMode( MOAIProp.CULL_BACK )
  p:setDepthTest( MOAIProp.DEPTH_TEST_LESS_EQUAL )
  local x,z = vx * sz,  vz * sz 
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
    self:setLoc(xx + scrollX,yy + CELLUNITSZ/2, zz + scrollZ)
    self.lastGridX, self.lastGridZ = x,z
  end 
  return p
end



keyState={}
function onKeyboardEvent(k,dn)
  keyState[k] = dn
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
  
  if not cursorProp or not cursorProp.lastGridX then return end
  local curx,cury,curz = cursorProp:getLoc()
  if cury < 0 then return end
  
  local x,z = cursorProp.lastGridX, cursorProp.lastGridZ
  print( "1up:", x,z )

  function updateCallback(x,z)
    local chx, chz = int( x / CHUNKSZ ), int( z / CHUNKSZ )
    for i,chunk in ipairs(chunks) do
      if chunk.chx >= chx-1 and chunk.chx <= chx+1 and chunk.chz >= chz-1 and chunk.chz <= chz+1 then
        chunk.toUpdate = true
      end          
    end        
  end
  fld:landup( x,z, updateCallback  )

  -- check updated chunks
  local toRemove, toReallocate = {}, {}
  for i,chunk in ipairs(chunks) do
    if chunk.toUpdate then
      chunk.toUpdate = false
      table.insert(toRemove,chunk)
      local posx, posy, posz = chunk:getLoc()
      table.insert(toReallocate, {chx=chunk.chx,chz=chunk.chz,prio=chunk:getPriority(), posx = posx, posy=posy, posz=posz} )
    end
  end
  print("AAAAAAAA:", #chunks )
  for i,chunk in ipairs(toRemove) do
    print("chunk",  chunk.chx, chunk.chz, "to update.")
    fieldLayer:removeProp(chunk)
    for j,ch in ipairs(chunks) do
      if ch == chunk then
        table.remove(chunks,j)
        break
      end
    end    
  end
  print("BBBBBBBB:", #chunks )  
  for i,v in ipairs(toReallocate) do
    local p = updateChunk( v.chx, v.chz )
    p:setPriority( v.prio )
    p:setLoc( v.posx, v.posy, v.posz )
  end
  cursorProp:setAtGrid( x,z )
end

MOAIInputMgr.device.mouseLeft:setCallback( onMouseLeftEvent )

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


---------------------------

-- cam
camera = MOAICamera3D.new ()
local z = camera:getFocalLength ( SCRW )
camera:setLoc ( 0, 1000, 800 )
fieldLayer:setCamera ( camera )
camera:setRot(-15,0,0)

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
statBox = makeTextBox( 0,0, "init")
hudLayer:insertProp(statBox)

----------------
scrollX, scrollZ = 0, 0
function moveWorld(dx,dz)
  for i,p in ipairs(chunks) do
    local x,y,z = p:getLoc()
    x,z = x+dx, z+dz
    p:setLoc(x,y,z)
  end
  scrollX, scrollZ = scrollX + dx, scrollZ + dz
end

camera.flyUp = true

th = MOAICoroutine.new()
th:run(function()
    local xrot = 0
    while true do
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

      cz = cy * 0.5
      camera:setLoc( cx, cy, cz )

      -- update cursor
      local px,py,pz, xn,yn,zn = fieldLayer:wndToWorld(lastPointerX,lastPointerY)
      print("pointer:", px,py,pz, xn,yn,zn )

      local camx,camy,camz = camera:getLoc()

      local ctlx,ctlz = fld:findControlPoint( camx - scrollX, camy, camz - scrollZ, xn,yn,zn )
      if ctlx and ctlz and ctlx >= 0 and ctlx < fld.width and ctlz >= 0 and ctlz < fld.height then
        print("controlpoint:", ctlx, ctlz )
        cursorProp:setAtGrid(ctlx,ctlz)
      else
        cursorProp:setLoc(0,-999999,0) -- disappear
      end

  
      coroutine.yield()
    end
  end)

