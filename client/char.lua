CHARSTATE={
  STAND = 1,
  WALK = 2,
  DIE = 3
}


CHARMOVE_SEEK_SEC = 0.8
CHAR_OUTDATE_SEC = 3

charIDs={}
chars={}
function makeChar(id,x,y,z,deck, baseIndex )
  assert(baseIndex)

    
  local ch = MOAIProp.new()

  ch.id = id
  ch.baseIndex = baseIndex
  ch.moveStartAt = 0

  ch.meshCache = {}
  
  function ch:setState(st)
    self.state = st
    self.cnt = 0
  end

  ch:setState( CHARSTATE.STAND )

  local scl = 1.5
  ch:setScl(scl,scl,scl)

  ch.ofsX,ch.ofsY,ch.ofsZ = CELLUNITSZ/2, CELLUNITSZ/2-5, CELLUNITSZ/2 
  ch:setRot(-45,0,0)
  function ch:moveToGrid(x,y,z)
    local curx,cury,curz = self:getLoc()
    x,y,z = x*CELLUNITSZ+ self.ofsX, y*CELLUNITSZ+self.ofsY, z*CELLUNITSZ+self.ofsZ
--    print("moveToGrid: id:",self.id, int(x),int(y),int(z), int(curx),int(cury),int(curz)    )
    if not self.prevX then
      self:setLoc(x-0.1,y,z) -- need 0.1 to avoid moai bug?
    else
      self:setLoc(self.prevX,self.prevY,self.prevZ)
    end
    self:seekLoc(x,y,z, CHARMOVE_SEEK_SEC, MOAIEaseType.LINEAR )

    self.moveStartAt = now()
    self.prevX, self.prevY, self.prevZ = x,y,z    
    self:setState(CHARSTATE.WALK)
  end

    
  function ch:poll(t)
    if t > self.moveStartAt + CHAR_OUTDATE_SEC then
      self.outdated = true
      return
    end
    
    self.cnt = self.cnt + 1
    local ind

    if self.state == CHARSTATE.STAND then
      ind = self.baseIndex
    elseif self.state == CHARSTATE.WALK then
      ind = self.baseIndex + 1 + int( self.cnt / 10 ) % 2
    elseif self.state == CHARSTATE.DIE then
      ind = self.baseIndex + 24
    end

    if ind ~= self.lastInd then
      self.lastInd = ind
      local mesh = self.meshCache[ind]
      if not mesh then
        mesh = makeSquareBoardMesh(deck,ind)
        self.meshCache[ind] = mesh
      end      
      ch:setDeck(mesh)            
    end

    if self.state == CHARSTATE.WALK and self.moveStartAt < (t-CHARMOVE_SEEK_SEC) then
      self:setState( CHARSTATE.STAND )
    end
        
    -- debug move
--     if self.baseIndex == 1 then
--       if not self.debugcnt then self.debugcnt = 0 end
--       self.debugcnt = self.debugcnt + 1
--       if self.debugcnt % 100 == 0 then
--         local nx,nz = self.gridX, self.gridZ
--         if birandom() then
--           nx,nz = self.gridX + choose({-1,1}), self.gridZ
--         else
--           nx,nz = self.gridX, self.gridZ + choose({-1,1})
--         end
--         self:moveToGrid(nx,nz)
--       end
--     end
    
  end
  
  ch:moveToGrid(x,y,z)

  charLayer:insertProp(ch)
  table.insert(chars,ch)
  charIDs[id] = ch
  return ch
end

function pollChars(t)
  local toRemove={}
  for i,v in ipairs(chars) do
    v:poll(t)
    if v.outdated then
      print("outdated:", v.id, v.moveStartAt,t )
      charLayer:removeProp(v)
      charIDs[v.id] = nil
      table.remove(chars,i)
      break -- TODO: can remove only 1 char within a loop
    end    
  end
end