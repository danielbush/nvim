-- Search utility functions for buffer content

local M = {}

-- Function to find all matches for a given pattern in the current buffer
function M.find_pattern_matches(pattern, pattern_name, show_line)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local matches = {}

  for line_num, line in ipairs(lines) do
    local start_pos = 1
    while true do
      local match_start, match_end = string.find(line, pattern, start_pos)
      if not match_start then
        break
      end

      local match_text = string.sub(line, match_start, match_end)
      table.insert(matches, {
        text = match_text,
        line = line_num,
        col = match_start,
        display = show_line and string.format('%s (line %d, col %d) %s', match_text, line_num, match_start, line)
          or string.format('%s (line %d, col %d)', match_text, line_num, match_start),
      })

      start_pos = match_end + 1
    end
  end

  return matches, pattern_name or 'matches'
end

-- Function to jump to the selected identifier
function M.jump_to_identifier(item)
  vim.api.nvim_win_set_cursor(0, { item.line, item.col - 1 })

  -- Open any folds that contain this line
  vim.cmd 'normal! zv'

  -- Center the line on screen
  vim.cmd 'normal! zz'
end

-- Function to insert selected text at cursor position
function M.insert_at_cursor(item)
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local line_num = cursor_pos[1]
  local col_num = cursor_pos[2]

  -- Get the current line
  local current_line = vim.api.nvim_get_current_line()

  -- Insert the text at cursor position
  local new_line = string.sub(current_line, 1, col_num) .. item.text .. string.sub(current_line, col_num + 1)

  -- Set the modified line
  vim.api.nvim_set_current_line(new_line)

  -- Move cursor to end of inserted text
  vim.api.nvim_win_set_cursor(0, { line_num, col_num + string.len(item.text) })
end

-- Function to insert selected text at cursor position with i: -> r: conversion
function M.insert_at_cursor_convert_i_to_r(item)
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local line_num = cursor_pos[1]
  local col_num = cursor_pos[2]

  -- Get the current line
  local current_line = vim.api.nvim_get_current_line()

  -- Convert i: to r: in the text
  local text_to_insert = item.text:gsub('^i:', 'r:')

  -- Insert the text at cursor position
  local new_line = string.sub(current_line, 1, col_num) .. text_to_insert .. string.sub(current_line, col_num + 1)

  -- Set the modified line
  vim.api.nvim_set_current_line(new_line)

  -- Move cursor to end of inserted text
  vim.api.nvim_win_set_cursor(0, { line_num, col_num + string.len(text_to_insert) })
end

-- Generic fuzzy search function for inserting at cursor with i: -> r: conversion
function M.fuzzy_search_pattern_insert_convert_i_to_r(pattern, pattern_name, prompt_title, show_line)
  local matches, display_name = M.find_pattern_matches(pattern, pattern_name, show_line)

  if #matches == 0 then
    vim.notify(string.format('No %s found in current buffer', display_name), vim.log.levels.INFO)
    return
  end

  -- Check if telescope is available
  local has_telescope, telescope = pcall(require, 'telescope')
  if has_telescope then
    local pickers = require 'telescope.pickers'
    local finders = require 'telescope.finders'
    local conf = require('telescope.config').values
    local actions = require 'telescope.actions'
    local action_state = require 'telescope.actions.state'

    pickers
      .new({}, {
        prompt_title = prompt_title or display_name,
        finder = finders.new_table {
          results = matches,
          entry_maker = function(entry)
            return {
              value = entry,
              display = entry.display,
              ordinal = entry.text,
            }
          end,
        },
        sorter = conf.generic_sorter {},
        attach_mappings = function(prompt_bufnr, map)
          actions.select_default:replace(function()
            actions.close(prompt_bufnr)
            local selection = action_state.get_selected_entry()
            M.insert_at_cursor_convert_i_to_r(selection.value)
          end)
          return true
        end,
      })
      :find()
  else
    -- Fallback to vim.ui.select if Telescope is not available
    local display_items = {}
    for _, item in ipairs(matches) do
      table.insert(display_items, item.display)
    end

    vim.ui.select(display_items, {
      prompt = string.format('Select %s to insert:', display_name),
    }, function(choice, idx)
      if choice and idx then
        M.insert_at_cursor_convert_i_to_r(matches[idx])
      end
    end)
  end
end

