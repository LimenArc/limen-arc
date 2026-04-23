--!strict
-- Story, NPCs, quests, and endings for the Mire Plague arc.
-- All data; no behavior. QuestHandler drives progress + completion.

export type ObjectiveKind =
	"CatchAny"
	| "CatchSpecies"
	| "DiscoverSpecies"
	| "DefeatType"
	| "VisitLocation"
	| "HaveItem"
	| "AccumulateCoins"
	| "SpendCoins"
	| "TalkToNpc"

export type Objective = {
	Id: string,
	Kind: ObjectiveKind,
	Target: number,        -- count or threshold
	SpeciesId: string?,    -- for CatchSpecies
	ItemId: string?,       -- for HaveItem
	MonsterType: string?,  -- for DefeatType  (e.g. "Dark")
	LocationId: string?,   -- for VisitLocation
	NpcId: string?,        -- for TalkToNpc
	Description: string,
}

export type Reward = {
	Coins: number?,
	Items: { { Id: string, Count: number } }?,
}

export type QuestDef = {
	Id: string,
	Name: string,
	Category: "Main" | "Side" | "Ending",
	Giver: string?,        -- npc id that offers this quest, if any
	Summary: string,
	Prereqs: { string },
	Objectives: { Objective },
	Rewards: Reward,
	CompletionText: string,
	TriggersEnding: string?, -- ending id if this quest completion plays an ending
}

export type NpcDef = {
	Id: string,
	DisplayName: string,
	Role: string,            -- "Merchant" / "Scholar" / etc.
	GreetingNoQuest: string, -- lines shown when no active quest from this NPC
	Anchor: string,          -- where to place: "Market+E" | "Market+W" | "Camp1" | "Cabin1" | "Cave1" | "CaveLast"
	HeadColor: { number },   -- RGB
	BodyColor: { number },
	Offers: { string },      -- quest ids this NPC offers
}

export type EndingDef = {
	Id: string,
	Name: string,
	Color: { number },
	Narration: { string },   -- lines of the ending cutscene
}

local Quest = {}

-- ── The opening story crawl ──────────────────────────────────────────────
Quest.StoryIntro = {
	"Long before, the Archipelago of Aethel was green and peopled.",
	"Farmers tilled the grass plains. Scholars read in the forest cloisters.",
	"Miners worked the volcanic cones. Fishermen rode the shore currents.",
	"",
	"Then the Mire rose.",
	"",
	"A pale fog drifted from a cave no one remembered digging.",
	"Those who breathed it grew sick. Within days they changed —",
	"skin hardening to stone, bones hollowing for flight,",
	"bodies becoming fire, water, vine, or shadow.",
	"The infected could not die and could not be reasoned with.",
	"They forgot their names.",
	"",
	"The last scholars sealed themselves in the caves and lit a beacon.",
	"You are one of the few who answered it — still yourself, still human.",
	"",
	"Catch what they became. Trade with the ones who remain.",
	"Four endings wait for you. Choose carefully.",
}

