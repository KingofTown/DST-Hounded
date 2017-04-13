--------------------------------------------------------------------------
--[[ Hounded class definition ]]
--------------------------------------------------------------------------

--[[
Sooo, everything in this class is set to private which makes it really hard to mod. 
Guess I'm forced to make a copy of the hounded class and just mod it here.
--]]

return Class(function(self, inst)



assert(TheWorld.ismastersim, "SuperHounded should not exist on client")

--------------------------------------------------------------------------
--[[ Constants ]]
--------------------------------------------------------------------------

local SPAWN_DIST = 30

local attack_levels =
{
	intro	=	{ warnduration = function() return 120 end, numspawns = function() return 2 end },
	light	=	{ warnduration = function() return 60 end, numspawns = function() return 2 + math.random(2) end },
	med		=	{ warnduration = function() return 45 end, numspawns = function() return 3 + math.random(3) end },
	heavy	=	{ warnduration = function() return 30 end, numspawns = function() return 4 + math.random(3) end },
	crazy	=	{ warnduration = function() return 30 end, numspawns = function() return 6 + math.random(4) end },
}

local attack_delays =
{
	rare		= function() return TUNING.TOTAL_DAY_TIME * 6, math.random() * TUNING.TOTAL_DAY_TIME * 7 end,
	occasional	= function() return TUNING.TOTAL_DAY_TIME * 4, math.random() * TUNING.TOTAL_DAY_TIME * 7 end,
	frequent	= function() return TUNING.TOTAL_DAY_TIME * 3, math.random() * TUNING.TOTAL_DAY_TIME * 5 end,
}

--------------------------------------------------------------------------
--[[ Member variables ]]
--------------------------------------------------------------------------

--Public
self.inst = inst

--Private
local _activeplayers = {}
local _warning = false
local _timetoattack = 0
local _warnduration = 30
local _attackplanned = false
local _timetonextwarningsound = 0
local _announcewarningsoundinterval = 4

--Mod Private variables
local MOB_LIST = {}
local warningCount = 1
local houndDebug = false

local defaultPhrase = STRINGS.CHARACTERS.GENERIC.ANNOUNCE_HOUNDS
STRINGS.CHARACTERS.GENERIC.ANNOUNCE_HOUNDS = "WTF WAS THAT!!"

--Mod Public variables
self.quakeMachine = CreateEntity()
self.quakeMachine.persists = false
self.quakeMachine.entity:AddSoundEmitter()
self.quakeMachine.soundIntensity = 0.01
self.currentIndex = nil

self.currentMobs = {}
self.numMobsSpawned = 0



--Configure this data using hounded:SetSpawnData
local _spawndata =
	{
		base_prefab = "hound",
		winter_prefab = "icehound",
		summer_prefab = "firehound",

		attack_levels =
		{
			intro 	= { warnduration = function() return 120 end, numspawns = function() return 2 end },
			light 	= { warnduration = function() return 60 end, numspawns = function() return 2 + math.random(2) end },
			med 	= { warnduration = function() return 45 end, numspawns = function() return 3 + math.random(3) end },
			heavy 	= { warnduration = function() return 30 end, numspawns = function() return 4 + math.random(3) end },
			crazy 	= { warnduration = function() return 30 end, numspawns = function() return 6 + math.random(4) end },
		},

		attack_delays =
		{
			rare 		= function() return TUNING.TOTAL_DAY_TIME * 6, math.random() * TUNING.TOTAL_DAY_TIME * 7 end,
			occasional 	= function() return TUNING.TOTAL_DAY_TIME * 4, math.random() * TUNING.TOTAL_DAY_TIME * 7 end,
			frequent 	= function() return TUNING.TOTAL_DAY_TIME * 3, math.random() * TUNING.TOTAL_DAY_TIME * 5 end,
		},

		warning_speech = "ANNOUNCE_HOUND",
		warning_sound_thresholds =
		{	--Key = time, Value = sound prefab
			{time = 30, sound = "houndwarning_lvl4"},
			{time = 60, sound = "houndwarning_lvl3"},
			{time = 90, sound = "houndwarning_lvl2"},
			{time = 500, sound = "houndwarning_lvl1"},
		},
	}

local _attackdelayfn = _spawndata.attack_delays.occasional
local _attacksizefn = _spawndata.attack_levels.light.numspawns
local _warndurationfn = _spawndata.attack_levels.light.warnduration
local _spawnmode = "escalating"
local _spawninfo = nil


--------------------------------------------------------------------------
--[[ Mod Private Functions ]]
--------------------------------------------------------------------------

local function getDumbString(num)
    if num == 1 then return "ONE!"
    elseif num == 2 then return "TWO!"
    elseif num == 3 then return "THREE!"
    elseif num == 4 then return "FOUR!"
    else return "TOO MANY!" end
end

-- Lookup the table index by prefab name. Returns nil if not found
local function getIndexByName(name)
	for k,v in pairs(MOB_LIST) do
		if v.prefab == name then
			return k
		end
	end
end

-- Gets a random enabled mob from the MOB_LIST.
-- If none are enabled or available, will always attack
-- least return 'hounds'
-- This returns the key for the MOB_LIST.
local function getRandomMob()
    -- Generate a shuffled list from 1 to #MOB_LIST
    local t={}
    for i=1,#MOB_LIST do
        t[i]=i
    end
    -- Shuffle
    for i = 1, #MOB_LIST do
        local j=math.random(i,#MOB_LIST)
        t[i],t[j]=t[j],t[i]
    end
    
    -- Return the first one that is enabled
    for k,v in pairs(t) do
        local pickThisMob = true
        if MOB_LIST[v].enabled then

            -- Check for season restrictions
            if MOB_LIST[v].Season ~= nil then
                for key,season in pairs(MOB_LIST[v].Season) do
                    if TheWorld.state.season ~= season then
                        pickThisMob = false
                    else
                        pickThisMob = true
                        break
                    end
                end
                
                if not pickThisMob then
                    print("Skipping " .. tostring(MOB_LIST[v].prefab) .. " as mob because season not met")
                end
            end
			
            -- If this is still true, return this selection 
            if pickThisMob then 
                return v 
            end
        end
    end

    -- If we are here...there is NOTHING in the list enabled and valid.
    -- This is strange. Just return hound I guess (even though
    -- hound is in the list and the user disabled it...)
    print("WARNING: No possible mobs to select from! Using Hound as default")
    return 1
end

-- This is called after each verbal warning. 
local function updateWarningString(index)
		
	--print("Updating strings")
	-- For each player, update the warning string.
	for i,v in ipairs(AllPlayers) do
		local character = string.upper(v.prefab)
		if character == nil or character == "WILSON" then
			character = "GENERIC"
		end
		
		-- If this is a mod character (or wes)...or just doesn't have
		-- this string defined...don't say anything.
		if STRINGS.CHARACTERS[character] == nil then
		   return
		end
		
		if not index then
			STRINGS.CHARACTERS[character].ANNOUNCE_HOUNDS = "I'm...not sure what that sound is..."
			return
		end
	
		local prefab = MOB_LIST[index].prefab
		if prefab == nil then
			STRINGS.CHARACTERS[character].ANNOUNCE_HOUNDS = defaultPhrase
		elseif prefab == "merm" then
			STRINGS.CHARACTERS[character].ANNOUNCE_HOUNDS = "Oh god, it smells like rotting fish."
		elseif prefab == "spider" then
			STRINGS.CHARACTERS[character].ANNOUNCE_HOUNDS = "Sounds like a million tiny legs."
		elseif prefab == "tallbird" then
			STRINGS.CHARACTERS[character].ANNOUNCE_HOUNDS = "Sounds like a murder...of tall birds."
		elseif prefab == "pigman" then
			STRINGS.CHARACTERS[character].ANNOUNCE_HOUNDS = "Was that an oink?"
		elseif prefab == "killerbee" then
			STRINGS.CHARACTERS[character].ANNOUNCE_HOUNDS = "Beeeeeeeeeeeeeeeeees!"
		elseif prefab == "mosquito" then
			STRINGS.CHARACTERS[character].ANNOUNCE_HOUNDS = "I hear a million teeny tiny vampires."
		elseif prefab == "lightninggoat" then
			STRINGS.CHARACTERS[character].ANNOUNCE_HOUNDS = "Those giant dark clouds look ominous."
		elseif prefab == "beefalo" then
			if warningCount == 1 then
				STRINGS.CHARACTERS[character].ANNOUNCE_HOUNDS = "Do you feel that?"
			else
				STRINGS.CHARACTERS[character].ANNOUNCE_HOUNDS = "The ground is shaking!"
			end
		elseif prefab == "bat" then
			-- TODO: Increment the count each warning lol
			STRINGS.CHARACTERS[character].ANNOUNCE_HOUNDS = getDumbString(warningCount) .. " Ah ah ah!"
		elseif prefab == "knight" then
			STRINGS.CHARACTERS[character].ANNOUNCE_HOUNDS = "The cavalry are coming!"
		elseif prefab == "perd" then
			STRINGS.CHARACTERS[character].ANNOUNCE_HOUNDS = "Gobbles!!!"
		elseif prefab == "penguin" then
			STRINGS.CHARACTERS[character].ANNOUNCE_HOUNDS = "Oh no...they think I took their eggs!"
		elseif prefab == "walrus" then
			STRINGS.CHARACTERS[character].ANNOUNCE_HOUNDS = "The hunter becomes the hunted."
		else
			STRINGS.CHARACTERS[character].ANNOUNCE_HOUNDS = defaultPhrase
		end
		
	 if character == "WX78" then
        STRINGS.CHARACTERS[character].ANNOUNCE_HOUNDS = string.upper(STRINGS.CHARACTERS[character].ANNOUNCE_HOUNDS)
    end
	end
end
--------------------------------------------------------------------------
--[[ Mod Public Functions ]]
--------------------------------------------------------------------------
self.AddMob = function(self,mob)
	if self.currentMobs[mob] == nil and mob then
		self.currentMobs[mob] = true
		self.numMobsSpawned = self.numMobsSpawned + 1
		-- Listen for death events on these dudes
		mob.deathfn = function() self:RemoveMob(mob) end
		
		-- If the mob leaves, remove it from the list
		self.inst:ListenForEvent("death", mob.deathfn,mob)
		self.inst:ListenForEvent("onremove", mob.deathfn, mob )
		
		---------------------------------------------------------------------------------
		--Add All of the stuff for this mob here so we can persist on save states----
		
		-- I've modified the mobs brains to be mindless killers with this tag
		mob:AddTag("houndedKiller")
		mob:AddTag("hostile") -- seems natural to set this

		-- This mob has no home anymore. It's set to kill.
		if mob.components.homeseeker then
			mob:RemoveComponent("homeseeker")
		end
		
		-- Just to be sure...
		if mob.components.knownlocations then
			mob.components.knownlocations:ForgetLocation("home")
		end
		
		-- Can't remove 'sleeper' tag as it causes the entity to throw errors. Just
		-- override the ShouldSleep functions
		if mob.components.sleeper ~= nil then
			local sleepFcn = function(self,inst)
				return false
			end
			local wakeFcn = function(self,inst)
				return true
			end
			mob.components.sleeper:SetSleepTest(sleepFcn)
			mob.components.sleeper:SetWakeTest(wakeFcn)
			
		end
		
		
		-- Override the default KeepTarget for this mob.
		-- Basically, if it's currently targeting the player, continue to.
		-- If not, let it do whatever it's doing for now until it loses interest
		-- and comes back for the player.
		local origCanTarget = mob.components.combat.keeptargetfn
		local function keepTargetOverride(inst, target)
			-- TODO: Testing this 
			if true then
				return inst.components.combat:CanTarget(target)
			end
			-- This wont get hit. Was original code. TODO : if above is better, remove this.
			if target:HasTag("player") and inst.components.combat:CanTarget(target) then
				return true
			else
				return origCanTarget and origCanTarget(inst,target)
			end
		end
		mob.components.combat:SetKeepTargetFunction(keepTargetOverride)
		
		-- Let's try this out. Give the players a chance. Basically, the mobs will look for something 
		-- else to attack every once in a while...
		local function retargetfn(inst)
			-- Give all mobs same search dist as hounds
			local dist = TUNING.HOUND_TARGET_DIST
			return FindEntity(inst, dist, function(guy)
					return inst.components.combat:CanTarget(guy)
					end,
					{"character"}, -- Always target a character?
					{"houndedKiller", inst.prefab}, -- Don't kill eachother or like kind
					nil)
		end
		
		if not mob.components.teamattacker then
		  mob.components.combat:SetRetargetFunction(3, retargetfn)
		end
		
		-- Set the min attack period to something...higher
		local currentAttackPeriod = mob.components.combat.min_attack_period
		mob.components.combat:SetAttackPeriod(math.max(currentAttackPeriod,3))
		-- This is done elsewhere.
		--mob.components.combat:SuggestTarget(GetPlayer())
		
		-- Tweak the damage output of this mob based on the table
		local index = getIndexByName(mob.prefab)
		if index and MOB_LIST[index].damageMult then
			local mult = MOB_LIST[index].damageMult
			mob.components.combat:SetDefaultDamage(mult*mob.components.combat.defaultdamage)
		end
		
		-- Tweak the health of this mob based on the table
		if index and MOB_LIST[index].healthMult then
			local healthMult = MOB_LIST[index].healthMult
			mob.components.health:SetMaxHealth(healthMult*mob.components.health.maxhealth)
		end

		
		-- Tweak the drop rates for the mobs
		if index and MOB_LIST[index].dropMult then
			local mult = MOB_LIST[index].dropMult
			if mob.components.lootdropper.loot then
				local current_loot = mob.components.lootdropper.loot
				mob.components.lootdropper:SetLoot(nil)
				-- Create a loot_table from this (chance would be 1)
				for k,v in pairs(current_loot) do
					mob.components.lootdropper:AddChanceLoot(v,mult)
				end			
			elseif mob.components.lootdropper.chanceloottable then
				local loot_table = LootTables[mob.components.lootdropper.chanceloottable]
				if loot_table then
				mob.components.lootdropper:SetChanceLootTable(nil)
					for i,entry in pairs(loot_table) do
						local prefab = entry[1]
						local chance = entry[2]*mult
						mob.components.lootdropper:AddChanceLoot(prefab,chance)
					end
				end
			end
		end
	end
end -- end AddMob fcn


self.RemoveMob = function(self,mob)
	if mob and self.currentMobs[mob] then
		self.currentMobs[mob] = nil
		self.numMobsSpawned = self.numMobsSpawned - 1
	end
end

-- Create some quake effects
self.quakeMachine.WarnQuake = function(self, duration, speed, scale)
						 -- type,duration,speed,scale,maxdist
	-- Do this for all players
	TheCamera:Shake("FULL", duration, speed, scale, 80)
	
	-- Increase the intensity for the next call (only start the sound once)
	if not self.quakeStarted then
		self.SoundEmitter:PlaySound("dontstarve/cave/earthquake", "earthquake")
		self.quakeStarted = true
	end
	self.SoundEmitter:SetParameter("earthquake", "intensity", self.soundIntensity)
end

self.quakeMachine.EndQuake = function(self)
	self.quakeStarted = false
	self.SoundEmitter:KillSound("earthquake")
	self.soundIntensity = 0.01
	self.quakeStarted = false
end

 
self.quakeMachine.MakeStampedeLouder = function(self)
        self.soundIntensity = self.soundIntensity + .04
        self.SoundEmitter:SetParameter("earthquake","intensity",self.soundIntensity)
end


--------------------------------------------------------------------------
--[[ Private member functions ]]
--------------------------------------------------------------------------

local function GetAveragePlayerAgeInDays()
	local sum = 0
	for i,v in ipairs(_activeplayers) do
		sum = sum + v.components.age:GetAgeInDays()
	end
	local average = sum / #_activeplayers
	return average > 0 and average or 0
end

local function CalcEscalationLevel()
	local day = GetAveragePlayerAgeInDays()

	if day < 10 then
		_attackdelayfn = _spawndata.attack_delays.rare
		_attacksizefn = _spawndata.attack_levels.intro.numspawns
		_warndurationfn = _spawndata.attack_levels.intro.warnduration
	elseif day < 25 then
		_attackdelayfn = _spawndata.attack_delays.rare
		_attacksizefn = _spawndata.attack_levels.light.numspawns
		_warndurationfn = _spawndata.attack_levels.light.warnduration
	elseif day < 50 then
		_attackdelayfn = _spawndata.attack_delays.occasional
		_attacksizefn = _spawndata.attack_levels.med.numspawns
		_warndurationfn = _spawndata.attack_levels.med.warnduration
	elseif day < 100 then
		_attackdelayfn = _spawndata.attack_delays.occasional
		_attacksizefn = _spawndata.attack_levels.heavy.numspawns
		_warndurationfn = _spawndata.attack_levels.heavy.warnduration
	else
		_attackdelayfn = _spawndata.attack_delays.frequent
		_attacksizefn = _spawndata.attack_levels.crazy.numspawns
		_warndurationfn = _spawndata.attack_levels.crazy.warnduration
	end

end

local function CalcPlayerAttackSize(player)
	local day = player.components.age:GetAgeInDays()
	local attacksize = 0
	if day < 10 then
		attacksize = _spawndata.attack_levels.intro.numspawns()
	elseif day < 25 then
		attacksize = _spawndata.attack_levels.light.numspawns()
	elseif day < 50 then
		attacksize = _spawndata.attack_levels.med.numspawns()
	elseif day < 100 then
		attacksize = _spawndata.attack_levels.heavy.numspawns()
	else
		attacksize = _spawndata.attack_levels.crazy.numspawns()
	end
	return attacksize
end

local function PlanNextAttack(inst,prefabIndex)
	if _timetoattack > 0 and houndDebug == false then
		-- we came in through a savegame that already had an attack scheduled
		return
	end
	-- if there are no players then try again later
	if #_activeplayers == 0 then
		_attackplanned = false
		self.inst:DoTaskInTime(1, PlanNextAttack)
		return
	end
	
	if _spawnmode == "escalating" then
		CalcEscalationLevel()
	end
	
	if _spawnmode ~= "never" then
		local timetoattackbase, timetoattackvariance = _attackdelayfn()
		_timetoattack = timetoattackbase + timetoattackvariance
		_warnduration = _warndurationfn()
		_attackplanned = true
	end
    _warning = false
	
	-- New Mod functionality
	-- Pick a random mob from the list
	if prefabIndex and prefabIndex > 0 and prefabIndex <= #MOB_LIST then
		print("Using supplied index " .. prefabIndex)
		self.currentIndex = prefabIndex
	else
		self.currentIndex = getRandomMob()
	end
	
	print("Current mob scheduled: " .. MOB_LIST[self.currentIndex].prefab)

	updateWarningString(self.currentIndex)
	
	-- Reset the warning counter
	warningCount = 1
end

local GROUP_DIST = 20
local EXP_PER_PLAYER = 0.05
local ZERO_EXP = 1 - EXP_PER_PLAYER -- just makes the math a little easier

local function GetWaveAmounts()

	-- first bundle up the players into groups based on proximity
	-- we want to send slightly reduced hound waves when players are clumped so that
	-- the numbers aren't overwhelming
	local groupindex = {}
	local nextgroup = 1
	for i,playerA in ipairs(_activeplayers) do
		for j,playerB in ipairs(_activeplayers) do
			if i == 1 and j == 1 then
				groupindex[playerA] = 1
				nextgroup = 2
			end
			if j > i then
				if playerA:IsNear(playerB, GROUP_DIST) then
					if groupindex[playerA] and groupindex[playerB] and groupindex[playerA] ~= groupindex[playerB] then
						local mingroup = math.min(groupindex[playerA], groupindex[playerB])
						groupindex[playerA] = mingroup
						groupindex[playerB] = mingroup
					else
						groupindex[playerB] = groupindex[playerA]
					end
				elseif groupindex[playerB] == nil then
					groupindex[playerB] = nextgroup
					nextgroup = nextgroup + 1
				end
			end
		end
	end

	-- calculate the hound attack for each player
	_spawninfo = {}
	for player,group in pairs(groupindex) do
		local playerAge = player.components.age:GetAge()
		local attackdelaybase, attackdelayvariance =  _attackdelayfn()

		-- amount of hounds relative to our age
		local spawnsToRelease = CalcPlayerAttackSize(player)
		local playerInGame = GetTime() - player.components.age.spawntime

		-- if we never saw a warning or have lived shorter than the minimum wave delay then don't spawn hounds to us
		if not houndDebug and (playerInGame <= _warnduration or playerAge < attackdelaybase) then
			print("Not releasing hounds for this n00b")
			spawnsToRelease = 0
		end

		if _spawninfo[group] == nil then
			_spawninfo[group] = {players = {player}, spawnstorelease = spawnsToRelease, timetonext = 0, totalplayerage=playerAge}
		else
			table.insert(_spawninfo[group].players, player)
			_spawninfo[group].spawnstorelease = _spawninfo[group].spawnstorelease + spawnsToRelease
			_spawninfo[group].totalplayerage = _spawninfo[group].totalplayerage + playerAge
		end
	end

	-- some groups were created then destroyed in the first step, crunch the array so we can ipairs() over it
	_spawninfo = GetFlattenedSparse(_spawninfo)

	-- Adjust hound wave size by mob
	local mult = MOB_LIST[self.currentIndex].mobMult or 1
	
	-- we want fewer hounds for larger groups of players so they don't get overwhelmed
	for i, info in ipairs(_spawninfo) do

		-- pow the number of hounds by a fractional exponent, to stave off huge groups
		-- e.g. hounds ^ 1/1.1 for three players
		local groupexp = 1.0 / (ZERO_EXP + (EXP_PER_PLAYER * #info.players))
		info.spawnstorelease = RoundBiasedDown(math.pow(info.spawnstorelease, groupexp))
		
		-- Now modify for the mob multiplier
		-----------------------------------------------------------------
		-- Always spawn at least 1 (unless there were 0 planned for this player)
		if info.spawnstorelease > 0 then
			local numHounds = math.max(1,info.spawnstorelease*mult)
			print("Adjusting hounds from " .. info.spawnstorelease .. " to " .. numHounds)
			-- Round to nearest int
			info.spawnstorelease = numHounds % 1 >= .5 and math.ceil(numHounds) or math.floor(numHounds)
			--print("Next Attack: " .. self.spawnsstorelease .. " " .. MOB_LIST[self.currentIndex].prefab)
		end
		
		-----------------------------------------------------------------
		
		-- This is used to ignore the 'new player' above. Reset it after each plan
		houndDebug = false

		info.averageplayerage = info.totalplayerage / #info.players
	end
end

local function NoHoles(pt)
    return not TheWorld.Map:IsPointNearHole(pt)
end

local function GetSpawnPoint(pt)
    if not TheWorld.Map:IsAboveGroundAtPoint(pt:Get()) then
        pt = FindNearbyLand(pt, 1) or pt
    end
    local offset = FindWalkableOffset(pt, math.random() * 2 * PI, SPAWN_DIST, 12, true, true, NoHoles)
    if offset ~= nil then
        offset.x = offset.x + pt.x
        offset.z = offset.z + pt.z
        return offset
    end
end

local function GetSpecialSpawnChance()
	local day = GetAveragePlayerAgeInDays()
	local chance = 0
	for k,v in ipairs(TUNING.HOUND_SPECIAL_CHANCE) do
	    if day > v.minday then
	        chance = v.chance
	    elseif day <= v.minday then
	        return chance
	    end
	end

	if TheWorld.state.issummer then
		chance = chance * 1.5
	end

	return chance
end

-- Transforms a mob to an ice/fire version.
-- Copies the ice/fire hound ondeath and gives
-- a special drop. 
-- Also changes the color.
local function makeMobSpecial(theMob, specialStats)

   -- Increase damage and decrease health
   local health = theMob.components.health.maxhealth
   theMob.components.health:SetMaxHealth(health*.66)
   
   local damage = theMob.components.combat.defaultdamage
   theMob.components.combat:SetDefaultDamage(damage*1.35)
   
   -- Add onDeath triggers
   if specialStats == "ice" then
      theMob.AnimState:SetMultColour(.1,.1,1,1)
	  -- only set the ondeath in the sim
	  --if not TheWorld.ismastersim then
      --  return
      --end
      theMob:ListenForEvent("death", function(inst)
      
		  if not inst.components.freezable then
			  -- Eh...it won't be there long enough to show this. This is
			  -- just to set up the FX.
			  MakeMediumFreezableCharacter(inst, "hound_body")
		  end
		  inst.components.freezable:SpawnShatterFX()
		  inst:RemoveComponent("freezable")
		  local x,y,z = inst.Transform:GetWorldPosition()
		  local ents = TheSim:FindEntities(x, y, z, 4, {"freezable"}, {"FX", "NOCLICK","DECOR","INLIMBO"}) 
		  for i,v in pairs(ents) do
			  if v.components.freezable then
				  v.components.freezable:AddColdness(2)
			  end
		  end
           
           
           -- Also drop a gem!
           if math.random() < .3 then
              inst.components.lootdropper:SpawnLootPrefab("bluegem")
           end
   
           inst.SoundEmitter:PlaySound("dontstarve/creatures/hound/icehound_explo", "explosion")
      end)
   else
      theMob.AnimState:SetMultColour(1,.25,.25,1)
	  -- Only set the ondeath in the sim
	  --if not TheWorld.ismastersim then
      --  return
      --end
      theMob:ListenForEvent("death", function(inst)
         if math.random() < .3 then
            inst.components.lootdropper:SpawnLootPrefab("redgem")
         end
         
         -- Make some fire!
         for k=1,3 do
            inst.components.lootdropper:SpawnLootPrefab("houndfire")
         end
         
         inst.SoundEmitter:PlaySound("dontstarve/creatures/hound/firehound_explo", "explosion")
      
      end)
   end
end

local function SummonSpawn(pt)
	assert(pt)

	local spawn_pt = GetSpawnPoint(pt)
	
	local prefab,index = "",0
	
	if self.currentIndex == nil then
		-- Next wave hasn't been planned
		print("No mob has been planned! Picking random from list")
		local index = getRandomMob()
		if index then
			self.currentIndex = index
			prefab = MOB_LIST[self.currentIndex].prefab
		end
	else 
		prefab = MOB_LIST[self.currentIndex].prefab
	end
	
	if spawn_pt then
		
		--local prefab = "hound"
		local specialStats = nil
		local special_hound_chance = self.debugSpawn and 1 or GetSpecialSpawnChance()
		
		-- If spiders...give a chance at warrior spiders
		if prefab == "spider" and math.random() < special_hound_chance then
			prefab = "spider_warrior"
		end

		local chanceMod = MOB_LIST[self.currentIndex].mobMult or 1
		if math.random() < special_hound_chance/chanceMod then
		--if prefab == "hound" and math.random() < special_hound_chance then
		    if TheWorld.state.iswinter or TheWorld.state.isspring then
		          if prefab == "hound" then
                     prefab = "icehound"
                  else
                     specialStats = "ice"
                  end
		    else
			      if prefab == "hound" then
                     prefab = "firehound"
                  else
                     specialStats = "fire"
                  end
			end
		end
		
		-- They spawn from lightning! This lightning is only for show though
		if prefab == "lightninggoat" then
			SpawnPrefab("lightning").Transform:SetPosition(spawn_pt:Get())
		end
		
		local theMob = SpawnPrefab(prefab)
		if theMob then
			-- give the mob its special sauce
			self:AddMob(theMob)
			
			if specialStats then
				makeMobSpecial(theMob,specialStats)
            end
			
			-- Mosquitos should have a random fill rate instead of all being at 0
			if theMob:HasTag("mosquito") then
				local fillUp = math.random(0,2)
				for i=0,fillUp do
					theMob:PushEvent("onattackother",{data=theMob})
				end
			end
			

			----------------------------------------------------------------------
			-- If lightning goat...give it a chance to get struck by lightning
			local exciteGoat = function(self)
				local goatPos = Vector3(self.Transform:GetWorldPosition())
				TheWorld:PushEvent("ms_sendlightningstrike",goatPos)
			end
			if theMob:HasTag("lightninggoat") and math.random() < (.85*special_hound_chance) then
				theMob:DoTaskInTime(math.max(5,10*math.random()),exciteGoat)
			end
			
			local transformWerePig = function(self)
				local pigPos = Vector3(self.Transform:GetWorldPosition())
				if self.components.werebeast and pigPos then 
					SpawnPrefab("lightning").Transform:SetPosition(pigPos:Get())
					self.components.werebeast:SetWere()
        
					-- DST has a bonus multipler for werepig health. Remove this.
					local curHealth = self.components.health.maxhealth
					self.components.health:SetMaxHealth(curHealth*.66)
				end
				--TODO: Do I need to override the target fcn again?
			end
			
			if theMob:HasTag("pig") and math.random() < (.85*special_hound_chance) then
				theMob:DoTaskInTime(math.max(5,10*math.random()),transformWerePig)
			end
			
			
			-----------------------------------------------------------------------
			-- Hunting party is here! Make some friends! Assume the kids don't come.
			if theMob.prefab == "walrus" then
				local numHounds = 2
				local leader = theMob
				for i=1,numHounds do
					print("Releasing pet hound")
					local hound = SpawnPrefab("icehound")
					if hound then
						-- TODO: These won't persist as followers...
						self:AddMob(hound)
						hound:AddTag("pet_hound")
						hound.Transform:SetPosition(spawn_pt:Get())
						if not hound.components.follower then
							hound:AddComponent("follower")
						end
						hound.components.follower:SetLeader(leader)
						hound:FacePoint(pt)
					end
				end
			end
			
			theMob.Physics:Teleport(spawn_pt:Get())
            theMob:FacePoint(pt)
			
			
			return theMob
		end
	end
end

local function ReleaseSpawn(target)
    local spawn = SummonSpawn(target:GetPosition())
    if spawn ~= nil then
        spawn.components.combat:SuggestTarget(target)
        return true
    end
    return false
end

local function RemovePendingSpawns(player)
    if _spawninfo ~= nil then
        for i, spawninforec in ipairs(_spawninfo) do
            for j, v in ipairs(spawninforec.players) do
                if v == player then
                    if #spawninforec.players > 1 then
                        table.remove(spawninforec.players, j)
                    else
                        table.remove(_spawninfo, i)
                    end
                    return
                end
            end
        end
    end
end

--------------------------------------------------------------------------
--[[ Private event handlers ]]
--------------------------------------------------------------------------

local function OnPlayerJoined(src, player)
    for i, v in ipairs(_activeplayers) do
        if v == player then
            return
        end
    end
    table.insert(_activeplayers, player)
end

local function OnPlayerLeft(src, player)
    for i, v in ipairs(_activeplayers) do
        if v == player then
			RemovePendingSpawns(player)
            table.remove(_activeplayers, i)
            return
        end
    end
end

local function OnPauseHounded(src, data)
    if data ~= nil and data.source ~= nil then
        _pausesources:SetModifier(data.source, true, data.reason)
    end
end

local function OnUnpauseHounded(src, data)
    if data ~= nil and data.source ~= nil then
        _pausesources:RemoveModifier(data.source, data.reason)
    end
end

--------------------------------------------------------------------------
--[[ Initialization ]]
--------------------------------------------------------------------------

--Initialize variables
for i, v in ipairs(AllPlayers) do
    table.insert(_activeplayers, v)
end

--Register events
inst:ListenForEvent("ms_playerjoined", OnPlayerJoined)
inst:ListenForEvent("ms_playerleft", OnPlayerLeft)

inst:ListenForEvent("pausehounded", OnPauseHounded)
inst:ListenForEvent("unpausehounded", OnUnpauseHounded)

self.inst:StartUpdatingComponent(self)
PlanNextAttack()

--------------------------------------------------------------------------
--[[ Public getters and setters ]]
--------------------------------------------------------------------------

function self:GetTimeToAttack()
	return _timetoattack
end

function self:GetWarning()
	return _warning
end

function self:GetAttacking()
	return ((_timetoattack <= 0) and _attackplanned)
end

function self:SetSpawnData(data)
	_spawndata = data
end

--------------------------------------------------------------------------
--[[ Public member functions ]]
--------------------------------------------------------------------------

function self:SpawnModeEscalating()
	_spawnmode = "escalating"
	PlanNextAttack()
end

function self:SpawnModeNever()
	_spawnmode = "never"
	PlanNextAttack()
end

function self:SpawnModeHeavy()
	_spawnmode = "constant"
	_attackdelayfn = _spawndata.attack_delays.frequent
	_attacksizefn = _spawndata.attack_levels.heavy.numspawns
	_warndurationfn = _spawndata.attack_levels.heavy.warnduration
	PlanNextAttack()
end

function self:SpawnModeMed()
	_spawnmode = "constant"
	_attackdelayfn = _spawndata.attack_delays.occasional
	_attacksizefn = _spawndata.attack_levels.med.numspawns
	_warndurationfn = _spawndata.attack_levels.med.warnduration
	PlanNextAttack()
end

function self:SpawnModeLight()
	_spawnmode = "constant"
	_attackdelayfn = _spawndata.attack_delays.rare
	_attacksizefn = _spawndata.attack_levels.light.numspawns
	_warndurationfn = _spawndata.attack_levels.light.warnduration
	PlanNextAttack()
end

-- Releases a hound near and attacking 'target'
function self:ForceReleaseSpawn(target)
	if target then
		ReleaseSpawn(target)
	end
end

local function OriginalSummonSpawn(pt)
	assert(pt)

	local spawn_pt = GetSpawnPoint(pt)

	if spawn_pt then

		local prefab = _spawndata.base_prefab
		local special_spawn_chance = GetSpecialSpawnChance()

		if math.random() < special_spawn_chance then
		    if TheWorld.state.iswinter or TheWorld.state.isspring then
		        prefab = _spawndata.winter_prefab
		    else
			    prefab = _spawndata.summer_prefab
			end
		end

		local spawn = SpawnPrefab(prefab)
		if spawn then
			spawn.Physics:Teleport(spawn_pt:Get())
			spawn:FacePoint(pt)

			return spawn
		end
	end
end

-- Creates a hound near 'pt'
function self:SummonSpawn(pt)
	print("self:SummonSpawn called")
	if pt then
		return OriginalSummonSpawn(pt)
	end
end

-- Spawns the next wave for debugging
function self:ForceNextWave()
	PlanNextAttack()
	_timetoattack = 0
	self:OnUpdate(1)
end

-- Can override the next hound mob with this index
function self:PlanNextHoundAttack(index)
	print("PlanNextHoundAttack with override")
	houndDebug=true
	PlanNextAttack(nil,index)
end

function self:StartAttack(tt)
	print("Starting attack in " .. tt .. " seconds")
	houndDebug = true
	_timetoattack=tt
	self:OnUpdate(1)
end

local function _DoWarningSpeech(player)
    player.components.talker:Say(GetString(player, _spawndata.warning_speech))
end

function self:DoWarningSpeech()
    for i, v in ipairs(_activeplayers) do
        v:DoTaskInTime(math.random() * 2, _DoWarningSpeech)
    end
end

function self:DoWarningSound()
    for k,v in pairs(_spawndata.warning_sound_thresholds) do
    	if _timetoattack <= v.time or _timetoattack == nil then
    		SpawnPrefab(v.sound)
    	end
    end
end

function self:OnUpdate(dt)
	if _spawnmode == "never" then
		return
	end

	-- if there's no players, then don't even try
	if #_activeplayers == 0  or not _attackplanned then
		return
	end

	_timetoattack = _timetoattack - dt

	if _timetoattack < 0 then
	
		-- Somehow this is nil. This should never be nil! 
		-- Generate a new random one at this point
		if self.currentIndex == nil then
			self.currentIndex = getRandomMob()
		end
	
		-- Okay, it's hound-day, get number of dogs for each player
		if not _spawninfo then
			GetWaveAmounts()
		end

		_warning = false

		local playersdone = {}
		for i,spawninforec in ipairs(_spawninfo) do
			spawninforec.timetonext = spawninforec.timetonext - dt
			if spawninforec.spawnstorelease > 0 and spawninforec.timetonext < 0 then
				-- hounds can attack anyone in the group, even new players.
				-- That's the risk you take!
				local playeridx = math.random(#spawninforec.players)
				ReleaseSpawn(spawninforec.players[playeridx])
				spawninforec.spawnstorelease = spawninforec.spawnstorelease - 1

				local day = spawninforec.averageplayerage / TUNING.TOTAL_DAY_TIME
				if day < 20 then
					spawninforec.timetonext = 3 + math.random()*5
				elseif day < 60 then
					spawninforec.timetonext = 2 + math.random()*3
				elseif day < 100 then
					spawninforec.timetonext = .5 + math.random()*3
				else
					spawninforec.timetonext = .5 + math.random()*1
				end
				
				-- Adjust the spawn time based on the current index
				local timeMult = MOB_LIST[self.currentIndex].timeMult or 1
				spawninforec.timetonext = spawninforec.timetonext*timeMult

			end
			if spawninforec.spawnstorelease <= 0 then
				table.insert(playersdone,i)
			end
		end
		for i,v in ipairs(playersdone) do
			table.remove(_spawninfo, v)
		end
		if #_spawninfo == 0 then
			_spawninfo = nil
			PlanNextAttack()
		end
	else
		if not _warning and _timetoattack < _warnduration then
			_warning = true
			_timetonextwarningsound = 0
		end
	end

    if _warning then
        _timetonextwarningsound	= _timetonextwarningsound - dt

        if _timetonextwarningsound <= 0 then
            _announcewarningsoundinterval = _announcewarningsoundinterval - 1
            if _announcewarningsoundinterval <= 0 then
                _announcewarningsoundinterval = 10 + math.random(5)
                self:DoWarningSpeech()
		warningCount = warningCount+1
		updateWarningString(self.currentIndex)
            end

            _timetonextwarningsound =
                (_timetoattack < 30 and .3 + math.random(1)) or
                (_timetoattack < 60 and 2 + math.random(1)) or
                (_timetoattack < 90 and 4 + math.random(2)) or
                                        5 + math.random(4)
            self:DoWarningSound()
        end
    end
end

function self:LongUpdate(dt)
	self:OnUpdate(dt)
end

--self.LongUpdate = self.OnUdpate
--------------------------------------------------------------------------
--[[ Save/Load ]]
--------------------------------------------------------------------------

function self:OnSave()
	-- Bundle up the current mob list
	local _mobs = {}
	for k,v in pairs(self.currentMobs) do
		table.insert(_mobs,k.GUID)
	end
	return 
	{
		warning = _warning,
		timetoattack = _timetoattack,
		warnduration = _warnduration,
		attackplanned = _attackplanned,
		currentIndex = self.currentIndex,
                mobs = _mobs,
		mob_list = MOB_LIST -- Save the current state of this
	}
end

function self:OnLoad(data)
	_warning = data.warning or false
	_warnduration = data.warnduration or 0
	_timetoattack = data.timetoattack or 0
	_attackplanned = data.attackplanned  or false
	
	local emptyList = {}
	MOB_LIST = data.mob_list or emptyList

	local index = data.currentIndex or -1
	print("data.currentIndex: " .. index)
	self.currentIndex = data.currentIndex or nil
	
	
	if _timetoattack > _warnduration then
		-- in case everything went out of sync
		_warning = false
	end
	if _attackplanned and self.currentIndex ~= nil then
		if _timetoattack < _warnduration then
			-- at least give players a fighting chance if we quit during the warning phase
			_timetoattack = _warnduration + 5
		end
	elseif self.currentIndex == nil then
		print("Current Index is not set. Planning new hound attack")
		PlanNextAttack()
	else
		updateWarningString(self.currentIndex)
	end
end

function self:LoadPostPass(newEnts,savedata)
	if savedata and savedata.mobs then
		for k,v in pairs(savedata.mobs) do
			local targ = newEnts[v]
			if targ then
				self:AddMob(targ.entity)
			end
		end
	end
end

function self:GetMobList()
	return MOB_LIST
end

function self:SetMobList(list)
	MOB_LIST = list
end

--------------------------------------------------------------------------
--[[ Debug ]]
--------------------------------------------------------------------------

function self:GetDebugString()
	if _timetoattack > 0 then
		if self.currentIndex then
			return string.format("%s %s are coming in %2.2f", _warning and "WARNING" or "WAITING", MOB_LIST[self.currentIndex].prefab,  _timetoattack)
		else
			return string.format("No mob selected yet...")
		end
	else	
		local s = "ATTACKING\n"
		for i, spawninforec in ipairs(_spawninfo) do
			s = s..tostring(spawninforec.player).." - spawns left:"..tostring(spawninforec.spawnstorelease).." next spawn:"..tostring(spawninforec.timetonext)
			if i ~= #_activeplayers then
				s = s.."\n"
			end
		end
		return s
	end
end

function self:GetDebugSupplies()
	for i,v in ipairs(AllPlayers) do
		local playerPos = Vector3(v.Transform:GetWorldPosition())
		if playerPos then
			SpawnPrefab("armorwood").Transform:SetPosition(playerPos:Get())
			SpawnPrefab("spear").Transform:SetPosition(playerPos:Get())
			SpawnPrefab("footballhat").Transform:SetPosition(playerPos:Get())
		end
	end
end

end)
