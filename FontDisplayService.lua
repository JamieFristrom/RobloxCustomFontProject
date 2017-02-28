-- FontDisplayService

local fds = {}
local out = {}

local FontCreator = require(script.Parent.FontCreator)

--
--

local wordCharactersString = 'abcdefghijklmnopqrstuvwxyz.?!1234567890/-\'";:,[]{}()<>'
local wordCharacters = {}; for i=1, #wordCharactersString do local char=wordCharactersString:sub(i,i) wordCharacters[char:lower()]=true end

--
--

setmetatable(out, {
	__index = function(out, index)
		if fds[index] then
			return fds[index]
		else
			error(tostring(index)..' is not a valid member of fontDisplayService')
		end
	end,

	__newindex = function(out, index, value)
		error('fontDisplayService.'..tostring(index)..' cannot be set')
	end
})

--
--

function findInString(str, text)
	local startingIndex = 0
	local checkingIndex = 1

	for i=1, #str do
		if str:sub(i,i) == text:sub(checkingIndex, checkingIndex) then
			if checkingIndex == 2 then
				startingIndex = i-1
			end

			if checkingIndex == #text then
				--print('found "' .. text .. '" in "' .. str .. '" at ' .. startingIndex .. 'x' .. i) wait()
				return startingIndex, i
			end

			checkingIndex = checkingIndex + 1
		end
	end

	return nil
end

--
--
local ContentProvider = game:GetService 'ContentProvider'

function fds:Preload(name)
	local source = FontCreator.load(name).source

	ContentProvider:Preload(source)
end

--
--

function fds:WriteToFrame(fontname, size, text, wraps, frame, wordDetectionEnabled)
	local font = FontCreator.load(fontname)

	local maxBounds = Vector2.new()
	local currentPosition = Vector2.new(0, 0)
	local wrappingBounds = frame.AbsoluteSize
	local sizeMultiplierX = size/font.baseHeight

	local wraps = wraps and true or false
	local wordDetectionEnabled = wordDetectionEnabled and true or false

	local currentWord = ''
	local currentWordPosition = Vector2.new(0, 0)
	local currentWordSpecialLocations = {}

	local specialCases = {} -- int index = string charname

	local visualCharacters = {}

	--
	-- load special cases

	for charname, bounds in pairs( font.chars ) do
		if #charname > 1 then
			local s='bbccabcc' 
			local case='cc' 
			local start, fin = s:find(case) s=s:gsub(s:sub(1, fin), s:sub(1, start-1)..'t')
			local start, fin = findInString(text, charname)

			while start ~= nil do
				-- text = text:gsub(
				-- 	text:sub(1, fin),
				-- 	text:sub(1, start-1)..'_'
				-- )
				-- If you don't understand it, just write it yourself
				text = text:sub(1, start-1) .. '_' .. text:sub(fin+1)
--				print(text)

				specialCases[start] = charname

				start, fin = findInString(text, charname)
			end
		end
	end

	--
	--

	local tryAddCharacter = function(charSize)
		if wraps == true and (currentPosition + charSize).x > wrappingBounds.x then
			currentPosition = Vector2.new(0, currentPosition.y + font.letterSpacing*sizeMultiplierX + size + font.lineSpacing*sizeMultiplierX)
		else
			currentPosition = currentPosition + charSize
		end

		-- maxBounds = Vector2.new( -- doing this in post
		-- 	math.max((currentPosition + charSize).x, maxBounds.x),
		-- 	currentPosition.y + size
		-- )
	end

	local addCharacter = function(char)
		--[[if char == ' ' or char == '\t' then
			local unitLength = (char == ' ' and 1) or (char == '\t' and 3)
			local realSize = (font.spaceWidth+font.letterSpacing)*unitLength*sizeMultiplierX

			tryAddCharacter(Vector2.new(realSize, 0))
		else --]]
		if char == '\n' then
			-- don't get why we're adding letterspacing in there
			currentPosition = Vector2.new(0, currentPosition.y + font.info.spacing[1]*sizeMultiplierX + size + font.common.lineHeight*sizeMultiplierX)
