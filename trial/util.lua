-- util

function b2i(b)
   if b then return 1 else return 0 end
end

currentElapsedTime = 0
function now()
   return currentElapsedTime
end
function addCurrentElapsedTime(dt)
   currentElapsedTime = currentElapsedTime + dt
end


function birandom()
   if math.random() < 0.5 then
      return true
   else
      return false
   end
end

-- 近い方の値を返す
function nearer(from,a,b)
   local da = math.abs(a-from)
   local db = math.abs(b-from)
   if da < db then
      return a
   else
      return b
   end   
end


   
function propDistance(p0,p1)
   local x0,y0 = p0:getLoc()
   local x1,y1 = p1:getLoc()
   return len(x0,y0,x1,y1)
end


function len(x0,y0,x1,y1)
   return math.sqrt( (x0-x1)*(x0-x1) + (y0-y1)*(y0-y1) )
end
function normalize(x,y,l)
   ll = len(0,0,x,y)
   return x / ll * l, y / ll * l
end

function int(x)
   if not x then return 0 else return math.floor(x) end
   return math.floor(x)
end
function int2(x,y)
   return int(x), int(y)
end

function expandVec(fromx,fromy,tox,toy,tolen)
   local dx,dy = (tox-fromx),(toy-fromy)
   local nx,ny = normalize(dx,dy,tolen)
   return fromx + nx, fromy + ny
   
end

function plusMinus(x)
   if math.random()<0.5 then
      return x
   else
      return x *-1
   end   
end
function range(a,b)
   return a + ( b-a ) * math.random()
end

function avg(a,b)
   return (a+b)/2
end


function sign(x)
   if x>0 then return 1 elseif x < 0 then return -1 else return 0 end
end

   
function printf ( ... )
   return io.stdout:write ( string.format ( ... ))
end

function randomize(x,y,r)
   return x + ( -r  + math.random() * (r*2) ), y + ( -r  + math.random() * (r*2) )
end

function min(a,b)
   if not a and not b then return 0 end
   if not a then return b end
   if not b then return a end
   if a < b then return a else return b end
end
function max(a,b)
   if not a and not b then return 0 end
   if not a then return b end
   if not b then return a end   
   if a > b then return a else return b end
end

function choose(ary)
   return ary[ int(  math.random() * #ary ) + 1]
end

-- poly: aabbが前提 {x,y,x,y,x,y,x,y}
function calcArea( poly )
   x0,y0,x1,y1,x2,y2,x3,y3 = poly[1],poly[2],poly[3],poly[4],poly[5],poly[6],poly[7],poly[8]
   leftx = min( min(x0,x1), min(x2,x3) )
   rightx = max( max(x0,x1), max(x2,x3) )
   bottomy = min( min(y0,y1), min(y2,y3) )
   topy = max( max(y0,y1), max(y2,y3) )
   return ( rightx - leftx ) * ( topy - bottomy )
end
function swapPropPrio(ap,bp)
   ai = ap:getPriority()
   bi = bp:getPriority()
   ap:setPriority(bi)
   bp:setPriority(ai)
end

function split(str, delim)
    if string.find(str, delim) == nil then
        return { str }
    end

    local result = {}
    local pat = "(.-)" .. delim .. "()"
    local lastPos
    for part, pos in string.gfind(str, pat) do
        table.insert(result, part)
        lastPos = pos
    end
    table.insert(result, string.sub(str, lastPos))
    return result
end

function readCSV(file)
   local fp = assert(io.open (file))
   local csv = {} 
   for line in fp:lines() do
      if not line then break end
      local row = split(line,",")
      csv[#csv+1] = row
   end
   fp:close()
   return csv
end
function writeCSV(file,tab)
   local fp = assert(io.open(file,"w"))
   for i,row in ipairs(tab) do
      for i,value in ipairs(row) do
         fp:write(tostring(value)..",")
      end
      fp:write "\n"
   end
   fp:close()
end
function table.copy(t)
  local t2 = {}
  for k,v in pairs(t) do
    t2[k] = v
  end
  return t2
end

function existfile(fn)
   local f = io.open(fn)
   if not f then
      return false
   else
      f:close()
      return true
   end
end

function reverseDir(d)
   if d == DIR.UP then
      return DIR.DOWN
   elseif d == DIR.DOWN then
      return DIR.UP
   elseif d == DIR.LEFT then
      return DIR.RIGHT
   elseif d == DIR.RIGHT then
      return DIR.LEFT
   else
      assert(false)
   end   
end


function scanCircle(cx,cy,dia,step,fn)
   local rdia = int(dia*1.41)
   for x=cx-rdia,cx+rdia,step do
      for y=cy-rdia,cy+rdia,step do
         if len( cx,cy,x,y) < dia then
            fn(x,y)
         end         
      end
   end
end

function scanRect(x0,y0,x1,y1,fn)
   for y=y0,y1 do
      for x=x0,x1 do
         fn(x,y)
      end
   end
end
