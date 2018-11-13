local hb = require'harf-base'
local hbdef = require'harf-load'
local processor = require("harf-node")
fonts.readers.buzz = function(spec)
  local hb_spec = {
    name = spec.specification,
    variants = {},
    features = {},
    options = {},
    file = spec.forcedname or spec.name,
    index = spec.sub and spec.sub - 1 or 0,
  }
  for k, v in pairs(spec.features.raw) do
    local code = k .. '='
    local num = tonumber(v)
             or ({['true'] = 1, ['false'] = 0})[string.lower(tostring(v))]
    if num then
      table.insert(hb_spec.features, hb.Feature.new(k .. '=' .. num))
    else
      hb_spec.options[k] = v
    end
  end
  return hbdef(hb_spec, spec.size)
end
luatexbase.add_to_callback('pre_linebreak_filter', processor, 'luahbtex.pre_linebreak_filter')
luatexbase.add_to_callback('hpack_filter', processor, 'luahbtex.hpack_filter')
