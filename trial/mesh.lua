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

  function vb:pushVert(x,y,z, u,v)
    self:writeFloat( x,y,z )
    self:writeFloat( u,v )
    self:writeColor32( 1,1,1 )        
  end
      
  return vb
end

function makeIndexBuffer(nIndex)
  local ib = MOAIIndexBuffer.new()
  ib:reserve( nIndex )
  return ib
end


--

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
  local vertNum = w * h
  local cellNum = (w-1) * (h-1)
  local triNum = cellNum * 2

  assert( vertNum == #hdata)
  assert( vertNum == #tdata)
  
  local vb = makeVertexBuffer(cellNum * 6 )
  local ib = makeIndexBuffer( triNum * 3 )

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
      local baseVertOffset = (cellCnt-1) * 6
      
      if normalDiv then
        -- 頂点(別々にUVで影をつけるので三角2個で6頂点必要        
        vb:pushVert( basex, leftTopHeight, basez, baseU, baseV ) -- A
        vb:pushVert( basex + sz, rightTopHeight, basez,  baseU + DECKSTEP,baseV ) -- B
        vb:pushVert( basex + sz, rightBottomHeight, basez + sz, baseU + DECKSTEP, baseV + DECKSTEP )  -- C
        
        vb:pushVert( basex, leftTopHeight, basez,  baseU, baseV )-- A
        vb:pushVert( basex + sz, rightBottomHeight, basez + sz, baseU + DECKSTEP, baseV + DECKSTEP ) -- C
        vb:pushVert( basex, leftBottomHeight, basez + sz, baseU, baseV + DECKSTEP ) -- D
      else
        vb:pushVert( basex, leftTopHeight, basez, baseU, baseV ) --A
        vb:pushVert( basex+sz, rightTopHeight, basez, baseU + DECKSTEP, baseV ) --B
        vb:pushVert( basex, leftBottomHeight, basez+sz, baseU, baseV + DECKSTEP ) --D

        vb:pushVert( basex + sz, rightTopHeight, basez,  baseU + DECKSTEP,baseV ) -- B
        vb:pushVert( basex + sz, rightBottomHeight, basez + sz, baseU + DECKSTEP, baseV + DECKSTEP ) -- C
        vb:pushVert( basex, leftBottomHeight, basez + sz, baseU, baseV + DECKSTEP ) -- D
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

function makeSquareBoardMesh()
  
end

function makeTriangleMesh(w)
  local vertexFormat = MOAIVertexFormat.new ()

  vertexFormat:declareCoord ( 1, MOAIVertexFormat.GL_FLOAT, 3 )
  vertexFormat:declareUV ( 2, MOAIVertexFormat.GL_FLOAT, 2 )
  vertexFormat:declareColor ( 3, MOAIVertexFormat.GL_UNSIGNED_BYTE )

  local vbo = MOAIVertexBuffer.new ()
  vbo:setFormat ( vertexFormat )
  vbo:reserveVerts ( 4 )

  -- 1: left front (-x,0,-z)
  vbo:writeFloat ( -w, 0, -w )
  vbo:writeFloat ( 0, 1 )
  vbo:writeColor32 ( 0, 1, 1 )

  -- 2: right front (x,0,-z)
  vbo:writeFloat ( w, 0, -w )
  vbo:writeFloat ( 1, 1 )
  vbo:writeColor32 ( 1, 0, 1 )

  -- 3: right back (x,0,z)
  vbo:writeFloat ( w, 0, w )
  vbo:writeFloat ( 1, 0 )
  vbo:writeColor32 ( 0, 1, 0 )

  -- 4: left back ( -x,0,z)
  vbo:writeFloat ( -w, 0, w )
  vbo:writeFloat ( 0, 0 )
  vbo:writeColor32 ( 1, 0, 0 )

  vbo:bless ()


  local ibo = MOAIIndexBuffer.new ()
  ibo:reserve ( 6 )

  -- left
  ibo:setIndex ( 1, 2 )
  ibo:setIndex ( 2, 1 )
  ibo:setIndex ( 3, 4 )

  -- right
  ibo:setIndex ( 4, 2 )
  ibo:setIndex ( 5, 4 )
  ibo:setIndex ( 6, 3 )


  local mesh = MOAIMesh.new ()
  mesh:setTexture ( baseDeck ) --"white.png" )
  mesh:setVertexBuffer ( vbo )
  mesh:setIndexBuffer ( ibo )
  mesh:setPrimType ( MOAIMesh.GL_TRIANGLES )

  return mesh
end
