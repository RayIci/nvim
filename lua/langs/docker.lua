---Docker language pack: Dockerfile LSP + compose LSP.
---@type LangPack
return {
  treesitter = { "dockerfile" },
  lsp = {
    dockerls = {},
    docker_compose_language_service = {},
  },
  mason = { "dockerfile-language-server", "docker-compose-language-service" },
}
