-- clean-docx-v2.lua
-- Cleanup filter for DOCX -> Markdown conversions with Pandoc.
--
-- Intended output: GFM / MkDocs / Obsidian / Zensical friendly Markdown.
--
-- What it does:
--   1. Removes width/height attributes inherited from Word images.
--   2. Removes bogus image alt text containing Windows temp/cache paths.
--   3. Cleans Word-generated TOC links such as:
--        [1. Abstract \[3\](#abstract)](#abstract)
--      into:
--        [1. Abstract](#abstract)
--   4. Converts hard line breaks from Word into normal spaces so Pandoc
--      does not emit "\" at the end of lines.
--   5. Uses the first top-level paragraph whose content is entirely bold
--      as the document H1 title.
--   6. Shifts every heading imported from Word down one level:
--        H1 -> H2
--        H2 -> H3
--        H3 -> H4
--        H4 -> H5
--        H5 -> H6
--        H6 -> H6   (Markdown has no H7)

local stringify = pandoc.utils.stringify

local function looks_like_word_garbage(text)
  if not text or text == "" then return false end
  local s = text:lower()

  local suspicious = {
    "appdata",
    "inetcache",
    "content%.mso",
    "%.tmp$",
    "^file:",
  }

  for _, pattern in ipairs(suspicious) do
    if s:match(pattern) then return true end
  end

  if s:match("^%a:[/\\]") then return true end
  if s:match("^\\\\") then return true end

  return false
end

local function is_numeric_page_label(inlines)
  local txt = stringify(inlines or {})
  txt = txt:gsub("^%s+", ""):gsub("%s+$", "")
  return txt:match("^%d+$") ~= nil
end

local function trim_trailing_breaks(inlines)
  while #inlines > 0 do
    local last = inlines[#inlines]

    if last.t == "Space" or last.t == "SoftBreak" or last.t == "LineBreak" then
      table.remove(inlines)
    else
      break
    end
  end

  return inlines
end

local function escape_lua_pattern(s)
  return (s:gsub("([^%w])", "%%%1"))
end

local function is_escaped_page_link_text(text, target)
  if not text or text == "" then return false end

  local normalized = text:gsub("\\", "")
  normalized = normalized:gsub("^%s+", ""):gsub("%s+$", "")

  local target_pattern = escape_lua_pattern(target)
  return normalized:match("^%[%d+%]%(" .. target_pattern .. "%)$") ~= nil
end

local function clean_toc_tail(inlines, target)
  trim_trailing_breaks(inlines)

  if #inlines == 0 then return inlines end

  local last = inlines[#inlines]

  if last.t == "Link" then
    local inner_target = last.target or ""

    if inner_target == target and is_numeric_page_label(last.content) then
      table.remove(inlines)
      trim_trailing_breaks(inlines)
      return inlines
    end
  end

  if last.t == "Span" and last.content then
    local before = #last.content
    clean_toc_tail(last.content, target)

    if #last.content == 0 then
      table.remove(inlines)
      trim_trailing_breaks(inlines)
      return inlines
    elseif #last.content < before then
      trim_trailing_breaks(inlines)
      return inlines
    end
  end

  if last.t == "Str" and is_escaped_page_link_text(last.text, target) then
    table.remove(inlines)
    trim_trailing_breaks(inlines)
    return inlines
  end

  return inlines
end

local function bold_title_from_para(para)
  if not para or para.t ~= "Para" then return nil end

  local meaningful = {}

  for _, inline in ipairs(para.content) do
    if inline.t == "Space" or inline.t == "SoftBreak" or inline.t == "LineBreak" then
      -- Ignore whitespace.
    elseif inline.t == "Span" and stringify(inline.content):match("^%s*$") then
      -- Ignore empty Word-generated spans.
    else
      table.insert(meaningful, inline)
    end
  end

  if #meaningful ~= 1 then return nil end

  local only = meaningful[1]

  -- Normal case: **Deliverable ...**
  if only.t == "Strong" then
    return only.content
  end

  -- Some DOCX files wrap the bold title in a Span.
  if only.t == "Span" and only.content then
    local inner = {}

    for _, inline in ipairs(only.content) do
      if inline.t ~= "Space" and inline.t ~= "SoftBreak" and inline.t ~= "LineBreak" then
        table.insert(inner, inline)
      end
    end

    if #inner == 1 and inner[1].t == "Strong" then
      return inner[1].content
    end
  end

  return nil
end

local function clean_image(img)
  if img.attributes then
    img.attributes["width"] = nil
    img.attributes["height"] = nil
  end

  local alt = stringify(img.caption)

  if looks_like_word_garbage(alt) then
    img.caption = pandoc.Inlines({})
  end

  return img
end

local function flatten_linebreak(_)
  return pandoc.Space()
end

local function clean_link(link)
  local target = link.target or ""

  if target:sub(1, 1) ~= "#" then
    return link
  end

  if not link.content or #link.content == 0 then
    return link
  end

  clean_toc_tail(link.content, target)
  return link
end

local function normalize_document_structure(doc)
  -- First shift all headings imported from the DOCX.
  -- This happens before creating the new title, so the generated H1 remains H1.
  doc = doc:walk({
    Header = function(header)
      if header.level < 6 then
        header.level = header.level + 1
      end
      return header
    end
  })

  -- Convert the first entirely-bold top-level paragraph to H1.
  for i, block in ipairs(doc.blocks) do
    local title = bold_title_from_para(block)

    if title and stringify(title):match("%S") then
      doc.blocks[i] = pandoc.Header(1, title)
      break
    end
  end

  return doc
end

return {
  {
    Image = clean_image,
    LineBreak = flatten_linebreak,
    Link = clean_link,
  },
  {
    Pandoc = normalize_document_structure,
  }
}
