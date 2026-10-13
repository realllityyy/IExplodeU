--!strict
--!native
--!optimize 2

--[[
	1.0 -> Scythe credits: checcerr,fridayqx 
	1.3 -> Dark Scythe credits: venexs, mycxm 
			- fixed problem where it would just fking drop the cleanup after the limit is reached 
			in cleanup but its not the max limit for the scope itself. fundamental problem.
	1.5 -> so fang released and I lowk tested out fang, its not bad im not gonna lie,
			but it has some problems which the divine the biggest femboy does not want to address
			like he lit said "xpcall is expensive bro" while his thing returns if error dropping remaining.
			
	2.0 -> credits : Mycxm 
			so fang stores one object per slot but we do (tag and value) + typeof check on every add
			also changed add to be itemsOf[scope][len] = value  and many more. 
]]

export type Scope = number

type Cleanup = (any) -> ()

const itemsOf = table.create(64) :: { { any } }
const lens = table.create(64) :: { number }
const bases = table.create(64) :: { number }
const flags = table.create(64) :: { number }
const free = table.create(64) :: { number }
local scopeCount = 16
local freeLen = 16

for i = 1, 16 do
	itemsOf[i] = { nil, nil, nil, nil, nil, nil, nil, nil }
	lens[i] = 0
	bases[i] = 1
	flags[i] = 0
	free[17 - i] = i
end

const methodCache: { [any]: Cleanup } = setmetatable({}, { __mode = "k" }) :: any

local destroyScope: (id: number) -> ()

local function findClassMethod(meta: any): Cleanup?
	local holder = rawget(meta, "__index")
	for _ = 1, 16 do
		if type(holder) ~= "table" then
			return nil
		end
		const method = rawget(holder, "Destroy") or rawget(holder, "Disconnect")
		if method ~= nil then
			return if type(method) == "function" then method else nil
		end
		const above = getmetatable(holder)
		if type(above) ~= "table" then
			return nil
		end
		holder = rawget(above, "__index")
	end
	return nil
end

local function disposeTable(object: any, meta: any)
	const method: any = object.Destroy or object.Disconnect
	if type(method) == "function" then
		if type(meta) == "table" then
			const classMethod = findClassMethod(meta)
			if classMethod then
				methodCache[meta] = classMethod
			end
		end
		method(object)
	else
		warn(`IExplodeU: {object} has no Destroy or Disconnect method and cannot be cleaned`)
	end
end

local function cancelLater(target: thread)
	if coroutine.status(target) == "suspended" then
		task.cancel(target)
	end
end

local function drain(id: number)
	const items = itemsOf[id]
	local bottom = bases[id] - 1
	local top = lens[id]
	local peak = top

	while top > bottom do
		for i = top, bottom + 1, -1 do
			const value = items[i]
			items[i] = nil

			const kind = typeof(value)
			if kind == "RBXScriptConnection" then
				value:Disconnect()
			elseif kind == "Instance" then
				value:Destroy()
			elseif kind == "function" then
				value()
			elseif kind == "table" then
				const meta = getmetatable(value)
				const method = methodCache[meta]
				if method then
					method(value)
				else
					disposeTable(value, meta)
				end
			elseif kind == "thread" then
				const status = coroutine.status(value)
				if status == "suspended" then
					task.cancel(value)
				elseif status ~= "dead" then
					task.defer(cancelLater, value)
				end
			elseif kind == "number" then
				destroyScope(value)
			elseif kind == "userdata" then
				const target = value :: any
				const method = target.Destroy or target.Disconnect
				if type(method) == "function" then
					method(target)
				end
			elseif kind ~= "nil" then
				warn(`IExplodeU: cannot clean a {kind}`)
			end
		end

		bottom = top
		top = lens[id]
		if top > peak then
			peak = top
		end
	end

	lens[id] = 0
	bases[id] = 1

	if peak > 4096 then
		itemsOf[id] = { nil, nil, nil, nil, nil, nil, nil, nil }
	end
end

local function newScope(): Scope
	local id: number

	if freeLen > 0 then
		id = free[freeLen]
		freeLen -= 1
	else
		scopeCount += 1
		id = scopeCount
		itemsOf[id] = { nil, nil, nil, nil, nil, nil, nil, nil }
		bases[id] = 1
	end

	lens[id] = 0
	flags[id] = 1

	return id
end

local function add<T>(scope: Scope, value: T): T
	const len = lens[scope] + 1
	itemsOf[scope][len] = value
	lens[scope] = len
	return value
end

local function addBulk(scope: Scope, ...: unknown)
	const n = select("#", ...)
	if n == 0 then
		return
	end

	const items = itemsOf[scope]
	local len = lens[scope]

	for i = 1, n do
		len += 1
		items[len] = (select(i, ...))
	end

	lens[scope] = len
end

local function remove(scope: Scope, value: unknown): boolean
	const len = lens[scope]
	if len == 0 or value == nil then
		return false
	end

	const items = itemsOf[scope]
	local base = bases[scope]

	if flags[scope] ~= 1 then
		for i = len, base, -1 do
			if items[i] == value then
				items[i] = nil
				return true
			end
		end
		return false
	end

	if items[len] == value then
		items[len] = nil
		if len == base then
			lens[scope] = 0
			bases[scope] = 1
		else
			lens[scope] = len - 1
		end
		return true
	end

	if items[base] == value then
		items[base] = nil
		base += 1

		if base > 64 and base * 2 > len then
			const live = len - base + 1
			table.move(items, base, len, 1)
			for i = live + 1, len do
				items[i] = nil
			end
			lens[scope] = live
			bases[scope] = 1
		else
			bases[scope] = base
		end
		return true
	end

	for i = len - 1, base + 1, -1 do
		if items[i] == value then
			items[i] = items[len]
			items[len] = nil
			lens[scope] = len - 1
			return true
		end
	end

	return false
end

local function clean(scope: Scope)
	if lens[scope] == 0 or flags[scope] ~= 1 then
		return
	end

	flags[scope] = 2
	drain(scope)

	if flags[scope] == 3 then
		flags[scope] = 0
		freeLen += 1
		free[freeLen] = scope
	else
		flags[scope] = 1
	end
end

function destroyScope(scope: number)
	const state = flags[scope]
	if state ~= 1 then
		if state == 2 then
			flags[scope] = 3
		end
		return
	end

	if lens[scope] ~= 0 then
		flags[scope] = 2
		drain(scope)
	end

	flags[scope] = 0
	freeLen += 1
	free[freeLen] = scope
end

local function count(scope: Scope): number
	const len = lens[scope]
	if len == 0 then
		return 0
	end
	return len - bases[scope] + 1
end

local function isAlive(scope: Scope): boolean
	return type(scope) == "number" and flags[scope] ~= nil and flags[scope] ~= 0
end

return table.freeze({
	scope = newScope,
	add = add,
	addBulk = addBulk,
	remove = remove,
	clean = clean,
	destroy = destroyScope,
	count = count,
	isAlive = isAlive,
})

-- BANG BANG BANG BANG BANG TILL  TAKE U DOWN DOWN DOWN DOWN DOWN
-- I WANT U IN THE GROUNDDD 
-- I EXPLODE U
