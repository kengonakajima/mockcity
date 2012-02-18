----------------------------------------------------------------
-- Copyright (c) 2010-2011 Zipline Games, Inc. 
-- All Rights Reserved. 
-- http://getmoai.com
----------------------------------------------------------------

require "./util"
require "./mesh"
require "./field"


SCRW, SCRH = 960, 640

MOAISim.openWindow ( "test", SCRW, SCRH )
MOAIGfxDevice.setClearDepth ( true )

viewport = MOAIViewport.new ()
viewport:setSize ( SCRW, SCRH )
viewport:setScale ( SCRW, SCRH )

layer = MOAILayer.new ()
layer:setViewport ( viewport )
layer:setSortMode ( MOAILayer.SORT_NONE ) -- don't need layer sort
MOAISim.pushRenderPass ( layer )


function loadTex( path )
  local t = MOAITexture.new()
  t:load( path )
  return t
end

whiteDeck = loadTex( "white.png" )
baseDeck = loadTex( "../images/citybase.png" )


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
-- vx,vy : 頂点の位置。 0開始。
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



keyState={}
function onKeyboardEvent(k,dn)
  keyState[k] = dn
end
MOAIInputMgr.device.keyboard:setCallback( onKeyboardEvent )


function onPointerEvent(mousex,mousey)
  local px,py,pz, xn,yn,zn = layer:wndToWorld(mousex,mousey)
  print("pointer:", px,py,pz, xn,yn,zn )

  local camx,camy,camz = camera:getLoc()

  local ctlx,ctlz = fld:findControlPoint( camx - scrollX, camy, camz - scrollZ, xn,yn,zn )
  print("controlpoint:", ctlx, ctlz )

--  local t,u,v = triangleIntersect( {x=camx,y=camy,z=camz}, {x=xn,y=yn,z=zn}, {x=0,y=0,z=0}, {x=32,y=0,z=32},{x=32,y=0,z=0} )
--  if t then
--    local hitx,hity,hitz = camx + xn*t, camy + yn*t, camz + zn*t
--    print( "hit:",hitx,hity,hitz,t,u,v)
--  end
  
end

MOAIInputMgr.device.pointer:setCallback( onPointerEvent )


chunks={}
CHUNKRANGE = 16
for chy=1,CHUNKRANGE do
  for chx=1,CHUNKRANGE do
    local p = makeHMProp((chx-1)*CHUNKSZ,(chy-1)*CHUNKSZ)
    layer:insertProp(p)
    table.insert(chunks,p)
  end
end

---------------------------

-- cam
camera = MOAICamera3D.new ()
local z = camera:getFocalLength ( SCRW )
camera:setLoc ( 0, 1000, 800 )
layer:setCamera ( camera )
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
      local dy,dz = 0 - cy, 0 - cz -- いつも中央点を見て、世界のほうを動かす。
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

      coroutine.yield()
    end
  end)

