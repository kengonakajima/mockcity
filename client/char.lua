CHARSTATE={
  STAND = 1,
  WALK = 2,
  DIE = 3
}


CHARMOVE_SEEK_SEC = 1
  
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

  ch.ofsX,ch.ofsY,ch.ofsZ = CELLUNITSZ/2+2, CELLUNITSZ/2-5, CELLUNITSZ/2 -- + CELLUNITSZ/4
  ch:setRot(-45,0,0)
  function ch:moveToGrid(x,z)
    local xx,yy,zz = getFieldGridLoc(x,z)
    if not xx then return end
    local h = getFieldHeight(x,z)
    assert(h)
    xx,yy,zz =  xx+ self.ofsX, yy+self.ofsY, zz+self.ofsZ
    if not self.gridX then
      self:setLoc(xx,yy,zz)
    else
      self:seekLoc(xx,yy,zz, CHARMOVE_SEEK_SEC, MOAIEaseType.LINEAR )
      self.moveStartAt = now()
    end
    self.gridX, self.gridY, self.gridZ = x,h,z    
    self:setState(CHARSTATE.WALK)
  end


  function ch:poll(t)
    self.cnt = self.cnt + 1
    local ind
    if self.state == CHARSTATE.STAND then
      ind = 1
    elseif self.state == CHARSTATE.WALK then
      ind = 2 + int( self.cnt / 10 ) % 2
    elseif self.state == CHARSTATE.DIE then
      ind = 25
    end
    if ind ~= self.lastInd then
      self.lastInd = ind
      local mesh = makeSquareBoardMesh(deck,ind)
      ch:setDeck(mesh)            
    end


    if self.state == CHARSTATE.WALK and self.moveStartAt < (t-CHARMOVE_SEEK_SEC) then
      self:setState( CHARSTATE.STAND )
    end
        
    -- debug move
    if not self.debugcnt then self.debugcnt = 0 end
    self.debugcnt = self.debugcnt + 1
    if self.debugcnt % 100 == 0 then
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

function pollChars(t)
  for i,v in ipairs(chars) do
    v:poll(t)
    print( "ch:", v:getLoc())
  end
  
end