--			currentPosition = Vector2.new(0, currentPosition.y + font.letterSpacing*sizeMultiplierX + size + font.lineSpacing*sizeMultiplierX)
		else
			local bounds = font.getCharBounds(char)
			--print(char, #char, char:byte())

			local sizeMultiplierY = sizeMultiplierX*(1/(bounds.height/font.baseHeight))

			local relativeSize = Vector2.new(bounds.width*sizeMultiplierX, bounds.height*sizeMultiplierX)--sizeMultiplierY)

			-- now that I know how this works, it occurs to me an alternative would be to build imagelabels
			-- for each character and simply clone them here
			local visual = Instance.new 'ImageLabel'
			visual.Name = tostring(#visualCharacters+1)
			visual.BackgroundTransparency = 1
			visual.Image = "rbxgameasset://Images/"..font.info.font  
			visual.ImageRectOffset = Vector2.new(bounds.x, bounds.y)
			visual.ImageRectSize = Vector2.new(bounds.width, bounds.height)
			visual.Position = UDim2.new(0, currentPosition.x, 0, currentPosition.y)
			visual.Size = UDim2.new(0, relativeSize.x, 0, relativeSize.y)
			-- visual.Parent = frame
			visual.ZIndex = frame.ZIndex
			table.insert(visualCharacters, visual)

			tryAddCharacter(Vector2.new(relativeSize.x + (font.info.spacing[1]*sizeMultiplierX), 0))

			--
			-- do extension

--			local ext = font.extensions[char]

			if true then --ext ~= nil then
				--local top, bottom = unpack(ext)
				--local top, bottom = top or 0, bottom or 0

				--visual.ImageRectOffset = visual.ImageRectOffset + Vector2.new(0, -top)
				--visual.ImageRectSize = visual.ImageRectSize + Vector2.new(0, top+bottom)

				visual.Position = visual.Position + UDim2.new(0, 0, 0, sizeMultiplierX*bounds.yoffset )---top)
				--visual.Size = visual.Size + UDim2.new(0, 0, 0, sizeMultiplierY*(bounds.height+bounds.yoffset))--top+bottom))
			end
		end
	end

	local addWord = function()
		-- print('adding word "' .. currentWord .. '"')
		local wordSize = font.getStringSize(currentWord, size)

		if wraps == true and wordDetectionEnabled == true and (currentWordPosition + wordSize).x > wrappingBounds.x then
			if currentWordPosition.x > 0 then
				currentPosition = Vector2.new(0, currentWordPosition.y + font.info.spacing[1]*sizeMultiplierX + size + font.common.lineHeight*sizeMultiplierX)
			else
				currentPosition = currentWordPosition
			end
		else
			currentPosition = currentWordPosition
		end

		--
		-- setup special info

		local specialStartingLocations = {} -- int start = vector2 size

		for specialSize, char in next, currentWordSpecialLocations do
			specialStartingLocations[specialSize.x] = specialSize
		end

		--
		--

		for index=1, #currentWord do
			local specialSize = specialStartingLocations[index]

			if specialSize then
				local diff = specialSize.y - specialSize.x
				currentWord = currentWord:sub(1, specialSize.x-1) .. '_' .. currentWord:sub(specialSize.y)

				local specialChar = currentWordSpecialLocations[specialSize]

				addCharacter(specialChar)

				--
				-- fix up the specialStartingLocations

				local diffv2 = Vector2.new(diff, 0)

				for specialSize, char in next, currentWordSpecialLocations do
					local v2 = specialSize - diffv2

					currentWordSpecialLocations[v2] = char
					specialStartingLocations[specialSize.x - diff] = v2
				end
			else
				if index <= #currentWord then
					addCharacter(currentWord:sub(index,index))
				end
			end
		end

		--
		--

		currentWord = ''
		currentWordPosition = currentPosition
		currentWordSpecialLocations = {}
	end

	for index=1, #text do
		local char = text:sub(index, index)
		local isSpecial = false

		if specialCases[index] ~= nil then
			char = specialCases[index]
			isSpecial = true
		end

		if wordCharacters[char:lower()] == true or font.specialWordCharacters[char] == true then
			currentWord = currentWord .. char

			if isSpecial then
				currentWordSpecialLocations[Vector2.new(#currentWord-#char+1, #currentWord+1)] = char
			end

			if currentWord == char then -- char is the first letter, set a new currentWordPosition
				currentWordPosition = currentPosition
			end

			currentPosition = currentPosition + Vector2.new(font.getStringSize(char, size), 0)
		else
			if currentWord ~= '' then -- need to write the current word
				addWord()
			end

			addCharacter(char)
		end
	end

	if currrentWord ~= '' then -- there's still a word waiting to be written
		addWord()
	end

	--
	-- ugly hack ahead since I can't figure out what's up with word detection not being accounted for when calculating max bounds

	if true then
		maxBounds = Vector2.new()

		for index, visual in next, visualCharacters do
			maxBounds = Vector2.new(
				math.max(maxBounds.x, visual.Position.X.Offset+visual.Size.X.Offset),
				math.max(maxBounds.y, visual.Position.Y.Offset+visual.Size.Y.Offset)
			)
		end
	end

	--
	-- now parent all the frames.

	for index, visual in next, visualCharacters do
		visual.Parent = frame
	end

	--
	--

	return maxBounds
end

--
--

return out