---vim-illuminate
---@param r ValeRoles
return function(r)
  return {
    IlluminatedWordText = { bg = r.word_highlight },
    IlluminatedWordRead = { bg = r.word_highlight },
    IlluminatedWordWrite = { bg = r.word_highlight, underline = true },
  }
end
