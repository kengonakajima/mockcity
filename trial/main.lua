----------------------------------------------------------------
-- Copyright (c) 2010-2011 Zipline Games, Inc. 
-- All Rights Reserved. 
-- http://getmoai.com
----------------------------------------------------------------

require "./util"

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


DECKDIV = 8
DECKSTEP = 1/DECKDIV
function tileIndexToUV(ind)
  local x = (ind-1) % DECKDIV
  local y = math.floor( (ind-1) / DECKDIV )
  return x * DECKSTEP, y * DECKSTEP
end

-- w,h : N=4だったら 頂点が4、 セルは3。
-- triの数は、(w-1) * (h-1) * 2
-- triの割り方は、Normal, Reverse
-- A-B         A-B
-- |\|  Normal |/| Reverse
-- D-C         D-C
--
-- ABCD
-- 0000 N
-- 0001 R
-- 0010 N
-- 0011 N
-- 0100 R
-- 0101 N
-- 0111 N
-- 1000 N
-- 1001 N
-- 1010 N
-- 1011 R
-- 1100 N
-- 1101 N
-- 1110 R
-- 1111 N
function makeHeightMapMesh(sz,w,h,hdata, tdata )
--  print("makeHeightMapMesh: sz:",sz, "w:",w,"h:",h,"dat:",#hdata, #tdata)
  -- 頂点を用意
  local vf = MOAIVertexFormat.new()
  vf:declareCoord ( 1, MOAIVertexFormat.GL_FLOAT, 3 )
  vf:declareUV ( 2, MOAIVertexFormat.GL_FLOAT, 2 )
  vf:declareColor ( 3, MOAIVertexFormat.GL_UNSIGNED_BYTE )

  local vertNum = w * h
  local cellNum = (w-1) * (h-1)
  local triNum = cellNum * 2

  assert( vertNum == #hdata)
  assert( vertNum == #tdata)
  
  local vb = MOAIVertexBuffer.new()
  vb:setFormat(vf)
  vb:reserveVerts( cellNum * 6 )

  local ib = MOAIIndexBuffer.new()
  ib:reserve( triNum * 3 )

  -- 3角形の数だけ回す
  local indexCnt, cellCnt = 1,1
  for z=1,h-1 do
    for x=1,w-1 do
      local basex, basez = (x-1)*sz, (z-1)*sz

      local fieldVertInd = (z-1)*w + (x-1) + 1
      local leftTopHeight = hdata[fieldVertInd] * sz
      local rightTopHeight = hdata[fieldVertInd+1] * sz
      local rightBottomHeight = hdata[fieldVertInd+1+w] * sz
      local leftBottomHeight = hdata[fieldVertInd+w] * sz

      local normalDiv = true
      if leftTopHeight < rightTopHeight and leftTopHeight == leftBottomHeight and leftBottomHeight == rightBottomHeight and rightBottomHeight < rightTopHeight then
        normalDiv = false
      end
      if rightBottomHeight < leftBottomHeight and rightBottomHeight == rightTopHeight and rightTopHeight == leftTopHeight and leftTopHeight < leftBottomHeight then
        normalDiv = false
      end
      

      local baseU, baseV = tileIndexToUV( tdata[fieldVertInd] )

      function pushVert(x,y,z, u,v)
        vb:writeFloat( x,y,z )
        vb:writeFloat( u,v )
        vb:writeColor32( 1,1,1 )        
      end

      local baseVertOffset = (cellCnt-1) * 6
      
      if normalDiv then
        -- 頂点(別々にUVで影をつけるので三角2個で6頂点必要        
        pushVert( basex, leftTopHeight, basez, baseU, baseV ) -- A
        pushVert( basex + sz, rightTopHeight, basez,  baseU + DECKSTEP,baseV ) -- B
        pushVert( basex + sz, rightBottomHeight, basez + sz, baseU + DECKSTEP, baseV + DECKSTEP )  -- C
        
        pushVert( basex, leftTopHeight, basez,  baseU, baseV )-- A
        pushVert( basex + sz, rightBottomHeight, basez + sz, baseU + DECKSTEP, baseV + DECKSTEP ) -- C
        pushVert( basex, leftBottomHeight, basez + sz, baseU, baseV + DECKSTEP ) -- D
      else
        pushVert( basex, leftTopHeight, basez, baseU, baseV ) --A
        pushVert( basex+sz, rightTopHeight, basez, baseU + DECKSTEP, baseV ) --B
        pushVert( basex, leftBottomHeight, basez+sz, baseU, baseV + DECKSTEP ) --D

        pushVert( basex + sz, rightTopHeight, basez,  baseU + DECKSTEP,baseV ) -- B
        pushVert( basex + sz, rightBottomHeight, basez + sz, baseU + DECKSTEP, baseV + DECKSTEP ) -- C
        pushVert( basex, leftBottomHeight, basez + sz, baseU, baseV + DECKSTEP ) -- D
      end
      
      -- 左側の三角形
      ib:setIndex( indexCnt, 4 + baseVertOffset )
      ib:setIndex( indexCnt+1, 6 + baseVertOffset )
      ib:setIndex( indexCnt+2, 5 + baseVertOffset )
      -- 右側の三角形
      ib:setIndex( indexCnt+3, 1 + baseVertOffset )
      ib:setIndex( indexCnt+4, 3 + baseVertOffset )
      ib:setIndex( indexCnt+5, 2 + baseVertOffset )
      
      indexCnt = indexCnt + 6
      cellCnt = cellCnt + 1
    end
  end
  vb:bless()

  local mesh = MOAIMesh.new()
  mesh:setTexture( baseDeck ) --"white.png")
  mesh:setVertexBuffer(vb)
  mesh:setIndexBuffer(ib)
  mesh:setPrimType( MOAIMesh.GL_TRIANGLES )
  return mesh  
end

CELLTYPE={
  NOTHING = 1,
  GRASS = 2,
  SAND = 3,
  WATER = 4
}

-- セルの数はw-1
function Field(w,h)
  local f = {
    width = w,
    height = h,
    heights = {},
    types = {} -- heightの頂点（左上）の属性としてもつ
  }

  local cnt = 1
  for z=1,h do
    for x=1,w do
      f.heights[cnt] = 0
      f.types[cnt] = CELLTYPE.GRASS
      cnt = cnt + 1
    end
  end

  function f:setHeight(x,z,h)
    local i = self.width * z + x + 1
    self.heights[i] = h
  end
  function f:setType(x,z,t)
    local i = self.width * z + x + 1
    self.types[i] = t
  end
  --h,tをかえす
  function f:get(x,z)
    local i = self.width * z + x + 1
    return self.heights[i] or 0, self.types[i] or CELLTYPE.GRASS
  end
  
  -- heights, typesをかえす
  function f:getRect( basex, basez, w,h )
    local outh, outt = {}, {}
    local outi = 1
    for z=basez,basez+h-1 do
      for x=basex,basex+w-1 do
        local i = self.width * z + x + 1
        local height, t = self.heights[i], self.types[i]
        if not height then height = 0 end
        if not t then t = CELLTYPE.GRASS end
        outh[outi] = height
        outt[outi] = t
        outi = outi + 1
      end
    end
--    print("getHeights:", basex, basez, w,h, "outnum:", #outh, #outt )
    return outh, outt
  end

  -- ある地点を1個盛り上げる
  function f:landup(x,z)
    local h = self:get(x,z)
    self:setHeight(x,z,h+1)
    self:checkSlopeUp(x,z,h+1)
  end
  -- 斜面の傾きが2以上だったらもりあげる
  f.dxdzTable = { {-1,-1},{0,-1},{1,-1},{-1,0},{1,0},{-1,1},{0,1},{1,1}}
  function f:checkSlopeUp(x,z,newh)

    for i,dxdz in ipairs(self.dxdzTable) do
      local dx,dz = dxdz[1], dxdz[2]
      local h,t = self:get(x+dx,z+dz)
      if h < newh-1 then
        self:setHeight(x+dx,z+dz,h+1)
        self:checkSlopeUp(x+dx,z+dz,h+1)
      end
    end
  end

  -- tで塗る
  function f:fillCircle(cx,cz,dia,t)
    scanCircle( cx,cz, dia,1, function(x,z)
        self:setType(x,z,t)
      end)
  end
  
  function f:generate()
    local cnt = 1
    for z=1,h do
      for x=1,w do

        if math.random() > 0.9 then
          f.types[cnt] = CELLTYPE.SAND
        end

        if math.random() > 0.99 then
          self:fillCircle( x,z, range(1,5),CELLTYPE.SAND )          
        end
        if math.random() > 0.99 then
          local upN = range(2,5)
          for i=1,upN do
            self:landup(x,z)
          end
        end
        
        cnt = cnt + 1
      end
    end

    for i=1,10 do
      self:landup(20,20)
    end
    
      
    -- 固定のマップを書き込む(デバッグ用)
    local htbl = {
      {0,0,0,0,0,0,0,0,0,0,0,0,0},
      {0,0,0,0,0,0,0,0,0,0,0,0,0},
      {0,0,1,1,0,0,0,0,0,0,0,0,0},
      {0,0,1,1,0,0,0,0,0,0,0,0,0},
      {0,0,0,0,0,1,1,1,0,0,0,0,0},
      {0,0,1,0,0,1,2,1,0,0,0,0,0},
      {0,0,0,0,0,1,1,1,0,0,0,0,0},
      {0,0,0,0,0,0,0,0,0,0,0,0,0},
      {0,0,0,0,0,0,0,0,0,0,0,0,0},
      {0,0,0,0,0,0,0,0,0,0,0,0,0},
      {0,0,0,0,0,0,0,0,0,0,0,0,0},      
    }
    for i,row in ipairs(htbl) do
      for j,col in ipairs(row) do
        self:setHeight( j-1,i-1, col )
      end      
    end
      
  end

  print("initField:", #f.heights )
  return f
end

local fld = Field(256,256)
fld:generate()

CHUNKSZ = 16
-- vx,vy : 頂点の位置。 0開始。
function makeHMProp(vx,vz)
  local sz = 32
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

-- t,u,v をかえす
function triangleIntersect( orig, dir, v0,v1,v2 )
  local e1 = vec3sub(v1,v0)
  local e2 = vec3sub(v2,v0)
  local pvec = vec3cross(dir,e2)
  local det = vec3dot(e1,pvec)
  
  local tvec = vec3sub(orig,v0)
  local u = vec3dot(tvec,pvec)
  local qvec
  local v
  if det > 1e-3 then
    if u < 0 or u > det then return nil end
    qvec = vec3cross(tvec,e1)
    print("b",qvec)    
    v = vec3dot(dir,qvec)
    if v < 0 or u+v >det then return nil end
  elseif det < - 1e-3 then
    if u > 0 or u < det then return nil end
    qvec = vec3cross(tvec,e1)
    print("a")
    v = vec3dot(dir,qvec)
    if v > 0 or u+v <det then return nil end
  else
    return nil
  end
  local inv_det = 1 / det  
  local t = vec3dot(e2,qvec)
  t = t * inv_det * -1
  u = u * inv_det
  v = v * inv_det
  return t,u,v
end

function onPointerEvent(mousex,mousey)
  local px,py,pz, xn,yn,zn = layer:wndToWorld(mousex,mousey)
  print("pointer:",x,y, px,py,pz, xn,yn,zn )

  local camx,camy,camz = camera:getLoc()

  local t,u,v = triangleIntersect( {x=camx,y=camy,z=camz}, {x=xn,y=yn,z=zn}, {x=0,y=0,z=0}, {x=32,y=0,z=32},{x=32,y=0,z=0} )
  if t then
    local hitx,hity,hitz = camx + xn*t, camy + yn*t, camz + zn*t
    print( "hit:",hitx,hity,hitz,t,u,v)
  else
    print("nohit")
  end
  
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
function moveWorld(dx,dy,dz)
  for i,p in ipairs(chunks) do
    local x,y,z = p:getLoc()
    x,y,z = x+dx, y+dy, z+dz
    p:setLoc(x,y,z)
  end
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
        moveWorld(0,0,camSpeed)
      end
      if keyState[115] then --s
        moveWorld(0,0,-camSpeed)
      end
      if keyState[100] then --d
        moveWorld(-camSpeed,0,0)
      end
      if keyState[97] then --a
        moveWorld(camSpeed,0,0)
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

