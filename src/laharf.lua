local hbdef = require'harf-load'
local processor = require("harf-node")
fonts.readers.buzz = function(spec)
  return hbdef(spec.specification, spec.size)
end
luatexbase.add_to_callback('pre_linebreak_filter', processor, 'luahbtex.pre_linebreak_filter')
luatexbase.add_to_callback('hpack_filter', processor, 'luahbtex.hpack_filter')
