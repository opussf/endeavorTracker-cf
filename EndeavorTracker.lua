ET_SLUG, ET = ...

-- Saved Variables
Endeavor_data = {}

ET.myTasks = {}
ET.displayData = {}

function ET.OnLoad()
	SLASH_ET1 = "/ET"
	SlashCmdList["ET"] = function(msg) ET.Command(msg) end
	EndeavorFrame:RegisterEvent("HOUSE_LEVEL_FAVOR_UPDATED")
	-- EndeavorFrame:RegisterEvent("INITIATIVE_ACTIVITY_LOG_UPDATED")
	-- EndeavorFrame:RegisterEvent("INITIATIVE_COMPLETED")
	EndeavorFrame:RegisterEvent("INITIATIVE_TASK_COMPLETED")
	EndeavorFrame:RegisterEvent("INITIATIVE_TASKS_TRACKED_LIST_CHANGED")
	EndeavorFrame:RegisterEvent("INITIATIVE_TASKS_TRACKED_UPDATED")
	EndeavorFrame:RegisterEvent("NEIGHBORHOOD_INITIATIVE_UPDATED")
	EndeavorFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
end
function ET.UpdateBars()
	-- print("UpdateBars")
	ET.displayData = {}
	if not ET.myTasks then
		return -- I HATE early returns.
	end
	for ID, task in pairs(ET.myTasks) do
		local newIndex = #ET.displayData + 1
		ET.displayData[newIndex] = task
		ET.displayData[newIndex].ID = ID
	end

	table.sort( ET.displayData, function(l, r)
		if l.progressContributionAmount > r.progressContributionAmount then
			return true
		elseif l.progressContributionAmount == r.progressContributionAmount then
			return l.ID < r.ID
		end
		return false
	end)

	for idx, barLine in pairs(ET.bars) do
		if ET.displayData[idx] then
			barLine.bar:SetMinMaxValues(0,150)
			barLine.bar:SetValue(ET.displayData[idx].progressContributionAmount)
			barLine.bar.text:SetText(
					string.format("%2i %s %s",
							ET.displayData[idx].progressContributionAmount,
							ET.displayData[idx].taskName,
							ET.displayData[idx].requirementText
					)
			)
			barLine.bar:Show()
		else
			barLine.bar:Hide()
		end
	end
end
function ET.PLAYER_ENTERING_WORLD()
	-- make sure Initiative Info is loaded.
	C_NeighborhoodInitiative.RequestNeighborhoodInitiativeInfo()
end
function ET.INITIATIVE_ACTIVITY_LOG_UPDATED()
	-- not sure what to do this.
	-- print("INITIATIVE_ACTIVITY_LOG_UPDATED")
end
function ET.INITIATIVE_COMPLETED( payload )  -- initiative title
	-- this probably fires when you get the final reward.
	-- print("INITIATIVE_COMPLETED: "..payload)
end
function ET.INITIATIVE_TASK_COMPLETED( payload ) -- task name
	-- print("INITIATIVE_TASK_COMPLETED: "..payload)
	for ID, task in pairs( ET.myTasks ) do
		if task.taskName == payload then
			if Endeavor_data.printChat then
				print(task.taskName.." ("..ID..") was completed.") --" Setting completed to: "..(task.tracked and "True" or "False"))
			end
			task.completed = task.tracked
		end
	end
	ET.UpdateBars()
end
function ET.INITIATIVE_TASKS_TRACKED_LIST_CHANGED( initiativeTaskID, added )  -- { Name = "initiativeTaskID", Type = "number", Name = "added", Type = "bool" },
	-- print("INITIATIVE_TASKS_TRACKED_LIST_CHANGED: "..initiativeTaskID.." added: "..(added and "True" or "False") )
	if added then
		local taskInfo = C_NeighborhoodInitiative.GetInitiativeTaskInfo(initiativeTaskID)
		local newTask = {}
		newTask.taskName = taskInfo.taskName
		newTask.requirementText = taskInfo.requirementsList[1].requirementText
		newTask.progressContributionAmount = taskInfo.progressContributionAmount
		newTask.tracked = true
		newTask.rewardQuestID = taskInfo.rewardQuestID
		ET.myTasks[initiativeTaskID] = newTask
	end

	if not added and ET.myTasks[initiativeTaskID] then
		C_Timer.After(0.25, function()
			if ET.myTasks[initiativeTaskID].completed then
				C_NeighborhoodInitiative.AddTrackedInitiativeTask(initiativeTaskID)
				ET.myTasks[initiativeTaskID].completed = nil
				-- Refresh here
			else
				ET.myTasks[initiativeTaskID] = nil
				-- remove from displayData
				for idx, displayData in pairs(ET.displayData) do
					if displayData.ID == initiativeTaskID then
						ET.displayData[idx] = nil
					end
				end
			end

		end)
	end
	ET.BuildBars()
	ET.UpdateBars()
