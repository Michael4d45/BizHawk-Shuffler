local gettime = require("socket.core").gettime
gui.clearGraphics()

buffer = 0 -- Sets countdown location. Adding 8 makes it appear correct for the NES.
if emu.getsystemid() == "NES" then
	buffer = 8
end

--- Check if a file or directory exists in this path
function exists(file)
	local ok, err, code = os.rename(file, file)
	if not ok then
	   if code == 13 then
		  -- Permission denied, but it exists
		  return true
	   end
	end
	return ok, err
end

 --- Check if a directory exists in this path
function isdir(path)
	-- "/" works on both Unix and Windows
	return exists(path.."/")
end

function message(message, color)
	gui.drawBox(client.bufferwidth()/2-60,buffer,client.bufferwidth()-(client.bufferwidth()/2+1-60),15+buffer,"white","black")
	gui.drawText(client.bufferwidth()/2,buffer,message,color,null,null,null,"center")
end

function ends_with(str, ending)
   return ending == "" or str:sub(-#ending) == ending
end

function to_time(t)
	if t < 0 then
		return "- " .. to_time(-1 * t)
	end
	local seconds = t % 60
	return (t - seconds) / 60 .. " minutes " .. seconds .. " seconds"
end

function openRom(game) 
	client.openrom(".\\CurrentROMs\\" .. game)
	saveRom(game)
end

function saveRom(game)
	local currentROM = io.open( savesFolder .. "CurrentROM.txt","w")
	currentROM:write(game)
	currentROM:close()
end

function getRom()
	local currentGameReader = io.open( savesFolder .. "CurrentROM.txt","a+")
	local game = currentGameReader:read("*line")
	currentGameReader:close()
	return game
end

function dirLookup() -- Reads all ROM names in the CurrentROMs folder.
	local games = {}
	local i = 0
	for directory in io.popen([[dir ".\\CurrentROMs" /b]]):lines() do
		if ends_with(directory, ".bin") then
			console.log("SKIP: " .. directory)
		else
			i = i + 1
			console.log(i .. " ROM: " .. directory)
			games["rom" .. i] = directory
		end
	end
	return games, i
end

function createSaveDir(s)
	if not isdir(".\\Saves") then
		os.execute( "mkdir Saves" )
	end
	if not isdir(".\\Saves\\" .. s) then
		os.execute( "mkdir Saves\\" .. s )
		os.execute( "mkdir Saves\\" .. s .. "\\States" )
		os.execute( "mkdir Saves\\" .. s .. "\\TimeLogs" )
		os.execute( "mkdir Saves\\" .. s .. "\\PlayCount" )
		return true
	end
	return false
end

function getSettings() -- Gets the settings saved by the RaceShufflerSetup.exe
	local fp = io.open("settings.xml", "r" ) -- Opens settings.xml
	if fp == nil then 
		return nil
	end
	settingsValue = {}
	k = 0
	for line in fp:lines() do -- Gets lines from the settings xml.
		newLine = string.match(line,'%l+%u*%l+')
		newSetting = string.match(line,'%p%a+%p(%w+)')
		if newLine ~= "settings" then
			settingsValue["value" .. k] = newSetting
		end
		k = k + 1
	end
	fp:close() -- Closes settings.xml
	lowTime = settingsValue["value2"]
	highTime = settingsValue["value3"]
	countdown = settingsValue["value5"] == "true"
	initialSeed = settingsValue["value4"]
	newShuffle = createSaveDir(initialSeed)
	savesFolder = ".\\Saves\\" .. initialSeed .. "\\"
	
	currentGame = getRom()
	if currentGame ~= nil then
		stateFile = savesFolder .. "States\\" .. currentGame .. ".State"
	end
end

function readTimes(game)
	if game == nil then return end
	local oldTime = io.open(savesFolder .. "TimeLogs\\" .. game .. ".txt","a+")
	local readOldTimeString = oldTime:read("*line")
	saveOldTime = 0
	if readOldTimeString ~= nil then
		saveOldTime = tonumber(readOldTimeString)
	end
	oldTime:close()

	local oldCount = io.open(savesFolder .. "PlayCount\\" .. game .. ".txt","a+")
	local readOldCountString = oldCount:read("*line")
	savePlayCount = 1
	if readOldCountString ~= nil then
		savePlayCount = tonumber(readOldCountString) + 1
	end
	oldCount:close()

	local currentGameTime = io.open("CurrentGameTime.txt","w")
	currentGameTime:write(game .. "\n" .. to_time(saveOldTime) .. "\ntimes played: " .. savePlayCount)
	currentGameTime:close()
end

function saveTimes(game)
	if game == nil then return end
	local currentGameTime = io.open(savesFolder .. "TimeLogs\\" .. game .. ".txt","w")
	local newTime = timeLimit
	if saveOldTime ~= nil then
		newTime = newTime + saveOldTime
	end
	currentGameTime:write(newTime)
	currentGameTime:close()

	local currentGamePlayCount = io.open(savesFolder .. "PlayCount\\" .. game .. ".txt","w")
	local newPlayCount = 1
	if savePlayCount ~= nil then
		newPlayCount = savePlayCount
	end
	currentGamePlayCount:write(newPlayCount)
	currentGamePlayCount:close()
end

function showCountdown(timeLeft)
	if (timeLeft <= 1) then 
		message("!.!.!.ONE.!.!.!","red")
	elseif (timeLeft <= 2) then 
		message("!.!...TWO...!.!","yellow")
	else
		message("!....THREE....!","lime")
	end
end

function readSeed()
	local seedFile = io.open(savesFolder .. "seed.txt","a+")
	local seedString = seedFile:read("*line")
	seedFile:close()
	if seedString ~= nil then
		seed = tonumber(seedString)
	else
		seed = 0
	end
end

function saveSeed(s)
	local seedFile = io.open(savesFolder .. "seed.txt","w")
	seedFile:write(s)
	seedFile:close()
end

function nextGame() 
	-- Changes to the next game and saves the current settings into userdata
	if gameinfo.getromname() == "Null" and currentGame ~= nil then
		openRom(currentGame)
	else
		local games, databaseSize = dirLookup()
		saveTimes(currentGame)

		local newGame = currentGame
		if databaseSize == 0 then return
		elseif databaseSize == 1 then
			newGame = games["rom" .. 1]
		else
			local ranNumber = 1
			while newGame == currentGame or newGame == nil do
				ranNumber = math.random(1, databaseSize)
				console.log("roll " .. ranNumber)
				newGame = games["rom" .. ranNumber]
			end
		end
		local randIncrease = math.random(1,20)
		saveSeed(seed + randIncrease)
		if currentGame ~= nil then
			savestate.save(stateFile)
		end
		openRom(newGame)
	end	
end

function saveTotalTime(t)
	totalTimeLimit = t
	local currentTotalTime = io.open(".\\totalTime.txt","w")
	currentTotalTime:write(t)
	currentTotalTime:close()
end

function saveInitialTime(t)
	initialTime = t
	local currentInitialTime = io.open(".\\initialTime.txt","w")
	currentInitialTime:write(t)
	currentInitialTime:close()
end

function resetTicker() 
	console.log("getting time")
	saveInitialTime(gettime())
	saveTotalTime(0)
end

function readTicker()
	local currentInitialTime = io.open(".\\initialTime.txt","a+")
	local readcurrentInitialTimeString = currentInitialTime:read("*line")
	currentInitialTime:close()
	if readcurrentInitialTimeString ~= nil then
		initialTime = tonumber(readcurrentInitialTimeString)
		local currentTotalTime = io.open(".\\totalTime.txt","a+")
		local readcurrentTotalTimeString = currentTotalTime:read("*line")
		currentTotalTime:close()
		if readcurrentTotalTimeString ~= nil then
			totalTimeLimit = tonumber(readcurrentTotalTimeString)
		else
			totalTimeLimit = 0
		end
	else
		resetTicker() 
	end
end

adjusting = false
function adjustTime(down, up)
	if (down or up) and adjusting then 
		return
	end
	local step = 0.5
	if up or down then 
		adjusting = true
	end
	if down and up then
		message(0)
	elseif down then
		message("back " .. step .. "s")
		saveInitialTime(initialTime + step)
	elseif up then
		message("forward " .. step .. "s")
		saveInitialTime(initialTime - step)
	elseif adjusting then
		gui.clearGraphics()
		adjusting = false
	end
end

pausing = false
function pause(p)
	if p and not pausing then
		pausing = true
		return true
	elseif pausing and not p then 
		pausing = false
	end
	return false
end

getSettings()

console.log(gameinfo.getromname())

if newShuffle or currentGame == nil or gameinfo.getromname() == "Null" then
	-- starting or resuming a new shuffle run
	seed = initialSeed

	math.randomseed(seed)
	math.random()

	timeLimit = 0
	resetTicker() 
else 
	-- continuing a shuffle run
	savestate.load(stateFile)
	console.log("Current Game: " .. currentGame)
	readTimes(currentGame)

	readSeed()
	math.randomseed(seed)
	math.random()

	readTicker()
	timeLimit = math.random(lowTime * 100, highTime * 100) / 100
	saveTotalTime(totalTimeLimit + timeLimit)
end

console.log("seed " .. seed)
console.log("Time Limit " .. to_time(timeLimit))

lastFrame = -1
t = gettime()

while true do -- The main cycle that causes the emulator to advance and trigger a game switch.
	local inputs = input.get()

	adjustTime(inputs["LeftBracket"], inputs["RightBracket"])
	if pause(inputs["Pause"]) then
		saveInitialTime(initialTime + (gettime() - t))
	end
	t = gettime()

	diff = t - initialTime

	if countdown and (totalTimeLimit - diff <= 3)  then
		showCountdown(totalTimeLimit - diff)
	end
	if diff > totalTimeLimit then
		nextGame()
	end
	
	local diff2 = diff - totalTimeLimit + timeLimit
	local mod = diff2 % 15
	local frame = diff2 - mod
	if (mod < 10 and frame ~= lastFrame) then
		console.log(to_time(frame))
		lastFrame = frame
	end

	emu.frameadvance()
end
