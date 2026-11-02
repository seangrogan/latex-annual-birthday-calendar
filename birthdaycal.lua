-- birthdaycal.lua : reads the CSV of dates and hands TeX one macro per month.
-- Loaded by birthdaycal.sty; you shouldn't need to edit this file.

local M = {}

local month_names = {
  jan = 1, feb = 2, mar = 3, apr = 4, may = 5, jun = 6,
  jul = 7, aug = 8, sep = 9, oct = 10, nov = 11, dec = 12,
}

-- "?" days sort after every real day and are shown as "?"
local UNKNOWN_DAY = 99

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local function warn(msg)
  texio.write_nl("term and log", "Package birthdaycal Warning: " .. msg)
  texio.write_nl("term and log", "")
end

-- Minimal CSV splitter: handles "quoted, fields" and "" escapes.
local function split_csv(line)
  local fields, i, n = {}, 1, #line
  while i <= n + 1 do
    local c = line:sub(i, i)
    if c == '"' then
      local buf, j = {}, i + 1
      while j <= n do
        local d = line:sub(j, j)
        if d == '"' then
          if line:sub(j + 1, j + 1) == '"' then buf[#buf + 1] = '"'; j = j + 2
          else j = j + 1; break end
        else buf[#buf + 1] = d; j = j + 1 end
      end
      fields[#fields + 1] = table.concat(buf)
      local k = line:find(",", j, true)
      if not k then break end
      i = k + 1
    else
      local k = line:find(",", i, true)
      if not k then fields[#fields + 1] = line:sub(i); break end
      fields[#fields + 1] = line:sub(i, k - 1)
      i = k + 1
    end
  end
  for k, v in ipairs(fields) do fields[k] = trim(v) end
  return fields
end

local function parse_month(s)
  local n = tonumber(s)
  if n then
    if n >= 1 and n <= 12 and n == math.floor(n) then return n end
    return nil
  end
  return month_names[s:lower():sub(1, 3)]
end

-- Escape the TeX specials people actually type in names.
-- Backslash and braces are left alone so you can use \textit{...} etc.
local function tex_escape(s)
  s = s:gsub("[&%%%$#_]", function(c) return "\\" .. c end)
  s = s:gsub("~", "\\textasciitilde{}")
  s = s:gsub("%^", "\\textasciicircum{}")
  return s
end

function M.load(filename)
  local path = kpse.find_file(filename) or filename
  local fh = io.open(path, "r")
  if not fh then
    tex.error("birthdaycal: cannot open data file '" .. filename .. "'")
    return
  end

  local months = {}
  for m = 1, 12 do months[m] = {} end
  local order, lineno, seen_data = 0, 0, false

  for raw in fh:lines() do
    lineno = lineno + 1
    local line = trim((raw:gsub("\r$", ""))):gsub("^\239\187\191", "") -- strip BOM
    if line ~= "" and not line:match("^#") then
      local f = split_csv(line)
      local m, d = parse_month(f[1] or ""), tonumber(f[2] or "")
      if (f[2] or "") == "?" then d = UNKNOWN_DAY end  -- unsure of the date
      if m and d and ((d >= 1 and d <= 31) or f[2] == "?") and (f[3] or "") ~= "" then
        local text = f[3]
        if f[4] and f[4] ~= "" then text = text .. " (" .. f[4] .. ")" end
        order = order + 1
        table.insert(months[m], { day = d, text = tex_escape(text), ord = order })
        seen_data = true
      elseif seen_data or m then
        warn("skipping line " .. lineno .. " of " .. filename .. ": " .. line)
      end
      -- (an unparseable line before any data is treated as the header row)
    end
  end
  fh:close()

  local out, words = {}, {}
  for m = 1, 12 do
    local list = months[m]
    table.sort(list, function(a, b)
      if a.day ~= b.day then return a.day < b.day end
      return a.ord < b.ord
    end)
    local body, k = {}, 1
    while k <= #list do
      local d, entries = list[k].day, {}
      while k <= #list and list[k].day == d do
        entries[#entries + 1] = "\\BDXentry{" .. list[k].text .. "}"
        for w in list[k].text:gmatch("%S+") do words[#words + 1] = "\\BDXword{" .. w .. "}" end
        k = k + 1
      end
      local label = (d == UNKNOWN_DAY) and "?" or tostring(d)
      body[#body + 1] = "\\BDXgroup{" .. label .. "}{" .. table.concat(entries) .. "}"
    end
    out[#out + 1] = "\\expandafter\\gdef\\csname BDXbody" .. m .. "\\endcsname{"
                    .. table.concat(body) .. "}"
  end
  out[#out + 1] = "\\gdef\\BDXallwords{" .. table.concat(words) .. "}"
  tex.sprint(table.concat(out))
end

return M