end
function ET.INITIATIVE_TASKS_TRACKED_UPDATED()
	-- made progress fires this event.
	-- print("INITIATIVE_TASKS_TRACKED_UPDATED")
	for ID, task in pairs(ET.myTasks) do
		local taskInfo = C_NeighborhoodInitiative.GetInitiativeTaskInfo(ID)
		if task.requirementText ~= taskInfo.requirementsList[1].requirementText then
			-- ID matches, requirementText does not.  Progress!
			task.requirementText = taskInfo.requirementsList[1].requirementText
			if Endeavor_data.printChat then
				print("Progress on ("..ID..") "..task.taskName.." "..task.requirementText)
			end
		end
	end
	ET.UpdateBars()
end
function ET.NEIGHBORHOOD_INITIATIVE_UPDATED()
	-- this fires a lot, but this might be the work hourse function here.
	-- print("NEIGHBORHOOD_INITIATIVE_UPDATED")
	EndeavorFrameBar0:SetMinMaxValues(0, 1000)
	ET.NeighborhoodInitiativeInfo = C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo()
	ET.currentProgress = ET.NeighborhoodInitiativeInfo.currentProgress
	ET.progressRequired = ET.NeighborhoodInitiativeInfo.progressRequired
	EndeavorFrameBar0:SetValue(ET.currentProgress)
	EndeavorFrameBar0.text:SetText(
			string.format("Endeavor Progress: %i / %i", ET.currentProgress, ET.progressRequired))
	EndeavorFrame:Show()

	-- store some general info
	ET.neighborhoodGUID = ET.NeighborhoodInitiativeInfo.neighborhoodGUID
	ET.playerTotalContribution = ET.NeighborhoodInitiativeInfo.playerTotalContribution

	ET.initiativeID = ET.NeighborhoodInitiativeInfo.playerTotalContribution
	ET.initiativeTitle = ET.NeighborhoodInitiativeInfo.title

	ET.myTasks = ET.myTasks or {}  -- [id] = {}
	-- scan for tracked tasks
	for _, task in pairs( ET.NeighborhoodInitiativeInfo.tasks ) do
		if not ET.myTasks[task.ID] and task.tracked then  -- I'm not tracking this task, and I should.
			local newTask = {}
			newTask.taskName = task.taskName
			newTask.requirementText = task.requirementsList[1].requirementText
			newTask.progressContributionAmount = task.progressContributionAmount
			newTask.tracked = true
			newTask.rewardQuestID = task.rewardQuestID
			ET.myTasks[task.ID] = newTask
		end
		-- if ET.myTasks[task.ID] and not task.tracked then
		-- 	ET.myTasks[task.ID] = nil
		-- end
	end
	-- ET.dump = ET.NeighborhoodInitiativeInfo
	ET.BuildBars()
