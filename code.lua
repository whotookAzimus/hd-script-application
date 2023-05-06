--!nocheck 
-- Since mods apparently need me to add damn comments to my code, here you go.

--[[ Services ]]--
-- defining Services
local collectionService = game:GetService("CollectionService")
local players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")

--[[ Events ]]--
-- Defining remove events and the such
local eventsFolder = rs:WaitForChild("Combat"):WaitForChild("Melee"):WaitForChild("Events")

local createWeaponHandlerUponSpawnRF = eventsFolder:WaitForChild("CreateWeaponHandlerUponSpawn")
local editWeaponHolsterRE = eventsFolder:WaitForChild("EditWeaponHolster")
local accumulatedDamageRE = eventsFolder:WaitForChild("AccumulatedDamage")
local hitCounterRE = eventsFolder:WaitForChild("HitCounter")

local stunClientRE = eventsFolder:WaitForChild("StunClient")
local unstunClientRE = eventsFolder:WaitForChild("UnstunClient")

local equipToolRF = eventsFolder:WaitForChild("EquipTool")
local unequipToolRF = eventsFolder:WaitForChild("UnequipTool")

local M1StartsRF = eventsFolder:WaitForChild("M1Starts")
local M1FinishesRF = eventsFolder:WaitForChild("M1Finishes")

local parryStartsRF = eventsFolder:WaitForChild("ParryStarts")
local parryFinishesRF = eventsFolder:WaitForChild("ParryFinishes")

local specialStartsRF = eventsFolder:WaitForChild("SpecialStarts")
local specialFinishesRF = eventsFolder:WaitForChild("SpecialFinishes")

local beginCastingRE = eventsFolder:WaitForChild("BeginCasting")
local finishCastingRE = eventsFolder:WaitForChild("FinishCasting")
local hitSomethingRE = eventsFolder:WaitForChild("HitSomething")

--[[ Modules ]]--
-- Defining all used modules
local toClients = require(rs:WaitForChild("Combat"):WaitForChild("Melee"):WaitForChild("Modules"):WaitForChild("ToClients"))
local weaponSettingsList = require(rs:WaitForChild("Combat"):WaitForChild("Melee"):WaitForChild("Modules"):WaitForChild("WeaponSettingsList"))

--[[ CombatStates ]]--

-- These are the combat state values that the weapon handler can be in.
local combatStateValues = {
	["None"] = "None",
	["M1"] = "M1",
	["Parry"] = "Parry",
	["Stunned"] = "Stunned",
	["Special"] = "Special",
}

--[[ WeaponHandlers ]]--

-- A table of all the weapon handlers in the server.
local weaponHandlers = {}

-- A template for the weapon handler.
local weaponHandlerTemplate = {
	["CurrentState"] = combatStateValues.None,
	["LastState"] = combatStateValues.None,

	["M1Stage"] = 1,
	["AccumulatedDamage"] = 0,

	["ConsecutiveHits"] = 0,

	["IsParrying"] = false,
	["IsCasting"] = false,

	["WeaponName"] = "",
	["Weapon"] = nil,
	["HolsterAccessory"] = nil,
	["PlayerHasDied"] = false
}

--[[ Special Functions ]]--
-- Special util functions that are used in the script.
local function deepCopy(tableToCopy)
	local copy = {}

	for i, v in pairs(tableToCopy) do
		if typeof(v) == "table" then
			copy[i] = deepCopy(v)
		else
			copy[i] = v
		end
	end

	return copy
end

local function changeWeaponHandlerState(weaponHandler, currentState, lastState: string?)
	weaponHandler.LastState = lastState or weaponHandler.CurrentState
	weaponHandler.CurrentState = currentState
end

--[[ Events ]]--
-- All the code inside this block relates to player events.

