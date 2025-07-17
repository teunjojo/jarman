# jarman

[![GitHub Release](https://img.shields.io/github/v/release/teunjojo/yapm?style=for-the-badge)](https://github.com/teunjojo/jarman/releases)

![Platforms](https://img.shields.io/badge/Supported_platforms-gray?style=for-the-badge)&nbsp;&nbsp;
![Spigot](https://img.shields.io/badge/Spigot-ED8106?style=for-the-badge&logo=spigotmc&logoColor=fff)&nbsp;
![Fabric](https://img.shields.io/badge/Fabric-BCB29C?style=for-the-badge)&nbsp;
![NeoForge](https://img.shields.io/badge/Neo-Forge-bdc7c7?style=for-the-badge&labelColor=d7742f)&nbsp;

![Sources](https://img.shields.io/badge/Supported_Sources-gray?style=for-the-badge)&nbsp;&nbsp;
[![Jenkins](https://img.shields.io/badge/Jenkins-D24939?style=for-the-badge&logo=jenkins&logoColor=fff)](https://www.jenkins.io/)
[![GitHub Releases](https://img.shields.io/badge/Github_Releases-181717?style=for-the-badge&logo=github&logoColor=fff)](https://docs.github.com/en/repositories/releasing-projects-on-github)
[![GitHub Releases](https://img.shields.io/badge/Modrinth-00AF5C?style=for-the-badge&logo=modrinth&logoColor=fff)](https://modrinth.com/)

## Note: This is still in early Beta so it may contain bugs and lack features

Jarman is a JAR update manager bash script designed for modified Minecraft versions like [SpigotMC](https://www.spigotmc.org/), [Fabric](https://fabricmc.net/), [NeoForge](https://neoforged.net/) etc.

Jarman is designed to check and download updates for plugins/mods from many different sources.

## Supported sources

Checked sources are currently supported.

Unchecked sources are planned to be supported in the future.

- [x] Jenkins
- [x] Github Releases
- [x] Modrinth
- [ ] SpigotMC

## Installation

### Method 1 (using git)

Clone this repository

``` bash
git clone https://github.com/teunjojo/jarman.git
```

### Method 2

1. Download this [zip](https://github.com/teunjojo/jarman/archive/refs/heads/main.zip)
2. Unzip it

## Usage

This script is portable an can be run from anywhere.

Its recommended to remove versions from your JAR files.
For example: `EssentialsX-2.21.2-dev+27-cc25a79.jar` -> `EssentialsX.jar`
While this is not necessary, it helps prevent confusion and helps things stay clean.

Start the script using the following command.

```bash
./jarman.sh /path/to/directory
```

It will list the found JAR files including their status. The following is an example of what that could look like.

```console
$ ./jarman.sh ~/mcserver/plugins/
JAR files in '/home/teuntje/mcserver/plugins/':
 - EssentialsX.jar [Outdated] (1690 -> 1691)
 - LuckPerms-Bukkit.jar [Outdated] (1593 -> 1594)
 - PlaceholderAPI.jar [Up to date] (212)
 - ProtocolLib.jar [Outdated] (752 -> 753)
 - Vualt.jar [Unmanaged]
```

Common statuses are:

- `[Up to Date]` : It is up to date.
- `[Outdated]`: There is a newer version available.
- `[Unmanaged]`: This file is not managed by jarman

The script will start scanning for JAR files. When a new one is detected it will give you the option to register it. The following is an example of what the JAR registration process can look like.

```console
----------------------------------------
Unregistered JAR file found!
Do you want to register 'EssentialsXChat.jar'? [Y/n] y
What is the JAR file update type? [jenkins]: jenkins
What is the update URL? [<Jenkins URL>/job/<Project>]: https://ci.ender.zone/job/EssentialsX/
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

In the above example, a new unregistered JAR file is found called: `EssentialsXChat.jar`. When asked if we want to registered it, `y` (for yes) is entered. Then it will ask which artifact should be chosen. `2` is entered to select artifact `EssentialsXChat-2.21.2-dev+27-cc25a79.jar`

Next jarman will try to update outdated JAR files. First it will ask the user if they want to exclude JAR files from the update. Next it will show a list of the JAR files that will be updated and ask the user to confirm their choice.
 The following is an example of how that may look.

```console
----------------------------------------
JAR files to update:
 [0] EssentialsXChat.jar
 [1] EssentialsX.jar
 [2] LuckPerms-Bukkit.jar
 [3] ProtocolLib.jar
JAR files to EXCLUDE from update (separated by space) [eg: "0 1"]: 0 2
```

In the above example, `0 2` is entered to exclude `EssentialsXChat.jar` and `LuckPerms-Bukkit.jar` and only update `EssentialsX.jar` and `ProtocolLib.jar`

After hitting enter the user will be asked to confirm their selection and the JAR files will be updated.

```console
----------------------------------------
Updating the following JAR files:
 - EssentialsX.jar
 - ProtocolLib.jar
Do you want to continue? [Y/n]: y
----------------------------------------
Updating JAR files...
EssentialsX.jar...Done
ProtocolLib.jar...Done
```

Here `y` is enter to confirm and start updating the JAR files.