-- Generic fuzzy search function for inserting at cursor
function M.fuzzy_search_pattern_insert(pattern, pattern_name, prompt_title, show_line)
  local matches, display_name = M.find_pattern_matches(pattern, pattern_name, show_line)

  if #matches == 0 then
    vim.notify(string.format('No %s found in current buffer', display_name), vim.log.levels.INFO)
    return
  end

  -- Check if telescope is available
  local has_telescope, telescope = pcall(require, 'telescope')
  if has_telescope then
    local pickers = require 'telescope.pickers'
    local finders = require 'telescope.finders'
    local conf = require('telescope.config').values
    local actions = require 'telescope.actions'
    local action_state = require 'telescope.actions.state'

    pickers
      .new({}, {
        prompt_title = prompt_title or display_name,
        finder = finders.new_table {
          results = matches,
          entry_maker = function(entry)
            return {
              value = entry,
              display = entry.display,
              ordinal = entry.text,
            }
          end,
        },
        sorter = conf.generic_sorter {},
        attach_mappings = function(prompt_bufnr, map)
          actions.select_default:replace(function()
            actions.close(prompt_bufnr)
            local selection = action_state.get_selected_entry()
            M.insert_at_cursor(selection.value)
          end)
          return true
        end,
      })
      :find()
  else
    -- Fallback to vim.ui.select if Telescope is not available
    local display_items = {}
    for _, item in ipairs(matches) do
      table.insert(display_items, item.display)
    end

    vim.ui.select(display_items, {
      prompt = string.format('Select %s to insert:', display_name),
    }, function(choice, idx)
      if choice and idx then
        M.insert_at_cursor(matches[idx])
      end
    end)
  end
end

-- Generic fuzzy search function
function M.fuzzy_search_pattern(pattern, pattern_name, prompt_title, show_line)
  local matches, display_name = M.find_pattern_matches(pattern, pattern_name, show_line)

  if #matches == 0 then
    vim.notify(string.format('No %s found in current buffer', display_name), vim.log.levels.INFO)
    return
  end

  -- Check if telescope is available
  local has_telescope, telescope = pcall(require, 'telescope')
  if has_telescope then
    local pickers = require 'telescope.pickers'
    local finders = require 'telescope.finders'
    local conf = require('telescope.config').values
    local actions = require 'telescope.actions'
    local action_state = require 'telescope.actions.state'

    pickers
      .new({}, {
        prompt_title = prompt_title or display_name,
        finder = finders.new_table {
          results = matches,
          entry_maker = function(entry)
            return {
              value = entry,
              display = entry.display,
              ordinal = entry.text,
            }
          end,
        },
        sorter = conf.generic_sorter {},
        attach_mappings = function(prompt_bufnr, map)
          actions.select_default:replace(function()
            actions.close(prompt_bufnr)
            local selection = action_state.get_selected_entry()
            M.jump_to_identifier(selection.value)
          end)
          return true
        end,
      })
      :find()
  else
    -- Fallback to vim.ui.select if Telescope is not available
    local display_items = {}
    for _, item in ipairs(matches) do
      table.insert(display_items, item.display)
    end

    vim.ui.select(display_items, {
      prompt = string.format('Select %s:', display_name),
    }, function(choice, idx)
      if choice and idx then
        M.jump_to_identifier(matches[idx])
      end
    end)
  end
end

-- Multi-word search function with live telescope filtering
function M.live_multiword_search()
  local has_telescope, telescope = pcall(require, 'telescope')
  if not has_telescope then
    vim.notify('Telescope not available', vim.log.levels.WARN)
    return
  end

  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local conf = require('telescope.config').values
  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'

  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local all_lines = {}
  for line_num, line in ipairs(lines) do
    table.insert(all_lines, {
      text = line,
      line = line_num,
      col = 1,
      display = string.format('Line %d: %s', line_num, line),
    })
  end

  pickers
    .new({}, {
      prompt_title = 'Multi-word Search (space-separated)',
      finder = finders.new_dynamic {
        fn = function(prompt)
          if not prompt or prompt == '' then
            return all_lines
          end

          -- Split prompt into words
          local words = {}
          for word in prompt:gmatch '%S+' do
            table.insert(words, word)
          end

          if #words == 0 then
            return all_lines
          end

          local filtered_lines = {}
          for _, item in ipairs(all_lines) do
            local line_matches_all = true

            -- Check if all words are present as whole words in the line
            for _, word in ipairs(words) do
              -- Use simple case-insensitive substring search
              if not string.find(item.text:lower(), word:lower()) then
                line_matches_all = false
                break
              end
            end

            if line_matches_all then
              table.insert(filtered_lines, item)
            end
          end

          return filtered_lines
        end,
        entry_maker = function(entry)
          return {
            value = entry,
            display = entry.display,
            ordinal = entry.text,
          }
        end,
      },
      sorter = conf.generic_sorter {},
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          M.jump_to_identifier(selection.value)
        end)
        return true
      end,
    })
    :find()
end

return M