-- All the code inside this block relates to when the player spawns.
local WhenThePlayerSpawns do
	createWeaponHandlerUponSpawnRF.OnServerInvoke = function(player)
		if not weaponHandlers[player] or weaponHandlers[player].PlayerHasDied then
			weaponHandlers[player] = deepCopy(weaponHandlerTemplate)
			print("Weapon handler for player: ", player.Name, " has now been created.")
			-- if they do not have one or are already dead then create a new one
		end
	end

	editWeaponHolsterRE.OnServerEvent:Connect(function(player, isVisible, weaponName)
		-- remote that edits whether their holster (the physical weapon the player sees on their body) is visible or not (play the game, you'll get it)
		local char = player.Character

		if weaponHandlers[player] and not weaponHandlers[player].PlayerHasDied then
			local weaponHandler = weaponHandlers[player]

			local holsterAccessory = weaponHandler.HolsterAccessory or rs:WaitForChild("Combat"):WaitForChild("Melee"):WaitForChild("Swords"):WaitForChild(weaponName):WaitForChild("Assets"):WaitForChild("Holstering"):WaitForChild("HolsterAccessory"):Clone()
			weaponHandler.HolsterAccessory = holsterAccessory
			-- define their holster accessory and set it to the weapon handler (this code looks a little weird now that i look back at it)

			if holsterAccessory.Parent ~= char then
				holsterAccessory.Parent = char
				-- if the holster accessory is not parented to the player's character then parent it to the player's character 🧠
			end

			for i, descendant in pairs(holsterAccessory:WaitForChild("Handle"):WaitForChild("Visible"):GetDescendants()) do
				if descendant:IsA("BasePart") then
					descendant.Transparency = isVisible and 0 or 1
					-- whenever this event is fired it will change the transparency of the weapon's holster accessory depending on what isVisible is
				end
			end
		end
	end)
end

-- All the code inside this block relates to when the player dies.
local WhenThePlayerDies do
	-- this should be a special fn lol, but it's not.
	local function checkIfHumanoidHasDied(hum: Humanoid)
		hum.StateChanged:Connect(function(oldState, newState)
			if newState == Enum.HumanoidStateType.Dead then
				print("Humanoid has died.")

				local player = players:GetPlayerFromCharacter(hum.Parent)

				if player then
					local weaponHandler = weaponHandlers[player]

					if weaponHandler then
						weaponHandler.PlayerHasDied = true
					end
				end
			end
		end)
	end

	-- check if existing humanoid dies
	for i, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("Humanoid") then
			checkIfHumanoidHasDied(descendant)
		end
	end
	-- check whenever any new humanoid dies
	workspace.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("Humanoid") then
			checkIfHumanoidHasDied(descendant)
		end
	end)
end

-- All the code inside this block relates to when the player equips a tool.
local WhenThePlayerEquipsATool do
	equipToolRF.OnServerInvoke = function(player, tool)
		if weaponHandlers[player] and not weaponHandlers[player].PlayerHasDied then
			local weaponHandler = weaponHandlers[player]

			weaponHandler.Weapon = tool
			weaponHandler.WeaponName = tool.Name

			if toClients[tool.Name] then
				local toClient = toClients[tool.Name]
				toClient.toClients("Equip", {player.Character})
				-- do the equip fx on all clients
			end
		end
	end
end

-- All the code inside this block relates to when the player unequips a tool.
local WhenThePlayerUnequipsATool do
	unequipToolRF.OnServerInvoke = function(player)
		local char = player.Character
		local weaponHandler = weaponHandlers[player]

		if char and not char:FindFirstChildWhichIsA("Tool") and weaponHandler and not weaponHandler.PlayerHasDied then
			weaponHandler.Weapon = nil
			weaponHandler.WeaponName = ""

			task.delay(1, function()
				if weaponHandler.CurrentState ~= combatStateValues.None then
					changeWeaponHandlerState(weaponHandler, combatStateValues.None)
					weaponHandler.IsParrying = false
					weaponHandler.IsCasting = false

					if toClients[weaponHandler.WeaponName] then
						local toClient = toClients[weaponHandler.WeaponName]
						toClient.toClients("AttackEnding", {player.Character})
					end
				end
			end)
			--weaponHandler.HolsterAccessory = nil
		end
	end
end