-- ── NPCs ─────────────────────────────────────────────────────────────────
Quest.Npcs = {
	{
		Id = "tavi",
		DisplayName = "Tavi, the Merchant",
		Role = "Market quartermaster",
		Anchor = "Market+E",
		HeadColor = { 230, 200, 160 },
		BodyColor = { 80, 50, 120 },
		GreetingNoQuest = "Welcome, traveler. Tap a stall to trade. Bring me interesting things.",
		Offers = { "beacon", "merchant_muscle", "dominion_seed" },
	},
	{
		Id = "sagewind",
		DisplayName = "Sagewind, the Healer",
		Role = "Market apothecary",
		Anchor = "Market+W",
		HeadColor = { 240, 230, 210 },
		BodyColor = { 120, 180, 130 },
		GreetingNoQuest = "Keep your potions stocked. A sick Warden is a dead Warden.",
		Offers = { "first_catch" },
	},
	{
		Id = "marla",
		DisplayName = "Marla, Camper",
		Role = "Survivor",
		Anchor = "Camp1",
		HeadColor = { 240, 200, 170 },
		BodyColor = { 180, 80, 40 },
		GreetingNoQuest = "Cold nights out here. I could use a little warmth.",
		Offers = { "frostkit_for_marla" },
	},
	{
		Id = "bren",
		DisplayName = "Bren, the Last Farmer",
		Role = "Homesteader",
		Anchor = "Cabin1",
		HeadColor = { 230, 190, 150 },
		BodyColor = { 140, 120, 60 },
		GreetingNoQuest = "Crops won't grow. Something's gone wrong with the green things.",
		Offers = { "sprouts_for_bren" },
	},
	{
		Id = "elin",
		DisplayName = "Elin, Sealed Scholar",
		Role = "Archivist",
		Anchor = "Cave1",
		HeadColor = { 220, 220, 240 },
		BodyColor = { 50, 80, 140 },
		GreetingNoQuest = "Log every form. The Warden's Pact will open when all thirty are known.",
		Offers = { "census_10", "compendium", "fragment_hunt", "clear_swamp", "visit_all_lakes" },
	},
	{
		Id = "heart_envoy",
		DisplayName = "Envoy at the Heart",
		Role = "Keeper of the Last Cave",
		Anchor = "CaveLast",
		HeadColor = { 255, 220, 220 },
		BodyColor = { 120, 30, 30 },
		GreetingNoQuest = "The Heart sleeps. Bring the four fragments to wake the cure — or bring a weapon to end it.",
		Offers = { "the_heart_cure", "the_heart_ashes" },
	},
}

