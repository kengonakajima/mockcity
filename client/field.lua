-- w,h:  vertex, not cells
function Field(w,h)
  local f = {
    width = w,
    height = h,
    heights = {},
    mockHeights = {},
    types = {} -- vertex has cell type.
  }

  local cnt = 1
  for z=1,h do
    for x=1,w do
      f.heights[cnt] = 0
      f.mockHeights[cnt] = 0
      f.types[cnt] = CELLTYPE.GRASS
      cnt = cnt + 1
    end
  end

  function f:setMockHeight(x,z,h)
    local i = self.width * z + x + 1
    self.mockHeights[i] = h
  end  
  function f:setHeight(x,z,h)
    local i = self.width * z + x + 1
    self.heights[i] = h
  end
  function f:setType(x,z,t)
    local i = self.width * z + x + 1
    self.types[i] = t
  end
  -- return height, type, mockheight
  function f:get(x,z)
    local i = self.width * z + x + 1
    return self.heights[i] or 0, self.types[i] or CELLTYPE.GRASS, self.mockHeights[i]
  end
  -- return 4 verts from LT
  function f:get4heights(x,z)
    local ah = self:get(x,z)
    local bh = self:get(x+1,z)
    local ch = self:get(x+1,z+1)
    local dh = self:get(x,z+1)
    return { leftTop=ah, rightTop=bh, rightBottom=ch, leftBottom=dh }    
  end  
  
  -- return heights, types, reddata
  function f:getRect( basex, basez, w,h )
    local outh, outt, outmh,outred = {}, {}, {}, {}
    local validMockNum = 0
    local outi = 1
    for z=basez,basez+h-1 do
      for x=basex,basex+w-1 do
        local i = self.width * z + x + 1
        local height, t, mockh = self.heights[i], self.types[i], self.mockHeights[i]
        if not height then height = 0 end
        if not mockh then mockh = 0 end
        if not t then t = CELLTYPE.GRASS end
        outh[outi] = height
        outt[outi] = t
        outmh[outi] = mockh
        if mockh < height then
          validMockNum = validMockNum + 1
          outred[outi] = true
          if (outi-1)>=1 then outred[outi - 1] = true end -- left
          if (outi-w) >= 1 then outred[outi-w] = true end -- up
          if (outi-w-1) >= 1 then outred[outi-w-1] = true end -- left up
        elseif mockh > height then
          validMockNum = validMockNum + 1
        else
          outred[outi] = false
        end
        
        
        outi = outi + 1
      end
    end

    if validMockNum == 0 then
      outmh = nil
    else
      print("gerrect: num mh:", #outmh, basex, basez )
      assert( #outmh == w * h)
    end    
    return outh, outt, outmh, outred
  end

  -- land up for 1
  function f:landMod(x,z,mod,callback)
    assert( mod == 1 or mod == -1 )
    local h = self:get(x,z)
    if h <= 0 and mod == -1 then return end
    self:setHeight(x,z,h+mod)
    if callback then callback(x,z) end
    self:checkSlopeMod(x,z,h,mod,callback)
  end

  -- recurse. maximum slope rate is 1 per cell.
  f.dxdzTable = { {-1,-1},{0,-1},{1,-1},{-1,0},{1,0},{-1,1},{0,1},{1,1}}
  function f:checkSlopeMod(x,z,curh,mod,callback)
    local newh = curh + mod
    for i,dxdz in ipairs(self.dxdzTable) do
      local dx,dz = dxdz[1], dxdz[2]
      local h,t = self:get(x+dx,z+dz)
      if (mod == 1 and h < newh-1 ) or (mod == -1 and h > newh+1 ) then
        self:setHeight(x+dx,z+dz,h+mod)
        if callback then callback(x+dx,z+dz) end
        self:checkSlopeMod(x+dx,z+dz,h,mod,callback)
      end
    end
  end

  -- t: fill type
  function f:fillCircle(cx,cz,dia,t)
    scanCircle( cx,cz, dia,1, function(x,z)
        self:setType(x,z,t)
      end)
  end

  -- dir : must be normalized
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
--          print("HIT TRIANGLE RIGHT-UP. x,z:", ix,iz)
          return ix,iz
        end
        t,u,v = triangleIntersect( camvec, dirvec, vec3(ltX,ltY,ltZ), vec3(ltX+CELLUNITSZ,rbY,ltZ+CELLUNITSZ), vec3(ltX,lbY,ltZ+CELLUNITSZ))
        if t then
--          print("HIT TRIANGLE LEFT-DOWN. x,z:",ix,iz)
          return ix,iz
        end
      end      
      previx,previz = ix,iz
      if y < 0 then break end
    end
    return nil
  end

  function f:copyHeightToMock()
    for i,v in ipairs(self.heights) do
      self.mockHeights[i] = v
    end    
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
            self:landMod(x,z,1)
          end
        end
        
        cnt = cnt + 1
      end
    end

    for i=1,10 do
      self:landMod(20,20,1)
    end


      
    -- fixed map for debug
    local htbl = {
      {0,0,0,0,0,0,0,0,0,0,0,0,0},
      {0,0,0,0,0,0,0,0,0,0,0,0,0},
      {0,0,1,1,0,0,0,0,0,0,0,0,0},
      {0,0,1,1,0,0,0,1,1,1,1,0,0},
      {0,0,0,0,0,0,1,1,1,0,1,0,0},
      {0,0,0,0,0,0,1,2,1,0,1,0,0},
      {0,0,1,0,0,0,1,1,1,0,1,0,0},
      {0,0,0,0,0,0,0,1,1,1,1,0,0},
      {0,0,0,0,0,0,0,0,0,0,0,0,0},
      {0,0,0,0,0,0,0,0,0,0,0,0,0},
      {0,0,0,0,0,0,0,0,0,0,0,0,0},      
    }
    local mocktbl = {
      {0,0,0,0,0,0,0,0,0,0,0,0,0},
      {0,0,0,0,0,0,0,0,0,0,0,0,0},
      {0,0,0,0,0,0,0,0,0,0,0,0,0},      
      {0,0,0,0,0,0,0,0,0,0,0,0,0},
      {0,0,0,0,0,0,0,0,1,1,1,1,0},
      {0,0,0,0,0,0,0,1,1,2,2,1,0},
      {0,0,0,0,0,0,0,1,1,2,2,1,0},
      {0,0,0,0,0,0,0,1,1,2,2,1,0},
      {0,0,0,0,0,0,0,0,1,1,1,1,0},
      {0,0,0,0,0,0,0,0,0,1,2,2,1},
      {0,0,0,0,0,0,0,0,0,1,2,2,1},
      {0,0,0,0,0,0,0,0,0,1,2,2,1},      
    }
    for i,row in ipairs(htbl) do
      for j,col in ipairs(row) do
        self:setHeight( j-1,i-1, col )
      end
    end
    self:copyHeightToMock()
    for i,row in ipairs(mocktbl) do
      for j,col in ipairs(row) do
        self:setMockHeight( j-1,i-1, col )
      end
    end    
      
  end

  print("gen:", #f.heights )
  return f
end
