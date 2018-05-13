
# LoupGG 

Loups-Garous GMOD (LoupGG or LGG) is a gamemode for Garry's Mod inspired from [Les Loups-Garous de Thiercelieux](https://fr.wikipedia.org/wiki/Les_Loups-garous_de_Thiercelieux) created by [Philippe des Pallières](https://fr.wikipedia.org/wiki/Philippe_des_Palli%C3%A8res) and [Hervé Marly](https://fr.wikipedia.org/wiki/Herv%C3%A9_Marly).
The project is completely open-source.

- Support Pointshop and Pointshop2

## Links

* group steam: http://steamcommunity.com/groups/LoupGG
* discord: https://discord.gg/q8QdfrX
* map: http://steamcommunity.com/sharedfiles/filedetails/?id=966255479
* addons: http://steamcommunity.com/workshop/filedetails/?id=971572823

### Servers

The gamemode is "LoupGG" in the Gmod server list.

## Installation

Copy the `loupgg` folder to your `gamemodes` directory, like any other gamemode.
To use another language than the default english, for example french, you need to edit the file `cfg/shared.lua` and change the `lang` variable to the correct language (a file named `<lang>.lua` must be present in `gamemode/lang/`.

You will need the addons collection for the server and the clients.
You will also need a way to have the superadmin Gmod permission to execute superadmin commands (something like ulx).


## Configuration

Everything is in the `cfg/` directory, `cfg/server.lua`, `cfg/client.lua` and `cfg/shared.lua`.
Never put credentials in shared and client.

The custom official map is `lgg_village_v1a`, but any map can work with the gamemode, once configured.

To configure each map, you can copy files inside `data/loupgg/maps/` from this repository (`maps/`) if they exists or use the command `/lgg savemap` in game after placing airboat seats for the villager seats and huladolls for each house spawns.

## Gameplay

The optimal number of players is currently 16, 8 should be a minimum to have a decent gameplay, 4 is the hardcoded minimum.

The conditions for hearing someone are used for chat and voice interactions, so it's also possible to play without mic, even if far less interesting.

### Roles

List of roles availables in the gamemode, with a short description:

* `Villager`: simple villager, no powers, goal is to survive
* `Werewolf`: can vote each night with other werewolves to devour someone, goal is to kill everyone
* `Sorcerer`: have two disposables items, a life potion to resurrect someone after the werewolf vote, a death potion to kill someone, goal is to survive with the villagers
* `Savior`: can protect someone from the werewolves each night, goal is to survive with the villagers
* `Seer`: can discover someone's role every night, goal is to survive with the villagers
* `Hunter`: when killed, will be able to kill someone (in a short duration) as a last stand (after day vote with a GUI selection, after a night death as a day last stand with the shotgun), goal is to survive with the villagers
* `Cupid`: when the game starts, will be able to create a relationship between two players, goal is to survive with the villagers
* `Sister`: same house between sisters, can talk with the other at night, goal is to survive with the villagers
* `Shaman`: can hear the deads at night, goal is to survive with the villagers
* `Little girl`: can hear werewolves at night, goal is to survive with the villagers

### Special states

List of states in the gamemode, with a short description:

* `Lover`: lovers will be in the same house and be able to talk at night, but will die if the other dies, they bypass their basic role goal and try to be the last alives in the village
* `Dead`: you can talk to the shaman at night if there is one
