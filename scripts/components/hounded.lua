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
    --[[ Dependencies ]]
    --------------------------------------------------------------------------

    local SourceModifierList = require("util/sourcemodifierlist")

    --------------------------------------------------------------------------
    --[[ Constants ]]
    --------------------------------------------------------------------------

    local SPAWN_DIST = 30

    --------------------------------------------------------------------------
    --[[ Member variables ]]
    --------------------------------------------------------------------------

    --Public
    self.inst = inst
    self.max_thieved_spawn_per_thief = 3
    --Private
    local _activeplayers = {}
    local _targetableplayers = {}
    local _warning = false
    local _timetoattack = 0
    local _warnduration = 30
    local _attackplanned = false
    local _timetonextwarningsound = 0
    local _announcewarningsoundinterval = 4
    local _pausesources = SourceModifierList(inst, false, SourceModifierList.boolean)

    local _spawnwintervariant = true
    local _spawnsummervariant = true
    --Mod Private variables
    local MOB_LIST = {}
    local _drop_mult = 1.0
    local warningCount = 1
    local houndDebug = false


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
            upgrade_spawn = "warglet",

            attack_levels =
            {
                intro 	= { warnduration = function() return 120 end, numspawns = function() return 2 end },
                light 	= { warnduration = function() return 60 end, numspawns = function() return 2 + math.random(2) end },
                med 	= { warnduration = function() return 45 end, numspawns = function() return 3 + math.random(3) end },
                heavy 	= { warnduration = function() return 30 end, numspawns = function() return 4 + math.random(3) end },
                crazy 	= { warnduration = function() return 30 end, numspawns = function() return 6 + math.random(4) end },
            },

	    --attack delays actually go from shorter to longer, to account for stronger waves
		--these names are describing the strength of the houndwave more than the duration
		attack_delays =
		{
			intro 		= function() return TUNING.TOTAL_DAY_TIME * 5, math.random() * TUNING.TOTAL_DAY_TIME * 3 end,
			light 		= function() return TUNING.TOTAL_DAY_TIME * 5, math.random() * TUNING.TOTAL_DAY_TIME * 5 end,
			med 		= function() return TUNING.TOTAL_DAY_TIME * 7, math.random() * TUNING.TOTAL_DAY_TIME * 5 end,
			heavy 		= function() return TUNING.TOTAL_DAY_TIME * 9, math.random() * TUNING.TOTAL_DAY_TIME * 5 end,
			crazy 		= function() return TUNING.TOTAL_DAY_TIME * 11, math.random() * TUNING.TOTAL_DAY_TIME * 5 end,
		},

            warning_speech = "ANNOUNCE_HOUNDS",
            warning_sound_thresholds =
            {	--Key = time, Value = sound prefab
                {time = 30, sound =  "LVL4"},
                {time = 60, sound =  "LVL3"},
                {time = 90, sound =  "LVL2"},
                {time = 500, sound = "LVL1"},
            },
        }

    local defaultPhrase
    if TheWorld:HasTag("cave") then
        defaultPhrase = STRINGS.CHARACTERS.GENERIC.ANNOUNCE_WORMS
    else
        defaultPhrase = STRINGS.CHARACTERS.GENERIC.ANNOUNCE_HOUNDS
    end

    STRINGS.CHARACTERS.GENERIC.ANNOUNCE_HOUNDS = "WTF WAS THAT!!"

    local _attackdelayfn = _spawndata.attack_delays.med
    local _warndurationfn = _spawndata.attack_levels.light.warnduration
    local _spawnmode = "escalating"
    local _spawninfo = nil
    --for players who leave during the warning when spawns are queued
    local _delayedplayerspawninfo = {}
    local _missingplayerspawninfo = {}

    --------------------------------------------------------------------------
    --[[ Mod Private Functions ]]
    --------------------------------------------------------------------------

    local function GetAveragePlayerAgeInDays()
        local sum = 0
        for i, v in ipairs(_activeplayers) do
            sum = sum + v.components.age:GetAgeInDays()
        end
        return sum > 0 and sum / #_activeplayers or 0
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

        print(#MOB_LIST .. " different options")

        -- Return the first one that is enabled
        for k,v in pairs(t) do
            local pickThisMob = true
            local reason = ""
            if MOB_LIST[v].enabled then
                -- Check for age restrictions
                -- This needs to be checked before spawning too
                local minAge = MOB_LIST[v].minAgeDays
                if minAge ~= nil then
                    local age = GetAveragePlayerAgeInDays()
                    if age < minAge then
                        pickThisMob = false
                        reason = "minimum player age not met"
                    end
                end


                -- Check for surface restriction
                local surface = MOB_LIST[v].surface
                if TheWorld:HasTag("cave") and pickThisMob then
                    if surface == nil or
                        (surface ~= "cave" and surface ~= "both") then
                            pickThisMob = false;
                            reason = "not spawning land mob in cave"
                    else
                      print(MOB_LIST[v].prefab .. " still valid...")
                    end
                else
                  -- On the surface. Don't spawn cave-only mobs
                    if surface ~= nil and (surface ~= "land" or surface ~= "both") then
                        pickThisMob = false
                        reason = "not spawning cave mob on land"
                    end
                end

                -- Check for season restrictions
                if MOB_LIST[v].Season ~= nil and pickThisMob then
                    local stillValid = false
                    for key,season in pairs(MOB_LIST[v].Season) do
                        -- Loop over all seasons before making decision
                        if TheWorld.state.season == season then
                            stillValid = true
                        end
                    end

                    -- No season overlapped with the current season
                    if not stillValid then
                        pickThisMob = false
                        reason = "season not met"
                    else
                        pickThisMob = true
                    end
                end

                if not pickThisMob then
                    print("Skipping " .. tostring(MOB_LIST[v].prefab) .. ". Reason: " .. reason)
                else
                    -- If this is still true, return this selection
                    print("Picked: " .. tostring(MOB_LIST[v].prefab) .. ". Special chance: ")
                    if(MOB_LIST[v].elemental) then
                        print("true!")
                    else
                        print("false!")
                    end
                    return v
                end
            else
              print("MOB: " .. MOB_LIST[v].prefab .. " is not enabled")
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

            -- Uhhh....this shouldn't happen.
            if not index then
                STRINGS.CHARACTERS[character].ANNOUNCE_HOUNDS = "I'm...not sure what that sound is..."
                return
            end

            -- Each mob can define its own warning string. Use the default if none is defined.
            STRINGS.CHARACTERS[character].ANNOUNCE_HOUNDS = MOB_LIST[index].warning or defaultPhrase

            -- Make them all UPPERCASE for WX
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
                local scaleHealth = 0
                if MOB_LIST[index].healthScale then
                  -- Scale the health based on average player age
                  -- TODO: Make this based on group age...
                  -- TODO: Make the max be the normal mob health...
                  scaleHealth = math.min(500,GetAveragePlayerAgeInDays())
                  print("Adding " .. scaleHealth .. " health based on age")
                end
                mob.components.health:SetMaxHealth(healthMult*mob.components.health.maxhealth + scaleHealth)
            end


            -- Tweak the drop rates for the mobs
            if _drop_mult ~= 1.0 then
                if mob.components.lootdropper.loot then
                    local current_loot = mob.components.lootdropper.loot
                    mob.components.lootdropper:SetLoot(nil)
                    -- Create a loot_table from this (chance would be 1)
                    for k,v in pairs(current_loot) do
                        mob.components.lootdropper:AddChanceLoot(v,_drop_mult)
                    end
                elseif mob.components.lootdropper.chanceloottable then
                    local loot_table = LootTables[mob.components.lootdropper.chanceloottable]
                    if loot_table then
                    mob.components.lootdropper:SetChanceLootTable(nil)
                        for i,entry in pairs(loot_table) do
                            local prefab = entry[1]
                            local chance = entry[2]*_drop_mult
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

    local function CalcEscalationLevel()
        local day = GetAveragePlayerAgeInDays()

        if day < 8 then
            _attackdelayfn = _spawndata.attack_delays.intro or _spawndata.attack_delays.rare
            _warndurationfn = _spawndata.attack_levels.intro.warnduration
        elseif day < 25 then
            _attackdelayfn = _spawndata.attack_delays.light or _spawndata.attack_delays.rare
            _warndurationfn = _spawndata.attack_levels.light.warnduration
        elseif day < 50 then
            _attackdelayfn = _spawndata.attack_delays.med or _spawndata.attack_delays.occasional
            _warndurationfn = _spawndata.attack_levels.med.warnduration
        elseif day < 100 then
            _attackdelayfn = _spawndata.attack_delays.heavy or _spawndata.attack_delays.frequent
            _warndurationfn = _spawndata.attack_levels.heavy.warnduration
        else
            _attackdelayfn = _spawndata.attack_delays.crazy or _spawndata.attack_delays.frequent
            _warndurationfn = _spawndata.attack_levels.crazy.warnduration
        end

    end

    local function CalcPlayerAttackSize(player)
        local day = player.components.age:GetAgeInDays()
        return (day < 10 and _spawndata.attack_levels.intro.numspawns())
            or (day < 25 and _spawndata.attack_levels.light.numspawns())
            or (day < 50 and _spawndata.attack_levels.med.numspawns())
            or (day < 100 and _spawndata.attack_levels.heavy.numspawns())
            or _spawndata.attack_levels.crazy.numspawns()
    end

    local function ClearWaterImunity()
        for GUID,data in pairs(_targetableplayers) do
            _targetableplayers[GUID] = nil
        end
    end
    local function PlanNextAttack(inst, prefabIndex)
        ClearWaterImunity()
        if _timetoattack > 0 and houndDebug == false then
            -- we came in through a savegame that already had an attack scheduled
            return
        end
        -- if there are no players then try again later
        if #_activeplayers <= 0 then
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
        else
            _attackplanned = false
        end
        _warning = false

        -- New Mod functionality
        -- Pick a random mob from the list
        if prefabIndex ~= nil and prefabIndex > 0 and prefabIndex <= #MOB_LIST then
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
        for i, playerA in ipairs(_activeplayers) do
            for j, playerB in ipairs(_activeplayers) do
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
        local thieves = {}
        local groupmap = {}
        for player, group in pairs(groupindex) do
            local attackdelaybase = _attackdelayfn()
            local playerAge = player.components.age:GetAge()

            -- amount of hounds relative to our age
            -- if we never saw a warning or have lived shorter than the minimum wave delay then don't spawn hounds to us
            local playerInGame = GetTime() - player.components.age.spawntime
            --local spawnsToRelease = playerInGame > _warnduration and playerAge >= attackdelaybase and CalcPlayerAttackSize(player) or 0
            local spawnsToRelease = CalcPlayerAttackSize(player)

            -- if we never saw a warning or have lived shorter than the minimum wave delay then don't spawn hounds to us
            if not houndDebug and (playerInGame <= _warnduration or playerAge < attackdelaybase) then
                print("Not releasing hounds for this n00b")
                spawnsToRelease = 0
            end

            if spawnsToRelease > 0 then
                if groupmap[group] == nil then
                    groupmap[group] = #_spawninfo + 1

                    table.insert(_spawninfo,
                        {
                            players = {}, -- tracks the number of spawns for this player
                            timetonext = 0,

                            -- working data
                            target_weight = {},
                            spawnstorelease = 0,
                            totalplayerage = 0,
                        })
                end
                local g = groupmap[group]
                _spawninfo[g].spawnstorelease = _spawninfo[g].spawnstorelease + spawnsToRelease
                _spawninfo[g].totalplayerage = _spawninfo[g].totalplayerage + playerAge

                _spawninfo[g].target_weight[player] = math.sqrt(spawnsToRelease) * (player.components.houndedtarget ~= nil and player.components.houndedtarget:GetTargetWeight() or 1)
                _spawninfo[g].players[player] = 0

                if player.components.houndedtarget ~= nil and player.components.houndedtarget:IsHoundThief() then
                    table.insert(thieves, {player = player, group = g})
                end
            end
        end

        groupindex = nil -- this is now invalid, some groups were created then destroyed in the first step

        -- Adjust hound wave size by mob
        local mult = MOB_LIST[self.currentIndex].mobMult or 1

        -- we want fewer hounds for larger groups of players so they don't get overwhelmed
        local thieved_spawns = 0
        for i, info in ipairs(_spawninfo) do
    		local group_size = GetTableSize(info.players)

            -- pow the number of hounds by a fractional exponent, to stave off huge groups
            -- e.g. hounds ^ 1/1.1 for three players
            local groupexp = 1.0 / (ZERO_EXP + (EXP_PER_PLAYER * #info.players))
            local spawnstorelease = math.max(group_size, RoundBiasedDown(math.pow(info.spawnstorelease, groupexp)))
            if #thieves > 0 and spawnstorelease > group_size then
                spawnstorelease = spawnstorelease - group_size
                thieved_spawns = thieved_spawns + group_size
            end
            -- Now modify for the mob multiplier
            -----------------------------------------------------------------
            -- Always spawn at least 1 (unless there were 0 planned for this player)
            if spawnstorelease > 0 then
                local numHounds = math.max(1,spawnstorelease*mult)
                print("Adjusting hounds from " .. spawnstorelease .. " to " .. numHounds)
                -- Round to nearest int
                spawnstorelease = numHounds % 1 >= .5 and math.ceil(numHounds) or math.floor(numHounds)
                --print("Next Attack: " .. self.spawnsstorelease .. " " .. MOB_LIST[self.currentIndex].prefab)
            end

            -- assign the hounds to each player
            for p = 1, spawnstorelease do
                local player = weighted_random_choice(info.target_weight)
                info.players[player] = info.players[player] + 1
            end

            -- calculate average age to be used for spawn delay
		    info.averageplayerage = info.totalplayerage / group_size

            -- remove working data
		    info.target_weight = nil
		    info.spawnstorelease = nil
        end
            -----------------------------------------------------------------

            -- This is used to ignore the 'new player' above. Reset it after each plan
        houndDebug = false

        -- distribute the thieved_spawns amoungst the thieves
        if thieved_spawns > 0 then
            thieved_spawns = math.min(thieved_spawns, (self.max_thieved_spawn_per_thief + 1) * #thieves)  -- +1 because we also removed one from the theif
            if #thieves == 1 then
                local player = thieves[1].player
                local group = thieves[1].group
                _spawninfo[group].players[player] = _spawninfo[group].players[player] + thieved_spawns
            else
                shuffleArray(thieves)
                for i = 1, thieved_spawns do
                    local index = ((i-1) % #thieves) + 1
                    local player = thieves[index].player
                    local group = thieves[index].group
                    _spawninfo[group].players[player] = _spawninfo[group].players[player] + 1
                end
            end
        end

    end

    local function GetDelayedPlayerWaveAmounts(player, data)
        local attackdelaybase = _attackdelayfn()
        local playerAge = player.components.age:GetAge()

        -- amount of hounds relative to our age
        -- if we have lived shorter than the minimum wave delay then don't spawn hounds to us
        local spawnsToRelease = playerAge >= attackdelaybase and CalcPlayerAttackSize(player) or 0

        data._spawninfo = {}
        table.insert(data._spawninfo,
        {
            players = {[player] = spawnsToRelease}, --tracks the number of spawns for this player
            timetonext = 0,
            averageplayerage = playerAge,
        })
    end

    local function NoHoles(pt)
        return not TheWorld.Map:IsPointNearHole(pt)
    end

    local function GetSpawnPoint(pt)
        if TheWorld.has_ocean then
            local function OceanSpawnPoint(offset)
                local x = pt.x + offset.x
                local y = pt.y + offset.y
                local z = pt.z + offset.z
                return TheWorld.Map:IsAboveGroundAtPoint(x, y, z, true) and NoHoles(pt)
            end

            local offset = FindValidPositionByFan(math.random() * 2 * PI, SPAWN_DIST, 12, OceanSpawnPoint)
            if offset ~= nil then
                offset.x = offset.x + pt.x
                offset.z = offset.z + pt.z
                return offset
            end
        else
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
    end

    local function GetSpecialSpawnChance()
        local day = GetAveragePlayerAgeInDays()
        local chance = 0
        for i, v in ipairs(TUNING.HOUND_SPECIAL_CHANCE) do
            if day > v.minday then
                chance = v.chance
            elseif day <= v.minday then
                return chance
            end
        end
        return TheWorld.state.issummer and chance * 1.5 or chance
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
                if (math.random() * _drop_mult) < .3 then
                    inst.components.lootdropper:SpawnLootPrefab("bluegem")
                end
                inst.SoundEmitter:PlaySound("dontstarve/creatures/hound/icehound_explo", "explosion")
            end)
        else
            theMob.AnimState:SetMultColour(1,.25,.25,1)
            theMob:ListenForEvent("death", function(inst)
                if (math.random() * _drop_mult) < .3 then
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

    local function SummonSpawn(pt, upgrade)
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

        if spawn_pt ~= nil then

            --local prefab = "hound"
            local specialStats = nil
            local special_hound_chance = self.debugSpawn and 1 or GetSpecialSpawnChance()

            -- Some mobs have a special variant (different from elemental). See if they convert.
            local specialPrefab = MOB_LIST[self.currentIndex].specialVariation
            -- Default to normal special hound chance if a variation rate isn't defined.
            local specialChance = MOB_LIST[self.currentIndex].specialVariationRate or special_hound_chance
            if specialPrefab ~= nil and math.random() <= specialChance then
                prefab = specialPrefab
            end

            local chanceMod = MOB_LIST[self.currentIndex].mobMult or 1

            -- If the user is crazy, they can make all of the mobs be a special version.
            local alwaysSpecial = (MOB_LIST[self.currentIndex].elemental == "always") or false

            if alwaysSpecial then
                print(prefab .. " is set to Always Special!!")
            end

            local rand = math.random()
            if alwaysSpecial or (rand < special_hound_chance/chanceMod) then
                print("Rolled a " .. rand .. "...summoning special mob")
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
            if theMob ~= nil then
                -- give the mob its special sauce
                self:AddMob(theMob)

                -- If this mob has special chance enabled, make a special version.
                -- Users can disable the special chance for any given mob.
                local canBeSpecial = (MOB_LIST[self.currentIndex].elemental == "normal") or
                                     (MOB_LIST[self.currentIndex].elemental == "always") or 0

                if specialStats ~= nil and canBeSpecial then
                    print("You're in for some fun!!!")
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
                if canBeSpecial and theMob:HasTag("lightninggoat") and (alwaysSpecial or math.random() < (.85*special_hound_chance)) then
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

                if canBeSpecial and theMob:HasTag("pig") and (alwaysSpecial or math.random() < (.85*special_hound_chance)) then
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

                if theMob.components.spawnfader ~= nil then
                    theMob.components.spawnfader:FadeIn()
                end
                return theMob
            end
        end
    end

    local function ReleaseSpawn(target, upgrade)
        if not _targetableplayers[target.GUID] or _targetableplayers[target.GUID] == "land" then
            local spawn = SummonSpawn(target:GetPosition(), upgrade)
            if spawn ~= nil then
                spawn.components.combat:SuggestTarget(target)
                return true
            end
        end

        return false
    end

    local function RemovePendingSpawns(player)
        if _spawninfo ~= nil then
            for i, info in ipairs(_spawninfo) do
                if info.players[player] ~= nil then
                    info.players[player] = nil
                    if next(info.players) == nil then
                        table.remove(_spawninfo, i)
                    end
                    return
                end
            end
        end
    end


    local function GenerateSaveDataFromDelayedSpawnInfo(player, savedata, delayedspawninfo)
        savedata[player.userid] =
        {
            _warning = delayedspawninfo._warning,
            _timetoattack = delayedspawninfo._timetoattack,
            _warnduration = delayedspawninfo._warnduration,
            _timetonextwarningsound = delayedspawninfo._timetonextwarningsound,
            _announcewarningsoundinterval = delayedspawninfo._announcewarningsoundinterval,
            _targetstatus =  _targetableplayers[player.GUID]
        }
        if delayedspawninfo._spawninfo then
            local spawninforec = delayedspawninfo._spawninfo
            savedata[player.userid]._spawninfo = {
                count = spawninforec.players and spawninforec.players[player] or 0,
                timetonext = spawninforec.timetonext,
                averageplayerage = spawninforec.averageplayerage,
            }
        end
    end

    local function GenerateSaveDataFromSpawnInfo(player, savedata)
        savedata[player.userid] =
        {
            _warning = _warning,
            _timetoattack = _timetoattack,
            _warnduration = _warnduration,
            _timetonextwarningsound = _timetonextwarningsound,
            _announcewarningsoundinterval = _announcewarningsoundinterval,
        }
        if _spawninfo then
            for i, spawninforec in ipairs(_spawninfo) do
                if spawninforec.players[player] then
                    savedata[player.userid]._spawninfo =
                    {
                        count = spawninforec.players[player],
                        timetonext = spawninforec.timetonext,
                        averageplayerage = spawninforec.averageplayerage,
                    }
                    break
                end
            end
        end
    end

    local function LoadSaveDataFromMissingSpawnInfo(player, missingspawninfo)
        _delayedplayerspawninfo[player] =
        {
            _warning = missingspawninfo._warning,
            _timetoattack = missingspawninfo._timetoattack,
            _warnduration = missingspawninfo._warnduration,
            _timetonextwarningsound = missingspawninfo._timetonextwarningsound,
            _announcewarningsoundinterval = missingspawninfo._announcewarningsoundinterval,
        }
        if missingspawninfo._targetstatus then
            _targetableplayers[player.GUID] = missingspawninfo._targetstatus
        end
        if missingspawninfo._spawninfo then
            local spawninforec = missingspawninfo._spawninfo
            _delayedplayerspawninfo[player]._spawninfo =
            {
                players = {[player] = spawninforec.count},
                timetonext = spawninforec.timetonext,
                averageplayerage = spawninforec.averageplayerage,
            }
        end
    end

    local function LoadPlayerSpawnInfo(player)
        if _missingplayerspawninfo[player.userid] then
            LoadSaveDataFromMissingSpawnInfo(player, _missingplayerspawninfo[player.userid])
            _missingplayerspawninfo[player.userid] = nil
        end
    end

    local function SavePlayerSpawnInfo(player, savedata, isworldsave)
        if _delayedplayerspawninfo[player] then
            GenerateSaveDataFromDelayedSpawnInfo(player, savedata, _delayedplayerspawninfo[player])
            if not isworldsave then
                _delayedplayerspawninfo[player] = nil
            end
        elseif _warning or _timetoattack < 0 or _spawninfo ~= nil then
            GenerateSaveDataFromSpawnInfo(player, savedata)
            if not isworldsave then
                RemovePendingSpawns(player)
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

	LoadPlayerSpawnInfo(player)
    end

    local function OnPlayerLeft(src, player)
        SavePlayerSpawnInfo(player, _missingplayerspawninfo)

        _targetableplayers[player.GUID] = nil

        for i, v in ipairs(_activeplayers) do
            if v == player then
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

    local function CheckForWaterImunity(player)
        if not _targetableplayers[player.GUID] then
            -- block hound wave targeting when target is on water.. for now.
            local x,y,z = player.Transform:GetWorldPosition()
            if TheWorld.Map:IsVisualGroundAtPoint(x,y,z) then
                _targetableplayers[player.GUID] = "land"
            else
                _targetableplayers[player.GUID] = "water"
            end
        end
    end

    local function CheckForWaterImunityAllPlayers()
        for i, v in ipairs(_activeplayers) do
            CheckForWaterImunity(v)
        end
    end

    local function SetDifficulty(src, difficulty)
        if difficulty == "never" then
            self:SpawnModeNever()
        elseif difficulty == "rare" then
            self:SpawnModeLight()
        elseif difficulty == "default" then
            self:SpawnModeNormal()
        elseif difficulty == "often" then
            self:SpawnModeMed()
        elseif difficulty == "always" then
            self:SpawnModeHeavy()
        end
    end

    local function SetSummerVariant(src, enabled)
        if enabled == "never" then
            self:SetSummerVariant(false)
        elseif enabled == "default" then
            self:SetSummerVariant(true)
        end
    end

    local function SetWinterVariant(src, enabled)
        if enabled == "never" then
            self:SetWinterVariant(false)
        elseif enabled == "default" then
            self:SetWinterVariant(true)
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

    inst:ListenForEvent("hounded_setdifficulty", SetDifficulty)
    inst:ListenForEvent("hounded_setsummervariant", SetSummerVariant)
    inst:ListenForEvent("hounded_setwintervariant", SetWinterVariant)

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

    function self:SetSummerVariant(enabled)
	    _spawnsummervariant = enabled
    end

    function self:SetWinterVariant(enabled)
	    _spawnwintervariant = enabled
    end

    function self:SpawnModeNever()
        _spawnmode = "never"
        PlanNextAttack()
    end

    function self:SpawnModeLight()
        _spawnmode = "constant"
        _attackdelayfn = _spawndata.attack_delays.heavy or _spawndata.attack_delays.frequent
        _warndurationfn = _spawndata.attack_levels.light.warnduration
        PlanNextAttack()
    end

    function self:SpawnModeNormal()
        _spawnmode = "escalating"
        PlanNextAttack()
    end

    self.SpawnModeEscalating = self.SpawnModeNormal

    function self:SpawnModeMed()
        _spawnmode = "constant"
        _attackdelayfn = _spawndata.attack_delays.med or _spawndata.attack_delays.occasional
        _warndurationfn = _spawndata.attack_levels.med.warnduration
        PlanNextAttack()
    end

    function self:SpawnModeHeavy()
        _spawnmode = "constant"
        _attackdelayfn = _spawndata.attack_delays.light or _spawndata.attack_delays.rare
        _warndurationfn = _spawndata.attack_levels.heavy.warnduration
        PlanNextAttack()
    end

    -- Releases a hound near and attacking 'target'
    function self:ForceReleaseSpawn(target)
        if target ~= nil then
            ReleaseSpawn(target)
        end
    end

    local function OriginalSummonSpawn(pt)
        local spawn_pt = GetSpawnPoint(pt)
        if spawn_pt ~= nil then
            local spawn = SpawnPrefab(
                (math.random() >= GetSpecialSpawnChance() and _spawndata.base_prefab) or
                ((TheWorld.state.iswinter or TheWorld.state.isspring) and _spawndata.winter_prefab) or
                _spawndata.summer_prefab
            )
            if spawn ~= nil then
                spawn.Physics:Teleport(spawn_pt:Get())
                spawn:FacePoint(pt)
                if spawn.components.spawnfader ~= nil then
                    spawn.components.spawnfader:FadeIn()
                end
                return spawn
            end
        end
    end

    -- Creates a hound near 'pt'
    function self:SummonSpawn(pt)
        print("self:SummonSpawn called")
        return pt ~= nil and OriginalSummonSpawn(pt) or nil
    end

    -- Spawns the next wave for debugging
    function self:ForceNextWave()
        PlanNextAttack()
        _timetoattack = 0
        houndDebug = true
        self:OnUpdate(1)
        --self:OnUpdate(1)
    end

    -- Can override the next hound mob with this index
    function self:PlanNextHoundAttack(index)
        print("PlanNextHoundAttack with override")
        houndDebug=true
        PlanNextAttack(nil, index)
    end

    function self:StartAttack(tt)
        if not tt then
            tt = 1
        end
        print("Starting attack in " .. tt .. " seconds")
        houndDebug = true
        _timetoattack=tt
        --self:OnUpdate(1)
    end

    local function _DoWarningSpeech(player)
        player.components.talker:Say(GetString(player, _spawndata.warning_speech))
    end

    function self:DoWarningSpeech()
        --for i, v in ipairs(_activeplayers) do
        for GUID,data in pairs(_targetableplayers) do
            if data == "land" then
                local player = Ents[GUID]
                player:DoTaskInTime(math.random() * 2, _DoWarningSpeech)
            end
        end
    end

    function self:DoWarningSound()
        for k,v in pairs(_spawndata.warning_sound_thresholds) do
            if _timetoattack <= v.time or _timetoattack == nil then
                for GUID,data in pairs(_targetableplayers)do
                    local player = Ents[GUID]
                    if player and data == "land" then
                        player:PushEvent("houndwarning",HOUNDWARNINGTYPE[v.sound])
                    end
                end
                break
            end
        end
    end


    function self:DoDelayedWarningSpeech(player, data)
        if _targetableplayers[player.GUID] == "land" then
            player:DoTaskInTime(math.random() * 2, _DoWarningSpeech)
        end
    end

    function self:DoDelayedWarningSound(player, data)
        for k,v in pairs(_spawndata.warning_sound_thresholds) do
            if data._timetoattack <= v.time or data._timetoattack == nil then
                if _targetableplayers[player.GUID] == "land" then
                    player:PushEvent("houndwarning",HOUNDWARNINGTYPE[v.sound])
                end
                break
            end
        end
    end

    local function ShouldUpgrade(amount)
        if amount >= 8 then
            return math.random() < 0.7
        elseif amount == 7 then
            return math.random() < 0.3
        elseif amount == 6 then
            return math.random() < 0.15
        elseif amount == 5 then
            return math.random() < 0.05
        end
        return false
    end

    local function HandleSpawnInfoRec(dt, i, spawninforec, groupsdone)
        spawninforec.timetonext = spawninforec.timetonext - dt
        if next(spawninforec.players) ~= nil and spawninforec.timetonext < 0 then
            local target = weighted_random_choice(spawninforec.players)

            if spawninforec.players[target] <= 0 then
                spawninforec.players[target] = nil
                if next(spawninforec.players) == nil then
                    table.insert(groupsdone, 1, i)
                end
                return
            end

            -- TEST IF GROUPS IF HOUNDS SHOULD BE TURNED INTO A VARG (or other)
            --local upgrade = _spawndata.upgrade_spawn and ShouldUpgrade(spawninforec.players[target])
            local upgrade = false

            if upgrade then
                spawninforec.players[target] = spawninforec.players[target] - 5
            else
                spawninforec.players[target] = spawninforec.players[target] - 1
            end

            ReleaseSpawn(target, upgrade)

            if spawninforec.players[target] <= 0 then
                spawninforec.players[target] = nil
            end

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
        if next(spawninforec.players) == nil then
            table.insert(groupsdone, 1, i)
        end
    end

    function self:OnUpdate(dt)
        if _spawnmode == "never" then
            return
        end

    	for player, data in pairs (_delayedplayerspawninfo) do
            data._timetoattack = data._timetoattack - dt
            if data._timetoattack < 0 then
                _warning = false

                -- Okay, it's hound-day, get number of dogs for each player
                if data._spawninfo == nil then
                    GetDelayedPlayerWaveAmounts(player, data)
                end

                local groupsdone = {}
                CheckForWaterImunity(player)
                for i, spawninforec in ipairs(data._spawninfo) do
                    HandleSpawnInfoRec(dt, i, spawninforec, groupsdone)
                end

                for i, v in ipairs(groupsdone) do
                    table.remove(data._spawninfo, v)
                end

                if #data._spawninfo <= 0 then
                    _delayedplayerspawninfo[player] = nil
                    _targetableplayers[player] = nil
                end
            elseif not data._warning and data._timetoattack < data._warnduration then
                data._warning = true
                data._timetonextwarningsound = 0
            end

            if data._warning then
                data._timetonextwarningsound = data._timetonextwarningsound - dt

                if data._timetonextwarningsound <= 0 then
                    CheckForWaterImunity(player)
                    data._announcewarningsoundinterval = data._announcewarningsoundinterval - 1
                    if data._announcewarningsoundinterval <= 0 then
                        data._announcewarningsoundinterval = 10 + math.random(5)
                        self:DoDelayedWarningSpeech(player, data)
                    end

                    data._timetonextwarningsound =
                        (data._timetoattack < 30 and .3 + math.random(1)) or
                        (data._timetoattack < 60 and 2 + math.random(1)) or
                        (data._timetoattack < 90 and 4 + math.random(2)) or
                                                5 + math.random(4)

                    self:DoDelayedWarningSound(player, data)
                end
            end
        end

        -- if there's no players, then don't even try
        if #_activeplayers == 0  or not _attackplanned then
            return
        end

        _timetoattack = _timetoattack - dt
        --print("Next Attack in " .. _timetoattack .. " seconds")

        if _pausesources:Get() and not _warning and (_timetoattack >= 0 or _spawninfo == nil) then
            if _timetoattack < 0 then
                PlanNextAttack()
            end
            return
        end

        if _timetoattack < 0 then
            _warning = false
            -- If this is nil somehow, generate a new mob
            if self.currentIndex == nil then
                self.currentIndex = getRandomMob()
            end

            -- Verify the season requirements are still valid.
            if MOB_LIST[self.currentIndex].Season ~= nil then
                local stillValid = false
                for key,season in pairs(MOB_LIST[self.currentIndex].Season) do
                    if TheWorld.state.season == season then
                        stillValid = true
                    end
                end

                -- If stillValid is false, pick a new mob!
                if not stillValid then
                    print("Current mob no longer valid! Picking new one...")
                    self.currentIndex = getRandomMob()
                end
            end

            -- Okay, it's hound-day, get number of dogs for each player
            if _spawninfo == nil then
                print("Calculating amounts for each player")
                GetWaveAmounts()
            end

            local groupsdone = {}
            CheckForWaterImunityAllPlayers()
            for i, spawninforec in ipairs(_spawninfo) do
                HandleSpawnInfoRec(dt, i, spawninforec, groupsdone)
            end

            for i, v in ipairs(groupsdone) do
                table.remove(_spawninfo, v)
            end

            if #_spawninfo <= 0 then
                print("Done releasing hounds. Planning next attack")
                _spawninfo = nil

                PlanNextAttack()
            end
        elseif not _warning and _timetoattack < _warnduration then
            _warning = true
            _timetonextwarningsound = 0
        end

        if _warning then
            _timetonextwarningsound	= _timetonextwarningsound - dt

            if _timetonextwarningsound <= 0 then
                CheckForWaterImunityAllPlayers()
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

    self.LongUpdate = self.OnUpdate

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
        local missingspawninfo = deepcopy(_missingplayerspawninfo)
        for i, player in ipairs(AllPlayers) do
            SavePlayerSpawnInfo(player, missingspawninfo, true)
        end
        return
        {
            warning = _warning,
            timetoattack = _timetoattack,
            warnduration = _warnduration,
            attackplanned = _attackplanned,
            missingplayerspawninfo = missingspawninfo,
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
        _missingplayerspawninfo = data.missingplayerspawninfo or {}

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

    function self:GetMobList()
        return MOB_LIST
    end

    function self:SetMobList(list)
        MOB_LIST = list
    end

    -- Allow users to add a custom mob to the list.
    -- Must follow the format defined in modmain.lua....
    -- Even though I've added this here, the game doesn't know it exsits. Maybe because
    -- I'm modifying a workshop mod and not a custom one....
    function self:AddCustomMob(theMob)

        -- Validate the minimum exists
        if theMob == nil or theMob.prefab == nil then
            print("ERROR: No prefab found in custom mob...nothing to do")
            return
        end
        print("Adding custom mob: " .. theMob.prefab)

        -- If the mob is disabled, it shouldn't be added as a custom mob on startup....
        -- so just forcing this true on all custom mobs
        theMob.enabled = true

        table.insert(MOB_LIST, theMob)

        -- ReRoll the next hound attack after a new one is added
        PlanNextAttack()
    end

    function self:SetDropRate(rate)
        print("Setting Drop Rate to " .. rate)
        _drop_mult = rate
    end

    --------------------------------------------------------------------------
    --[[ Debug ]]
    --------------------------------------------------------------------------

    function self:GetDebugString()
        if _timetoattack > 0 then
            if self.currentIndex then
                return string.format("%s %s are coming in %2.2f", (_warning and "WARNING") or (_pausesources:Get() and "BLOCKED") or "WAITING", MOB_LIST[self.currentIndex].prefab,  _timetoattack)
            else
                return string.format("No mob selected yet...")
            end
        else
            local s = "DORMANT"
            if _spawnmode ~= "never" then
                s = "ATTACKING"
                for i, spawninforec in ipairs(_spawninfo) do
                    s = s.."\n{"
                    for player, _ in pairs(spawninforec.players) do
                        s = s..tostring(player)..","
                    end
                    s = s.."} - spawns left:"..tostring(spawninforec.spawnstorelease).." next spawn:"..tostring(spawninforec.timetonext)
                end
            end
            return s
        end
    end

    function self:GetDebugSupplies()
        for i,v in ipairs(AllPlayers) do
            local playerPos = Vector3(v.Transform:GetWorldPosition())
            if playerPos ~= nil then
                SpawnPrefab("armorwood").Transform:SetPosition(playerPos:Get())
                SpawnPrefab("spear").Transform:SetPosition(playerPos:Get())
                SpawnPrefab("footballhat").Transform:SetPosition(playerPos:Get())
            end
        end
    end

    function self:GetSpawnData()
        return _spawndata
    end

    end)