local hb = require("harf-base")

local disccode  = node.id("disc")
local gluecode  = node.id("glue")
local glyphcode = node.id("glyph")
local dircode   = node.id("dir")
local parcode   = node.id("local_par")
local spaceskip = 13

local function shape(head, current, run, nodes, codes)
  local offset = run.start
  local len = run.len
  local dir = run.dir
  local fontid = run.font
  local fontdata = fontid and font.fonts[fontid]

  if fontdata and fontdata.hb then
    local options = {}
    local buf = hb.Buffer.new()

    if dir == "TRT" then
      options.direction = hb.Direction.HB_DIRECTION_RTL
    else
      options.direction = hb.Direction.HB_DIRECTION_LTR
    end

    buf:add_codepoints(codes, offset - 1, len)
    if hb.shape(fontdata.hb.font, buf, options) then
      if dir == "TRT" then
        buf:reverse()
      end
      local glyphs = buf:get_glyph_infos_and_positions()
      for _, g in next, glyphs do
        -- Copy the node for the first character in the cluster, so that we
        -- inherit any of its properties.
        local n = node.copy(nodes[g.cluster + 1])
        local id = n.id

        head, current = node.insert_after(head, current, n)

        if id == glyphcode then
          n.char = hb.CH_GID_PREFIX + g.codepoint
          n.xoffset = g.x_offset
          n.yoffset = g.y_offset
          if n.width ~= g.x_advance then
            -- LuaTeX always uses the glyph width from the font, so we need to
            -- insert a kern node if the x advance is different.
            local kern = node.new("kern")
            kern.kern = g.x_advance - n.width
            head, current = node.insert_after(head, current, kern)
          end
          node.protect_glyph(n)
        elseif id == gluecode and n.subtype == spaceskip then
          if n.width ~= g.x_advance then
            n.width = g.x_advance
          end
        end
      end
    end
  else
    -- Not shaping, insert the original node list of of this run.
    for i = offset, offset + len do
      head, current = node.insert_after(head, current, nodes[i])
    end
  end

  return head, current
end

local function process(head, groupcode, size, packtype, direction)
  local fontid
  local has_hb
  for n in node.traverse_id(glyphcode, head) do
    local fontdata = font.fonts[n.font]
    has_hb = has_hb or fontdata.hb ~= nil
    fontid = fontid or n.font
  end

  -- Nothing to do; no glyphs or no HarfBuzz fonts.
  if not has_hb then
    return head
  end

  local dirstack = {}
  local dir = direction or "TLT"
  local nodes, codes = {}, {}
  local runs = { { font = fontid, dir = dir, start = 1, len = 0 } }
  local i = 1
  for n in node.traverse(head) do
    local id = n.id
    local char = 0xFFFC -- OBJECT REPLACEMENT CHARACTER
    local currdir = dir
    local currfont = fontid

    if id == glyphcode then
      currfont = n.font
      char = n.char
    elseif id == gluecode and n.subtype == spaceskip then
      char = 0x0020 -- SPACE
    elseif id == disccode then
      -- XXX actually handle this
      char = 0x00AD -- SOFT HYPHEN
    elseif id == dircode then
      if n.dir:sub(1, 1) == "+" then
        table.insert(dirstack, currdir)  -- push
        currdir = n.dir:sub(2)
      else
        currdir = table.remove(dirstack) -- pop
      end
    elseif id == parcode then
      currdir = n.dir
    end

    if currfont ~= fontid or currdir ~= dir then
      runs[#runs + 1] = { font = currfont, dir = currdir, start = i, len = 0 }
    end

    fontid = currfont
    dir = currdir
    runs[#runs].len = runs[#runs].len + 1

    nodes[#nodes + 1] = n
    codes[#codes + 1] = char
    i = i + 1
  end

  local newhead, current
  for _, run in next, runs do
    newhead, current = shape(newhead, current, run, nodes, codes)
  end

  return newhead or head
end

callback.register('pre_linebreak_filter', process)
callback.register('hpack_filter',         process)
