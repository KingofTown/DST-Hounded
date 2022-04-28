-- Mod Settings
name = "Super Hound Waves (Local)"
description = "Are the occasional Hound attack getting boring? Try this out. Each hound attack will instead" ..
              " be an attack from a random mob selected from the configuration file.\n" ..
			  "Surprises await those brave enough to try it out.\n\n" ..
			  "Configuration Notes:\n" ..
			  "Normal - mob has a chance to spawn with some enhancements (fire/ice/were/charged/etc).\n" ..
			  "No Enhanced - mob has a chance to spawn, normal versions only.\n" ..
			  "Always Enhanced - mob has a chance to spawn, will always be the enhanced version only.\n" ..
			  "Off - mob will not be picked to spawn\n"

author = "KingofTown"
version = "4.0"
forumthread = "None"
icon_atlas = "modicon.xml"
icon = "modicon.tex"
priority = -3


-- Compatibility
dst_compatible = true
api_version = 10

configuration_options =
{
	{
		name = "Enabled",
		label = "Hound Waves Enabled",
		options =	{
						{description = "true", data = "true"},
						{description = "false", data = "false"},
					},
		default = "true",
	},
	{
		name = "hound",
		label = "Hounds",
		options =	{
						{description = "Normal", data = "default"},
						{description = "No Enhanced", data = "on_no_ele"},
						{description = "Always Enhanced", data = "on_always_ele"},
						{description = "Off", data = "off"},
					},
		default = "default",
	},
    {
		name = "merm",
		label = "Mermen",
		options =	{
						{description = "Normal", data = "default"},
						{description = "No Enhanced", data = "on_no_ele"},
						{description = "Always Enhanced", data = "on_always_ele"},
						{description = "Off", data = "off"},
					},
		default = "default",
	},
	{
		name = "tallbird",
		label = "Tallbirds",
		options =	{
						{description = "Normal", data = "default"},
						{description = "No Enhanced", data = "on_no_ele"},
						{description = "Always Enhanced", data = "on_always_ele"},
						{description = "Off", data = "off"},
					},
		default = "default",
	},
	{
		name = "pigman",
		label = "Pigmen",
		options =	{
						{description = "Normal", data = "default"},
						{description = "No Enhanced", data = "on_no_ele"},
						{description = "Always Enhanced", data = "on_always_ele"},
						{description = "Off", data = "off"},
					},
		default = "default",
	},
	{
		name = "spider",
		label = "Spiders",
		options =	{
						{description = "Normal", data = "default"},
						{description = "No Enhanced", data = "on_no_ele"},
						{description = "Always Enhanced", data = "on_always_ele"},
						{description = "Off", data = "off"},
					},
		default = "default",
	},
	{
		name = "killerbee",
		label = "Killer Bees",
		options =	{
						{description = "Normal", data = "default"},
						{description = "No Enhanced", data = "on_no_ele"},
						{description = "Always Enhanced", data = "on_always_ele"},
						{description = "Off", data = "off"},
					},
		default = "default",
	},
	{
		name = "mosquito",
		label = "Mosquitos",
		options =	{
						{description = "Normal", data = "default"},
						{description = "No Enhanced", data = "on_no_ele"},
						{description = "Always Enhanced", data = "on_always_ele"},
						{description = "Off", data = "off"},
					},
		default = "default",
	},
	{
		name = "lightninggoat",
		label = "Lightning Goats",
		options =	{
						{description = "Normal", data = "default"},
						{description = "No Enhanced", data = "on_no_ele"},
						{description = "Always Enhanced", data = "on_always_ele"},
						{description = "Off", data = "off"},
					},
		default = "default",
	},
	{
		name = "beefalo",
		label = "Beefalo",
		options =	{
						{description = "Normal", data = "default"},
						{description = "No Enhanced", data = "on_no_ele"},
						{description = "Always Enhanced", data = "on_always_ele"},
						{description = "Off", data = "off"},
					},
		default = "default",
	},
	{
		name = "knight",
		label = "Clockwork Knights",
		options =	{
						{description = "Normal", data = "default"},
						{description = "No Enhanced", data = "on_no_ele"},
						{description = "Always Enhanced", data = "on_always_ele"},
						{description = "Off", data = "off"},
					},
		default = "default",
	},
	{
		name = "perd",
		label = "Turkeys",
		options =	{
						{description = "Normal", data = "default"},
						{description = "No Enhanced", data = "on_no_ele"},
						{description = "Always Enhanced", data = "on_always_ele"},
						{description = "Off", data = "off"},
					},
		default = "default",
	},
	{
		name = "penguin",
		label = "Penguins!",
		options =	{
						{description = "Normal", data = "default"},
						{description = "No Enhanced", data = "on_no_ele"},
						{description = "Always Enhanced", data = "on_always_ele"},
						{description = "Off", data = "off"},
					},
		default = "default",
	},
	{
		name = "walrus",
		label = "Walrus Hunting Party!",
		options =	{
						{description = "Normal", data = "default"},
						{description = "No Enhanced", data = "on_no_ele"},
						{description = "Always Enhanced", data = "on_always_ele"},
						{description = "Off", data = "off"},
					},
		default = "default",
	},
	{
	    name = "spider_hider",
	    label = "Cave Spiders (Caves Only)",
	    options = {
							{description = "Normal", data = "default"},
							{description = "No Enhanced", data = "on_no_ele"},
							{description = "Always Enhanced", data = "on_always_ele"},
							{description = "Off", data = "off"},
	          },
	    default = "default",
  	},
	{
		name = "warg",
		label = "Varg!",
		options =	{
						{description = "Normal", data = "default"},
						{description = "No Enhanced", data = "on_no_ele"},
						{description = "Always Enhanced", data = "on_always_ele"},
						{description = "Off", data = "off"},
					},
		default = "default",
	},
	{
	    name = "worm",
	    label = "Cave Worms",
	    options = {
							{description = "Normal", data = "default"},
							{description = "No Enhanced", data = "on_no_ele"},
							{description = "Always Enhanced", data = "on_always_ele"},
							{description = "Off", data = "off"},
	          },
	    default = "default",
	},
	{
	    name = "squid",
	    label = "SkitterSquid",
	    options = {
							{description = "Normal", data = "default"},
							{description = "No Enhanced", data = "on_no_ele"},
							{description = "Always Enhanced", data = "on_always_ele"},
							{description = "Off", data = "off"},
	          },
	    default = "default",
	},
	{
		name = "drop_mult",
		label = "Drop Rate Modifier",
		options = {
			{ description = "Normal" , data = 1.0},
			{ description = "Half",    data = 0.5},
			{ description = "None",    data = 0.0},
			{ description = "Double",  data = 2.0},
		},
		default = 1.0,
	},

}