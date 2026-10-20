--!strict
-- Shared type definitions for config data and player data.

-- Config ---------------------------------------------------------------------

export type RarityDef = {
	Id: string,
	DisplayName: string,
	Order: number,
	Color: Color3,
	-- Whether luck bonuses increase this rarity's drop weight.
	LuckAffected: boolean,
}

export type VariantDef = {
	Id: string,
	DisplayName: string,
	Order: number,
	Color: Color3,
	IncomeMultiplier: number,
	SaleMultiplier: number,
	-- Relative weight when rolling a variant for a newly opened card.
	DropWeight: number,
	LuckAffected: boolean,
}

export type CollectionDef = {
	Id: string,
	DisplayName: string,
	Order: number,
	Color: Color3,
	-- Permanent global income bonus once every card in the collection is discovered.
	CompletionIncomeBonus: number,
	-- Not shown in the Binder or counted in overall progress (e.g. unreleased promo sets).
	Hidden: boolean?,
}

export type UnlockRequirement = {
	Level: number?,
	CollectionComplete: string?,
}

export type CardDef = {
	Id: string,
	Name: string,
	Description: string,
	Species: string,
	Rarity: string,
	BaseIncome: number,
	BaseSaleValue: number,
	Artwork: string,
	Collection: string,
	CollectionNumber: number,
	-- Variant ids this card can roll as. Nil means every variant.
	Variants: { string }?,
	Unlock: UnlockRequirement?,
	-- True while name / rarity / income are placeholders waiting for the owner's values.
	Placeholder: boolean?,
}

export type PackDef = {
	Id: string,
	DisplayName: string,
	Description: string,
	Order: number,
	Price: number,
	Currency: string,
	CardsPerOpen: number,
	Collections: { string },
	RarityWeights: { [string]: number },
	Xp: number,
	Color: Color3,
	Artwork: string,
	Unlock: UnlockRequirement?,
	-- Not listed in or sold by the cash Pack Shop (premium / Robux-only packs).
	ShopHidden: boolean?,
	-- Asset key of the card back shown for this pack's cards (default: Config.Assets card.back).
	CardBack: string?,
}

export type UpgradeDef = {
	Id: string,
	DisplayName: string,
	Description: string,
	Order: number,
	MaxLevel: number,
	Currency: string,
	BaseCost: number,
	CostGrowth: number,
	-- Effect amount added per level (meaning depends on the upgrade).
	PerLevel: number,
}

-- Player data ------------------------------------------------------------------

export type CardInstance = {
	CardId: string,
	Variant: string,
	-- Grade 1-10 once graded; nil while ungraded.
	Grade: number?,
	Obtained: number,
	Favorite: boolean,
}

export type DiscoveryEntry = {
	First: number,
	Count: number,
	Variants: { [string]: boolean },
}

export type PlayerData = {
	SchemaVersion: number,
	Currency: { [string]: number },
	Cards: { [string]: CardInstance },
	NextCardSerial: number,
	Discovered: { [string]: DiscoveryEntry },
	-- Unopened packs owned: pack id -> count.
	Packs: { [string]: number },
	-- Slot index (as a string, so the table saves as a dictionary) -> card instance id.
	Display: { [string]: string },
	-- Uncollected stand earnings (slot index -> amount) and the last time the player was
	-- online (Unix seconds, 0 = never), used for capped offline earnings.
	Income: { LastOnline: number, Pending: { [string]: number } },
	Upgrades: { [string]: number },
	Collections: { Claimed: { [string]: boolean } },
	Quests: { Active: { [string]: number }, Completed: { [string]: boolean } },
	DailyRewards: { LastClaimDay: number, Streak: number },
	Settings: { [string]: any },
	Progression: { Level: number, Xp: number },
	Stats: { [string]: number },
	Flags: { [string]: boolean },
	-- Receipts: processed Developer Product PurchaseId -> Unix time (reserved; no Developer
	-- Products are sold yet).
	-- Entitlements: last confirmed game pass ownership (e.g. MultiOpen3), mirrored from
	-- UserOwnsGamePassAsync; a failed query never clears it.
	Purchases: { Receipts: { [string]: number }, Entitlements: { [string]: boolean } },
}

return {}
