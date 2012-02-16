----------------------------------------------------------------
-- Copyright (c) 2010-2011 Zipline Games, Inc. 
-- All Rights Reserved. 
-- http://getmoai.com
----------------------------------------------------------------

MOAISim.openWindow ( "test", 320, 480 )
MOAIGfxDevice.setClearDepth ( true )

viewport = MOAIViewport.new ()
viewport:setSize ( 320, 480 )
viewport:setScale ( 320, 480 )

layer = MOAILayer.new ()
layer:setViewport ( viewport )
layer:setSortMode ( MOAILayer.SORT_NONE ) -- don't need layer sort
MOAISim.pushRenderPass ( layer )

vertexFormat = MOAIVertexFormat.new ()

vertexFormat:declareCoord ( 1, MOAIVertexFormat.GL_FLOAT, 3 )
vertexFormat:declareUV ( 2, MOAIVertexFormat.GL_FLOAT, 2 )
vertexFormat:declareColor ( 3, MOAIVertexFormat.GL_UNSIGNED_BYTE )

vbo = MOAIVertexBuffer.new ()
vbo:setFormat ( vertexFormat )
vbo:reserveVerts ( 4 )

-- 1: left front (-x,0,-z)
vbo:writeFloat ( -64, 0, -64 )
vbo:writeFloat ( 0, 1 )
vbo:writeColor32 ( 0, 1, 1 )

-- 2: right front (x,0,-z)
vbo:writeFloat ( 64, 0, -64 )
vbo:writeFloat ( 1, 1 )
vbo:writeColor32 ( 1, 0, 1 )

-- 3: right back (x,0,z)
vbo:writeFloat ( 64, 0, 64 )
vbo:writeFloat ( 1, 0 )
vbo:writeColor32 ( 0, 1, 0 )

-- 4: left back ( -x,0,z)
vbo:writeFloat ( -64, 0, 64 )
vbo:writeFloat ( 0, 0 )
vbo:writeColor32 ( 1, 0, 0 )

vbo:bless ()


ibo = MOAIIndexBuffer.new ()
ibo:reserve ( 6 )

-- left
ibo:setIndex ( 1, 2 )
ibo:setIndex ( 2, 1 )
ibo:setIndex ( 3, 4 )

-- right
ibo:setIndex ( 4, 2 )
ibo:setIndex ( 5, 4 )
ibo:setIndex ( 6, 3 )


mesh = MOAIMesh.new ()
mesh:setTexture ( "white.png" )
mesh:setVertexBuffer ( vbo )
mesh:setIndexBuffer ( ibo )
mesh:setPrimType ( MOAIMesh.GL_TRIANGLES )

prop = MOAIProp.new ()
prop:setDeck ( mesh )
prop:setCullMode ( MOAIProp.CULL_BACK )
prop:setDepthTest ( MOAIProp.DEPTH_TEST_LESS_EQUAL )
prop:moveRot ( 0, 180, 0, 3 )
layer:insertProp ( prop )

camera = MOAICamera3D.new ()
camera:setLoc ( 0, 100, camera:getFocalLength ( 320 ))
layer:setCamera ( camera )