end
function ET.BuildBars()
	-- print("BuildBars()")
	if not ET.bars then
		ET.bars = {}
	end

	local taskCount = 0
	for _,_ in pairs(ET.myTasks) do
		taskCount = taskCount + 1
	end
	local barCount = #ET.bars
	-- print("I'm tracking "..taskCount.." tasks, and have "..barCount.." bars.")

	if taskCount > barCount then
		-- print("Need to make bars.")
		for idx = barCount+1, taskCount do
			-- print("Make bar #"..idx)
			ET.bars[idx] = {}
			local newBar = CreateFrame("StatusBar", "EndeavorFrameBar"..idx, EndeavorFrame, "EndeavorBarTemplate")
			newBar:SetPoint("TOPLEFT", "EndeavorFrameBar"..idx-1, "BOTTOMLEFT", 0, 0)
			newBar:SetMinMaxValues(0,150)
			newBar:SetValue(0)
			--newBar:SetScript("OnClick", func)
			local text = newBar:CreateFontString("EndeavorFrameBarText"..idx, "OVERLAY", "EndeavorBarTextTemplate")
			text:SetPoint("LEFT", newBar, "LEFT", 5, 0)
			newBar.text = text
			ET.bars[idx].bar = newBar
		end
	elseif taskCount < barCount then
		-- print("Need to hide bars.")
		for idx = taskCount+1, barCount do
			-- print("Hide bar #"..idx)
		end
	end

	-- resize window here
	local barHeight = EndeavorFrameBar0:GetHeight()  -- ~ 12
	local EPBottom = EndeavorFrameBar0:GetBottom()   -- ~ 717
	local taskSizeNeeded = taskCount * barHeight     -- for 10, 120
	local parentTop = EndeavorFrame:GetTop()
	local parentBottom = EndeavorFrame:GetBottom()
	-- print("I have "..EPBottom-parentBottom.." to fit "..taskCount.." bars.")
	-- print("I need "..taskCount*barHeight)

	local newHeight = (parentTop - EPBottom) + (taskCount * barHeight) + (barHeight/2)
	if taskCount*barHeight > EPBottom - parentBottom then
		-- print("Set new height to: "..newHeight)
		EndeavorFrame:SetHeight(newHeight)
	end

	-- set resize
	local minWidth = EndeavorFrame:GetResizeBounds()  -- minW, minH, maxW, maxH
	-- print("minWidth: "..minWidth)
	-- print("Set("..minWidth..", "..newHeight..", "..minWidth..", "..newHeight+(3*barHeight)..")")
	EndeavorFrame:SetResizeBounds(minWidth, newHeight, minWidth, newHeight+(3*barHeight))
end
function ET.HOUSE_LEVEL_FAVOR_UPDATED( payload )
	-- print("HOUSE_LEVEL_FAVOR_UPDATED( payload )")
	ET.houseInfo = payload   -- houseLevel, houseFavor, houseGUID

	ET.houseInfo.levelMaxFavor = C_Housing.GetHouseLevelFavorForLevel(ET.houseInfo.houseLevel + 1)
	EndeavorFrame_TitleText:SetText(string.format("Endeavors (House lvl:%i %i/%i)",
			ET.houseInfo.houseLevel, ET.houseInfo.houseFavor, ET.houseInfo.levelMaxFavor ))
end
function ET.OnDragStart()
	EndeavorFrame:StartMoving()
end
function ET.OnDragStop()
	EndeavorFrame:StopMovingOrSizing()
end
function ET.Print(msg)
	-- print to the chat frame
	DEFAULT_CHAT_FRAME:AddMessage( msg )
end
function ET.ParseCmd(msg)
	if msg then
		local i,c = strmatch(msg, "^(|c.*|r)%s*(%d*)$")
		if i then  -- i is an item, c is a count or nil
			return i, c
		else  -- Not a valid item link
			msg = string.lower(msg)
			local a,b,c = strfind(msg, "(%S+)")  --contiguous string of non-space characters
			if a then
				-- c is the matched string, strsub is everything after that, skipping the space
				return c, strsub(msg, b+2)
			else
				return ""
			end
		end
	end
end
function ET.Command(msg)
	local cmd, param = ET.ParseCmd(msg);
	local cmdFunc = ET.CommandList[cmd];
	if cmdFunc then
		cmdFunc.func(param);
	elseif ( cmd and cmd ~= "") then  -- exists and not empty
		ET.PrintHelp()
	end
end
function ET.PrintHelp()
	-- ET.Print(INEED_MSG_ADDONNAME.." ("..INEED_MSG_VERSION..") by "..INEED_MSG_AUTHOR);
	for cmd, info in pairs(ET.CommandList) do
		if info.help then
			ET.Print(string.format("%s %s %s -> %s",
				SLASH_ET1, cmd, info.help[1], info.help[2]));
		end
	end
end

ET.CommandList = {
	["help"] = {
		["func"] = ET.PrintHelp,
		["help"] = {"", "Print this help."},
	},
	["chat"] = {
		["func"] = function() Endeavor_data.printChat = not Endeavor_data.printChat end,
		["help"] = {"", "Toggle chat progress"},
	},
	[""] = {
		["func"] = function() EndeavorFrame:Show() end,
		["help"] = {"", "Show Endeavor Tracker window."},
	},
	["debug"] = {
		["func"] = function() Endeavor_data.debug = not Endeavor_data.debug end,
	},
}