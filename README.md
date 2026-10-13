# IExplodeU

A lightweight cleanup utility for Roblox Luau, forked and rewritten by **Mycxm**, based on Scythe and Dark Scythe.

## Example

```lua
local IExplodeU = require(path.To.IExplodeU)

local scope = IExplodeU.scope()

-- Track a connection
IExplodeU.add(scope, game:GetService("RunService").Heartbeat:Connect(function()
    print("Running")
end))

-- Track an instance
IExplodeU.add(scope, Instance.new("Part"))

-- Track a cleanup function
IExplodeU.add(scope, function()
    print("Cleaned up!")
end)

-- Track multiple values at once
IExplodeU.addBulk(scope, connection1, connection2, instance)

-- Remove a value without cleaning it up
IExplodeU.remove(scope, instance)

-- Clean everything while keeping the scope reusable
IExplodeU.clean(scope)

-- Destroy the scope permanently
IExplodeU.destroy(scope)
```

## Methods

```lua
IExplodeU.scope()          -- Create a scope
IExplodeU.add(scope, value) -- Track a value
IExplodeU.addBulk(scope, ...) -- Track multiple values
IExplodeU.remove(scope, value) -- Remove without cleanup
IExplodeU.clean(scope)     -- Clean and reuse
IExplodeU.destroy(scope)   -- Clean and invalidate
IExplodeU.count(scope)     -- Get tracked value count
IExplodeU.isAlive(scope)   -- Check whether scope is active
```

## Features

- LIFO cleanup order.
- Reusable scopes with `clean()`.
- Automatic cleanup for supported Roblox objects and resources.
- Bulk registration with `addBulk()`.
- Scope slot reuse to reduce unnecessary allocations.
- Direct value storage without per-item cleanup tags.
- Reworked cleanup and scope management.

## Credits & History

- **Scythe 1.0** — Original implementation by checcerr and fridayqx.
- **Dark Scythe 1.3** — venexs and mycxm. Fixed cleanup processing issues that could leave remaining items unprocessed when a cleanup limit was reached.
- **Fang 1.5** — Referenced for implementation comparisons and cleanup behavior.
- **IExplodeU 2.0** — Rewritten by Mycxm, with redesigned storage, cleanup, removal, and scope management.

IExplodeU builds on the work of its predecessors while introducing a substantially reworked implementation.
