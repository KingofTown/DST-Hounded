local Vector3 = GLOBAL.Vector3
local dlcEnabled = GLOBAL.IsDLCEnabled(GLOBAL.REIGN_OF_GIANTS)
local SEASONS = GLOBAL.SEASONS
local ipairs = GLOBAL.ipairs

--[[ Table is as follows:
        enabled: is this a valid prefab to use (DLC restrictions or config file)
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
        
--]]
local MOB_LIST =
{
    [1]  = {prefab="hound",
              enabled=true
           }, -- No changes here...same old hounds
    [2]  = {prefab="merm",
              enabled=true,
              brain="mermbrain",
              mobMult=1,
              timeMult=1.5,
              healthMult=.5, 
              damageMult=.8
           },
    [3]  = {prefab="tallbird",
              enabled=true,
              brain="tallbirdbrain",
              mobMult=.75,
              timeMult=1.2,
              healthMult=.5
            },
    [4]  = {prefab="pigman",
              enabled=true,
              brain="pigbrain",
              mobMult=1,
              timeMult=1
            },
    [5]  = {prefab="spider",
              enabled=true,
              brain="spiderbrain",
              mobMult=1.7,
              timeMult=.5
            },
    [6]  = {prefab="killerbee",
              enabled=true,
              brain="killerbeebrain",
              mobMult=2.2,
              timeMult=.1
            },
    [7]  = {prefab="mosquito",
              enabled=true,
              brain="mosquitobrain",
              mobMult=2.5,
              timeMult=.15
            }, 
    [8]  = {prefab="lightninggoat",
              enabled=true,
              brain="lightninggoatbrain",
              mobMult=.75,
              timeMult=1.25, 
              healthMult=.5
            }, 
    [9]  = {prefab="beefalo",
              enabled=true,
              brain="beefalobrain",
              mobMult=.75,
              timeMult=1.5,
              healthMult=.5
            },
    [10] = {prefab="bat",
              enabled=false,
              brain="batbrain",
              CaveState="open",
              mobMult=1,
              timeMult=1
            }, -- No caves in DST...no bats
    [11] = {prefab="rook",
              enabled=false, -- These dudes just get lost. Probably need to check their braincode
              brain="rookbrain",
              mobMult=1,
              timeMult=1,
              healthMult=.33
           },
    [12] = {prefab="knight",
              enabled=true,
              brain="knightbrain",
              mobMult=1,
              timeMult=1.5,
              healthMult=.33
           }, 
    [13] = {prefab="mossling",
              enabled=false, -- Needs work. They wont get enraged. Also spawns moosegoose....so yeah
              brain="mosslingbrain",
              Season={SEASONS.SPRING},
              mobMult=1,timeMult=1,
              healthMult=.66
           }, 
	  [14] = {prefab="perd",
	            enabled=true,
          	  brain="perdbrain",
          	  mobMult=2.5,
          	  timeMult=.25
        	  },
	  [15] = {prefab="penguin",
	            enabled=true,
          	  brain="penguinbrain",
          	  Season={SEASONS.WINTER},
          	  mobMult=2.5,
          	  timeMult=.35,
          	  damageMult=.5
        	  },
	  [16] = {prefab="walrus",
	            enabled=true,
          	  brain="walrusbrain",
          	  Season={SEASONS.WINTER},
          	  mobMult=.33,
          	  timeMult=3,
          	  healthMult=.5
          	},
    [17] = {prefab="warg", -- Varg
              enabled=true,
              brain="wargbrain",
              minAgeDays=40,
              mobMult=.1,
              timeMult=3,
              healthMult=.2, -- 180 health
              healthScale=true, -- 
              damageMult=.5  -- 25 damage per attack
            },
    [18] = {prefab="spider_hider", -- Cave Spiders
              enabled=true,
              surface="cave",
              healthMult=.84, -- 125 health
              mobMult=3.2,   -- This is compared against worm spawn rates.
              timeMult=.5
            },
    [19] = {prefab="worm", -- Cave Worms
              enabled=true,
              surface="cave"
           },
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
			end
		end
		-- Update the list with the new ones
		GLOBAL.TheWorld.components.hounded:SetMobList(MOB_LIST)
	end
end
AddSimPostInit(disableMobs)

--------------------------------------------------
-- Brain Modifications
--------------------------------------------------


--[[ Make this the top of the priority node. If a mob has the 'houndedKiller'
     tag, then they should act like mindless killers
--]]
local function MakeMobChasePlayer(brain)

    local function KillKillDieDie(inst)
		-- Chase for 60 seconds, target distance 60
        return GLOBAL.ChaseAndAttack(inst,60,60)
    end
    
	attackWall = GLOBAL.WhileNode(function() return brain.inst:HasTag("houndedKiller") end, "Get The Coward", GLOBAL.AttackWall(brain.inst) )
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
        AddBrainPostInit(v.brain,MakeMobChasePlayer)
    end
end


