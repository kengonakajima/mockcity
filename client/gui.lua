-- init ui
buttons = {}

BUTTONSIZE = 32

function makeButton( name, x,y, deck, index, keycode, callback )
  local p = MOAIProp2D.new()
  p.name = name
  p:setDeck(deck)
  p:setIndex(1)
  p:setScl(BUTTONSIZE,BUTTONSIZE)
  p:setLoc(x,y)
  hudLayer:insertProp(p)
  p.flippable = true

  if index then
    local iconp = MOAIProp2D.new()
    iconp:setDeck(deck)
    iconp:setIndex(index)
    iconp:setScl(BUTTONSIZE,BUTTONSIZE)
    iconp:setLoc(x,y)
    hudLayer:insertProp(iconp)
    p.iconprop = iconp
  end
  
  p.hitRect = { x1 = x -BUTTONSIZE/2, y1 = y-BUTTONSIZE/2, x2=x+BUTTONSIZE/2, y2=y+BUTTONSIZE/2 }
  p.callback = callback
  p.keyCode = keycode  
  table.insert( buttons, p )
  return p
end

function processButtonMouseEvent(x,y,down)
  for i,v in ipairs(buttons) do
    if rectIncludes( v.hitRect, x,y ) then
      v:callback(x,y,down)
      return true
    end    
  end
  return false
end

function processButtonShortcutKey(keycode,down)
  for i,v in ipairs(buttons) do
    if v.keyCode == keycode then
      v:callback(down)
      return true
    end
  end
  return false
end

function selectButton(btn)
  local origSelected = btn.selected
  for i,v in ipairs(buttons) do
      v.selected = false
  end
  for i,v in ipairs(buttons) do
    if v == btn then
      v.selected = not origSelected
      break
    end
  end
  updateButtonBGs()
end

guiSelectedButton = nil
function updateButtonBGs()
  local prevsel = guiSelectedButton
  guiSelectedButton = nil
  for i,v in ipairs(buttons) do
    if v.flippable then
      if v.selected then
        v:setIndex(2)
        guiSelectedButton = v
      else
        v:setIndex(1)
      end
    end    
  end
  if prevsel ~= guiSelectedButton then
    if guiSelectModeCallback then
      guiSelectModeCallback(guiSelectedButton)
    end
  end  
end
