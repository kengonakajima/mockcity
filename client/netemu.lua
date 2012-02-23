-- luvit net emulator  by luasocket.

local socket = require("socket")

function net_connect(ip,port)
  print("net_connect called.", ip, port )
  local conn = {}
  return conn
end

-- self: needed by luvit
function net_createServer(self, ip,port,cb)
  print("net_createServer called.", ip, port, cb )
  local sv = {}
  return sv   
end

function net_new()
  local conn={}
  conn.state = "init"

  conn.callbacks = {}
  conn.on = function(self,ev,cb)
    --         print("netemu: on: ev:", ev, "cb:", cb )
    self.callbacks[ev] = cb
  end
  conn.emit = function(self,data,cb)
    --         print("write! ndata:", #data )
    self:write(data,cb)
  end
  conn.connect = function(self,ip,port)
    assert( self.state == "init"  )
    print("netemu: connect: ip:",ip, "port:", port, "socket:",socket  )
    --         for k,v in pairs(socket) do            print("SK:",k,v)         end
    local sock = socket.tcp()
    sock:settimeout(0)
    sock:connect(ip,port)
    self.sock = sock
    print( "netemu: newsocket:", self.sock)
    self.state = "connecting"
  end
  conn.read_start = function(self)
    print("netemu: read_start")
  end

  conn.write = function(self,data,cb)
    if self.closed then
      print("write: socket closed!")
      return 0
    end
    if cb then error("netemu: write callback is not implemented" ) end
    --         print("netemu: write data:", data, " cb:", cb )
    return self.sock:send(data)
  end

  conn.close = function(self)
    self.closed = true
    return self.sock:close()
  end
  
  conn.poll = function(self)
    if self.closed then error_("socket closed") end    
    if not self.counter then self.counter = 1 end

    self.counter = self.counter + 1
    local sendt,recvt = {},{}
    table.insert(sendt,self.sock)
    table.insert(recvt,self.sock)         
    local rs,ws,e = socket.select(recvt,sendt,0)

    --         if ( self.counter % 50 ) == 0  then
    --            print("netemu: poll. r:",#rs,"w:",#ws, "e:",e )
    --         end

    if ws[1] == self.sock then
      if self.state == "connecting" then
        print("netemu: connected!")
        if self.callbacks["complete"] then
          self.callbacks["complete"]()
        end
        self.state = "connected"
      end
    end
    if rs[1] == self.sock then
      if self.state == "connected" then
        local res, msg, partial = self.sock:receive(1024*1024*16) -- try to get everything
        if not res and msg == "closed" then
          self.state = "closed"
          if self.callbacks["end"] then
            self.callbacks["end"]()
          end                  
        else
          local got
          if partial then got = partial end
          if res then got = res end
          if got then

            --                     print("data recv! res:", got, "nr:", #got )
            if self.callbacks["data"] then
              self.callbacks["data"](got)
            end
          end
        end               
      end
    end
  end
  
  return conn
end

netemu = {
  new = net_new,
  connect = net_connect,
  createServer = net_createServer
}

return netemu