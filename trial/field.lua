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
  -- 左上座標を指定したら4点を返す
  function f:get4heights(x,z)
    local ah = self:get(x,z)
    local bh = self:get(x+1,z)
    local ch = self:get(x+1,z+1)
    local dh = self:get(x,z+1)
    return { leftTop=ah, rightTop=bh, rightBottom=ch, leftBottom=dh }    
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
--    print("getRect:", basex, basez, w,h, "outnum:", #outh, #outt )
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

  -- dirはnormalized
  function f:findControlPoint( camx,camy,camz, dirx,diry,dirz )
    local x,y,z = camx,camy,camz
    local camvec, dirvec = vec3(camx,camy,camz), vec3(dirx,diry,dirz)
    local loopN = camy / CELLUNITSZ
    local previx,previz
    for i=1,loopN*2 do
      x,y,z = x + dirx * CELLUNITSZ, y + diry * CELLUNITSZ, z + dirz * CELLUNITSZ
      local ix, iz = int(x/CELLUNITSZ), int(z/CELLUNITSZ)
      if ix ~= previx or iz ~= previz then
        local h4s = fld:get4heights(ix,iz)
--        print("diffed.",ix,iz, h4s.leftTop, h4s.rightTop, h4s.rightBottom, h4s.leftBottom )
        local ltY,rtY,rbY,lbY = h4s.leftTop * CELLUNITSZ, h4s.rightTop * CELLUNITSZ, h4s.rightBottom * CELLUNITSZ, h4s.leftBottom * CELLUNITSZ
        local ltX,ltZ = ix*CELLUNITSZ, iz*CELLUNITSZ
        local t,u,v = triangleIntersect( camvec, dirvec, vec3(ltX,ltY,ltZ), vec3(ltX+CELLUNITSZ,rtY,ltZ), vec3(ltX+CELLUNITSZ,rbY,ltZ+CELLUNITSZ))
        if t then
          print("HIT TRIANGLE RIGHT-UP. x,z:", ix,iz)
          return ix,iz
        end
        t,u,v = triangleIntersect( camvec, dirvec, vec3(ltX,ltY,ltZ), vec3(ltX+CELLUNITSZ,rbY,ltZ+CELLUNITSZ), vec3(ltX,lbY,ltZ+CELLUNITSZ))
        if t then
          print("HIT TRIANGLE LEFT-DOWN. x,z:",ix,iz)
          return ix,iz
        end
      end      
      previx,previz = ix,iz
      if y < 0 then break end
    end
    return nil
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
