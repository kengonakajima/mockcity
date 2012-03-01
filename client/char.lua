CHARSTATE={
  STAND = 1,
  WALK = 2,
  DIE = 3
}

chars={}
function makeChar(x,z,deck,index)
  local h = getFieldHeight(x,z)
  if not h then
    print("makeChar: invalid coord or no chunk?:",x,z)
    return
  end
    
  local ch = MOAIProp.new()

  function ch:setState(st)
    self.state = st
    self.cnt = 0
  end

  ch:setState( CHARSTATE.STAND )

  local scl = 1.5
  ch:setScl(scl,scl,scl)

  ch:setRot(-45,0,0)
  function ch:moveToGrid(x,z)
    local xx,yy,zz = getFieldGridLoc(x,z)
    if not xx then return end
    local h = getFieldHeight(x,z)
    assert(h)
    xx,yy,zz =  xx+CELLUNITSZ/2, yy+CELLUNITSZ/2-5, zz+CELLUNITSZ/2 
    if not self.gridX then
      self:setLoc(xx,yy,zz)
    else
      self:seekLoc(xx,yy,zz, 0.3 )
    end
    self.gridX, self.gridY, self.gridZ = x,h,z    
    
  end

  function ch:poll()
    self.cnt = self.cnt + 1
    local ind
    if self.state == CHARSTATE.STAND then
      ind = 1
    elseif self.state == CHARSTATE.WALK then
      ind = 2 + int( self.cnt / 15 ) % 2
    elseif self.state == CHARSTATE.DIE then
      ind = 25
    end
    if ind ~= self.lastInd then
      self.lastInd = ind
      local mesh = makeSquareBoardMesh(deck,ind)
      ch:setDeck(mesh)            
    end

    -- debug move
    if self.cnt % 100 == 0 then
      local nx,nz = self.gridX, self.gridZ
      if birandom() then
        nx,nz = self.gridX + choose({-1,1}), self.gridZ
      else
        nx,nz = self.gridX, self.gridZ + choose({-1,1})
      end
      self:moveToGrid(nx,nz)
    end

  end
  
  ch:moveToGrid(x,z)

  charLayer:insertProp(ch)
  table.insert(chars,ch)
  return ch
end

function pollChars()
  for i,v in ipairs(chars) do
    v:poll()
    print( "ch:", v:getLoc())
  end
  
end