-- ── Quests ───────────────────────────────────────────────────────────────
Quest.Quests = {
	-- Opening.
	{
		Id = "beacon", Name = "The Beacon", Category = "Main", Giver = "tavi",
		Summary = "Talk to Sagewind, the healer at the west stall. She has your starting kit of advice.",
		Prereqs = {},
		Objectives = {
			{ Id = "talk_sagewind", Kind = "TalkToNpc", Target = 1, NpcId = "sagewind",
			  Description = "Talk to Sagewind at the market" },
		},
		Rewards = { Coins = 50, Items = { { Id = "trap_basic", Count = 3 } } },
		CompletionText = "Tavi nods. 'Good. Now catch me something.'",
	},

	{
		Id = "first_catch", Name = "First Catch", Category = "Main", Giver = "sagewind",
		Summary = "The infected can't be spoken to. Trap one and bring it into your care.",
		Prereqs = { "beacon" },
		Objectives = {
			{ Id = "catch_any", Kind = "CatchAny", Target = 1,
			  Description = "Capture any monster" },
		},
		Rewards = { Coins = 120, Items = { { Id = "potion_hp", Count = 2 } } },
		CompletionText = "Sagewind studies your catch. 'It still remembers something. Keep it safe.'",
	},

	-- Mid-game main line.
	{
		Id = "census_10", Name = "Census of the Changed", Category = "Main", Giver = "elin",
		Summary = "Discover ten distinct forms. The archive needs samples.",
		Prereqs = { "first_catch" },
		Objectives = {
			{ Id = "discover_10", Kind = "DiscoverSpecies", Target = 10,
			  Description = "Discover 10 unique monster species" },
		},
		Rewards = { Coins = 400, Items = { { Id = "trap_strong", Count = 3 } } },
		CompletionText = "Elin stamps a new page. 'The thirty are the old population, we think.'",
	},

	{
		Id = "compendium", Name = "The Compendium", Category = "Ending", Giver = "elin",
		Summary = "Log every one of the thirty forms. If you do, the Warden's Pact opens: coexistence.",
		Prereqs = { "census_10" },
		Objectives = {
			{ Id = "discover_30", Kind = "DiscoverSpecies", Target = 30,
			  Description = "Discover all 30 species" },
		},
		Rewards = { Coins = 5000 },
		CompletionText = "Elin seals the archive and bows. 'The Pact is yours.'",
		TriggersEnding = "warden",
	},

	{
		Id = "fragment_hunt", Name = "Four Fragments", Category = "Main", Giver = "elin",
		Summary = "Four map fragments are scattered in lucky blocks across Aethel. Gather them all.",
		Prereqs = { "census_10" },
		Objectives = {
			{ Id = "have_fragments", Kind = "HaveItem", Target = 4, ItemId = "map_fragment",
			  Description = "Collect 4 map fragments" },
		},
		Rewards = { Coins = 800, Items = { { Id = "trap_master", Count = 1 } } },
		CompletionText = "Elin assembles the map. 'The Heart of the Mire. Go.'",
	},

	{
		Id = "the_heart_cure", Name = "The Cure", Category = "Ending", Giver = "heart_envoy",
		Summary = "With the four fragments in hand, face the Envoy at the last cave and choose the cure.",
		Prereqs = { "fragment_hunt" },
		Objectives = {
			{ Id = "talk_envoy", Kind = "TalkToNpc", Target = 1, NpcId = "heart_envoy",
			  Description = "Return to the Envoy at the Heart" },
			{ Id = "fragments_held", Kind = "HaveItem", Target = 4, ItemId = "map_fragment",
			  Description = "Still holding the 4 fragments" },
		},
		Rewards = {},
		CompletionText = "The Envoy raises a stone flame. Light pours into the cave.",
		TriggersEnding = "cure",
	},

	{
		Id = "the_heart_ashes", Name = "Ashes", Category = "Ending", Giver = "heart_envoy",
		Summary = "Refuse the cure. Kill enough of the Changed to collapse the Heart. The plague ends; so does every monster in the world.",
		Prereqs = { "first_catch" },
		Objectives = {
			{ Id = "defeat_any_many", Kind = "DefeatType", Target = 40, MonsterType = "Any",
			  Description = "Defeat 40 wild monsters of any kind" },
		},
		Rewards = {},
		CompletionText = "The Heart splinters. Across Aethel, the forms fall silent.",
		TriggersEnding = "ashes",
	},

	-- Silent auto-ending.
	{
		Id = "dominion_seed", Name = "Dominion", Category = "Ending", Giver = "tavi",
		Summary = "Accumulate ten thousand coins and you will have bought what's left of Aethel. No one else will be there to notice.",
		Prereqs = {},
		Objectives = {
			{ Id = "lifetime_coins", Kind = "AccumulateCoins", Target = 10000,
			  Description = "Accumulate 10,000 coins in lifetime earnings" },
		},
		Rewards = {},
		CompletionText = "Tavi counts your coins without meeting your eyes.",
		TriggersEnding = "dominion",
	},

	-- Side quests.
	{
		Id = "frostkit_for_marla", Name = "A Warmth in the Cold", Category = "Side", Giver = "marla",
		Summary = "Marla's fire won't stay lit. Bring her the little ice form — a Frostkit — to keep her company. (You'll keep the monster.)",
		Prereqs = { "first_catch" },
		Objectives = {
			{ Id = "catch_frostkit", Kind = "CatchSpecies", Target = 1, SpeciesId = "frostkit",
			  Description = "Capture a Frostkit" },
			{ Id = "talk_marla", Kind = "TalkToNpc", Target = 1, NpcId = "marla",
			  Description = "Return to Marla" },
		},
		Rewards = { Coins = 180, Items = { { Id = "potion_hp_super", Count = 1 } } },
		CompletionText = "Marla laughs. 'That's a good beast. Thank you.'",
	},

	{
		Id = "sprouts_for_bren", Name = "The Last Harvest", Category = "Side", Giver = "bren",
		Summary = "Bren wants three Sprout Cubs to study. Something in them remembers being corn.",
		Prereqs = { "first_catch" },
		Objectives = {
			{ Id = "catch_sprout3", Kind = "CatchSpecies", Target = 3, SpeciesId = "sproutcub",
			  Description = "Capture 3 Sprout Cubs" },
			{ Id = "talk_bren", Kind = "TalkToNpc", Target = 1, NpcId = "bren",
			  Description = "Return to Bren" },
		},
		Rewards = { Coins = 260, Items = { { Id = "candy_xp", Count = 2 } } },
		CompletionText = "Bren looks at the three cubs. 'Maybe I can still grow something.'",
	},

	{
		Id = "clear_swamp", Name = "The Dark Count", Category = "Side", Giver = "elin",
		Summary = "The Dark-type forms gather in the swamp. Defeat five of them to mark the archive's risk map.",
		Prereqs = { "first_catch" },
		Objectives = {
			{ Id = "defeat_dark", Kind = "DefeatType", Target = 5, MonsterType = "Dark",
			  Description = "Defeat 5 Dark-type wild monsters" },
		},
		Rewards = { Coins = 220, Items = { { Id = "trap_shock", Count = 2 } } },
		CompletionText = "Elin ticks five boxes. 'A little safer now.'",
	},

	{
		Id = "visit_all_lakes", Name = "Cartographer", Category = "Side", Giver = "elin",
		Summary = "Set foot at each of the four lakes and note them. The scholars lost the map.",
		Prereqs = {},
		Objectives = {
			{ Id = "visit_lakes", Kind = "VisitLocation", Target = 4, LocationId = "Lake",
			  Description = "Visit all 4 lakes" },
		},
		Rewards = { Coins = 200 },
		CompletionText = "Elin redraws the water in blue ink. 'Good traveling.'",
	},

	{
		Id = "merchant_muscle", Name = "Merchant's Muscle", Category = "Side", Giver = "tavi",
		Summary = "Spend 500 coins at the market to keep trade alive.",
		Prereqs = { "beacon" },
		Objectives = {
			{ Id = "spend_500", Kind = "SpendCoins", Target = 500,
			  Description = "Spend 500 coins at the market" },
		},
		Rewards = { Coins = 150, Items = { { Id = "trap_lure", Count = 2 } } },
		CompletionText = "Tavi slides a lure trap to you. 'Economy's the last law left.'",
	},
}

