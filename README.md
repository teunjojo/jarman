![GitHub Release](https://img.shields.io/github/v/release/teunjojo/yapm?style=for-the-badge)

![Compatible with](https://img.shields.io/badge/Compatible_with-gray?style=for-the-badge)
![Jenkins](https://img.shields.io/badge/Jenkins-D24939?style=for-the-badge&logo=jenkins&logoColor=fff)
# Yet Another Plugin Manager
## Note: This is still in early Beta so it may contain bugs and lack features.

Yet Another Plugin Manager (YAPM) is a Plugin Manager bash script for Bukkit/Spigot/Paper plugins.
This would technically also work for fabric/forge mods since it just downloads jar files.

YAPM is designed to check and download plugin updates from many different sources.

## Supported sources
###### Checked sources are currently supported
- [x] Jenkins
- [ ] Github Releases
- [ ] SpigotMC
- [ ] Modrinth

# Installation
## Method 1 (using git)
Clone this repository 
```
git clone https://github.com/teunjojo/yapm.git
```

## Method 2
1. Download this [zip](https://github.com/teunjojo/yapm/archive/refs/heads/main.zip)
2. Unzip it

## Usage
This script is portable an can be run from anywhere.

Its recommended to remove versions from your plugin artifacts.
For example: `EssentialsX-2.21.2-dev+27-cc25a79.jar` -> `EssentialsX.jar`
While this is not necessary, it helps prevent confusion and helps things stay clean.

Start the script using the following command.

```bash
./YAPM.sh /path/to/plugins-directory
```

It will list the found plugins including their status. The following is an example of what that could look like.

```console
$ ./YAPM.sh ~/mcserver/plugins/
Plugins in '/home/teuntje/mcserver/plugins/':
 - EssentialsX.jar [Outdated] (1690 -> 1691)
 - LuckPerms-Bukkit.jar [Outdated] (1593 -> 1594)
 - PlaceholderAPI.jar [Up to date] (212)
 - ProtocolLib.jar [Outdated] (752 -> 753)
 - Vualt.jar [Unmanaged]
```

Common statuses are:

- `[Up to Date]` : The plugin is up to date.
- `[Outdated]`: There is a newer version available for this plugin.
- `[Unmanaged]`: This plugin is not managed by YAPM

The script will start scanning for plugins. When a new one is detected it will give you the option to register it. The following is an example of what the plugin registration process can look like.

```console
----------------------------------------
Unregistered Plugin found!
Do you want to register 'EssentialsXChat.jar'? [Y/n] y
What is the plugin update type? [jenkins]: jenkins
What is the update URL? [<Jenkins URL>/job/<Plugin>]: https://ci.ender.zone/job/EssentialsX/
Available artifacts: 
 1) EssentialsX-2.21.2-dev+27-cc25a79.jar
 2) EssentialsXAntiBuild-2.21.2-dev+27-cc25a79.jar
 3) EssentialsXChat-2.21.2-dev+27-cc25a79.jar
 4) EssentialsXDiscord-2.21.2-dev+27-cc25a79.jar
 5) EssentialsXDiscordLink-2.21.2-dev+27-cc25a79.jar
 6) EssentialsXGeoIP-2.21.2-dev+27-cc25a79.jar
 7) EssentialsXProtect-2.21.2-dev+27-cc25a79.jar
 8) EssentialsXSpawn-2.21.2-dev+27-cc25a79.jar
 9) EssentialsXXMPP-2.21.2-dev+27-cc25a79.jar
Select the number of the artifact: [0]: 2
----------------------------------------
 - EssentialsXChat.jar [Outdated] (unknown -> 1691)
```

In the above example, a new unregistered plugin is found called: `EssentialsXChat.jar`. When asked if we want to registered it, `y` (for yes) is entered. Then it will ask which artifact should be chosen. `2` is entered to select artifact `EssentialsXChat-2.21.2-dev+27-cc25a79.jar`

Next the plugin will try to update outdated plugins. First it will ask the user if they want to exclude plugins from the update. Next it will show a list of the plugins that will be updated and ask the user to confirm their choice.
 The following is an example of how that may look.

```console
----------------------------------------
Plugins to update:
 [0] EssentialsXChat.jar
 [1] EssentialsX.jar
 [2] LuckPerms-Bukkit.jar
 [3] ProtocolLib.jar
Plugins to EXCLUDE from update (separated by space) [eg: "0 1"]: 0 2
```

In the above example, `0 2` is entered to exclude `EssentialsXChat.jar` and `LuckPerms-Bukkit.jar` and only update `EssentialsX.jar` and `ProtocolLib.jar`

After hitting enter the plugins the user will be asked to confirm their selection and the plugins will be updated.

```console
----------------------------------------
Updating the following plugins:
 - EssentialsX.jar
 - ProtocolLib.jar
Do you want to continue? [Y/n]: y
----------------------------------------
Updating plugins...
EssentialsX.jar...Done
ProtocolLib.jar...Done
```

Here `y` is enter to confirm and start updating the plugins.
