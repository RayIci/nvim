---Environment-aware clipboard provider selection.
---Supports: WSL, macOS, Linux (X11/Wayland), SSH, tmux, Windows.
---Requiring this module selects a provider and sets clipboard=unnamedplus.
local M = {}

-- =============================================================================
-- ENVIRONMENT DETECTION
-- =============================================================================

local function executable(cmd)
  return vim.fn.executable(cmd) == 1
end

local function is_wsl()
  if vim.fn.has("wsl") == 1 then
    return true
  end
  local ok, uname = pcall(vim.fn.system, "uname -r")
  if ok and uname then
    return uname:lower():find("microsoft") ~= nil
  end
  return false
end

local function is_ssh()
  return vim.env.SSH_TTY ~= nil or vim.env.SSH_CLIENT ~= nil or vim.env.SSH_CONNECTION ~= nil
end

local function is_tmux()
  return vim.env.TMUX ~= nil
end

local function has_wayland()
  return vim.env.WAYLAND_DISPLAY ~= nil
end

local function has_x11()
  return vim.env.DISPLAY ~= nil
end

local function is_macos()
  return vim.fn.has("mac") == 1
end

local function is_windows()
  return vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1
end

-- =============================================================================
-- CLIPBOARD PROVIDERS
-- =============================================================================

local providers = {}

-- WSL: win32yank.exe (preferred, fast and handles line endings)
providers.win32yank = function()
  if not executable("win32yank.exe") then
    return nil
  end
  return {
    name = "win32yank",
    copy = {
      ["+"] = "win32yank.exe -i --crlf",
      ["*"] = "win32yank.exe -i --crlf",
    },
    paste = {
      ["+"] = "win32yank.exe -o --lf",
      ["*"] = "win32yank.exe -o --lf",
    },
    cache_enabled = 0,
  }
end

-- WSL fallback: clip.exe + PowerShell
providers.wsl_native = function()
  if not (executable("clip.exe") and executable("powershell.exe")) then
    return nil
  end
  return {
    name = "wsl-native",
    copy = {
      ["+"] = "clip.exe",
      ["*"] = "clip.exe",
    },
    paste = {
      -- PowerShell Get-Clipboard with tr to remove Windows line endings
      ["+"] = 'powershell.exe -NoLogo -NoProfile -c "Get-Clipboard -Raw" | tr -d "\\r"',
      ["*"] = 'powershell.exe -NoLogo -NoProfile -c "Get-Clipboard -Raw" | tr -d "\\r"',
    },
    cache_enabled = 0,
  }
end

-- Wayland: wl-clipboard
providers.wayland = function()
  if not (has_wayland() and executable("wl-copy") and executable("wl-paste")) then
    return nil
  end
  return {
    name = "wl-clipboard",
    copy = {
      ["+"] = "wl-copy --type text/plain",
      ["*"] = "wl-copy --type text/plain --primary",
    },
    paste = {
      ["+"] = "wl-paste --no-newline",
      ["*"] = "wl-paste --no-newline --primary",
    },
    cache_enabled = 0,
  }
end

-- X11: xclip
providers.xclip = function()
  if not (has_x11() and executable("xclip")) then
    return nil
  end
  return {
    name = "xclip",
    copy = {
      ["+"] = "xclip -quiet -selection clipboard",
      ["*"] = "xclip -quiet -selection primary",
    },
    paste = {
      ["+"] = "xclip -selection clipboard -o",
      ["*"] = "xclip -selection primary -o",
    },
    cache_enabled = 0,
  }
end

-- X11: xsel (fallback if xclip not available)
providers.xsel = function()
  if not (has_x11() and executable("xsel")) then
    return nil
  end
  return {
    name = "xsel",
    copy = {
      ["+"] = "xsel --clipboard --input",
      ["*"] = "xsel --primary --input",
    },
    paste = {
      ["+"] = "xsel --clipboard --output",
      ["*"] = "xsel --primary --output",
    },
    cache_enabled = 0,
  }
end

-- macOS: pbcopy/pbpaste
providers.macos = function()
  if not (is_macos() and executable("pbcopy") and executable("pbpaste")) then
    return nil
  end
  return {
    name = "pbcopy",
    copy = {
      ["+"] = "pbcopy",
      ["*"] = "pbcopy",
    },
    paste = {
      ["+"] = "pbpaste",
      ["*"] = "pbpaste",
    },
    cache_enabled = 0,
  }
end

-- OSC 52: terminal escape sequence (works over SSH, in tmux, etc.)
-- Requires terminal support and Neovim 0.10+.
providers.osc52 = function()
  local ok, osc52 = pcall(require, "vim.ui.clipboard.osc52")
  if not ok then
    return nil
  end
  return {
    name = "OSC52",
    copy = {
      ["+"] = osc52.copy("+"),
      ["*"] = osc52.copy("*"),
    },
    paste = {
      -- OSC 52 paste is often blocked by terminals for security; falls back to
      -- reading from the unnamed register in practice.
      ["+"] = osc52.paste("+"),
      ["*"] = osc52.paste("*"),
    },
    cache_enabled = 0,
  }
end

-- =============================================================================
-- PROVIDER SELECTION LOGIC
-- =============================================================================

local function select_provider()
  -- WSL: try win32yank first, then native WSL tools
  if is_wsl() then
    return providers.win32yank()
      or providers.wayland() -- WSLg support
      or providers.xclip() -- X11 forwarding
      or providers.xsel()
      or providers.wsl_native()
      or providers.osc52()
  end

  if is_macos() then
    return providers.macos() or providers.osc52()
  end

  if is_windows() then
    return nil -- let Neovim use its built-in Windows clipboard
  end

  -- SSH session without display: use OSC 52
  if is_ssh() and not has_x11() and not has_wayland() then
    return providers.osc52()
  end

  if has_wayland() then
    return providers.wayland() or providers.osc52()
  end

  if has_x11() then
    return providers.xclip() or providers.xsel() or providers.osc52()
  end

  -- Headless/TTY: fall back to OSC 52
  return providers.osc52()
end

-- =============================================================================
-- SETUP
-- =============================================================================

function M.setup()
  -- Don't override if the user has already configured a clipboard provider.
  if vim.g.clipboard then
    vim.opt.clipboard = "unnamedplus"
    return
  end

  local provider = select_provider()
  if provider then
    vim.g.clipboard = provider
  end

  vim.opt.clipboard = "unnamedplus"
end

-- =============================================================================
-- ENVIRONMENT INFO (for statusline or debugging)
-- =============================================================================

function M.get_environment_info()
  local env = {}

  if is_wsl() then
    env.os = "WSL"
  elseif is_macos() then
    env.os = "macOS"
  elseif is_windows() then
    env.os = "Windows"
  else
    env.os = "Linux"
  end

  env.ssh = is_ssh()
  env.tmux = is_tmux()
  env.wayland = has_wayland()
  env.x11 = has_x11()
  env.provider = vim.g.clipboard and vim.g.clipboard.name or "default"

  return env
end

function M.get_environment_string()
  local info = M.get_environment_info()
  local parts = { info.os }

  if info.ssh then
    table.insert(parts, "SSH")
  end
  if info.tmux then
    table.insert(parts, "tmux")
  end

  return table.concat(parts, " + ") .. " [" .. info.provider .. "]"
end

-- =============================================================================
-- INITIALIZATION
-- =============================================================================

M.setup()

return M