-- ── Endings ──────────────────────────────────────────────────────────────
Quest.Endings = {
	cure = {
		Id = "cure",
		Name = "The Cure",
		Color = { 220, 240, 255 },
		Narration = {
			"You bring the four fragments to the Envoy at the Heart.",
			"Stone fire wells up. A cure spreads outward like a held breath released.",
			"Across Aethel, the forms you caught grow soft, stand up, remember names.",
			"Your party empties. The cages open on themselves.",
			"Humanity is restored.",
			"The monsters are gone. The people are back.",
			"— THE CURE —",
		},
	},
	warden = {
		Id = "warden",
		Name = "The Warden's Pact",
		Color = { 200, 230, 160 },
		Narration = {
			"Elin seals the last page of the Compendium.",
			"All thirty forms are known. The infected agree to live alongside the few who remain.",
			"No one is cured. No one is killed.",
			"You are named the Warden, keeper of both sides.",
			"Aethel is not what it was, but it is alive.",
			"— THE WARDEN'S PACT —",
		},
	},
	ashes = {
		Id = "ashes",
		Name = "Ashes",
		Color = { 240, 140, 90 },
		Narration = {
			"You cut through the Heart of the Mire until it splinters.",
			"Across the map, every form you left wild falls silent at once.",
			"The fog clears. The sun is still too bright.",
			"You stand in a quiet that is not peace. It is an ending.",
			"No one was saved. No one is coming.",
			"— ASHES —",
		},
	},
	dominion = {
		Id = "dominion",
		Name = "Dominion",
		Color = { 230, 200, 90 },
		Narration = {
			"Ten thousand coins.",
			"You have bought everything Tavi still sells, and most of what she doesn't.",
			"The market grows quiet when you approach.",
			"You sit, at last, on a chair of pooled money, in a plaza no one else uses.",
			"You are the last remembered sovereign of a world nobody else lives in.",
			"— DOMINION —",
		},
	},
}

-- Helpers ----------------------------------------------------------------
local byId: { [string]: QuestDef } = {}
for _, q in ipairs(Quest.Quests) do byId[q.Id] = q end

local npcById: { [string]: NpcDef } = {}
for _, n in ipairs(Quest.Npcs) do npcById[n.Id] = n end

function Quest.GetQuest(id: string): QuestDef?
	return byId[id]
end

function Quest.GetNpc(id: string): NpcDef?
	return npcById[id]
end

function Quest.QuestsOfferedBy(npcId: string): { QuestDef }
	local out = {}
	for _, q in ipairs(Quest.Quests) do
		if q.Giver == npcId then table.insert(out, q) end
	end
	return out
end

return Quest
