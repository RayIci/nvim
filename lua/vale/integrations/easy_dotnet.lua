---easy-dotnet.nvim (dotnet language pack). The test-runner and debugger
---groups are force-linked by the plugin on ColorScheme to core groups
---(DiagnosticError, Directory, Comment…), so they follow vale already; only
---the groups it leaves to the theme are defined here.
---@param r ValeRoles
return function(r)
  return {
    EasyDotnetTestPassed = { fg = r.ok },
    EasyDotnetTestFailed = { fg = r.error },
    EasyDotnetTestSkipped = { fg = r.info },
    EasyDotnetTestInProgress = { fg = r.warn },
    EasyDotnetTestError = { fg = r.error },
  }
end
