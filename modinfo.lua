-- Mod Settings
name = "Super Hound Waves"
description = "Are the occasional Hound attack getting boring? Try this out. Each hound attack will instead" ..
              " be an attack from a random mob selected from the configuration file.\n" ..
			  "Surprises await those brave enough to try it out."
author = "KingofTown"
version = "1.4"
forumthread = "None"
icon_atlas = "modicon.xml"
icon = "modicon.tex"
priority = 2


-- Compatibility
dst_compatible = true
api_version = 10

configuration_options =
{
	{
		name = "hound",
		label = "Hounds",
		options =	{
						{description = "On", data = "default"},
						{description = "Off", data = "off"},
					},
		default = "default",
	},
    {
		name = "merm",
		label = "Mermen",
		options =	{
						{description = "On", data = "default"},
						{description = "Off", data = "off"},
					},
		default = "default",
	},
	{
		name = "tallbird",
		label = "Tallbirds",
		options =	{
						{description = "On", data = "default"},
						{description = "Off", data = "off"},
					},
		default = "default",
	},
	{
		name = "pigman",
		label = "Pigmen",
		options =	{
						{description = "On", data = "default"},
						{description = "Off", data = "off"},
					},
		default = "default",
	},
	{
		name = "spider",
		label = "Spiders",
		options =	{
						{description = "On", data = "default"},
						{description = "Off", data = "off"},
					},
		default = "default",
	},
	{
		name = "killerbee",
		label = "Killer Bees",
		options =	{
						{description = "On", data = "default"},
						{description = "Off", data = "off"},
					},
		default = "default",
	},
	{
		name = "mosquito",
		label = "Mosquitos",
		options =	{
						{description = "On", data = "default"},
						{description = "Off", data = "off"},
					},
		default = "default",
	},
	{
		name = "lightninggoat",
		label = "Lightning Goats",
		options =	{
						{description = "On", data = "default"},
						{description = "Off", data = "off"},
					},
		default = "default",
	},
	{
		name = "beefalo",
		label = "Beefalo",
		options =	{
						{description = "On", data = "default"},
						{description = "Off", data = "off"},
					},
		default = "default",
	},
	{
		name = "knight",
		label = "Clockwork Knights",
		options =	{
						{description = "On", data = "default"},
						{description = "Off", data = "off"},
					},
		default = "default",
	},
	{
		name = "perd",
		label = "Turkeys",
		options =	{
						{description = "On", data = "default"},
						{description = "Off", data = "off"},
					},
		default = "default",
	},
	{
		name = "penguin",
		label = "Penguins!",
		options =	{
						{description = "On", data = "default"},
						{description = "Off", data = "off"},
					},
		default = "default",
	},
	{
		name = "walrus",
		label = "Walrus Hunting Party!",
		options =	{
						{description = "On", data = "default"},
						{description = "Off", data = "off"},
					},
		default = "default",
	},
	
	
}