local Vector3 = GLOBAL.Vector3
local dlcEnabled = GLOBAL.IsDLCEnabled(GLOBAL.REIGN_OF_GIANTS)
local SEASONS = GLOBAL.SEASONS
local ipairs = GLOBAL.ipairs

--[[ Table is as follows:
        enabled: is this a valid prefab to use (DLC restrictions or config file)
        elemental: normal, always, never, off
        prefab: prefab name
        brain: brain name. If a mob has this defined, will add a new PriorityNode to the brain to attack player.
               (leave this out if don't want to override brain function at all)
        CaveState: "open", "used", nil - This mob will only spawn when the cavestate condition is met. If not defined, ignore
        Season: restricts the season(s) this can come. If not defined...can come any season. 
        mobMult: multiplier compared to normal hound values (how many to release)
        timeMult: how fast these come out compared to normal hounds. 0.5 is twice as fast. 2 is half speed.
		    damageMult: how much damage it does compared to normal mob
		    healthMult: how much health it starts with relative to a normal version of it
		    healthScale: true/false - mob health increases to the group size/age
        surface: land, cave, both (Defaults to land only)
        minAgeDays: minimum average age of all players before considering spawning this
        specialVariation: prefab name of a type that has a chance to spawn instead
        specialVariationBrain: some of these have a different brain
        specialVariationRate: percent chance any given mob in wave will be that special type. If not set, will follow
                              the same probability as a fire/ice hound would have spawned...
        warning: "String that will be announced as warning for this mob..."

--]]
local MOB_LIST =
{
    [1]  = {prefab="hound",
              enabled=true,
              elemental=normal,
           }, -- No changes here...same old hounds
    [2]  = {prefab="merm",
              enabled=true,
              elemental=normal,
              brain="mermbrain",
              mobMult=1,
              timeMult=1.5,
              healthMult=.5, 
              damageMult=.8,
              warning="It smells like rotting fish!"
           },
    [3]  = {prefab="tallbird",
              enabled=true,
              elemental=normal,
              brain="tallbirdbrain",
              mobMult=.75,
              timeMult=1.5,
              healthMult=.4,
              warning="It sounds like a murder..."
            },
    [4]  = {prefab="pigman",
              enabled=true,
              elemental=normal,
              brain="pigbrain",
              mobMult=1,
              timeMult=1,
              warning="Was that an oink??"
            },
    [5]  = {prefab="spider",
              enabled=true,
              elemental=normal,
              brain="spiderbrain",
              mobMult=1.7,
              timeMult=.5,
              specialVariation="spider_warrior",
              warning="Sounds like a million tiny legs!"
            },
    [6]  = {prefab="killerbee",
              enabled=true,
              elemental=normal,
              brain="killerbeebrain",
              mobMult=2.2,
              timeMult=.1,
              warning="Beeeeeeeeeeeeeeees!!!!!"
            },
    [7]  = {prefab="mosquito",
              enabled=true,
              elemental=normal,
              brain="mosquitobrain",
              mobMult=2.5,
              timeMult=.15,
              warning="....tiny vampires!"
            }, 
    [8]  = {prefab="lightninggoat",
              enabled=true,
              elemental=normal,
              brain="lightninggoatbrain",
              mobMult=.75,
              timeMult=1.25, 
              healthMult=.5,
              warning="Those dark clouds look ominous..."
            }, 
    [9]  = {prefab="beefalo",
              enabled=true,
              elemental=normal,
              brain="beefalobrain",
              mobMult=.75,
              timeMult=1.5,
              healthMult=.5,
              warning="The ground is shaking!"
            },
    [10] = {prefab="bat",
              enabled=false,
              elemental=normal,
              brain="batbrain",
              CaveState="open",
              mobMult=1,
              timeMult=1,
              warning="Ahh! Bats???"
            }, -- No caves in DST...no bats
    [11] = {prefab="rook",
              enabled=false, -- These dudes just get lost. Probably need to check their braincode
              elemental=normal,
              brain="rookbrain",
              mobMult=1,
              timeMult=1,
              healthMult=.33,
              warning="Sounds like a train....or a bull...."
           },
    [12] = {prefab="knight",
              enabled=true,
              elemental=normal,
              brain="knightbrain",
              mobMult=1,
              timeMult=1.5,
              healthMult=.33,
              warning="The calvary are comming!"
           },
    [13] = {prefab="mossling",
              enabled=false, -- Needs work. They wont get enraged. Also spawns moosegoose....so yeah
              elemental=normal,
              brain="mosslingbrain",
              Season={SEASONS.SPRING},
              mobMult=1,timeMult=1,
              healthMult=.66
           },
	  [14] = {prefab="perd",
              enabled=true,
              elemental=normal,
              brain="perdbrain",
              mobMult=2.5,
              timeMult=.25,
              warning="Gobbles!!!"
            },
	  [15] = {prefab="penguin",
	            enabled=true,
              elemental=normal,
              brain="penguinbrain",
              Season={SEASONS.WINTER},
              mobMult=2.5,
              timeMult=.35,
              damageMult=.5,
              warning="Why do they always wear a tuxedo?"
            },
	  [16] = {prefab="walrus",
	            enabled=true,
              elemental=normal,
              brain="walrusbrain",
              Season={SEASONS.WINTER},
              mobMult=.33,
              timeMult=3,
              healthMult=.5,
              warning="The hunter becomes the hunted..."
            },
    [17] = {prefab="warg", -- Varg
              enabled=true,
              elemental=normal,
              brain="wargbrain",
              minAgeDays=40,
              mobMult=.1,
              timeMult=3,
              healthMult=.2, -- 180 health
              healthScale=true, -- 
              damageMult=.5,  -- 25 damage per attack
              warning="That one sounds bigger than the others..."
            },
    [18] = {prefab="spider_hider", -- Cave Spiders
              enabled=true,
              elemental=normal,
              surface="cave",
              healthMult=.84, -- 125 health
              mobMult=3.2,   -- This is compared against worm spawn rates.
              timeMult=.5,
              specialVariation="spider_spitter",
              warning="Spiders? Here???"
            },
    [19] = {prefab="worm", -- Cave Worms
              enabled=true,
              brain="wormbrain",
              elemental=normal,
              surface="cave"
           },
    [20] = {prefab="slurtle", -- Cave Worms
              enabled=true,
              brain="slurtlebrain",
              elemental=normal,
              surface="cave",
              warning="Slimey..."
           },
    [21] = {prefab="squid", -- Skittersquids
              enabled=true,
              brain="squidbrain",
              elemental=normal,
              surface="land",
              mobMult=1.5,
              timeMult=.8,
              healthMult=1,
              warning="Helecopters of DOOM!"
          }
} -- end MOB_LIST

-- Override the hounded component with our own
AddComponentPostInit("hounded",Class)


-- Check the config file to disable some of the mobs
local function disableMobs()
	if GLOBAL.TheWorld.ismastersim then
		for k,v in pairs(MOB_LIST) do
			-- Get the config data for it
			local enabled = GetModConfigData(v.prefab)
			if enabled ~= nil and enabled == "off" then
				print("Disabling " .. v.prefab .. " due to config setting")
				MOB_LIST[k].enabled = false
      elseif enabled ~= nil and enabled == "on_no_ele" then
        print("Removing elemental chance for " .. v.prefab)
        MOB_LIST[k].elemental = "never"
      elseif enabled ~= nil and enabled == "on_always_ele" then
        print("Setting " .. v.prefab .. " to always elemental")
        MOB_LIST[k].elemental = "always"
			end
		end
		-- Update the list with the new ones
    GLOBAL.TheWorld.components.hounded:SetMobList(MOB_LIST)
    drop_mult = GetModConfigData("drop_mult")
    if drop_mult ~= nil then
      GLOBAL.TheWorld.components.hounded:SetDropRate(drop_mult)
    end
	end
end
AddSimPostInit(disableMobs)
--AddComponentPostInit()

--------------------------------------------------
-- Brain Modifications
--------------------------------------------------

--[[ 
    GLOBAL function - injects a few simple nodes to make any mob a mindless killer. 
--]]
GLOBAL.MakeMobChasePlayer = function(brain)

  local function KillKillDieDie(inst)
    -- Chase for 60 seconds, target distance 60
    return GLOBAL.ChaseAndAttack(inst,60,60)
  end

  attackWall = GLOBAL.WhileNode(function() return brain.inst:HasTag("houndedKiller") end, "Get The Coward", GLOBAL.AttackWall(brain.inst))
  chaseAndKill = GLOBAL.WhileNode(function() return brain.inst:HasTag("houndedKiller") end, "Kill Kill", KillKillDieDie(brain.inst))

  -- Find the root node. Insert this WhileNode at the top.
  -- Well, we'll put it after "OnFire" (if it exists) so it will still panic if on fire
  local fireindex = 0
  for i,node in ipairs(brain.bt.root.children) do
    if node.name == "Parallel" and node.children[1].name == "OnFire" then
      fireindex = i
    end
  end

  -- Let warg summon children
  -- Blindly put it one further after the summon node...
  if(brain.inst.prefab == "warg") then
    fireindex = fireindex + 1
  end


  -- Tell the brain "Attack the player...unless there is a wall in the way, get that instead"
	table.insert(brain.bt.root.children, fireindex+1, chaseAndKill)
	table.insert(brain.bt.root.children, fireindex+1, attackWall)
end

-- Insert this brain for each mob that has it defined in MOB_LIST
for k,v in pairs(MOB_LIST) do
  if v.brain then
    AddBrainPostInit(v.brain,GLOBAL.MakeMobChasePlayer)
  end

  if v.SpecialVariationBrain then
    AddBrainPostInit(v.SpecialVariationBrain, GLOBAL.MakeMobChasePlayer)
  end
end

-- Check if another mod is loaded
-- Can do it by workshop id or name
-- Workshop ID: IsModEnabled("workshop-544126369")
-- By Name: IsModEnabled(GLOBAL.KnownModIndex:GetModActualName("Super Hound Waves"))

local function AddToHoundedMod()
  -- Define a mob, look at modinfo.lua in workshop-544126369 for the full list of things that can be set.
  myMob = {
    prefab = "perd",
    enabled=true,
    elemental=normal, -- never, normal, always
    mobMult=5, -- percentage of mobs to spawn relative to how many hounds would hve
    timeMult=1.0, -- rate at which they spawn (relative to what hounds would have)
    healthMult=.5, -- percent of health they start with
    specialVariation="spider",
    specialVariationRate=.8,
    warning = "AHHHHHHHHHHHHHHHHH"
  }

  print("Adding custom mob: " .. myMob.prefab)
  GLOBAL.TheWorld.components.hounded:AddCustomMob(myMob)
end

-- EXAMPLE: Loading this from a separate mod to add a custom mob to Super Hound Waves
-- If this mod is enabled, add some things to it. 
-- if GLOBAL.KnownModIndex:IsModEnabled("workshop-544126369") then
--   -- Tell the sim to add our stuff after it's done with init. 
--   AddSimPostInit(
--     function()
--       -- Define the mob
--       myMob = {
--         prefab = "wobster_sheller_land",
--         brain = "wobsterlandbrain",
--         enabled=true,
--         specialVariation="wobster_moonglass_land",
--         specialVariationRate=0.4,
--         warning = "CRAAAAaaaAAb"
--       }
--       -- Add it to hounded
--       GLOBAL.TheWorld.components.hounded:AddCustomMob(myMob)
--     end
--   )
--   -- This global function is declared in hounded mod. Make sure any custom brains get the special sauce added. 
--   AddBrainPostInit("wobsterlandbrain", GLOBAL.MakeMobChasePlayer)
-- end
