#!/usr/bin/env lua
--[[
    units2json.lua
    
    Reads all unit definition files, filters to only player-buildable units
    (discovered by starting from starting units defined in sidedata.lua and 
    recursively following buildoptions), and outputs a flat units.json file.
    
    Usage: lua units2json.lua [output_file]
    Default output: units.json
]]

-- Add local lua_modules to package path (for luarocks --tree=./lua_modules installs)
local script_dir = arg[0]:match("(.*/)" ) or "./"
package.path = script_dir .. "lua_modules/share/lua/5.5/?.lua;" .. package.path

local lfs = require("lfs")
local json = require("dkjson")

-- Configuration
local GAME_DIR = "Beyond-All-Reason"
local UNITS_DIR = GAME_DIR .. "/units"
local GAMEDATA_DIR = GAME_DIR .. "/gamedata"
local SIDES_ENUM_FILE = GAMEDATA_DIR .. "/sides_enum.lua"
local SIDEDATA_FILE = GAMEDATA_DIR .. "/sidedata.lua"
local ICONTYPES_FILE = GAMEDATA_DIR .. "/icontypes.lua"
local OUTPUT_FILE = arg[1] or "units.json"

-- Storage for all unit definitions
local allUnits = {}
-- Storage for icon types
local iconTypes = {}
-- Set of buildable unit names
local buildableUnits = {}
-- Queue for BFS traversal
local queue = {}

--------------------------------------------------------------------------------
-- File System Utilities
--------------------------------------------------------------------------------

