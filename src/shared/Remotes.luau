--!strict
-- Single list of RemoteEvent / RemoteFunction names. A server service (Phase 1) will create them under
-- ReplicatedStorage.Remotes at startup; clients only ever look them up by these names.
-- Add entries as features land, e.g. OpenPack = "OpenPack".

local Remotes = {
	Events = {} :: { [string]: string },
	Functions = {} :: { [string]: string },
}

return table.freeze(Remotes)
