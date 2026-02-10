local M = {}

local get_cwd = ya.sync(function(st)
  return cx.active.current.cwd
end)

function M:entry(job)
  local cwd = get_cwd()

  local options, err = M.parse(job.args)
  if not options then
    ya.notify {
      title = "Television Arguments Error",
      content = tostring(err),
      timeout = 5,
      level = "error"
    }
    return
  end

  local permit = ui.hide()
  local target, err = M.run_tv(options.cable, cwd)
  permit:drop()

  if not target then
    ya.notify {
      title = "Television Runtime Error",
      content = tostring(err),
      timeout = 5,
      level = "error"
    }
    return
  end

  if target == "" then
    return
  end

  local cd
  if options.cd and type(options.cd) == "string" then
    cd = options.cd
  else
    cd = target
  end
  local shell = options.shell
  local reveal
  if options.reveal then
    reveal = options.reveal
  else
    reveal = target
  end

  if options.pattern then
    local data = M.match(target, options.pattern, options.pattern_keys)
    if options.cd and type(options.cd) == "string" then
      cd = M.render(options.cd, data, cwd)
    end
    if options.shell then
      shell = M.render(options.shell, data, cwd)
    end
    if options.reveal then
      reveal = M.render(options.reveal, data, cwd)
    end
  end

  if options.cd then
    ya.emit("cd", { M.expand(cd, cwd), raw = true })
  elseif options.shell then
    if options.reveal then
      ya.emit("reveal", { M.expand(reveal, cwd), raw = true })
    end
    ya.emit("shell", { shell, block = true })
  else
    ya.emit("reveal", { M.expand(reveal, cwd), raw = true })
  end
end

---@param args table
---@return table?, Error?
function M.parse(args)
  local result = {}

  if #args == 0 then
    result.cable = "files"
  elseif #args == 1 then
    result.cable = args[1]
  else
    return nil, Err("Expected 0 or 1 argument got %d", #args)
  end

  if args.text then
    args.pattern = "^(.+):(%d+)$"
    args.pattern_keys = "file,line"
    args.reveal = '{{file}}'
    args.shell = '"$EDITOR" {{$%file}}'
  end

  if args.pattern and not args.pattern_keys then
    return nil, Err("Argument `--pattern` specified but no `--pattern-keys`")
  elseif not args.pattern and args.pattern_keys then
    return nil, Err("Argument `--pattern-keys` specified but no `--pattern`")
  elseif args.pattern and args.pattern_keys then
    if type(args.pattern) ~= "string" then
      return nil, Err("Invalid arugment `--pattern` which is not a string")
    end
    result.pattern = args.pattern
    if type(args.pattern_keys) ~= "string" then
      return nil, Err("Invalid arugment `--pattern-keys` which is not a string")
    end
    result.pattern_keys = M.split_by_comma(args.pattern_keys)
  end

  if args.shell and args.cd then
    return nil, Err("Conflict arugments `--shell` and `--cd` specified")
  end
  if args.reveal and args.cd then
    return nil, Err("Conflict arugments `--reveal` and `--cd` specified")
  end

  if args.cd then
    result.cd = args.cd
  else
    if args.shell then
      if type(args.shell) ~= "string" then
        return nil, Err("Invalid arugment `--shell` which is not a string")
      end
      result.shell = args.shell
    end
    if args.reveal and type(args.reveal) ~= "string" then
      return nil, Err("Invalid arugment `--reveal` which is not a string")
    end
    result.reveal = args.reveal
  end

  return result, nil
end

---@param keys string
---@return table
function M.split_by_comma(keys)
  local result = {}
  for key in string.gmatch(keys, "[^,]+") do
    matched = key:match("^%s*(.-)%s*$")
    table.insert(result, matched)
  end
  return result
end

---@param text string
---@param pattern string
---@param keys table
---@return table
function M.match(text, pattern, keys)
  local captures = { string.match(text, pattern) }
  local result = {}
  for i, key in ipairs(keys) do
    result[key] = captures[i]
  end
  return result
end

---@param template string
---@param data table
---@param cwd Url
---@return string
function M.render(template, data, cwd)
  return (template:gsub("{{($?%%?.-)}}", function(key)
    local rest = key
    local need_quote = rest:sub(1, 1) == "$"
    if need_quote then
      rest = rest:sub(2)
    end
    local need_expand = rest:sub(1, 1) == "%"
    if need_expand then
      rest = rest:sub(2)
    end
    local datum = data[rest]
    if not datum then
      return "{{" .. key .. "}}"
    end
    if need_expand then
      datum = tostring(M.expand(datum, cwd))
    end
    if need_quote then
      datum = ya.quote(datum)
    end
    return datum
  end))
end

---@param file_name string
---@param cwd Url
---@return Url
function M.expand(path, cwd)
  local url = Url(path)
  if not url.is_absolute then
    url = cwd:join(url)
  end
  return url
end

---@param cable string
---@param cwd Url
---@return string?, Error?
function M.run_tv(cable, cwd)
  local child, err = Command("tv")
    :arg({ cable })
    :cwd(tostring(cwd))
    :stdin(Command.INHERIT)
    :stdout(Command.PIPED)
    :stderr(Command.INHERIT)
    :spawn()

  if not child then
    return nil, Err("Failed to start `tv`, error: %s", err)
  end

  local output, err = child:wait_with_output()
  if not output then
    return nil, Err("Cannot read `tv` output, error: %s", err)
  elseif not output.status.success then
    return nil, Err("`tv` exited with code %s", output.status.code)
  end
  return output.stdout:gsub("\n$", ""), nil
end

return M
