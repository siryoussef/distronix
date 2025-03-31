{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.virtualisation.distronix;
in {
  options.virtualisation.distronix = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Distrobox integration.";
    };

    containers = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          autoStart = mkOption {
            type = types.bool;
            default = true;
            description = ''
              When enabled, the container is automatically started on boot.
              If this option is set to false, the container has to be started on-demand via its service.
            '';
          };

          image = mkOption {
            type = types.str;
            description = "Container image to use.";
          };

          imageFile = mkOption {
            type = with types; nullOr package;
            default = null;
            description = ''
              Path to an image file to load before running the image. This can
              be used to bypass pulling the image from the registry.

              The `image` attribute must match the name and
              tag of the image contained in this file, as they will be used to
              run the container with that image. If they do not match, the
              image will be pulled from the registry as usual.
            '';
            example = literalExpression "pkgs.dockerTools.buildImage {...};";
          };

          imageStream = mkOption {
            type = with types; nullOr package;
            default = null;
            description = ''
              Path to a script that streams the desired image on standard output.

              This option is mainly intended for use with
              `pkgs.dockerTools.streamLayeredImage` so that the intermediate
              image archive does not need to be stored in the Nix store.  For
              larger images this optimization can significantly reduce Nix store
              churn compared to using the `imageFile` option, because you don't
              have to store a new copy of the image archive in the Nix store
              every time you change the image.  Instead, if you stream the image
              then you only need to build and store the layers that differ from
              the previous image.
            '';
            example = literalExpression "pkgs.dockerTools.streamLayeredImage {...};";
          };

          serviceName = mkOption {
            type = types.str;
            default = "${cfg.backend}-${name}";
            defaultText = "<backend>-<name>";
            description = "Systemd service name that manages the container";
          };

          login = {
            username = mkOption {
              type = with types; nullOr str;
              default = null;
              description = "Username for login.";
            };

            passwordFile = mkOption {
              type = with types; nullOr str;
              default = null;
              description = "Path to file containing password.";
              example = "/etc/nixos/dockerhub-password.txt";
            };

            registry = mkOption {
              type = with types; nullOr str;
              default = null;
              description = "Registry where to login to.";
              example = "https://docker.pkg.github.com";
            };
          };

          cmd = mkOption {
            type = with types; listOf str;
            default = [];
            description = "Commandline arguments to pass to the image's entrypoint.";
            example = literalExpression ''
              ["--port=9000"]
            '';
          };

          labels = mkOption {
            type = with types; attrsOf str;
            default = {};
            description = "Labels to attach to the container at runtime.";
            example = literalExpression ''
              {
                "traefik.https.routers.example.rule" = "Host(`example.container`)";
              }
            '';
          };

          entrypoint = mkOption {
            type = with types; nullOr str;
            description = "Override the default entrypoint of the image.";
            default = null;
            example = "/bin/my-app";
          };

          environment = mkOption {
            type = types.attrsOf types.str;
            default = {};
            description = "Environment variables to set inside the container.";
          };

          environmentFiles = mkOption {
            type = with types; listOf path;
            default = [];
            description = "Environment files for this container.";
            example = literalExpression ''
              [
                /path/to/.env
                /path/to/.env.secret
              ]
            '';
          };

          log-driver = mkOption {
            type = types.str;
            default = "journald";
            description = ''
              Logging driver for the container.  The default of
              `"journald"` means that the container's logs will be
              handled as part of the systemd unit.

              For more details and a full list of logging drivers, refer to respective backends documentation.

              For Docker:
              [Docker engine documentation](https://docs.docker.com/engine/logging/configure/)

              For Podman:
              Refer to the docker-run(1) man page.
            '';
          };

          ports = mkOption {
            type = with types; listOf str;
            default = [];
            description = ''
              Network ports to publish from the container to the outer host.

              Valid formats:
              - `<ip>:<hostPort>:<containerPort>`
              - `<ip>::<containerPort>`
              - `<hostPort>:<containerPort>`
              - `<containerPort>`

              Both `hostPort` and `containerPort` can be specified as a range of
              ports.  When specifying ranges for both, the number of container
              ports in the range must match the number of host ports in the
              range.  Example: `1234-1236:1234-1236/tcp`

              When specifying a range for `hostPort` only, the `containerPort`
              must *not* be a range.  In this case, the container port is published
              somewhere within the specified `hostPort` range.
              Example: `1234-1236:1234/tcp`

              Publishing a port bypasses the NixOS firewall. If the port is not
              supposed to be shared on the network, make sure to publish the
              port to localhost.
              Example: `127.0.0.1:1234:1234`

              Refer to the
              [Docker engine documentation](https://docs.docker.com/engine/network/#published-ports) for full details.
            '';
            example = literalExpression ''
              [
                "127.0.0.1:8080:9000"
              ]
            '';
          };

          user = mkOption {
            type = types.str;
            default = "1000";
            description = "User ID to run the container as.";
          };

          volumes = mkOption {
            type = with types; listOf str;
            default = [];
            description = ''
              List of volumes to attach to this container.

              Note that this is a list of `"src:dst"` strings to
              allow for `src` to refer to `/nix/store` paths, which
              would be difficult with an attribute set.  There are
              also a variety of mount options available as a third
              field; please refer to the
              [docker engine documentation](https://docs.docker.com/engine/storage/volumes/) for details.
            '';
            example = literalExpression ''
              [
                "volume_name:/path/inside/container"
                "/path/on/host:/path/inside/container"
              ]
            '';
          };

          dependsOn = mkOption {
            type = with types; listOf str;
            default = [];
            description = ''
              Define which other containers this one depends on. They will be added to both After and Requires for the unit.

              Use the same name as the attribute under `virtualisation.oci-containers.containers`.
            '';
            example = literalExpression ''
              virtualisation.oci-containers.containers = {
                node1 = {};
                node2 = {
                  dependsOn = [ "node1" ];
                }
              }
            '';
          };

          nvidia = mkOption {
            type = types.bool;
            default = false;
            description = "Enable NVIDIA GPU support for the container.";
          };

          additionalPackages = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "List of additional packages to install inside the container.";
          };

          exportApps = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "List of applications to export from the container to the host.";
          };

          exportBinaries = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "List of binaries to export from the container to the host.";
          };

          additionalFlags = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Additional flags to pass to the container runtime.";
          };
        };
      });
      default = {};
      description = "Configurations for Distrobox containers.";
    };
  };

  config = mkIf cfg.enable (mapAttrs (name: containerCfg: let
      variables = rec {
        DISTROBOX_APP_DESKTOP = "/usr/share/.desktop";
        XDG_DATA_DIRS = ["${DISTROBOX_APP_DESKTOP}/icons"];
      };
      containerName = name; # Replace with your container's name
      backend = config.virtualisation.oci-containers.backend; # e.g., "podman" or "docker"
      containerManager = pkgs.${backend}; # e.g., "podman" or "docker"
      serviceName = "${backend}-${containerName}"; # Constructs the service name
      distroBinWrapper = {
        containerManager,
        containerName,
        binName,
        binPath ? binName, #distroBinGuestPath {inherit containerManager containerName binName;},
        isApp ? false,
        isBin ? true,
        ...
      }:
        pkgs.writeScriptBin "${binName}" ''
          sh ${distro-enter {inherit containerManager containerName;}}/bin/distro-enter
          ${containerManager} exec ${containerName} ${binPath}
          # ${(
            if isBin
            then "distrobox_binary"
            else " "
          )}
          # ${(
            if isApp
            then "Exec=.*distrobox-enter.*"
            else " "
          )}
        '';
      distroAppWrapper = {
        containerManager,
        containerName,
        appName,
        appPath ? appName, #distroBinGuestPath {inherit containerManager containerName binName;},
        icon ? appName,
        ...
      }:
        pkgs.makeDesktopItem rec {
          name = "${containerName}-${appName}";
          desktopName = "${appName}";
          exec = "${distroBinWrapper {
            inherit containerManager containerName;
            binName = appPath;
            isApp = true;
            isBin = terminal;
          }}/bin/${appName}";
          terminal = false;
          categories = ["Utility"];
          inherit icon;
        };
      containerPath = {
        containerManager,
        containerName,
        ...
      }:
        builtins.readFile pkgs.runCommand "distro-path" ''
          echo "$(${containerManager} inspect --format '{{ .GraphDriver.Data.MergedDir}}' ${containerName})" > $out
        '';
      distroBinGuestPath = {
        containerManager,
        containerName,
        binName,
        ...
      }:
        builtins.readFile pkgs.runCommand "capture-pkg-path" {} ''
          echo "$(${containerManager} exec ${containerName} which ${binName})" > $out
        '';
      distroBinHostPath = {
        containerManager,
        containerName,
        binName,
        ...
      }:
        containerPath {inherit containerManager containerName;} + distroBinGuestPath {inherit containerManager containerName binName;};
      distro-enter = {
        containerManager,
        containerName,
        ...
      }:
        pkgs.writeScriptBin "distro-enter" ''

          # Define necessary variables
          appCacheDir="''${XDG_CACHE_HOME:-"''${HOME}/.cache"}/distrobox"

          trap cleanup TERM INT HUP EXIT

          # Cleanup function to remove FIFO and temp files
          cleanup() {
              rm -f "''${appCacheDir}/.''${containerName}.fifo"
              if [ -n "''${logsPid:-}" ]; then
                  kill "''${logsPid:-}" 2> /dev/null || :
              fi
          }

          generate_enter_command() {
              resultCommand="exec --interactive --detach-keys= --tty --user=''${USER} --workdir=''${PWD:-"''${HOME}"} --env=CONTAINER_ID=${containerName} --env=PATH=''${PATH} ${containerName}"
              printf "%s\n" "''${resultCommand}" | tr -d '\t'
          }

          containerHome="''${HOME}"
          containerPath="''${PATH}"
          unshareGroups=0

          # Inspect the container
          containerStatus="unknown"
          eval "$(${containerManager} inspect --type container --format \
              'containerStatus={{.State.Status}};
              {{range .Config.Env}}{{if and (ge (len .) 5) (eq (slice . 0 5) "HOME=")}}containerHome={{slice . 5 | printf "%q"}}{{end}}{{end}};
              {{range .Config.Env}}{{if and (ge (len .) 5) (eq (slice . 0 5) "PATH=")}}containerPath={{slice . 5 | printf "%q"}}{{end}}{{end}}' \
              "${containerName}")"

          # Start the container if not running
          if [ "''${containerStatus}" != "running" ]; then
              logTimestamp="$(date -u +%FT%T).000000000+00:00"
              ${containerManager} start "${containerName}" > /dev/null 2>&1

              if [ "$(${containerManager} inspect --type container --format "{{.State.Status}}" "${containerName}")" != "running" ]; then
                  containerManagerLog="$(${containerManager} logs "${containerName}")"
                  exit 1
              fi

              mkdir -p "''${appCacheDir}"
              rm -f "''${appCacheDir}/.''${containerName}.fifo"
              mkfifo "''${appCacheDir}/.''${containerName}.fifo"

              while true; do
                  if [ "$(${containerManager} inspect --type container --format '{{.State.Status}}' "${containerName}")" != "running" ]; then
                      exit 1
                  fi
                  ${containerManager} logs --since "''${logTimestamp}" -f "${containerName}" \
                      > "''${appCacheDir}/.''${containerName}.fifo" 2>&1 &
                  logsPid="$!"

                  while IFS= read -r line; do
                      case "''${line}" in
                          "container_setup_done"*)
                              kill "''${logsPid}" > /dev/null 2>&1
                              break 2
                              ;;
                          *) ;;
                      esac
                  done < "''${appCacheDir}/.''${containerName}.fifo"
              done
              rm -f "''${appCacheDir}/.''${containerName}.fifo"
          fi

          # Execute command inside the container
          cmd="$(generate_enter_command | awk '{a[i++]=$0} END {for (j=i-1; j>=0;) print a[j--]}')"
          IFS='
          '
          for arg in "''${cmd}"; do
              set - "''${arg}" "$@"
          done

          exec "$@"
        '';
    in {
      virtualisation.oci-containers.containers = {
        inherit
          (containerCfg)
          autoStart
          image
          imageFile
          imageStream
          serviceName
          login
          cmd
          entrypoint
          environmentFiles
          log-driver
          ports
          user
          dependsOn
          additionalFlags
          ;
        volumes =
          containerCfg.volumes
          ++ (
            if containerCfg.nvidia
            then [
              # "/usr/local/nvidia:/usr/local/nvidia:ro"
              "/run/opengl-driver:/run/opengl-driver:ro"
              "/usr/bin/nvidia-smi:/usr/bin/nvidia-smi:ro"
              "/usr/bin/nvidia-container-cli:/usr/bin/nvidia-container-cli:ro"
              "/usr/bin/nvidia-container-runtime:/usr/bin/nvidia-container-runtime:ro"
              "/usr/lib/libnvidia-container.so:/usr/lib/libnvidia-container.so:ro"
              "/usr/lib/libnvidia-container.so.1:/usr/lib/libnvidia-container.so.1:ro"
              "/usr/lib/libnvidia-container.so.1.0.0:/usr/lib/libnvidia-container.so.1.0.0:ro"
              "/usr/lib/libnvidia-ml.so:/usr/lib/libnvidia-ml.so:ro"
              "/usr/lib/libnvidia-ml.so.1:/usr/lib/libnvidia-ml.so.1:ro"
              "/usr/lib/libnvidia-ml.so.1.0.0:/usr/lib/libnvidia-ml.so.1.0.0:ro"
              "/usr/local/cuda:/usr/local/cuda:ro"
            ]
            else []
          )
          ++ [
            "/etc/localtime:/etc/localtime:ro"
            "/etc/timezone:/etc/timezone:ro"
          ];
        environment =
          containerCfg.environment
          // variables
          // (
            if containerCfg.nvidia
            then {
              NVIDIA_VISIBLE_DEVICES = "all";
              NVIDIA_DRIVER_CAPABILITIES = "all";
            }
            else {}
          );
        labels =
          containerCfg.labels
          // {
          };

        extraOptions =
          [
            "--userns=keep-id"
            "--security-opt"
            "label=disable"
          ]
          ++ containerCfg.additionalFlags;
      };
      systemd.services = let
        extractIcons = {
          pkgs,
          containerManager,
          containerName,
          appName,
        }:
          builtins.readFile
          pkgs.writeShellScript "extract-${appName}-desktop-files" ''
            # Define paths based on DISTROBOX_APP_DESKTOP (which is always set now)
            DESKTOP_DIR="''${DISTROBOX_APP_DESKTOP}/desktop"
            ICONS_DIR="''${DISTROBOX_APP_DESKTOP}/icons"
            mkdir -p "''${DESKTOP_DIR}"
            mkdir -p "''${ICONS_DIR}"

            extract_desktop_files_and_icons() {
              local container_id="$1"
              local export_application="$2"

              local desktop_files
              desktop_files=$(${containerManager} exec "''${container_id}" find /usr/share/applications /usr/local/share/applications /var/lib/flatpak/exports/share/applications -type f -name "*.desktop" 2>/dev/null | xargs ${containerManager} exec "''${container_id}" grep -l "Exec=.*''${export_application}.*" 2>/dev/null)

              if [ -z "''${desktop_files}" ]; then
                echo "Error: No desktop files found for application ''${export_application}."
                return 127
              fi

              for desktop_file in ''${desktop_files}; do
                ${containerManager} cp "''${container_id}:''${desktop_file}" "''${DESKTOP_DIR}/"

                local icon_name
                icon_name=$(${containerManager} exec "''${container_id}" grep -E '^Icon=' "''${desktop_file}" | cut -d'=' -f2-)

                if [ -n "''${icon_name}" ]; then
                  local icon_files
                  icon_files=$(${containerManager} exec "''${container_id}" find /usr/share/icons /usr/share/pixmaps /var/lib/flatpak/exports/share/icons -iname "*''${icon_name}*" 2>/dev/null)
                  for icon_file in ''${icon_files}; do
                    ${containerManager} cp "''${container_id}:''${icon_file}" "''${ICONS_DIR}/"
                  done
                fi
              done

              echo "Application ''${export_application} desktop files and icons extracted successfully."
            }

            extract_desktop_files_and_icons "${containerName}" "${appName}"
          '';
      in (
        lib.listToAttrs (map (appName: {
            name = "extract-desktop-${appName}";
            value = {
              description = "Extract ${appName} desktop files from container";
              after = ["${serviceName}.service"];
              wants = ["${serviceName}.service"];
              environment = variables;
              serviceConfig = {
                Type = "oneshot";
                ExecStart = "${extractScript appName}";
                ExecStartPost = "${pkgs.gtk3}/bin/gtk-update-icon-cache -f ~/.local/share/icons";
                Restart = "on-failure";
              };
            };
          })
          containerCfg.exportApps)
        // {
          ${serviceName} = {
            postStart = let
            in ''
                # Start the container
                # ${cfg.backend} start ${containerName}
                # Install nix inside the container
                ${pkgs.curl} --proto '=https' --tlsv1.2 -sSf -L https://install.lix.systems/lix -o lix-install.sh
                ${containerManager} cp lix-install.sh ${containerName}:/tmp/lix-install.sh
                ${containerManager} exec ${containerName} sh -c "if ! command -v nix > /dev/null 2>&1; then echo Installing Nix...; sh /tmp/lix-install.sh | sh; fi"
                # Install additional packages inside the container
                ${concatMapStringsSep "\n" (pkg: ''
                  ${containerManager} exec ${name} sh -c "if ! command -v ${pkg} > /dev/null 2>&1; then echo Installing ${pkg}...; nix profile install nixpkgs#${pkg}; fi"
                '')
                containerCfg.additionalPackages}

              # Export applications from the container to the host
              ${concatMapStringsSep "\n" (app: ''
                  # ${containerManager} exec ${name} sh -c "distrobox-export --app ${app}"
                '')
                containerCfg.exportApps}

              # Export binaries from the container to the host
              ${concatMapStringsSep "\n" (bin: ''

                  # ${containerManager} exec ${name} sh -c "distrobox-export --bin ${bin} --export-path /usr/local/bin"
                '')
                containerCfg.exportBinaries}
            '';
            # serviceConfig = {
            #   ExecStartPost = [
            #     # Command to execute after the container starts
            #     # Replace the following with your desired command
            #     "${pkgs.bash}/bin/bash -c 'echo Container ${containerName} has started'"
            #   ];
            # };
          };
        }
      );
      environment = {
        inherit variables;
        systemPackages =
          (map (bin:
            distroBinWrapper {
              inherit containerManager containerName;
              binName = bin;
            })
          containerCfg.exportBinaries)
          ++ (map (app:
            distroAppWrapper {
              inherit containerManager containerName;
              appName = app;
            })
          containerCfg.exportApps);
      };
    })
    cfg.containers);
}