local function scanDirectory(path, fileList)
	fileList = fileList or {}
	for entry in lfs.dir(path) do
		if entry ~= "." and entry ~= ".." then
			local fullPath = path .. "/" .. entry
			local attr = lfs.attributes(fullPath)
			if attr then
				if attr.mode == "directory" then
					scanDirectory(fullPath, fileList)
				elseif attr.mode == "file" and entry:match("%.lua$") then
					fileList[#fileList + 1] = fullPath
				end
			end
		end
	end
	return fileList
end

--------------------------------------------------------------------------------
-- Unit Loading
--------------------------------------------------------------------------------

local function loadUnitFile(filepath)
	-- Create a sandboxed environment for loading unit defs.
	-- Some unit files use Spring engine globals (Spring, VFS, etc.) that aren't
	-- available in standalone Lua. Those files will fail to load, but they
	-- contain non-buildable units (raptors, scavengers, evocom, etc.) that get
	-- filtered out anyway, so we silently skip them.
	local env = {
		pairs = pairs,
		ipairs = ipairs,
		type = type,
		tostring = tostring,
		tonumber = tonumber,
		string = string,
		table = table,
		math = math,
	}

	local chunk, err = loadfile(filepath, "t", env)
	if not chunk then
		-- Silently skip files that fail to load - they typically use Spring
		-- engine features not available in standalone Lua, and are usually
		-- not player-buildable units anyway.
		return nil
	end

	local success, result = pcall(chunk)
	if not success then
		-- Silently skip files that fail to execute
		return nil
	end

	return result
end

local function loadAllUnits()
	local files = scanDirectory(UNITS_DIR)
	local count = 0

	for _, filepath in ipairs(files) do
		local units = loadUnitFile(filepath)
		if units and type(units) == "table" then
			for unitName, unitDef in pairs(units) do
				if type(unitName) == "string" and type(unitDef) == "table" then
					-- Store the unit with its source file for reference
					unitDef._sourceFile = filepath
					allUnits[unitName] = unitDef
					count = count + 1
				end
			end
		end
	end

	io.stderr:write("Loaded " .. count .. " unit definitions from " .. #files .. " files\n")
end

--------------------------------------------------------------------------------
-- Icon Types Loading
--------------------------------------------------------------------------------

local function loadIconTypes()
	local attr = lfs.attributes(ICONTYPES_FILE)
	if not attr or attr.mode ~= "file" then
		io.stderr:write("Warning: " .. ICONTYPES_FILE .. " not found, icons will not be included\n")
		return
	end

	local env = {
		pairs = pairs,
		ipairs = ipairs,
		type = type,
		tostring = tostring,
		tonumber = tonumber,
		string = string,
		table = table,
		math = math,
	}

	local chunk, err = loadfile(ICONTYPES_FILE, "t", env)
	if not chunk then
		io.stderr:write("Warning: Failed to load " .. ICONTYPES_FILE .. ": " .. tostring(err) .. "\n")
		return
	end

	local success, result = pcall(chunk)
	if not success then
		io.stderr:write("Warning: Failed to execute " .. ICONTYPES_FILE .. ": " .. tostring(result) .. "\n")
		return
	end

	if type(result) ~= "table" then
		io.stderr:write("Warning: " .. ICONTYPES_FILE .. " did not return a table\n")
		return
	end

	iconTypes = result

	-- Count loaded icons
	local count = 0
	for _ in pairs(iconTypes) do
		count = count + 1
	end
	io.stderr:write("Loaded " .. count .. " icon type definitions\n")
end

--------------------------------------------------------------------------------
-- Starting Unit Discovery (from sidedata.lua)
--------------------------------------------------------------------------------

local function loadSidesEnum()
	-- Load sides_enum.lua which defines faction prefixes (arm, cor, leg)
	local attr = lfs.attributes(SIDES_ENUM_FILE)
	if not attr or attr.mode ~= "file" then
		return nil, "File not found: " .. SIDES_ENUM_FILE
	end

	local env = {
		-- Minimal safe environment
		pairs = pairs,
		ipairs = ipairs,
		type = type,
		tostring = tostring,
		tonumber = tonumber,
		string = string,
		table = table,
		math = math,
	}

	local chunk, err = loadfile(SIDES_ENUM_FILE, "t", env)
	if not chunk then
		return nil, "Failed to load " .. SIDES_ENUM_FILE .. ": " .. tostring(err)
	end

	local success, result = pcall(chunk)
	if not success then
		return nil, "Failed to execute " .. SIDES_ENUM_FILE .. ": " .. tostring(result)
	end

	if type(result) ~= "table" then
		return nil, SIDES_ENUM_FILE .. " did not return a table (got " .. type(result) .. ")"
	end

	return result
end

local function loadSideData(sidesEnum)
	-- Load sidedata.lua which defines starting units for each faction
	local attr = lfs.attributes(SIDEDATA_FILE)
	if not attr or attr.mode ~= "file" then
		return nil, "File not found: " .. SIDEDATA_FILE
	end

	-- Create environment with mock VFS.Include that returns the pre-loaded sides enum
	local vfsIncludeCalled = false
	local env = {
		-- Minimal safe environment
		pairs = pairs,
		ipairs = ipairs,
		type = type,
		tostring = tostring,
		tonumber = tonumber,
		string = string,
		table = table,
		math = math,
		error = error,
		-- Mock VFS object
		VFS = {
			Include = function(path)
				-- sidedata.lua calls VFS.Include("gamedata/sides_enum.lua")
				if path == "gamedata/sides_enum.lua" then
					vfsIncludeCalled = true
					return sidesEnum
				end
				error("Unexpected VFS.Include path: " .. tostring(path))
			end,
		},
	}

	local chunk, err = loadfile(SIDEDATA_FILE, "t", env)
	if not chunk then
		return nil, "Failed to load " .. SIDEDATA_FILE .. ": " .. tostring(err)
	end

	local success, result = pcall(chunk)
	if not success then
		return nil, "Failed to execute " .. SIDEDATA_FILE .. ": " .. tostring(result)
	end

	if type(result) ~= "table" then
		return nil, SIDEDATA_FILE .. " did not return a table (got " .. type(result) .. ")"
	end

	if not vfsIncludeCalled then
		io.stderr:write("Warning: " .. SIDEDATA_FILE .. " did not call VFS.Include for sides_enum.lua\n")
		io.stderr:write("         The file structure may have changed.\n")
	end

	return result
end

local function findStartingUnits()
	-- Load sides enum first
	local sidesEnum, err = loadSidesEnum()
	if not sidesEnum then
		io.stderr:write("Error: " .. err .. "\n")
		io.stderr:write("Cannot determine starting units. The gamedata file structure may have changed.\n")
		os.exit(1)
	end

	-- Load side data
	local sideData, err = loadSideData(sidesEnum)
	if not sideData then
		io.stderr:write("Error: " .. err .. "\n")
		io.stderr:write("Cannot determine starting units. The gamedata file structure may have changed.\n")
		os.exit(1)
	end

	-- Extract starting units from side data
	local startingUnits = {}
	local skipped = {}

	for i, side in ipairs(sideData) do
		if type(side) ~= "table" then
			io.stderr:write(
				"Warning: Entry " .. i .. " in sidedata is not a table (got " .. type(side) .. "), skipping.\n"
			)
		elseif side.startunit then
			local unitName = side.startunit
			local sideName = side.name or ("entry " .. i)

			-- Skip placeholder units like 'dummycom' for Random faction
			if unitName == "dummycom" then
				skipped[#skipped + 1] = sideName .. " (" .. unitName .. ")"
			elseif type(unitName) == "string" and unitName ~= "" then
				startingUnits[#startingUnits + 1] = unitName
			else
				io.stderr:write("Warning: Invalid startunit for " .. sideName .. ": " .. tostring(unitName) .. "\n")
			end
		else
			local sideName = side.name or ("entry " .. i)
			io.stderr:write("Warning: No startunit defined for " .. sideName .. ", skipping.\n")
		end
	end

	if #startingUnits == 0 then
		io.stderr:write("Error: No valid starting units found in " .. SIDEDATA_FILE .. "\n")
		io.stderr:write("The sidedata.lua file structure may have changed.\n")
		io.stderr:write("Expected format: array of tables with 'startunit' field.\n")
		os.exit(1)
	end

	if #skipped > 0 then
		io.stderr:write("Skipped placeholder factions: " .. table.concat(skipped, ", ") .. "\n")
	end

	return startingUnits
end

--------------------------------------------------------------------------------
-- Buildable Unit Discovery
--------------------------------------------------------------------------------

local function discoverBuildableUnits()
	-- Start with starting units from sidedata.lua
	local startingUnits = findStartingUnits()
	io.stderr:write("Found " .. #startingUnits .. " starting units: " .. table.concat(startingUnits, ", ") .. "\n")

	-- Initialize queue with starting units
	for _, unitName in ipairs(startingUnits) do
		if not buildableUnits[unitName] then
			buildableUnits[unitName] = true
			queue[#queue + 1] = unitName
		end
	end

	-- BFS through buildoptions
	local processed = 0
	while #queue > 0 do
		local unitName = table.remove(queue, 1)
		processed = processed + 1

		local unitDef = allUnits[unitName]
		if unitDef and unitDef.buildoptions then
			for _, buildableUnitName in pairs(unitDef.buildoptions) do
				if type(buildableUnitName) == "string" and not buildableUnits[buildableUnitName] then
					buildableUnits[buildableUnitName] = true
					queue[#queue + 1] = buildableUnitName
				end
			end
		end
	end

	-- Count buildable units
	local count = 0
	for _ in pairs(buildableUnits) do
		count = count + 1
	end
	io.stderr:write("Discovered " .. count .. " buildable units\n")
end

--------------------------------------------------------------------------------
-- Output Generation
--------------------------------------------------------------------------------

local function generateOutput()
	-- Build the output table with only buildable units
	local output = {}
	local missing = {}
	local iconsAdded = 0

	for unitName in pairs(buildableUnits) do
		local unitDef = allUnits[unitName]
		if unitDef then
			-- Create a clean copy without internal fields
			local cleanDef = {}
			for k, v in pairs(unitDef) do
				if k ~= "_sourceFile" then
					cleanDef[k] = v
				end
			end

			-- Add icon from iconTypes if available
			local iconDef = iconTypes[unitName]
			if iconDef and iconDef.bitmap then
				cleanDef.icon = iconDef.bitmap
				iconsAdded = iconsAdded + 1
			end

			output[unitName] = cleanDef
		else
			missing[#missing + 1] = unitName
		end
	end

	if #missing > 0 then
		io.stderr:write("Warning: " .. #missing .. " buildable units not found in unit files:\n")
		table.sort(missing)
		for _, name in ipairs(missing) do
			io.stderr:write("  - " .. name .. "\n")
		end
	end

	io.stderr:write("Added icons to " .. iconsAdded .. " units\n")

	return output
end

local function writeJSON(data, filepath)
	local output = json.encode(data, { indent = true })
	local file, err = io.open(filepath, "w")
	if not file then
		io.stderr:write("Error opening output file: " .. tostring(err) .. "\n")
		os.exit(1)
	end
	file:write(output)
	file:write("\n")
	file:close()
	io.stderr:write("Wrote output to " .. filepath .. "\n")
end

--------------------------------------------------------------------------------
-- Main
--------------------------------------------------------------------------------

local function main()
	io.stderr:write("units2json.lua - Converting unit definitions to JSON\n")
	io.stderr:write("========================================\n")

	-- Check if units directory exists
	local attr = lfs.attributes(UNITS_DIR)
	if not attr or attr.mode ~= "directory" then
		io.stderr:write("Error: '" .. UNITS_DIR .. "' directory not found.\n")
		io.stderr:write("Please run this script from the game's root directory.\n")
		os.exit(1)
	end

	-- Load all unit definitions
	loadAllUnits()

	-- Load icon types
	loadIconTypes()

	-- Discover buildable units starting from commanders
	discoverBuildableUnits()

	-- Generate and write output
	local output = generateOutput()
	writeJSON(output, OUTPUT_FILE)

	io.stderr:write("========================================\n")
	io.stderr:write("Done!\n")
end

main()
