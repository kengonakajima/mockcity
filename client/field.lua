

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

