# RoR2 unofficial dedicated server container

Proton container and Helm chart for the [unofficial dedicated server plugin](https://github.com/zdiemer/ror2-unofficial-dedicated-server). The image includes GE-Proton, BepInEx, and the plugin DLL. It does **not** include Risk of Rain 2 game files or DLC. Supply your own current Windows game install as a read-only mount or Kubernetes PVC.

This is experimental. The homelab Proton deployment boots without Steam desktop,
loads the plugin, and binds UDP 7777. A tailnet client connected, readied in the
lobby, and started a run. Game-over and disconnect reset remain unverified. The
current direct-IP path does not validate Steam tickets; use a trusted network.

## Build the image

The checked-in `plugin/Ror2UnofficialDedicatedServer.dll` comes from the companion repository's Release build. After changing that repository, rebuild it against your installed game assemblies and copy the new DLL here before building the image.

```sh
docker build -t ror2-unofficial-dedicated-server:local .
```

The Dockerfile pins [GE-Proton11-7](https://github.com/GloriousEggroll/proton-ge-custom/releases/tag/GE-Proton11-7) and checks its published SHA-512. It installs [BepInEx 5.4.23.5](https://github.com/BepInEx/BepInEx/releases/tag/v5.4.23.5). The Windows BepInEx loader is used under Proton.

## Run with Docker

Copy your game install to a directory on the Linux host, then mount that directory read-only. The container makes a writable copy at startup, so allow at least 8 GiB of free scratch space and several GiB of RAM.

```sh
docker run --rm --init \
  -p 7777:7777/udp \
  -v /srv/ror2/game:/game-src:ro \
  --tmpfs /work:rw,exec,size=8g,mode=1777 \
  ror2-unofficial-dedicated-server:local
```

For mods, mount a JSON file at `/config/mods.json` and add one entry per server mod or dependency:

```json
[
  {
    "name": "ExampleServerMod",
    "url": "https://example.invalid/ExampleServerMod.zip",
    "sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  }
]
```

The ZIP is verified before extraction. An archive containing `BepInEx/` overlays that tree; other archives are installed below `BepInEx/plugins/<name>`. **Clients must remain unmodified:** this container never distributes mods to players. Only list server-side mods that work with the game's existing client protocol. Mods adding client assets, UI, or custom networking generally require matching client installs and are outside this project's supported scope. The [RoR2 modding wiki](https://risk-of-thunder.github.io/R2Wiki/Mod-Creation/C%23-Programming/Networking/Server-side-and-client-side-mods/) explains this distinction.

## Run with Helm

Create a PVC containing the **Windows** game install at its root. The Pod mounts it read-only at `/game-src`. Build and push this image to a registry your cluster can access, then create `values.local.yaml`:

```yaml
image:
  repository: registry.example.net/ror2-unofficial-dedicated-server
  tag: local
game:
  existingClaim: ror2-game-files
service:
  type: NodePort
  nodePort: 30777
mods:
  - name: ExampleServerMod
    url: https://example.invalid/ExampleServerMod.zip
    sha256: 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
```

```sh
helm upgrade --install ror2 ./charts/ror2-server -f values.local.yaml
kubectl logs deployment/ror2-ror2 -f
```

Forward UDP 30777 to a cluster node, then use `connect "NODE_IP:30777"` in the game console. The chart uses one replica and `Recreate` strategy to avoid two servers sharing a game PVC. Changing the `mods` list rolls the Pod. Each listed mod is downloaded and applied on startup; pin ZIP checksums so restarts use the same content.

The plugin's `Port`, `MaxPlayers`, and game-over return delay come from `server` values. `service.nodePort` can differ from `server.port` because Kubernetes forwards UDP to the container port. The chart's readiness probe waits until the plugin logs an initialized, active server.

If the game install is a folder within a shared PVC, set `game.subPath` to that
folder's path within the claim. On clusters that publish the game port on node
IPs, set `service.type: LoadBalancer`; `service.externalTrafficPolicy` defaults
to `Cluster`. Keep the direct-IP listener on a trusted network while the plugin
does not validate Steam tickets.

For a large install, enable `work.persistence` with a storage class and size
large enough for the game and Proton prefix. Startup stages the game once and
reuses it on later pod starts. After updating the source install, bump
`game.revision` to replace the staged copy. The work claim is excluded from
backups because its contents can be rebuilt from the source game install.
