# "Ask Flattoo": the copilot that replaces the terminal for the artist.
#
#   flattoo-copilot   runs as the artist. Understands a plain request
#                     ("something like paint", "fix the printer", "update
#                     now") and maps it to ONE of a fixed list of actions.
#                     No shell, no free-form commands, ever.
#   flattoo-admin     the only privileged piece, reached through polkit
#                     (org.flattoo.admin). Four subcommands: install/remove a
#                     catalog package, update, cleanup.
#   catalog.json      the curated app list the copilot may install from.
#   flattoo.apps.extra  the packages the artist has added; flattoo-admin
#                     writes hosts/<host>/apps.nix = { flattoo.apps.extra = [...]; }.
#                     Anything not in the catalog fails evaluation here, so a
#                     tampered apps.nix cannot pull in arbitrary software.
#
# Optional: an LLM to understand odd phrasings. Its output is a structured
# choice validated against the same allowlist and catalog. Provider "none"
# (the default) uses the built-in rules only.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.flattoo;
  catalog = builtins.fromJSON (builtins.readFile ../pkgs/flattoo-copilot/share/flattoo/catalog.json);
  catalogPkgs = map (e: e.pkg) catalog;
  unknown = lib.filter (p: !(builtins.elem p catalogPkgs)) cfg.apps.extra;
  resolve = p: lib.attrByPath (lib.splitString "." p) null pkgs;
in
{
  options.flattoo = {
    apps.extra = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "pinta"
        "blender"
      ];
      description = ''
        Catalog packages added by the artist through Ask Flattoo. Written to
        hosts/<host>/apps.nix by flattoo-admin; names outside the catalog
        are rejected at evaluation time.
      '';
    };
    copilot = {
      enable = lib.mkEnableOption "Ask Flattoo, the plain-English copilot" // {
        default = true;
      };
      llm = {
        provider = lib.mkOption {
          type = lib.types.enum [
            "none"
            "anthropic"
            "ollama"
          ];
          default = "none";
          description = ''
            Who interprets requests the built-in rules do not understand.
            "anthropic" needs an API key in anthropicKeyFile; "ollama" runs a
            small local model (slow on a laptop without a GPU). Either way
            the model only picks an action; it cannot run anything.
          '';
        };
        anthropicKeyFile = lib.mkOption {
          type = lib.types.str;
          default = "/etc/flattoo/copilot.key";
          description = "File holding the Anthropic API key, mode 0640 root:flattoo. Not managed by Nix.";
        };
        model = lib.mkOption {
          type = lib.types.str;
          default = "claude-haiku-5-5";
          description = "Anthropic model id, or the Ollama model tag when provider = ollama.";
        };
      };
    };
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = unknown == [ ];
          message = "flattoo.apps.extra contains packages that are not in the Flattoo catalog: ${toString unknown}";
        }
      ];
      environment.systemPackages = lib.filter (p: p != null) (map resolve cfg.apps.extra);
    }

    (lib.mkIf cfg.copilot.enable {
      environment.systemPackages = [ pkgs.flattoo-copilot ];

      # The artist may run flattoo-admin's four subcommands without a
      # password; anyone else needs the administrator's.
      security.polkit.extraConfig = ''
        polkit.addRule(function(action, subject) {
          if (action.id == "org.flattoo.admin" && subject.isInGroup("flattoo") && subject.active && subject.local) {
            return polkit.Result.YES;
          }
          if (action.id == "org.flattoo.admin") {
            return polkit.Result.AUTH_ADMIN;
          }
        });
      '';

      environment.sessionVariables = {
        FLATTOO_COPILOT_PROVIDER = cfg.copilot.llm.provider;
        FLATTOO_COPILOT_MODEL = cfg.copilot.llm.model;
      }
      // lib.optionalAttrs (cfg.copilot.llm.provider == "anthropic") {
        FLATTOO_COPILOT_KEYFILE = cfg.copilot.llm.anthropicKeyFile;
      };

      services.ollama = lib.mkIf (cfg.copilot.llm.provider == "ollama") {
        enable = true;
        loadModels = [ cfg.copilot.llm.model ];
      };
    })
  ];
}
