{ config, lib, ... }:
let
  cfg = config.modules.mcp;
in
{
  options.modules.mcp = {
    enable = lib.mkEnableOption "MCP servers";

    servers = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            url = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "HTTP(S) endpoint for a remote MCP server.";
            };
            command = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Executable for a local MCP server.";
            };
            args = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Arguments for a local MCP server.";
            };
          };
        }
      );
      default = { };
      description = "MCP server definitions shared across all harnesses.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.mcp = {
      enable = true;
      servers = cfg.servers;
    };
  };
}
