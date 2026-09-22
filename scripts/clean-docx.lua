-- clean-docx.lua
-- Cleanup filter for DOCX -> Markdown conversions with Pandoc.
--
-- Intended output: GFM / MkDocs / Obsidian friendly Markdown.
--
-- What it does:
--   1. Removes width/height attributes inherited from Word images.
--   2. Removes bogus image alt text containing Windows temp/cache paths.
--   3. Cleans Word-generated TOC links such as:
--        [1. Abstract \[3\](#abstract)](#abstract)
--      or equivalent nested-link AST forms, into:
--        [1. Abstract](#abstract)
--   4. Converts hard line breaks from Word into normal spaces so Pandoc
--      does not emit "\" at the end of lines.
--
-- Recommended usage on Windows:
--
--   pandoc input.docx ^
--     -t gfm ^
--     --extract-media=. ^
--     --wrap=none ^
--     --lua-filter=clean-docx.lua ^
--     -o output.md

local stringify = pandoc.utils.stringify

-- ------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------

local function looks_like_word_garbage(text)
  if not text or text == "" then
    return false
  end

  local s = text:lower()

  local suspicious = {
    "appdata",
    "inetcache",
    "content%.mso",
    "%.tmp$",
    "^file:",
  }

  for _, pattern in ipairs(suspicious) do
    if s:match(pattern) then
      return true
    end
  end

  -- Windows absolute path, e.g. C:\Users\name\...
  if s:match("^%a:[/\\]") then
    return true
  end

  -- UNC path, e.g. \\server\share\...
  if s:match("^\\\\") then
    return true
  end

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
  if not text or text == "" then
    return false
  end

  -- Pandoc may serialize the inner Word TOC link as literal escaped Markdown:
  --   \[3\](#abstract)
  -- Remove backslashes before testing.
  local normalized = text:gsub("\\", "")
  normalized = normalized:gsub("^%s+", ""):gsub("%s+$", "")

  local target_pattern = escape_lua_pattern(target)

  return normalized:match("^%[%d+%]%(" .. target_pattern .. "%)$") ~= nil
end


local function clean_toc_tail(inlines, target)
  trim_trailing_breaks(inlines)

  if #inlines == 0 then
    return inlines
  end

  local last = inlines[#inlines]

  -- Case 1: actual nested link in the Pandoc AST.
  if last.t == "Link" then
    local inner_target = last.target or ""

    if inner_target == target and is_numeric_page_label(last.content) then
      table.remove(inlines)
      trim_trailing_breaks(inlines)
      return inlines
    end
  end

  -- Case 2: the nested link is wrapped in a Span.
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

  -- Case 3: Pandoc has already converted the inner link to escaped text:
  --   \[3\](#abstract)
  if last.t == "Str" and is_escaped_page_link_text(last.text, target) then
    table.remove(inlines)
    trim_trailing_breaks(inlines)
    return inlines
  end

  return inlines
end


-- ------------------------------------------------------------
-- Images
-- ------------------------------------------------------------

function Image(img)
  -- Remove sizing inherited from Word.
  if img.attributes then
    img.attributes["width"] = nil
    img.attributes["height"] = nil
  end

  -- Remove clearly bogus alt text while preserving meaningful alt text.
  local alt = stringify(img.caption)

  if looks_like_word_garbage(alt) then
    img.caption = pandoc.Inlines({})
  end

  return img
end


-- ------------------------------------------------------------
-- Hard line breaks
-- ------------------------------------------------------------

function LineBreak(_)
  -- A hard line break is written by Pandoc in Markdown/GFM as:
  --
  --   text\
  --   next line
  --
  -- DOCX files often contain these because of manual Word line breaks.
  -- Flatten them to a normal space.
  return pandoc.Space()
end


-- ------------------------------------------------------------
-- Word TOC cleanup
-- ------------------------------------------------------------

function Link(link)
  local target = link.target or ""

  -- Only touch internal-document links.
  if target:sub(1, 1) ~= "#" then
    return link
  end

  if not link.content or #link.content == 0 then
    return link
  end

  clean_toc_tail(link.content, target)
  return link
end
