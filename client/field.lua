
PAGESZ = 128

-- chunk : field cache
function Page(px,pz)
  local pg = {
    heights = {},
    mockHeights = {},
    types = {} -- vertex has cell type.
  }
  pg.state = "init"
  pg.px, pg.pz = px, pz

  function pg:allocateMemory()
    local cnt=1
    for z=0,PAGESZ-1 do
      for x=0,PAGESZ-1 do
        self.heights[cnt] = 0
        self.mockHeights[cnt] = 0
        self.types[cnt] = 0
      end
    end
  end
      
  return pg
end


-- w,h:  vertex, not cells
function Field(w,h)
  local f = {
    width = w,
    height = h,
    pageWidth = int( w / CHUNKSZ ),
    pageHeight = int( h / CHUNKSZ ),
    pages = {}
  }

  function f:pageIndex(px,pz)
    return ( px + pz * self.pageWidth ) + 1
  end

  function f:allocatePageTable()
    local cnt = 1
    for pz=0,f.pageHeight-1 do
      for px=0,f.pageWidth-1 do
        self.pages[cnt] = Page(px,pz)
        cnt = cnt + 1
      end
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
  function f:targetSet(target,x,z,h)
    local i = self.width * z + x + 1
    target[i] = h    
  end
  function f:targetGet(target,x,z)
    local i = self.width * z + x + 1
    return target[i]
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
--      print("gerrect: num mh:", #outmh, basex, basez )
      assert( #outmh == w * h)
    end    
    return outh, outt, outmh, outred
  end

    
--  function f:landMod(x,z,mod,callback)
--    self:targetMod( self.heights, x,z,mod,callback)
--  end
--  function f:mockMod(x,z,mod,callback)
--    self:targetMod( self.mockHeights, x,z,mod,callback)
--  end

  -- 
--  function f:mockClear(x,z,callback)
--    local h = self:get(x,z)
--     local mockh = self:targetGet( self.mockHeights, x,z )

--     local dh = mockh - h
--     print( "DDDDDDDDD:", dh )
--     if dh == 0 then return end    
--     if dh > 0 then
--       for i=1,dh do
--         self:mockMod(x,z,-1,callback)
--       end
--     elseif dh < 0 then
--       for i=-1,dh,-1 do
--         self:mockMod(x,z,1,callback)
--       end
--     end
--   end
  
  -- dir : must be normalized

  function f:copyHeightToMock()
    for i,v in ipairs(self.heights) do
      self.mockHeights[i] = v
    end    
  end

  f:allocatePageTable()

  print("gen:", #f.heights )
  return f
end
