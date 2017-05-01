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
        surface: land, cave, both (Defaults to land only)
        minAgeDays: minimum average age of all players before considering spawning this
        
--]]
local MOB_LIST =
{
    [1]  = {enabled=true,prefab="hound"}, -- No changes here...same old hounds
    [2]  = {enabled=true,prefab="merm",brain="mermbrain",mobMult=1,timeMult=1.5,healthMult=.5, damageMult=.8},
    [3]  = {enabled=true,prefab="tallbird",brain="tallbirdbrain",mobMult=.75,timeMult=1.2,healthMult=.5},
    [4]  = {enabled=true,prefab="pigman",brain="pigbrain",mobMult=1,timeMult=1},
    [5]  = {enabled=true,prefab="spider",brain="spiderbrain",mobMult=1.7,timeMult=.5},
    [6]  = {enabled=true,prefab="killerbee",brain="killerbeebrain",mobMult=2.2,timeMult=.1},
    [7]  = {enabled=true,prefab="mosquito",brain="mosquitobrain",mobMult=2.5,timeMult=.15}, 
    [8]  = {enabled=true,prefab="lightninggoat",brain="lightninggoatbrain",mobMult=.75,timeMult=1.25, healthMult=.5}, 
    [9]  = {enabled=true,prefab="beefalo",brain="beefalobrain",mobMult=.75,timeMult=1.5,healthMult=.5},
    [10] = {enabled=false,prefab="bat",brain="batbrain",CaveState="open",mobMult=1,timeMult=1}, -- No caves in DST...no bats
    [11] = {enabled=false,prefab="rook",brain="rookbrain",mobMult=1,timeMult=1,healthMult=.33}, -- These dudes don't work too well (mostly works, but they get lost)
    [12] = {enabled=true,prefab="knight",brain="knightbrain",mobMult=1,timeMult=1.5,healthMult=.33}, 
    [13] = {enabled=false,prefab="mossling",brain="mosslingbrain",Season={SEASONS.SPRING},mobMult=1,timeMult=1,healthMult=.66}, -- Needs work. They wont get enraged. Also spawns moosegoose....so yeah
	[14] = {enabled=true,prefab="perd",brain="perdbrain",mobMult=2.5,timeMult=.25},
	[15] = {enabled=true,prefab="penguin",brain="penguinbrain",Season={SEASONS.WINTER},mobMult=2.5,timeMult=.35,damageMult=.5},
	[16] = {enabled=true,prefab="walrus",brain="walrusbrain",Season={SEASONS.WINTER},mobMult=.33, timeMult=3,healthMult=.5},
    [17] = {enabled=true,prefab="warg",brain="wargbrain",minAgeDays=40,mobMult=.1, timeMult=3,healthMult=.2, damageMult=.5}, -- 180 health, 25 damage per attack, can summon children
    [18] = {enabled=true,prefab="spider_hider",surface="cave",mobMult=1.7,timeMult=.5},
    [19] = {enabled=true,prefab="worm",surface="cave"} -- Normal cave mobs
}

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


