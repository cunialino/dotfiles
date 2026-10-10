{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.ntfy;

  # Plain portable bash with @placeholders@ for the values this module owns, so
  # the script is readable on its own and `ntfy-notify` still works when typed
  # by hand. See the header of ntfy-notify for the behaviour itself.
  notifyScript = pkgs.replaceVarsWith {
    src = ./ntfy-notify;
    dir = "bin";
    isExecutable = true;
    replacements = {
      server = cfg.server;
      topicFiles = lib.concatStringsSep ":" cfg.topicFiles;
      topics = lib.concatStringsSep ":" cfg.topics;
      replaySince = cfg.replaySince;
      dedupe = lib.boolToString cfg.dedupe;
      appName = cfg.appName;
      daemonWaitSecs = toString cfg.daemonWaitSecs;
    };
  };

  # Closed PATH: the bridge runs as a user unit, where `PATH` is whatever systemd
  # felt like giving it, and it shells out to curl, jq, notify-send and busctl.
  notifyPackage = pkgs.runCommand "ntfy-notify" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
    mkdir -p "$out/bin"
    makeWrapper "${notifyScript}/bin/ntfy-notify" "$out/bin/ntfy-notify" \
      --prefix PATH : "${lib.makeBinPath [
        pkgs.bash
        pkgs.curl
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.jq
        pkgs.libnotify
        pkgs.systemd
      ]}"
  '';
in
{
  options.modules.ntfy = {
    enable = lib.mkEnableOption ''
      ntfy to desktop notifications bridge (subscribe to topics, show them with
      whatever owns org.freedesktop.Notifications -- see modules.gui, which runs
      swaync)
    '';

    # No `package` option on purpose: nixpkgs does not have binwiederhier/ntfy.
    # `pkgs.ntfy` is a different project that happens to provide an `ntfy`
    # command (a Python trigger CLI, no `subscribe`), so picking a package here
    # would only be a way to shoot oneself in the foot. The subscription is a
    # plain GET against the API; see modules/ntfy/ntfy-notify.

    server = lib.mkOption {
      type = lib.types.str;
      default = "https://ntfy.tail2f38ea.ts.net";
      description = ''
        Base URL used to expand bare topic names. This is the tailnet-only
        instance deployed in `homelab/base/ntfy` (tailscale Ingress, no auth,
        24h message cache); the URL itself is not the secret -- see
        {option}`modules.ntfy.topicFiles`.
      '';
    };

    topicFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "${config.home.homeDirectory}/.config/ntfy/topics" ];
      description = ''
        Files to read topics from, one per line, `#` for comments. Each line is
        a full URL, a `host/topic`, or a bare topic name expanded with
        {option}`modules.ntfy.server`. Missing files are skipped with a line in
        the journal, so a machine that has not been set up yet just sits idle.

        The files are deliberately not generated here. The instance has no auth
        (the tailnet is the boundary), which makes **the topic name the only
        credential**, so it stays out of this public repository -- the same
        reasoning as `modules.herdr.queue.ntfyTopicFile`. Create it once per
        machine:

        ```bash
        install -Dm600 /dev/null ~/.config/ntfy/topics
        printf 'https://ntfy.tail2f38ea.ts.net/%s\n' \
          "$(head -c 8 /dev/urandom | od -An -tx1 | tr -d ' \n')" >> ~/.config/ntfy/topics
        ```
      '';
    };

    topics = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "homelab-backups" ];
      description = ''
        Topics to subscribe to that are not secrets, i.e. ones you would be
        comfortable seeing in this repository. Anything else belongs in a
        {option}`modules.ntfy.topicFiles` file.
      '';
    };

    replaySince = lib.mkOption {
      type = lib.types.str;
      default = "all";
      example = "6h";
      description = ''
        Value of the `since=` query parameter on every subscription: `all` for
        everything still in the server's cache, a duration (`6h`) or Unix
        timestamp to bound it, or `""` for live messages only.

        `all` is what makes the laptop behave like the phone: start sway in the
        morning and the overnight pushes appear. {option}`modules.ntfy.dedupe`
        is what stops that from repeating the same messages on every restart.
      '';
    };

    dedupe = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Remember delivered message IDs in
        `{env}`XDG_RUNTIME_DIR/ntfy-notify/seen` and skip them on the next
        replay. Per boot, not per lifetime: a reboot shows the cached messages
        again, which is the same thing the phone does after a restart.
      '';
    };

    appName = lib.mkOption {
      type = lib.types.str;
      default = "ntfy";
      description = ''
        App name of every notification sent. swaync groups by it and can target
        it with `notification-visibility` / `scripts` rules.
      '';
    };

    daemonWaitSecs = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 0;
      example = 120;
      description = ''
        How long to wait for something to own `org.freedesktop.Notifications`
        before subscribing, `0` to wait forever. Waiting is what lets this start
        at login on a machine where sway may never be started at all; anything
        published meanwhile is picked up by the replay once a daemon appears.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # The wrapper is also the debuggable entry point: `ntfy-notify --topics`
    # says what the topic files resolve to right now.
    home.packages = [ notifyPackage ];

    # default.target rather than wayland.systemd.target: this is not a compositor
    # client, it is a subscriber that happens to need a notification daemon, and
    # it waits for one by itself. Starting it with the login session (linger is
    # on for elcungem) is what keeps it running whether or not anyone is at the
    # screen.
    systemd.user.services.ntfy-notify = {
      Unit = {
        Description = "Mirror ntfy topics into desktop notifications";
        Documentation = [ "https://docs.ntfy.sh/subscribe/cli/" ];
        PartOf = [ "default.target" ];
        X-Restart-Triggers = [ "${notifyPackage}" ];
      };
      Service = {
        ExecStart = "${notifyPackage}/bin/ntfy-notify";
        Restart = "on-failure";
        RestartSec = 15;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
