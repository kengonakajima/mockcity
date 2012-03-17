CHARANIMTYPE={
  STAND = 1,
  WALK = 2,
  DIE = 3
}



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
  
  function ch:setAnimType(t)
    self.animtype = t
    self.cnt = 0
  end

  ch:setAnimType( CHARANIMTYPE.STAND )

  local scl = 1.5
  ch:setScl(scl,scl,scl)

  ch.ofsX,ch.ofsY,ch.ofsZ = CELLUNITSZ/2, CELLUNITSZ/2-5, CELLUNITSZ/2 
  ch:setRot(-45,0,0)
  function ch:moveToGrid(x,y,z,state,nextms)
    local curx,cury,curz = self:getLoc()
    x,y,z = x*CELLUNITSZ+ self.ofsX, y*CELLUNITSZ+self.ofsY, z*CELLUNITSZ+self.ofsZ
    
    local seektime
    if not self.nextms then
      seektime = 1
    else
      seektime = (nextms - self.nextms) / 1000
    end
    self.nextms = nextms

    if seektime > 0 then
      if not self.prevX then
        self:setLoc(x-0.1,y,z) -- need 0.1 to avoid moai bug?
      else
        self:setLoc(self.prevX,self.prevY,self.prevZ)
      end
      local ix,iy,iz = int(x) % 32,int(y) % 32,int(z)%32
      if self.easeDriver then
        self.easeDriver:setLink(1,self,MOAITransform.ATTR_X_LOC,0)
        self.easeDriver:setLink(1,self,MOAITransform.ATTR_Y_LOC,0)
        self.easeDriver:setLink(1,self,MOAITransform.ATTR_Z_LOC,0)
      end        
      self.easeDriver = self:seekLoc(x,y,z, seektime, MOAIEaseType.LINEAR )
      self.moveStopAt = self.moveStartAt + seektime + 1
    end    
    self.moveStartAt = now()
--    print("start:",self.moveStartAt, "stop:", self.moveStopAt)
    
    if state == CHARSTATE.DIED then
      self:setAnimType(CHARANIMTYPE.DIE )
    else
      if x ~= self.prevX or z ~= self.prevZ then
        self:setAnimType(CHARANIMTYPE.WALK )
      end
    end

    if state == CHARSTATE.NORMAL then
      self:setColor(1,1,1)
    else
      self:setColor(1,0.5,0.5)
    end
    self.prevX, self.prevY, self.prevZ = x,y,z    
  end

    
  function ch:poll(t)
    if t > self.moveStartAt + CHAR_OUTDATE_SEC then
      self.outdated = true
      return
    end
    
    self.cnt = self.cnt + 1
    local ind
    if self.animtype == CHARANIMTYPE.STAND then
      ind = self.baseIndex
    elseif self.animtype == CHARANIMTYPE.WALK then
      ind = self.baseIndex + 1 + int( self.cnt / 10 ) % 2
    elseif self.animtype == CHARANIMTYPE.DIE then
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

    if self.animtype == CHARANIMTYPE.WALK and self.moveStopAt < t then
      self:setAnimType( CHARANIMTYPE.STAND )
    end
    
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