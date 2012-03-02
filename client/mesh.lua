-- 3D utils


function getDefaultVertexFormat()
  local vf = MOAIVertexFormat.new()
  vf:declareCoord ( 1, MOAIVertexFormat.GL_FLOAT, 3 )
  vf:declareUV ( 2, MOAIVertexFormat.GL_FLOAT, 2 )
  vf:declareColor ( 3, MOAIVertexFormat.GL_UNSIGNED_BYTE )
  return vf
end

function makeVertexBuffer(nVert)
  local vf = getDefaultVertexFormat()
  local vb = MOAIVertexBuffer.new()
  vb:setFormat(vf)
  vb:reserveVerts( nVert )

  function vb:pushVert(x,y,z, u,v, r,g,b)
    self:writeFloat( x,y,z )
    self:writeFloat( u,v )
    self:writeColor32( r,g,b )
  end
      
  return vb
end

function makeIndexBuffer(nIndex)
  local ib = MOAIIndexBuffer.new()
  ib:reserve( nIndex )
  ib.cnt = 1
  function ib:pushIndex(ind)
    self:setIndex(self.cnt,ind)
    self.cnt = self.cnt + 1
  end
  function ib:pushIndexes(t,d)
    if not d then d = 0 end
    for i,v in ipairs(t) do
      self:pushIndex(v+d)
    end
  end
  
  return ib
end

function makeMesh(deck, vb, ib, primtype )
  local mesh = MOAIMesh.new()
  mesh:setTexture( deck )
  mesh:setVertexBuffer(vb)
  mesh:setIndexBuffer(ib)
  mesh:setPrimType( primtype )
  return mesh
end


--

DECKDIV = 8
DECKSTEP = 1/DECKDIV

function tileIndexToUV(ind)
  local x = (ind-1) % DECKDIV
  local y = math.floor( (ind-1) / DECKDIV )
  return x * DECKSTEP, y * DECKSTEP
end

