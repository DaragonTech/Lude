local function p(...) print(...) end
local function section(n) print("== " .. n) end

section "numbers"
for _, v in ipairs{0, -0, 1, -1, 0.1, 1/3, 2^53, 2^63, 1e15, 1e14, 123456789012, 1e100, 1e-100, 5e-324, 1.7976931348623157e308, 3.14159265358979, 100, 2^31, -2^31, 0.5, 1.5, 2.5, 1e21, 12345678901234567890} do
  p(v, tostring(v), string.format("%g %.3f %e %.0f %5.1f %-8.2e| %+.14g %#g %G %E", v, v, v, v, v, v, v, v, v, v))
end
for _, s in ipairs{"10", "0x10", "  0x1F  ", "1e3", " 12 ", "12a", "", " ", "0x", "1.", ".5", "5e", "1e+", "- 1", "-1", "+2", "0X1p4", "1d2", "inf", "nan", "0x7fffffff", "0xffffffff", "0x100000000", "  -0x10"} do
  p(string.format("%q", s), tonumber(s))
end
for _, b in ipairs{2, 8, 10, 16, 36} do p(b, tonumber("101", b), tonumber("zz", b), tonumber("  11  ", b), tonumber("-11", b)) end
p(math.floor(3.7), math.floor(-3.7), math.ceil(3.2), math.ceil(-3.2), math.fmod(7, 3), math.fmod(-7, 3), math.fmod(7, -3), math.fmod(5.5, 2))
p(7 % 3, -7 % 3, 7 % -3, 5.5 % 2, -5.5 % 2, 2^10, 2^0.5, (-8)^(1/3) ~= (-8)^(1/3))
p(math.max(1, 5, 3), math.min(4, -2, 8), math.abs(-3), math.sqrt(16), math.huge > 1e308, -math.huge < -1e308)
p(math.modf(3.7), math.modf(-3.7), math.frexp(8), math.frexp(0.3), math.ldexp(0.5, 4))
p(string.format("%.14g %.14g %.14g %.14g %.14g", math.sin(1), math.cos(1), math.tan(1), math.asin(0.5), math.acos(0.5)))
p(string.format("%.14g %.14g %.14g %.14g", math.atan(1), math.atan2(1, 2), math.atan2(-1, -2), math.exp(1)))
p(string.format("%.14g %.14g %.14g %.14g", math.log(10), math.log10(1000), math.log10(2), math.sinh(0.5)))
p(string.format("%.14g %.14g %.14g %.14g", math.cosh(0.5), math.tanh(0.5), math.deg(1), math.rad(180)))
p(string.format("%.14g %.14g %.14g", 1.1^100, 10^-5, 3^40))
math.randomseed(42) local r = {} for i = 1, 5 do r[#r+1] = math.random(100) end p(table.concat(r, ","))
math.randomseed(7) p(math.random(3, 9), math.random(1000))

section "string.format"
p(string.format("[%5d][%-5d][%05d][%+d][% d][%x][%X][%#x][%o][%#o][%c]", 42, 42, 42, 42, 42, 255, 255, 255, 8, 8, 65))
p(string.format("[%d][%d][%d][%u][%x]", 3.9, -3.9, 2^31, -1, -1))
p(string.format("[%s][%10s][%-10s][%.2s][%5.1s]", "abc", "abc", "abc", "abc", "abc"))
p(string.format("%q", "a\nb\r\0c\"d\\e"))
p(string.format("%%[%3c]", 66), pcall(string.format, "%y", 1), pcall(string.format, "%-----d", 1))
p(pcall(string.format, "%123d", 1), pcall(string.format, "%d"))
p(string.format("%.20f", 0.1), string.format("%.0f", 2^63), string.format("%f", 1e20))

section "strings"
local s = "hello world from Lua"
p(s:len(), s:upper(), s:lower(), s:sub(3, 7), s:sub(-3), s:sub(0), s:sub(10, 5), s:rep(2, "-"))
p(s:byte(1, 3), string.char(72, 105), s:reverse(), ("x"):rep(0), ("ab"):rep(3))
p(s:find("wor"), s:find("o", 6), s:find("o", -5), s:find("%s"), s:find("l+"), s:find(".", 1, true), s:find(""))
p(s:match("(%w+) (%w+)"), s:match("()ll()"), s:match("^hello"), s:match("Lua$"), s:match("%u%l+"))
p(s:gsub("o", "0"), s:gsub("%w+", "<%0>", 2), s:gsub("(%w+)", "%1%1", 1), ("abc"):gsub("", "-"))
p(("hello"):gsub("l", {l = "L"}), ("hello"):gsub(".", function(c) return c:byte() end))
p(("THE (quick) fox"):find("%((%a+)%)"), ("f(a(b)c)d"):match("%b()"), ("THE (quick) fox"):match("%f[%a]%a+", 5))
p(("key = value"):match("^(%w+)%s*=%s*(%w+)$"), ("  trim  "):match("^%s*(.-)%s*$"), ("a,b,,c"):gsub(",", ";"))
local t = {} for w in ("one two  three"):gmatch("%a+") do t[#t+1] = w end p(table.concat(t, "|"))
for k, v in ("a=1, b=2, c=3"):gmatch("(%w+)=(%w+)") do io.write(k, v, " ") end print()
p(pcall(string.rep), pcall(("x").rep, "x", -1), ("abc"):byte(-1), ("abc"):byte(10))
p(string.format("%s", 1.5), #string.format("%099d", 7), ("%d"):format(3))
p(("x"):rep(3, nil), tostring(nil), tostring(true), ("abc" < "abd"), ("Z" < "a"), ("" < "a"), ("a\0b" < "a\0c"))

section "tables"
local tt = {5, 2, 8, 1, 9, 3}
table.sort(tt) p(table.concat(tt, " "))
table.sort(tt, function(a, b) return a > b end) p(table.concat(tt, " "))
local words = {"banana", "apple", "Cherry", "date"} table.sort(words) p(table.concat(words, " "))
table.insert(tt, 100) table.insert(tt, 1, 0) p(table.concat(tt, " "), table.remove(tt), table.remove(tt, 1), #tt)
p(table.concat({1, 2, 3}, ", ", 2, 3), table.concat({}, "x"), table.maxn({1, 2, nil, 4}), #{1, 2, nil, 4}, #{nil, nil, 3})
p(pcall(table.concat, {1, {}, 3}), select("#", unpack({1, 2, 3})), unpack({1, 2, 3}, 2))
local keys = {} for k in pairs({alpha = 1, beta = 2, gamma = 3, delta = 4, epsilon = 5, zeta = 6, eta = 7, theta = 8}) do keys[#keys+1] = k end p(table.concat(keys, " "))
local mixed = {10, 20, 30, x = 1, y = 2, [3.5] = "f", [true] = "b"} local ks = {} for k, v in pairs(mixed) do ks[#ks+1] = tostring(k) .. "=" .. tostring(v) end p(table.concat(ks, " "))
local big = {} for i = 1, 100 do big["k" .. i] = i end local cnt, sum = 0, 0 for k, v in pairs(big) do cnt = cnt + 1 sum = sum + v end p(cnt, sum, next({}))
local order = {} for k in pairs(big) do order[#order+1] = k if #order == 10 then break end end p(table.concat(order, " "))
p(pcall(table.sort, {3, 1, 2}, function(a, b) return true end))
p(table.getn({1, 2, 3}), pcall(table.setn, {}, 1))

section "metatables"
local V = {} V.__index = V
V.__add = function(a, b) return setmetatable({x = a.x + b.x}, V) end
V.__eq = function(a, b) return a.x == b.x end
V.__lt = function(a, b) return a.x < b.x end
V.__le = function(a, b) return a.x <= b.x end
V.__tostring = function(a) return "V(" .. a.x .. ")" end
V.__concat = function(a, b) return tostring(a) .. "&" .. tostring(b) end
V.__call = function(self, y) return self.x * y end
V.__len = function() return 42 end
V.__unm = function(a) return setmetatable({x = -a.x}, V) end
local a, b = setmetatable({x = 1}, V), setmetatable({x = 2}, V)
p(tostring(a + b), a == b, a < b, a <= b, a > b, a .. b, a(10), #a, tostring(-a))
local ro = setmetatable({}, {__newindex = function(t, k, v) rawset(t, k, v * 2) end, __index = function(t, k) return k .. "!" end})
ro.q = 21 p(ro.q, ro.zz, rawget(ro, "zz"))
p(getmetatable("").__index == string, pcall(setmetatable, setmetatable({}, {__metatable = 1}), {}))
local prox = newproxy(true) getmetatable(prox).__index = function(_, k) return k * 2 end p(prox[21], type(prox))

section "closures & varargs"
local function counter() local c = 0 return function() c = c + 1 return c end end
local c1, c2 = counter(), counter() c1() c1() p(c1(), c2())
local function va(...) return select("#", ...), ... end p(va(1, nil, 3, nil))
local function va2(...) local t = {...} return #t, arg end p(va2(1, 2))
local function oldva(...) return arg.n, arg[1] end p(oldva("x", "y"))
p(select(-1, 1, 2, 3), select(2, "a", "b", "c"), pcall(select, 0, 1))
local fs = {} for i = 1, 3 do fs[i] = function() return i end end p(fs[1](), fs[2](), fs[3]())
local function tail(n) if n == 0 then return "done" end return tail(n - 1) end p(tail(10000))
local function rec(n) if n == 0 then return 0 end return 1 + rec(n - 1) end p(pcall(rec, 150), select(2, pcall(rec, 1e6)):sub(1, 40))

section "errors"
p(pcall(error, "msg"), pcall(error, "msg", 0), pcall(error, "msg", 2), pcall(error, {1}), pcall(error))
p(pcall(function() local x = nil return x.y end))
p(pcall(function() return 1 + {} end))
p(pcall(function() return #nil end))
p(pcall(function() return {} < {} end))
p(pcall(function() return 1 < "2" end))
p(pcall(function() return ("x")() end))
p(pcall(function() undefinedfunc() end))
p(pcall(function() local t = {} t.a.b = 1 end))
p(pcall(function() return "a" .. {} end))
p(pcall(function() for i = 1, "x" do end end))
p(xpcall(function() error("deep") end, function(m) return "handled: " .. m end))
p(loadstring("x = = 1"))
p(loadstring("for"))
p(loadstring("x = 'unfinished"))
p(loadstring("x = [==[ unfinished"))
p(loadstring("return 1", "=mychunk"), loadstring("return ...")(7, 8))
p(pcall(loadstring("error('in chunk')", "@file.lua")))
p(pcall(loadstring(("x = 1 "):rep(10) .. "error('line?')")))
p(string.format("%s", select(2, pcall(string.sub))))
p(select(2, pcall(string.rep, "x", {})))
p(select(2, pcall(math.floor, "a")))
p(select(2, pcall(ipairs)))
p(select(2, pcall(setmetatable, 1, {})))
p(tostring(1e308 * 10) == tostring(math.huge), tostring(-(0/0)) == tostring(-(0/0)))

section "coroutines"
local co = coroutine.create(function(a, b)
  local c = coroutine.yield(a + b)
  local d, e = coroutine.yield(c * 2)
  return d + e
end)
p(coroutine.resume(co, 1, 2)) p(coroutine.status(co)) p(coroutine.resume(co, 10)) p(coroutine.resume(co, 3, 4)) p(coroutine.status(co), coroutine.resume(co))
local gen = coroutine.wrap(function() for i = 1, 3 do coroutine.yield(i) end end) p(gen(), gen(), gen())
p(coroutine.running(), pcall(coroutine.yield))
local co2 = coroutine.create(function() error("in co") end) p(coroutine.resume(co2))
local co3 = coroutine.wrap(function() error({code = 1}) end) p(pcall(co3))
p(select(2, pcall(coroutine.wrap(function() local t = nil; return t.x end))))

section "dump/load"
local f = function(x, y) local z = x * y return z + 1, "s" .. x end
local d = string.dump(f) p(#d, d:sub(1, 12):byte(1, 12))
local g = loadstring(d) p(g(6, 7))
p(loadstring(d:sub(1, 20)))
p(loadstring("\27Lua\82"))

section "gc & misc"
local wk = setmetatable({}, {__mode = "k"}) wk[{}] = 1 collectgarbage() local n = 0 for _ in pairs(wk) do n = n + 1 end p(n)
local wv = setmetatable({}, {__mode = "v"}) wv[1] = {} wv[2] = "str" collectgarbage() p(wv[1], wv[2])
p(type(collectgarbage("count")), collectgarbage("step", 0) ~= nil, collectgarbage("setpause", 150), collectgarbage("setpause", 200))
p(rawequal("a", "a"), rawequal({}, {}), rawlen, next({}, nil), type(_G), _G._G == _G, _VERSION)
p(getfenv(1) == _G, pcall(setfenv, 1, _G))
local env = {print = print} local fe = loadstring("y = 5 return y") setfenv(fe, env) p(fe(), env.y, y)
p(module ~= nil, package.path ~= nil, package.config)
p(string.format("%d %d", #arg, 0), arg[0])
