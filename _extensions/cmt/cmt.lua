local id_counter = 0

local function get_param(kwargs, args, name, pos, default)
  if kwargs[name] then
    local val = pandoc.utils.stringify(kwargs[name])
    if val ~= "" then return val end
  end
  if args[pos] then
    local val = pandoc.utils.stringify(args[pos])
    if val ~= "" then return val end
  end
  return default
end

return {
  ["cmt"] = function(args, kwargs, meta)
    local comment        = get_param(kwargs, args, "comment",   1, "")
    local highlight      = get_param(kwargs, args, "highlight", 2, "")
    local meta_author    = meta["cmt-author"] and pandoc.utils.stringify(meta["cmt-author"]) or "Author"
    local author         = get_param(kwargs, args, "author",    3, meta_author)
    local date      = os.date("!%Y-%m-%dT%H:%M:%SZ")

    local id = tostring(id_counter)
    id_counter = id_counter + 1

    if quarto.doc.is_format("docx") then
      local md = string.format(
        '[%s]{.comment-start id="%s" author="%s" date="%s"} %s []{.comment-end id="%s"}',
        comment, id, author, date, highlight, id
      )
      local parsed = pandoc.read(md, "markdown")
      if parsed.blocks and #parsed.blocks > 0 then
        return parsed.blocks[1].content
      end
      return pandoc.Inlines({})
    else
      local result = {}
      if highlight ~= "" then
        table.insert(result, pandoc.Emph({ pandoc.Str(highlight) }))
        table.insert(result, pandoc.Space())
      end
      local label = string.format("[Comment id %s by %s at %s: %s]", id, author, date, comment)
      table.insert(result, pandoc.Strong({ pandoc.Str(label) }))
      return pandoc.Inlines(result)
    end
  end
}
