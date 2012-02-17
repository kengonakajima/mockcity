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


local mesh = makeTriangleMesh(16)
local props = {}
local n = 10
for x=1,n do
  for z=1,n do
    local prop = MOAIProp.new ()
    prop:setDeck ( mesh )
    prop:setCullMode ( MOAIProp.CULL_BACK )
    prop:setDepthTest ( MOAIProp.DEPTH_TEST_LESS_EQUAL )
    prop:moveRot ( 0, 180, 0, 3 )
    prop:setLoc( (x-(n/2))*30, 0, (z-(n/2))*30 )
    layer:insertProp ( prop )
    table.insert( props, prop )
  end
end

