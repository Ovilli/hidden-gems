-- json.lua - tiny JSON parser (objects, arrays, strings, numbers, true/false/null)
-- Public domain / MIT-like: use at will for contest bots.

local M = {}

local sub, byte = string.sub, string.byte
local floor = math.floor

local function skip_ws(s, i)
  local c = byte(s, i)
  while c == 32 or c == 9 or c == 10 or c == 13 do
    i = i + 1
    c = byte(s, i)
  end
  return i
end

local function parse_value(s, i)
  i = skip_ws(s, i)
  local c = byte(s, i)
  if not c then error("unexpected end at pos "..i) end
  if c == 123 then -- {
    local obj = {}
    i = i + 1
    i = skip_ws(s, i)
    if byte(s, i) == 125 then return obj, i + 1 end -- }
    while true do
      local key; key, i = parse_string(s, i)
      i = skip_ws(s, i)
      if byte(s, i) ~= 58 then error("expected ':' at pos "..i) end
      i = i + 1
      local val; val, i = parse_value(s, i)
      obj[key] = val
      i = skip_ws(s, i)
      local ch = byte(s, i)
      if ch == 125 then return obj, i + 1 end -- }
      if ch ~= 44 then error("expected ',' at pos "..i) end
      i = i + 1
    end
  elseif c == 91 then -- [
    local arr = {}
    i = i + 1
    i = skip_ws(s, i)
    if byte(s, i) == 93 then return arr, i + 1 end -- ]
    local k = 1
    while true do
      local v; v, i = parse_value(s, i)
      arr[k] = v; k = k + 1
      i = skip_ws(s, i)
      local ch = byte(s, i)
      if ch == 93 then return arr, i + 1 end -- ]
      if ch ~= 44 then error("expected ',' at pos "..i) end
      i = i + 1
    end
  elseif c == 34 then -- "
    return parse_string(s, i)
  elseif c == 116 then -- true
    if sub(s, i, i+3) ~= "true" then error("bad literal at "..i) end
    return true, i + 4
  elseif c == 102 then -- false
    if sub(s, i, i+4) ~= "false" then error("bad literal at "..i) end
    return false, i + 5
  elseif c == 110 then -- null
    if sub(s, i, i+3) ~= "null" then error("bad literal at "..i) end
    return nil, i + 4
  else
    return parse_number(s, i)
  end
end

function parse_string(s, i)
  if byte(s, i) ~= 34 then error("expected '\"' at pos "..i) end
  i = i + 1
  local out = {}
  local start = i
  while true do
    local c = byte(s, i)
    if not c then error("unterminated string at "..i) end
    if c == 34 then -- "
      table.insert(out, sub(s, start, i - 1))
      return table.concat(out), i + 1
    elseif c == 92 then -- \
      table.insert(out, sub(s, start, i - 1))
      local e = byte(s, i + 1)
      if not e then error("bad escape at end") end
      if e == 34 then table.insert(out, "\"")
      elseif e == 92 then table.insert(out, "\\")
      elseif e == 47 then table.insert(out, "/")
      elseif e == 98 then table.insert(out, "\b")
      elseif e == 102 then table.insert(out, "\f")
      elseif e == 110 then table.insert(out, "\n")
      elseif e == 114 then table.insert(out, "\r")
      elseif e == 116 then table.insert(out, "\t")
      elseif e == 117 then
        local hex = sub(s, i+2, i+5)
        if #hex < 4 then error("bad \\u escape at "..i) end
        local cp = tonumber(hex, 16)
        -- Encode BMP codepoint to UTF-8
        if cp < 0x80 then
          table.insert(out, string.char(cp))
        elseif cp < 0x800 then
          table.insert(out, string.char(0xC0 + floor(cp/0x40), 0x80 + (cp % 0x40)))
        else
          table.insert(out, string.char(0xE0 + floor(cp/0x100),
                                        0x80 + (floor(cp/0x40) % 0x40),
                                        0x80 + (cp % 0x40)))
        end
        i = i + 4
      else
        error("bad escape \\"..string.char(e).." at pos "..(i+1))
      end
      i = i + 2
      start = i
    else
      i = i + 1
    end
  end
end

function parse_number(s, i)
  local j = i
  local c = byte(s, j)
  if c == 45 then j = j + 1 end
  while byte(s, j) and byte(s, j) >= 48 and byte(s, j) <= 57 do j = j + 1 end
  if byte(s, j) == 46 then
    j = j + 1
    while byte(s, j) and byte(s, j) >= 48 and byte(s, j) <= 57 do j = j + 1 end
  end
  local e = byte(s, j)
  if e == 69 or e == 101 then
    j = j + 1
    local sgn = byte(s, j)
    if sgn == 43 or sgn == 45 then j = j + 1 end
    while byte(s, j) and byte(s, j) >= 48 and byte(s, j) <= 57 do j = j + 1 end
  end
  local num = sub(s, i, j - 1)
  local n = tonumber(num)
  if n == nil then error("bad number at "..i) end
  return n, j
end

-- Public API
function M.decode(s)
  local v, i = parse_value(s, 1)
  i = skip_ws(s, i)
  if i <= #s then error("extra data after JSON at pos "..i) end
  return v
end

return M
