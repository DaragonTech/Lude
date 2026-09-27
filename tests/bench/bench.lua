-- CPU benchmarks for comparing lua5.1.dll builds.  usage: lua bench.lua [scale]
local scale = tonumber(arg and arg[1]) or 1
local clock = os.clock
local results = {}
local function bench(name, f, n)
  n = math.floor(n * scale)
  collectgarbage() collectgarbage()
  local t0 = clock()
  f(n)
  local t = clock() - t0
  results[#results+1] = name
  io.write(string.format("%-14s %8.3f\n", name, t))
end

bench("fib", function(n)
  local function fib(k) if k < 2 then return k end return fib(k-1) + fib(k-2) end
  for i = 1, n do fib(27) end
end, 30)

bench("loop_arith", function(n)
  local s = 0
  for i = 1, n do s = s + i * 2 - i / 3 + i % 7 end
  return s
end, 20000000)

bench("float_math", function(n)
  local sin, cos, sqrt, floor = math.sin, math.cos, math.sqrt, math.floor
  local s = 0
  for i = 1, n do s = s + sin(i) * cos(i) + sqrt(i) + floor(i / 3) end
  return s
end, 3000000)

bench("pow_fmod", function(n)
  local s = 0
  for i = 1, n do s = s + (i % 13) ^ 1.5 + math.fmod(i, 7.5) end
  return s
end, 3000000)

bench("table_array", function(n)
  for r = 1, n do
    local t = {}
    for i = 1, 100000 do t[i] = i end
    local s = 0
    for i = 1, #t do s = s + t[i] end
  end
end, 30)

bench("table_hash", function(n)
  for r = 1, n do
    local t = {}
    for i = 1, 50000 do t["k" .. i] = i end
    local s = 0
    for k, v in pairs(t) do s = s + v end
  end
end, 10)

bench("table_sort", function(n)
  for r = 1, n do
    local t = {}
    math.randomseed(42)
    for i = 1, 100000 do t[i] = math.random(1000000) end
    table.sort(t)
    table.sort(t, function(a, b) return a > b end)
  end
end, 3)

bench("str_concat", function(n)
  for r = 1, n do
    local parts = {}
    for i = 1, 100000 do parts[#parts+1] = tostring(i) end
    local s = table.concat(parts, ",")
    local x = ""
    for i = 1, 3000 do x = x .. "ab" end
  end
end, 10)

bench("str_format", function(n)
  local fmt = string.format
  for i = 1, n do
    local s = fmt("%d %5.2f %s %x %g", i, i / 7, "abc", i, i * 1.5)
  end
end, 500000)

bench("tostring_num", function(n)
  local s = 0
  for i = 1, n do s = s + #tostring(i * 0.37) + tonumber("12.5e3") end
  return s
end, 500000)

bench("str_patterns", function(n)
  local text = string.rep("The quick brown fox jumps over the lazy dog 12345. ", 200)
  for i = 1, n do
    local c = 0
    for w in text:gmatch("%a+") do c = c + 1 end
    local r = text:gsub("(%w+) (%w+)", "%2 %1")
    local a = text:find("lazy dog 9", 1, true)
    local b = text:match("(%d+)%.%s*$")
  end
end, 100)

bench("str_ops", function(n)
  local s = "Hello, World! "
  for i = 1, n do
    local u = s:upper() .. s:lower() .. s:rep(3) .. s:sub(2, 8) .. s:reverse()
    local b = s:byte(1, -1)
    local ch = string.char(72, 105)
  end
end, 500000)

bench("closures", function(n)
  local s = 0
  for i = 1, n do
    local f = function(x) return x + i end
    s = s + f(1)
  end
  return s
end, 3000000)

bench("oop_methods", function(n)
  local Point = {}
  Point.__index = Point
  function Point.new(x, y) return setmetatable({x = x, y = y}, Point) end
  function Point:add(o) return Point.new(self.x + o.x, self.y + o.y) end
  function Point:len2() return self.x * self.x + self.y * self.y end
  local p = Point.new(0, 0)
  local d = Point.new(1, 2)
  local s = 0
  for i = 1, n do p = p:add(d); s = s + p:len2() % 3 end
  return s
end, 2000000)

bench("metamethods", function(n)
  local mt = {__add = function(a, b) return a.v + b.v end,
              __index = function(t, k) return k end,
              __len = function() return 3 end}
  local a = setmetatable({v = 1}, mt)
  local b = setmetatable({v = 2}, mt)
  local s = 0
  for i = 1, n do s = s + (a + b) + a[i] + #a end
  return s
end, 2000000)

bench("coroutines", function(n)
  local co = coroutine.wrap(function()
    local i = 0
    while true do i = i + 1; coroutine.yield(i) end
  end)
  local s = 0
  for i = 1, n do s = s + co() end
  return s
end, 1000000)

bench("pcall_error", function(n)
  local s = 0
  for i = 1, n do
    local ok, e = pcall(error, "x")
    if not ok then s = s + 1 end
    local ok2 = pcall(function() return i end)
  end
  return s
end, 300000)

bench("gc_alloc", function(n)
  for r = 1, n do
    local t
    for i = 1, 200000 do t = {i, i + 1, {x = i}} end
  end
end, 5)

bench("compile", function(n)
  local src = [[
    local t = {}
    for i = 1, 100 do
      t[i] = function(a, b) if a > b then return a - b else return b + a * 2 end end
    end
    return t
  ]]
  for i = 1, n do assert(loadstring(src))() end
end, 20000)

bench("dump_load", function(n)
  local f = function(a) local x = {} for i = 1, a do x[i] = i * 2 end return x end
  for i = 1, n do
    local s = string.dump(f)
    assert(loadstring(s))
  end
end, 100000)
