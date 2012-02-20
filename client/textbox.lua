
-- font
local charcodes = ' !\"#$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~あいうえおぁぃぅぇぉかきくけこがぎぐげごさしすせそざじずぜぞたちつてとだぢづでどなにぬねのはひふへほばびぶべぼぱぴぷぺぽまみむめもやゆよゃゅょらりるれろわをん、。アイウエオァィゥェォカキクケコガギグゲゴサシスセソザジズゼゾタチツテトダヂヅデドナニヌネノハヒフヘホバビブベボパピプペポマミムメモヤユヨャュョラリルレロワヲンーッっ　「」'

font = MOAIFont.new()
--   font:loadFromTTF( "images/ipag.ttf", charcodes, 12, 72 )
font:loadFromTTF( "images/cinecaption227.ttf", charcodes, 16, 72 )


-- convert screen coord to hud view coord
function makeTextBox( x,y, str )
   local t = MOAITextBox.new()
   t:setString(str)
   t:setFont(font)
   t:setTextSize(font:getScale())
   t:setRect(-SCRW/2,-SCRH/2,SCRW/2,SCRH/2)       -- TODO?
   t:setYFlip(true)
   -- yflipしてる場合、0,0にすると左上で、+xが右、 +yが上、なので
   t:setLoc( x +SCRW/2, y - SCRH/2 )
   t.resetLoc =
      function(self,x,y)
         self:setLoc( x+SCRW/2, y - SCRH/2 )
      end
   
   return t
end
