-- FontCreator

local fontCreator = {}
local out = {}
local loaderBin = game.ReplicatedStorage.FontBin

--
--

setmetatable(out, {
	__index = function(out, index)
		if fontCreator[index] then
			return fontCreator[index]
		else
			error(tostring(index)..' is not a valid member of fontCreator')
		end
	end,

	__newindex = function(out, index, value)
		error('fontCreator.'..tostring(index)..' cannot be set')
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
				-- print('found "' .. text .. '" in "' .. str .. '" at ' .. startingIndex .. 'x' .. i) wait()
				return startingIndex, i
			end

			checkingIndex = checkingIndex + 1
		end
	end

	return nil
end

--
--

local loadedFonts = {}
local fontObjs = {} -- out=font

local fontMeta = {
	__index = function(fout, index)
		if fontObjs[fout][index] then
			return fontObjs[fout][index]
		else
			error(tostring(index)..' is not a valid member of font')
		end
	end,

	__newindex = function(fout, index, value)
		error('font.'..tostring(index)..' cannot be set')
	end
}

fontCreator.load = function(name)
	if loadedFonts[name] then
		return loadedFonts[name]
	else
		local f = {}
		local fout = {}

		-- gives us some error catching ability. 
		-- the fontObjs class. But fuck it in the nose because we can't step through it  
		-- setmetatable(fout, fontMeta)  
		
		-- OLD WAY:
		-- fout was a key that had fontMeta as its metatable which then indexed into the fontObjs
		-- here when we modify f we are, in effect, modifying fontObjs[fout], so later when we pass fouts around 
		-- the fout metatable indexes into the fontObjs and provides us with some error protection
		-- yes, it gives me a nosebleed
		
		-- NEW WAY
		-- loadedFonts[name] contains the font  
		
		fontObjs[fout] = f  -- this is obsolete

		local loaderObj = loaderBin:FindFirstChild(name)

		if loaderObj == nil then
			error(tostring(name)..' is not a valid font name')
		end

		local fontTable = require(loaderObj)
		for i,v in pairs( fontTable ) do
			f[i] = v 
		end  -- copy font table. because why - why not just say f = fontTable? Lets us customize size, but we don't seem
		-- to have the ability to have multiple fonts of different sizes anyway

		--
		-- find what size to scale the characters to

		local maxCharHeight = 0

		for char, bounds in pairs( f.chars ) do
			maxCharHeight = math.max(maxCharHeight, bounds.height)
		end

		f.baseHeight = maxCharHeight

		--
		-- create a list of special word characters

		f.specialWordCharacters = {}

		for index, char in pairs( f.specialWordCharactersList or {} ) do
			f.specialWordCharacters[char] = true
		end

		--
		-- create utility functions

		function f.transformCharacter(char)
			return char
			--[[
			if f.lowercase == 'none' then
				return char
			elseif f.lowercase == 'determinate' then
				if f.chars[char] ~= nil then
					return char
				elseif f.chars[char:upper()] ~= nil then
					return char:upper()
				elseif f.chars[char:lower()] ~= nil then
					return char:lower()
				end

				return char
			elseif f.lowercase == 'all' then
				return char:lower()
			end--]]
		end

		function f.getCharBounds(char)  -- actually returns a reference to the whole character because why not
			return f.chars[f.transformCharacter(char)]
		end

		function f.getStringSize(str, fontSize)
			-- fontSize is in pixels
			-- 
			local sizemx = fontSize/f.baseHeight
			local totalSize = Vector2.new(0, 0)

			local specials = {} -- index = bounds  -- I don't think this is currently used

			for char, bounds in pairs( f.chars ) do
				if #char > 1 then
					local start, fin = findInString(str, char)

					while start ~= nil do
						-- print(str, char, start, fin)
						str = str:sub(1, start-1) .. '_' .. str:sub(fin+1)
						specials[start] = {bounds, f.extensions[char]}
						start, fin = findInString(str, char)
						-- print(str, char, start, fin)
						-- return
					end
				end
			end

			for index=1, #str do
				-- don't believe this is used 
				local specialBounds, specialExt = unpack(specials[index] or {})
				
				-- get the indexth character
				local char = str:sub(index, index)
				
				-- transform bounds so it uses special bounds if necessary and is 0,0				
				local bounds = specialBounds or f.getCharBounds(char) or f.chars[char]

				-- get size multiplier y. It's the height of the character relative to the font height * the relative font size
				local sizemy = sizemx/(1/(bounds.height/f.baseHeight))
				local relativeSize = Vector2.new(bounds.width*sizemx + f.info.spacing[1], bounds.height*sizemy)
				
--[[				local ext = (specialBounds and specialExt) or (not specialBounds and f.extensions[char])
				
				if ext then
					local relativeExtension = Vector2.new(0, (ext[1]+ext[2])*sizemy)
					relativeSize = relativeSize + relativeExtension
end--]]
				-- add in the yoffset		
				relativeSize = relativeSize + Vector2.new( 0, bounds.yoffset * sizemy ) 

				-- totalSize = totalSize+relativeSize
				
				totalSize = Vector2.new(
					(totalSize + relativeSize).x,
					math.max(totalSize.y, relativeSize.y)
				)
			end

			return totalSize
		end

		--
		--

		loadedFonts[name] = f

		return f
	end
end

--
--

return out