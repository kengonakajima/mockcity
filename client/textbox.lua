
--local charcodes = ' !\"#$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~あいうえおぁぃぅぇぉかきくけこがぎぐげごさしすせそざじずぜぞたちつてとだぢづでどなにぬねのはひふへほばびぶべぼぱぴぷぺぽまみむめもやゆよゃゅょらりるれろわをん、。アイウエオァィゥェォカキクケコガギグゲゴサシスセソザジズゼゾタチツテトダヂヅデドナニヌネノハヒフヘホバビブベボパピプペポマミムメモヤユヨャュョラリルレロワヲンーッっ　「」'
--   font:loadFromTTF( "images/ipag.ttf", charcodes, 12, 72 )
--font:loadFromTTF( "images/cinecaption227.ttf", charcodes, 16, 72 )


-- now moai three-dee  loadFromTTF is broken 

charcodes = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 .,:;!?()&/-'
font = nil
function ensureFont()
  if not font then 
    font = MOAIFont.new ()
    font:load ( './images/FontVerdana18.png', charcodes )
  end
end

-- convert screen coord to hud view coord
function makeTextBox( x,y, str )
  ensureFont()
  local t = MOAITextBox.new()
  t:setString(str)
  t:setFont(font)
  t:setTextSize(font:getScale())
  t:setRect(-SCRW/2,-SCRH/2,SCRW/2,SCRH/2)       -- TODO?
  t:setYFlip(true)
  -- yflipしてる場合、0,0にすると左上で、+xが右、 +yが上、なので
  t:setLoc( x +SCRW/2, y - SCRH/2 )
  t:setColor(1,1,1)
  t.resetLoc =
  function(self,x,y)
    self:setLoc( x+SCRW/2, y - SCRH/2 )
  end
  
  return t
end