-- All the code inside this block relates to when the player m1s (clicks).
local WhenThePlayerM1s do
	M1StartsRF.OnServerInvoke = function(player, M1Stage, delayToBeginCasting, delayToStopCasting)
		local weaponHandler = weaponHandlers[player]

		print("Are they parrying: ", weaponHandler.IsParrying)
		print("Are they casting: ", weaponHandler.IsCasting)
		print("Their current state: ", weaponHandler.CurrentState)

		if weaponHandler and not weaponHandler.PlayerHasDied and weaponHandler.Weapon and not weaponHandler.IsParrying and not weaponHandler.IsCasting and weaponHandler.CurrentState == combatStateValues.None then
			changeWeaponHandlerState(weaponHandler, combatStateValues.M1)
			weaponHandler.M1Stage = M1Stage
			-- change the m1 stage (1, 2, 3, etc.)

			if delayToBeginCasting then
				task.delay(delayToBeginCasting, function()
					weaponHandler.IsCasting = true
					beginCastingRE:FireClient(player)
				end)
			else
				beginCastingRE:FireClient(player)
				-- start casting
			end

			if delayToStopCasting then
				task.delay(delayToStopCasting, function()
					weaponHandler.IsCasting = false
					finishCastingRE:FireClient(player)
					-- stop casting
				end)
			end

			local wpnSettings = weaponSettingsList[weaponHandler.WeaponName]

			if wpnSettings then
				if toClients[weaponHandler.WeaponName] then
					local toClient = toClients[weaponHandler.WeaponName]
					toClient.toClients("Attack", {player.Character, M1Stage == #wpnSettings.Assets.Animations.M1})
					-- do attack fx on all clients
				end
			end

			return true
		end
	end

	M1FinishesRF.OnServerInvoke = function(player, newStage)
		local weaponHandler = weaponHandlers[player]

		if weaponHandler and weaponHandler.CurrentState == combatStateValues.M1 then
			changeWeaponHandlerState(weaponHandler, combatStateValues.None)
			weaponHandler.M1Stage = newStage
			-- set the m1 stage to the new stage

			if toClients[weaponHandler.WeaponName] then
				local toClient = toClients[weaponHandler.WeaponName]
				toClient.toClients("AttackEnding", {player.Character})
				-- do attack fx on all clients
			end

			if weaponHandler.IsCasting then
				weaponHandler.IsCasting = false
				finishCastingRE:FireClient(player)
				-- stop casting
			end
		end
	end
end

-- All the code inside this block relates to when the player uses their special attack.
local WhenThePlayerUsesTheirSpecial do
	specialStartsRF.OnServerInvoke = function(player, delayToBeginCasting, delayToStopCasting, reqDamage)
		local weaponHandler = weaponHandlers[player]
		
		-- if they are alive, they have a weapon, they are not parrying, they are not already attacking and are in a neutral state
		if weaponHandler and not weaponHandler.PlayerHasDied and weaponHandler.Weapon and not weaponHandler.IsParrying and not weaponHandler.IsCasting and weaponHandler.CurrentState == combatStateValues.None and weaponHandler.AccumulatedDamage >= reqDamage then
			changeWeaponHandlerState(weaponHandler, combatStateValues.Special)
			weaponHandler.AccumulatedDamage = 0
			accumulatedDamageRE:FireClient(player, weaponHandler.AccumulatedDamage)
			-- reset the accumulated damage and fire client to change the ui


			if delayToBeginCasting then
				task.delay(delayToBeginCasting, function()
					weaponHandler.IsCasting = true
					beginCastingRE:FireClient(player)
					-- begin casting (hit detection is on the client)
				end)
			else
				beginCastingRE:FireClient(player)
			end

			if delayToStopCasting then
				task.delay(delayToStopCasting, function()
					weaponHandler.IsCasting = false
					finishCastingRE:FireClient(player)
					-- finish casting rays on the client
				end)
			end

			return true
		end
	end

	specialFinishesRF.OnServerInvoke = function(player)
		local weaponHandler = weaponHandlers[player]
		
		-- if they are in an ideal state to finish casting
		if weaponHandler and not weaponHandler.PlayerHasDied and weaponHandler.Weapon and not weaponHandler.IsParrying and weaponHandler.CurrentState == combatStateValues.Special then
			changeWeaponHandlerState(weaponHandler, combatStateValues.None)
			finishCastingRE:FireClient(player)
			-- finish casting 🤯
			return true
		end
	end
end

-- All the code inside this block relates to when the player hits something (hit validation).
local WhenThePlayerHitsSomething do
	hitSomethingRE.OnServerEvent:Connect(function(player, whatWasHit: Instance)
		local weaponHandler = weaponHandlers[player]

		local wpnSettings = weaponSettingsList[weaponHandler.WeaponName]
		-- grabs the weapon settings from the weapon settings list

		if not wpnSettings then
			return
		end
		-- i know the readers are intelligent enough to get this one

		if weaponHandler and weaponHandler.IsCasting then --If they have a wpnhandler and are casting an attack
			if weaponHandler.CurrentState == combatStateValues.M1 then -- If they are using a normal m1
				if whatWasHit and whatWasHit:IsA("Humanoid") then -- if something was hit and it is a humanoid (client hit detection just returns a humanoid)
					--print("The humanoid with a parent of: ", whatWasHit.Parent, " was hit!")

					local victimChar, victimHum = whatWasHit.Parent, whatWasHit
					local victimHumRP: BasePart = victimChar:WaitForChild("HumanoidRootPart")
					local victimPlayer: Player? = players:GetPlayerFromCharacter(victimChar)

					-- define the victim (who got hit)

					if victimHum:GetState() == Enum.HumanoidStateType.Dead then
						return
					end

					if victimPlayer then
						if player.Team and player.Team == victimPlayer.Team then
							if not wpnSettings.Interaction.FriendlyFire.Enabled then
								-- If they are on the same team and no friendly fire then dont hit them
								return -- Friendly fire is not enabled
							end
						end
					end

					local victimWeaponHandler = weaponHandlers[victimPlayer]

					if victimWeaponHandler and victimWeaponHandler.CurrentState == combatStateValues.Parry then
						-- if the victim that was hit was parrying, then the aggressor has been parried
						local victimWeaponSettings = weaponSettingsList[victimWeaponHandler.WeaponName]

						if victimWeaponSettings.Enabled.WeaponStunEnabled then
							-- if they are using a weapon that can stun and has stun enabled
							if player.Team and player.Team == victimPlayer.Team and not victimWeaponSettings.Interaction.FriendlyFire.StunsFriendlies then
								print("cant stun friendlies")
							else
								changeWeaponHandlerState(weaponHandler, combatStateValues.Stunned)
								stunClientRE:FireClient(player, victimWeaponSettings.Interaction.Stuns.StunWalkSpeed)

								-- do the stun stuff

								if toClients[weaponHandler.WeaponName] then
									local toClient = toClients[weaponHandler.WeaponName]
									toClient.toClients("Parried", {player, player.Character, victimPlayer})
								end

								task.delay(victimWeaponSettings.Interaction.Stuns.ParryStunDuration, function()
									-- unstun them after the stun duration
									unstunClientRE:FireClient(player)
									changeWeaponHandlerState(weaponHandler, combatStateValues.None)
									print(weaponHandler.CurrentState)
								end)
							end
						else
							print("Weapon can't stun")
						end

						if toClients[weaponHandler.WeaponName] then
							local toClient = toClients[weaponHandler.WeaponName]
							toClient.toClients("AttackEnding", {player.Character})
							-- end their attack early, since they were parried
						end
					else
						-- if they were not parrying, then the aggressor has hit the victim
						local isFinalStage = weaponHandler.M1Stage == #wpnSettings.Assets.Animations.M1 and true
						local damage

						if isFinalStage then
							damage = wpnSettings.Interaction.Attacking.LungeDamage
						else
							damage = wpnSettings.Interaction.Attacking.SlashDamage
						end

						if victimPlayer and player.Team and player.Team == victimPlayer.Team then
							damage *= wpnSettings.Interaction.FriendlyFire.DamageMultiplier
						end

						victimHum:TakeDamage(damage)
						weaponHandler.AccumulatedDamage += damage
						weaponHandler.ConsecutiveHits += 1
						-- Deal damage, add to consecutive hits, and add to accumulated damage

						accumulatedDamageRE:FireClient(player, weaponHandler.AccumulatedDamage)

						if wpnSettings.Enabled.HitCounterEnabled then
							hitCounterRE:FireClient(player, weaponHandler.ConsecutiveHits)
							-- if they have the hit counter (UI that shows how many hits), fire to client

							if weaponHandler.ConsecutiveHits > 0 then
								local oldHitCounts = weaponHandler.ConsecutiveHits

								task.delay(wpnSettings.Interaction.HitCounter.ResetConsecutiveHitsAfter, function()
									if weaponHandler.ConsecutiveHits == oldHitCounts then
										weaponHandler.ConsecutiveHits = 0
										hitCounterRE:FireClient(player, weaponHandler.ConsecutiveHits)
									end
								end)
							end
						end

						if toClients[weaponHandler.WeaponName] then
							local toClient = toClients[weaponHandler.WeaponName]
							toClient.toClients("Hit", {player, victimChar, victimPlayer, false})
							-- configure hit effects on all clients
						end
					end
				else
					--print(whatWasHit.Name, " with a type of: ", whatWasHit.ClassName, " was hit by ", player.Name, "!")
				end
			elseif weaponHandler.CurrentState == combatStateValues.Special then
				-- if they were doing the special attack, then do all the same stuff (more or less) as the normal attack (dont feel like explaining 500 lines, sorry readers lol)
				if whatWasHit and whatWasHit:IsA("Humanoid") then
					--print("The humanoid with a parent of: ", whatWasHit.Parent, " was hit!")

					local victimChar, victimHum = whatWasHit.Parent, whatWasHit
					local victimHumRP: BasePart = victimChar:WaitForChild("HumanoidRootPart")
					local victimPlayer = players:GetPlayerFromCharacter(victimChar)

					if victimHum:GetState() == Enum.HumanoidStateType.Dead then
						return
					end

					local victimWeaponHandler = weaponHandlers[victimPlayer]

					local damage

					if victimWeaponHandler then
						damage = victimWeaponHandler.CurrentState == combatStateValues.Parry and wpnSettings.Interaction.Special.ParrybrokenDamageDealt or wpnSettings.Interaction.Special.NormalDamageDealt
					else
						damage = wpnSettings.Interaction.Special.NormalDamageDealt
					end

					if victimPlayer and player.Team and player.Team == victimPlayer.Team then
						damage *= wpnSettings.Interaction.FriendlyFire.DamageMultiplier
					end

					victimHum:TakeDamage(damage)
					print("hello daddy")

					weaponHandler.ConsecutiveHits += 1

					if wpnSettings.Enabled.HitCounterEnabled then
						hitCounterRE:FireClient(player, weaponHandler.ConsecutiveHits)

						if weaponHandler.ConsecutiveHits > 0 then
							local oldHitCounts = weaponHandler.ConsecutiveHits

							task.delay(wpnSettings.Interaction.HitCounter.ResetConsecutiveHitsAfter, function()
								if weaponHandler.ConsecutiveHits == oldHitCounts then
									weaponHandler.ConsecutiveHits = 0
									hitCounterRE:FireClient(player, weaponHandler.ConsecutiveHits)
								end
							end)
						end
					end

					if toClients[weaponHandler.WeaponName] then
						local toClient = toClients[weaponHandler.WeaponName]
						toClient.toClients("Hit", {player, victimChar, victimPlayer, true})
					end

					if victimPlayer then
						local victimWeaponSettings = weaponSettingsList[victimWeaponHandler.WeaponName]

						if victimWeaponSettings.Enabled.WeaponStunEnabled then
							if victimWeaponHandler and victimWeaponHandler.CurrentState == combatStateValues.Parry then
								--The victim has been parrybroken

								if player.Team and player.Team == victimPlayer.Team and not wpnSettings.Interaction.FriendlyFire.StunsFriendlies then
									print("cant stun friendlies")
								else
									stunClientRE:FireClient(victimPlayer, wpnSettings.Interaction.Stuns.StunWalkSpeed)

									if toClients[weaponHandler.WeaponName] then
										local toClient = toClients[weaponHandler.WeaponName]
										toClient.toClients("Parried", {victimPlayer, victimPlayer.Character, player})
									end

									changeWeaponHandlerState(victimWeaponHandler, combatStateValues.Stunned)
									victimWeaponHandler.IsParrying = false

									task.delay(wpnSettings.Interaction.Stuns.SpecialBreaksParryDuration, function()
										unstunClientRE:FireClient(victimPlayer)
										changeWeaponHandlerState(victimWeaponHandler, combatStateValues.None)
										print(victimWeaponHandler.CurrentState)
									end)
								end

								victimHum.WalkSpeed = wpnSettings.Interaction.Stuns.StunWalkSpeed
								victimHum.JumpPower = 0
							end
						end
					end
				else
					--print(whatWasHit.Name, " with `
			end
		end
	end)
end

-- All this code inside this block relates to when the player parries (blocks a hit)
local WhenThePlayerParries do
	parryStartsRF.OnServerInvoke = function(player)
		local weaponHandler = weaponHandlers[player]

		-- If they are not dead, they have a weapon, they are not already parrying, attacking, and they are in a neutral state
		if weaponHandler and not weaponHandler.PlayerHasDied and weaponHandler.Weapon and not weaponHandler.IsParrying and not weaponHandler.IsCasting and weaponHandler.CurrentState == combatStateValues.None then
			changeWeaponHandlerState(weaponHandler, combatStateValues.Parry)
			weaponHandler.IsParrying = true

			-- configure parrying to true

			if toClients[weaponHandler.WeaponName] then
				local toClient = toClients[weaponHandler.WeaponName]
				toClient.toClients("Parry", {player.Character})
				-- Loads fx on client and reps to all clients
			end

			return true
		end
	end

	-- When their parry ends
	parryFinishesRF.OnServerInvoke = function(player)
		local weaponHandler = weaponHandlers[player]

		if weaponHandler and not weaponHandler.PlayerHasDied and weaponHandler.Weapon and weaponHandler.IsParrying and not weaponHandler.IsCasting and weaponHandler.CurrentState == combatStateValues.Parry then
			changeWeaponHandlerState(weaponHandler, combatStateValues.None)
			weaponHandler.IsParrying = false
			-- configure parrying to false
		end
	end
end


-- happy, readers?