-- Loads project ModuleScripts under Lune with Roblox-style requires.
--
-- Source modules use `require(script.Parent.Foo)` and `game:GetService("ReplicatedStorage").Shared`.
-- This loader emulates just enough of the instance tree, following Rojo's file mapping rules
-- (default.project.json), for pure modules to run unmodified:
--   * `Foo.luau`              -> ModuleScript "Foo"
--   * `Foo/init.luau`         -> ModuleScript "Foo" whose children are the folder's other files
--   * `Foo/` (no init)        -> Folder "Foo"
-- Modules that touch real Roblox services (Players, DataStoreService, ...) are not loadable here.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local task = require("@lune/task")
local roblox = require("@lune/roblox")

local Loader = {}

type Node = {
	path: string, -- filesystem path ("" for virtual containers)
	name: string,
	className: string,
	parent: Node?,
	virtualChildren: { [string]: Node }?,
}

local nodeProxies: { [Node]: any } = {}
local proxyNodes: { [any]: Node } = {}
local moduleCache: { [string]: any } = {}
local loading: { [string]: boolean } = {}

local function stripExt(name: string): (string, string?)
	for _, ext in { ".server.luau", ".client.luau", ".luau", ".lua" } do
		if string.sub(name, -#ext) == ext then
			return string.sub(name, 1, -#ext - 1), ext
		end
	end
	return name, nil
end

local function initFile(dir: string): string?
	for _, candidate in { "init.luau", "init.lua", "init.server.luau", "init.client.luau" } do
		if fs.isFile(dir .. "/" .. candidate) then
			return dir .. "/" .. candidate
		end
	end
	return nil
end

local function classFor(path: string): string
	if fs.isDir(path) then
		local init = initFile(path)
		if not init then
			return "Folder"
		end
		path = init
	end
	if string.find(path, "%.server%.luau$") then
		return "Script"
	elseif string.find(path, "%.client%.luau$") then
		return "LocalScript"
	end
	return "ModuleScript"
end

local makeProxy: (node: Node) -> any

-- The filesystem is scanned eagerly: Lune's fs calls may yield, and yielding is not
-- allowed inside the __index metamethods that resolve `script.Parent.X`.
local childCache: { [string]: { Node } } = {}
local sources: { [string]: string } = {}

local function scan(node: Node)
	local list = {}
	if node.path ~= "" and fs.isDir(node.path) then
		local names = fs.readDir(node.path)
		table.sort(names)
		for _, entry in names do
			local full = node.path .. "/" .. entry
			local base, ext = stripExt(entry)
			if base ~= "init" and (fs.isDir(full) or ext ~= nil) then
				local child: Node = { path = full, name = base, className = classFor(full), parent = node }
				table.insert(list, child)
				if fs.isFile(full) then
					sources[full] = fs.readFile(full)
				else
					local init = initFile(full)
					if init then
						sources[init] = fs.readFile(init)
					end
				end
				scan(child)
			end
		end
	end
	childCache[node.path] = list
end

local function children(node: Node): { Node }
	if node.virtualChildren then
		local list = {}
		for _, child in node.virtualChildren do
			table.insert(list, child)
		end
		return list
	end
	return childCache[node.path] or {}
end

local function findChild(node: Node, name: string): Node?
	for _, child in children(node) do
		if child.name == name then
			return child
		end
	end
	return nil
end

makeProxy = function(node: Node): any
	local existing = nodeProxies[node]
	if existing then
		return existing
	end
	local proxy = {}
	local methods = {
		WaitForChild = function(_, name: string)
			local child = findChild(node, name)
			assert(child, `WaitForChild: {node.name}.{name} does not exist`)
			return makeProxy(child)
		end,
		FindFirstChild = function(_, name: string)
			local child = findChild(node, name)
			return if child then makeProxy(child) else nil
		end,
		GetChildren = function()
			local out = {}
			for _, child in children(node) do
				table.insert(out, makeProxy(child))
			end
			return out
		end,
		IsA = function(_, className: string)
			return node.className == className
		end,
	}
	setmetatable(proxy, {
		__index = function(_, key: string)
			if key == "Name" then
				return node.name
			elseif key == "ClassName" then
				return node.className
			elseif key == "Parent" then
				return if node.parent then makeProxy(node.parent) else nil
			elseif methods[key] then
				return methods[key]
			end
			local child = findChild(node, key)
			if child then
				return makeProxy(child)
			end
			error(`{key} is not a valid member of {node.className} "{node.name}"`, 2)
		end,
		__tostring = function()
			return node.name
		end,
	})
	nodeProxies[node] = proxy
	proxyNodes[proxy] = node
	return proxy
end

-- Virtual DataModel following default.project.json.
local dataModel: Node = { path = "", name = "game", className = "DataModel", virtualChildren = {} }
local function service(name: string, mounts: { [string]: string }): Node
	local node: Node = { path = "", name = name, className = name, parent = dataModel, virtualChildren = {} }
	for childName, path in mounts do
		local mount: Node = { path = path, name = childName, className = classFor(path), parent = node }
		scan(mount);
		(node.virtualChildren :: any)[childName] = mount
	end
	(dataModel.virtualChildren :: any)[name] = node
	return node
end
service("ReplicatedStorage", { Shared = "src/shared" })
service("ServerScriptService", { Server = "src/server" })

local game = makeProxy(dataModel)
local gameMethods = {
	GetService = function(_, name: string)
		local node = (dataModel.virtualChildren :: any)[name]
		assert(node, `Loader: service {name} is not emulated`)
		return makeProxy(node)
	end,
}
-- DataModel proxy: GetService is the only API modules may use.
getmetatable(game).__index = (function(original)
	return function(self, key)
		if gameMethods[key] then
			return gameMethods[key]
		end
		return original(self, key)
	end
end)(getmetatable(game).__index)

local function requireNode(node: Node): any
	assert(node.className == "ModuleScript", `require: {node.name} is a {node.className}, not a ModuleScript`)
	local file = if fs.isDir(node.path) then initFile(node.path) else node.path
	assert(file, `require: no source for {node.path}`)
	if moduleCache[file] ~= nil then
		return moduleCache[file]
	end
	assert(not loading[file], `require: cyclic dependency at {file}`)
	loading[file] = true

	local chunk = luau.load(sources[file] or error(`require: {file} was not scanned`), {
		debugName = file,
		environment = {
			script = makeProxy(node),
			game = game,
			task = task,
			Color3 = roblox.Color3,
			require = function(target: any)
				local targetNode = proxyNodes[target]
				assert(targetNode, `require: expected a ModuleScript proxy, got {typeof(target)}`)
				return requireNode(targetNode)
			end,
		},
	})
	local result = chunk()
	loading[file] = nil
	moduleCache[file] = result
	return result
end

-- Loads a module by its filesystem path, e.g. Loader.require("src/shared/Config").
function Loader.require(path: string): any
	-- Resolve by walking from the virtual service mount so `script.Parent` chains work.
	for _, svc in dataModel.virtualChildren :: any do
		for _, mount in svc.virtualChildren do
			if path == mount.path or string.sub(path, 1, #mount.path + 1) == mount.path .. "/" then
				local node = mount
				local rest = string.sub(path, #mount.path + 2)
				for segment in string.gmatch(rest, "[^/]+") do
					local name = stripExt(segment)
					node = findChild(node, name)
					assert(node, `Loader.require: {path} not found`)
				end
				return requireNode(node)
			end
		end
	end
	error(`Loader.require: {path} is outside the Rojo tree`)
end

return Loader