UVEPSILON = 0.001
function tileIndexToUVEpsilon(ind)
  local u1,v1 = tileIndexToUV(ind)
  local u2,v2 = tileIndexToUV(ind+8+1)
  return u1+UVEPSILON,v1+UVEPSILON,u2-UVEPSILON,v2-UVEPSILON
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
function makeHeightMapMesh(sz,w,h, lightRate, hdata, tdata, reddata, lineMode, heightDiv )
--  print("makeHeightMapMesh: sz:",sz, "w:",w,"h:",h,"dat:",#hdata, tdata )

  local vertNum = w * h
  local cellNum = (w-1) * (h-1)
  local triNum = cellNum * 2

  if hdata then
    assert( vertNum == #hdata)
  end
  if tdata then assert( vertNum == #tdata) end

  local numVert = cellNum * 6
  if lineMode then
    numVert = cellNum * 4
    if reddata then
      for z=0,CHUNKSZ-1 do
        for x=0,CHUNKSZ-1 do
          local ind = x + z * (CHUNKSZ + 1) + 1
          if reddata[ind] then numVert = numVert - 4 end
        end
      end
    end    
  end
  local vb = makeVertexBuffer(numVert+1) -- +1 : moaiのバグ回避用 (TODO:fix)
  
  local numIndex = triNum * 3
  if lineMode then
    numIndex = cellNum * 5 * 2 -- 5 lines
    if reddata then
      for z=0,CHUNKSZ-1 do
        for x=0,CHUNKSZ-1 do
          local ind = x + z * (CHUNKSZ + 1) + 1
          if reddata[ind] then numIndex = numIndex - 5 * 2 end
        end
      end
    end
  end
  
  local ib = makeIndexBuffer( numIndex )

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

      local toRed = nil
      if reddata then toRed = reddata[fieldVertInd] end
      
      local normalDiv = true
      if leftTopHeight < rightTopHeight and leftTopHeight == leftBottomHeight and leftBottomHeight == rightBottomHeight and rightBottomHeight < rightTopHeight then
        normalDiv = false
      end
      if rightBottomHeight < leftBottomHeight and rightBottomHeight == rightTopHeight and rightTopHeight == leftTopHeight and leftTopHeight < leftBottomHeight then
        normalDiv = false
      end
      if leftBottomHeight < rightTopHeight and leftBottomHeight < leftTopHeight and leftBottomHeight < rightBottomHeight then
        normalDiv = false
      end
      if rightTopHeight < rightBottomHeight and rightTopHeight < leftTopHeight and rightTopHeight < leftBottomHeight then
        normalDiv = false
      end

      leftTopHeight = leftTopHeight / heightDiv
      leftBottomHeight = leftBottomHeight / heightDiv
      rightTopHeight = rightTopHeight / heightDiv
      rightBottomHeight = rightBottomHeight / heightDiv
      
      if lineMode then
        if not toRed then
          -- need only 4 vert in line mode.
          local baseVertOffset = (cellCnt-1) * 4
          local baseU, baseV = tileIndexToUV(CELLTYPE.WHITE)
          baseU, baseV = baseU + DECKSTEP/2, baseV + DECKSTEP/2
          vb:pushVert( basex, leftTopHeight, basez, baseU, baseV, 1,1,1 ) -- A
          vb:pushVert( basex + sz, rightTopHeight, basez,  baseU,baseV, 1,1,1 ) -- B
          vb:pushVert( basex + sz, rightBottomHeight, basez + sz, baseU,baseV, 1,1,1 )  -- C
          vb:pushVert( basex, leftBottomHeight, basez + sz, baseU,baseV, 1,1,1 ) -- D
          -- A-B
          ib:pushIndex( 1 + baseVertOffset )
          ib:pushIndex( 2 + baseVertOffset )
          -- B-C
          ib:pushIndex( 2 + baseVertOffset )
          ib:pushIndex( 3 + baseVertOffset )
          if normalDiv then
            -- C-A
            ib:pushIndex( 3 + baseVertOffset )
            ib:pushIndex( 1 + baseVertOffset )            
          else
            -- D-B
            ib:pushIndex( 2 + baseVertOffset )
            ib:pushIndex( 4 + baseVertOffset )                      
          end        
          -- A-D
          ib:pushIndex( 1 + baseVertOffset )
          ib:pushIndex( 4 + baseVertOffset )          
          -- D-C
          ib:pushIndex( 4 + baseVertOffset )
          ib:pushIndex( 3 + baseVertOffset )

          cellCnt = cellCnt + 1
        end        
      else

        local baseU, baseV = tileIndexToUV( tdata[fieldVertInd] )
        local baseVertOffset = (cellCnt-1) * 6

        local r,g,b
        
        if normalDiv then
          -- 頂点(別々にUVで影をつけるので三角2個で6頂点必要
          local lg = 0.7 
          if leftTopHeight<rightTopHeight or leftTopHeight < rightBottomHeight then
            lg = 1
          elseif leftTopHeight >rightTopHeight or leftTopHeight > rightBottomHeight then
            lg = 0.5
          end
          lg = lg * lightRate
          r,g,b = lg,lg,lg
          if toRed then r,g,b=1,g*0.7,b*0.7 end
          vb:pushVert( basex, leftTopHeight, basez, baseU, baseV, r,g,b ) -- A
          vb:pushVert( basex + sz, rightTopHeight, basez,  baseU + DECKSTEP,baseV, r,g,b ) -- B
          vb:pushVert( basex + sz, rightBottomHeight, basez + sz, baseU + DECKSTEP, baseV + DECKSTEP, r,g,b )  -- C
          
          if leftTopHeight<rightBottomHeight or leftTopHeight < leftBottomHeight then
            lg = 1
          elseif leftTopHeight>rightBottomHeight or leftTopHeight > leftBottomHeight then
            lg = 0.5
          else
            lg = 0.7
          end
          lg = lg * lightRate
          r,g,b = lg,lg,lg
          if toRed then r,g,b = 1,g*0.7,b*0.7 end
          vb:pushVert( basex, leftTopHeight, basez,  baseU, baseV, r,g,b )-- A
          vb:pushVert( basex + sz, rightBottomHeight, basez + sz, baseU + DECKSTEP, baseV + DECKSTEP, r,g,b ) -- C
          vb:pushVert( basex, leftBottomHeight, basez + sz, baseU, baseV + DECKSTEP, r,g,b ) -- D
        else
          if rightTopHeight > leftBottomHeight then
            if leftTopHeight > leftBottomHeight then
              lg = 0.5
            else
              lg = 1
            end          
          elseif rightTopHeight < leftBottomHeight then
            if leftTopHeight < leftBottomHeight then
              lg = 1
            else
              lg = 0.5
            end          
          end
          lg = lg * lightRate
          r,g,b = lg,lg,lg
          if toRed then r,g,b=1,g*0.7,b*0.7 end
          vb:pushVert( basex, leftTopHeight, basez, baseU, baseV, r,g,b ) --A
          vb:pushVert( basex+sz, rightTopHeight, basez, baseU + DECKSTEP, baseV, r,g,b ) --B
          vb:pushVert( basex, leftBottomHeight, basez+sz, baseU, baseV + DECKSTEP, r,g,b ) --D

          if rightTopHeight > leftBottomHeight then
            if rightBottomHeight > leftBottomHeight then
              lg = 1
            else
              lg = 0.5
            end          
          elseif rightTopHeight < leftBottomHeight then
            if rightBottomHeight < leftBottomHeight then
              lg = 0.5
            else
              lg = 1
            end          
          end
          lg = lg * lightRate
          r,g,b = lg,lg,lg
          if toRed then r,g,b = 1,g*0.7,b*0.7 end
          vb:pushVert( basex + sz, rightTopHeight, basez,  baseU + DECKSTEP,baseV, r,g,b ) -- B
          vb:pushVert( basex + sz, rightBottomHeight, basez + sz, baseU + DECKSTEP, baseV + DECKSTEP, r,g,b ) -- C
          vb:pushVert( basex, leftBottomHeight, basez + sz, baseU, baseV + DECKSTEP, r,g,b ) -- D
        end

        -- 左側の三角形
        ib:pushIndexes( { 4 + baseVertOffset, 6 + baseVertOffset, 5 + baseVertOffset } )
        -- 右側の三角形
        ib:pushIndexes( { 1 + baseVertOffset, 3 + baseVertOffset, 2 + baseVertOffset } )

        cellCnt = cellCnt + 1
      end      
    end
  end
  -- 最後に、moaiのcullバグを回避するための頂点を追加してみる (TODO:fix)
  vb:pushVert( 0, - w * CELLUNITSZ, 0 )
  vb:bless()
  local pt = MOAIMesh.GL_TRIANGLES
  if lineMode then
    pt = MOAIMesh.GL_LINES
  end
  
  return makeMesh( baseDeck, vb, ib, pt )
end

-- boardなので、 垂直に立っているmesh. z=0
function makeSquareBoardMesh(deck,index)
  local vb = makeVertexBuffer( 4 )
  local ib = makeIndexBuffer( 2 * 3 ) -- 2 tris
  -- A-B
  -- |\|
  -- D-C
  local u1,v1,u2,v2 = tileIndexToUVEpsilon(index)
  vb:pushVert( -16, 16, 0,   u1,v1 ) -- A
  vb:pushVert( 16, 16, 0,    u2,v1 ) -- B
  vb:pushVert( 16, -16, 0,   u2,v2 ) -- C
  vb:pushVert( -16, -16, 0,  u1, v2 ) --D
  -- ABC
  ib:pushIndexes( {1,3,2,  1,4,3} )
  
  vb:bless()
  return makeMesh( deck, vb, ib, MOAIMesh.GL_TRIANGLES )
end




-- { { x,z,facedir,ind }, {x,z,facedir,ind}, ... }
--
--   0  1  2
--  0+---+---+-..
--   |0,0|1,0|
--  1+---+---+-..
--   |0,1|1,1|
--   .   .   .
--
--
--    w
-- A-----B
-- |  \  | h
-- D-----C
--
-- facing
--       up
--       +-+  
--  left | |  right
--       +-+
--      down

OBJMESHTYPE = {
  FENCE=1, -- vert:4 index:6, support 4 direction
  BOARD=2 -- vert:4 index:6, only front face
}
  
function makeMultiObjMesh(ary,deck)
  local n = #ary 
  local vb = makeVertexBuffer( n * 4 )
  local ib = makeIndexBuffer( n * 2 * 3 ) -- 2 tris
  local l,h = 16,16
  local dIndex = 0
  for i,v in ipairs(ary) do
    local t,x,y,z,ind,facedir = unpack(v)
    local dx,dy,dz = x * CELLUNITSZ, y*CELLUNITSZ, z * CELLUNITSZ
    local u1,v1,u2,v2 = tileIndexToUVEpsilon( ind )
    
    if t == OBJMESHTYPE.FENCE then
      print("FENCE!",x,z)
      local faceZ = false
      if facedir == DIR.DOWN then
        faceZ = true
        dz = dz + l
      elseif facedir == DIR.UP then
        faceZ = true
        dz = dz - l
      elseif facedir == DIR.LEFT then
        dx = dx - l
      elseif facedir == DIR.RIGHT then
        dx = dx + l
      end
      if faceZ then
        vb:pushVert( dx-l,dy+h,dz, u1,v1 ) -- A
        vb:pushVert( dx+l,dy+h,dz, u2,v1 ) -- B
        vb:pushVert( dx+l,dy,dz, u2,v2) --C
        vb:pushVert( dx-l,dy,dz, u1,v2 ) -- D
      else
        vb:pushVert(dx,dy+h,dz+l, u1,v1 ) -- A
        vb:pushVert(dx,dy+h,dz-l, u2,v1 ) -- B
        vb:pushVert(dx,dy,dz-l, u2,v2 ) -- C
        vb:pushVert(dx,dy,dz+l, u1,v2 ) -- D
      end
      ib:pushIndexes( { 1,3,2,   1,4,3 }, dIndex )
      dIndex = dIndex + 4
    elseif t == OBJMESHTYPE.BOARD then
      print("BOARD!",x,z)
      vb:pushVert( dx-l,dy+h,dz-l, u1,v1 ) -- A
      vb:pushVert( dx+l,dy+h,dz-l, u2,v1 ) -- B
      vb:pushVert( dx+l,dy,dz+l/2, u2,v2) --C
      vb:pushVert( dx-l,dy,dz+l/2, u1,v2 ) -- D
--      vb:pushVert( dx-l,dy+CELLUNITSZ,dz,  u1,v1 )
--      vb:pushVert( dx+l,dy+CELLUNITSZ,dz,  u2,v1 )
--      vb:pushVert( dx+l,dy,dz+l, u2,v2)
--      vb:pushVert( dx-l,dy,dz+l, u1,v2)
      ib:pushIndexes( { 1,3,2,   1,4,3 }, dIndex )
      dIndex = dIndex + 4
    end
  end
  vb:bless()
  return makeMesh(deck, vb, ib, MOAIMesh.GL_TRIANGLES )
end


