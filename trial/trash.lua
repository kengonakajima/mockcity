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



-- not completed, wasted!

function Vector3(x,y,z)
  local vec = {x=x,y=y,z=z}
  function vec:normalize()
    local l = math.sqrt( x*x + y*y + z*z )
    return Vector3( self.x/l, self.y/l, self.z/l )
  end
  function vec:sub(tosub)
    return Vector3( self.x - tosub.x, self.y - tosub.y, self.z - tosub.z )
  end
  function vec:dot(v)
    return Vector3(
      self.y * v.z - self.z * v.y,
      self.z * v.x - self.x * v.z,
      self.x * v.y - self.y * v.x
    )     
  end
  function vec:mul(s)
    return Vector3( self.x * s, self.y * s, self.z * s )
  end
  function vec:toString()
    return string.format("(%f,%f,%f)", self.x, self.y, self.z )
  end
  return vec
end

-- from cocos2d
function lookat( eyex, eyey, eyez,    centerx, centery, centerz,   upx,  upy, upz)
  --    GLfloat m[16];
  --    GLfloat x[3], y[3], z[3];
  --    GLfloat mag;
  -- Make rotation matrix 
	
  -- Z vector
  local z={}
  z[0] = eyex - centerx
  z[1] = eyey - centery
  z[2] = eyez - centerz
  
  mag = math.sqrt( z[0] * z[0] + z[1] * z[1] + z[2] * z[2])
  
  if mag ~= 0 then
    z[0] = z[0] / mag
    z[1] = z[1] / mag
    z[2] = z[2] / mag
  end  
	
  -- Y vector
  local y={}
  y[0] = upx
  y[1] = upy
  y[2] = upz

  -- X vector = Y cross Z 
  x[0] = y[1] * z[2] - y[2] * z[1]
  x[1] = -y[0] * z[2] + y[2] * z[0]
  x[2] = y[0] * z[1] - y[1] * z[0]
	
  -- Recompute Y = Z cross X 
  y[0] = z[1] * x[2] - z[2] * x[1]
  y[1] = -z[0] * x[2] + z[2] * x[0]
  y[2] = z[0] * x[1] - z[1] * x[0]
	
  -- cross product gives area of parallelogram, which is < 1.0 for
  -- non-perpendicular unit-length vectors; so normalize x, y here
  
  mag = math.sqrt(x[0] * x[0] + x[1] * x[1] + x[2] * x[2])
  
  if mag ~= 0 then
    x[0] = x[0] / mag
    x[1] = x[1] / mag
    x[2] = x[2] / mag
  end

  mag = math.sqrt(y[0] * y[0] + y[1] * y[1] + y[2] * y[2])
  if mag ~= 0 then
    y[0] = y[0] / mag
    y[1] = y[1] / mag
    y[2] = y[2] / mag
  end
  
  local m={}

  -- #define M(row,col)  m[col*4+row]
  local function Mset(m,row,col,value) m[ col*4 + row + 1] = value end

  Mset(m, 0, 0, x[0])
  Mset(m, 0, 1, x[1])
  Mset(m, 0, 2, x[2])
  Mset(m, 0, 3, 0.0f)
  Mset(m, 1, 0, y[0])
  Mset(m, 1, 1, y[1])
  Mset(m, 1, 2, y[2])
  Mset(m, 1, 3, 0.0f)
  Mset(m, 2, 0, z[0])
  Mset(m, 2, 1, z[1])
  Mset(m, 2, 2, z[2])
  Mset(m, 2, 3, 0.0f)
  Mset(m, 3, 0, 0.0f)
  Mset(m, 3, 1, 0.0f)
  Mset(m, 3, 2, 0.0f)
  Mset(m, 3, 3, 1.0f)

  local fixedM={} -- GLfloat fixedM[16]
  for a=1,16 do
    fixedM[a] = m[a]
  end
  local identity = { 1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,0 }
  local mm = matmul44( identity, fixedM)
	
  -- Translate Eye to Origin 
  mm = tranlatemat( mm, -eyex, -eyey, -eyez)
  return mm
end

--#define A(row,col)  a[(col<<2)+row]
--#define B(row,col)  b[(col<<2)+row]
--#define P(row,col)  product[(col<<2)+row]
-- static void matmul4( GLfloat *product, const GLfloat *a, const GLfloat *b )
-- out: mat44
function matmul44( amat, bmat )
  local function A(row,col) return amat[col*4+row + 1] end
  local function B(row,col) return bmat[col*4+row + 1] end
  local function Pset(row,col,val) return product[col*4+row+1] = val end
  
  for i=0,3 do
    local ai0 = A(
    

      const GLfloat ai0=A(i,0),  ai1=A(i,1),  ai2=A(i,2),  ai3=A(i,3);
      P(i,0) = ai0 * B(0,0) + ai1 * B(1,0) + ai2 * B(2,0) + ai3 * B(3,0);
      P(i,1) = ai0 * B(0,1) + ai1 * B(1,1) + ai2 * B(2,1) + ai3 * B(3,1);
      P(i,2) = ai0 * B(0,2) + ai1 * B(1,2) + ai2 * B(2,2) + ai3 * B(3,2);
      P(i,3) = ai0 * B(0,3) + ai1 * B(1,3) + ai2 * B(2,3) + ai3 * B(3,3);
   }
}



local pos = Vector3(0,10,0)
local target = Vector3( 0, 0, 0 )
local left, up, forward = lookAtToAxes( pos, target )
print( left:toString() , up:toString(), forward:toString() )
