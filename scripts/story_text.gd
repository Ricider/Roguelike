# StoryText: the words of the story campaigns (see scripts/story.gd), and the way
# to look them up. Eight campaigns share one history: the State Troops' own
# (below) and seven more in story_campaigns.gd, put in order by its ACTS.
# Each chapter: its title, the illustration shown with its intro (Assets/Story/),
# the intro paragraphs, the objective, and the outro shown after you win it,
# which plays over the next chapter's illustration (the campaign's finale after
# the last). Optional "briefing" / "combat_briefing" are shown on the map.
extends RefCounted
class_name StoryText

const SAGA_TITLE := "A STATE OF EMERGENCY"
const SAGA_SUBTITLE := "The reluctant war of the State Troops, in five chapters."
const CHRONICLE_TITLE := "CAMPAIGNS"
const CHRONICLE_SUBTITLE := "Eight factions, one history. Each campaign tells a different part of it."

# Campaign menu order: the State Troops' saga first, then the rest in order of their first act.
const ORDER := ["state", "corporate", "horde", "coalition", "fundamentalists", "mercenaries", "insurgents", "peacekeepers"]

const CHAPTERS := [
	{
		"title": "Smoke Over Anatolia",
		"image": "ch1",
		"intro": [
			"For years the State Troops asked for very little. A paycheque that arrived more or less on time. Boots without holes. A quiet barracks on the Bosporus, where the biggest threat was the canteen's Tuesday soup.",
			"Then the telephones in the eastern provinces stopped answering.",
			"From the hills around Diyarbakir the Insurgents came down with borrowed rifles and suspiciously new trucks. Within a week, two thirds of Anatolia flew the orange sun.",
			"Nobody in Constantinople asked where the trucks had come from. There wasn't time.",
		],
		"objective": "Retake Anatolia. Wipe out the Insurgents.",
		# shown on the map: at the start of the chapter, and after your first End Turn.
		# [Brackets] are highlighted. {wall_hint} is filled in by the map screen.
		"briefing": {
			"title": "Field Briefing",
			"lines": [
				"Look at the hills, commander. Every Insurgent [Infantry] is dug in on a [Mountain]. A ground unit standing on a mountain hex takes [1 less damage] from every hit, so they will be stubborn to shift.",
				"How targeting works: units without range ([Melee]) always shoot the [closest enemy target] anywhere on the map, a card or a flag. Units with [HasRange] pick the closest enemy nation and hit a random one of its targets. Hover any card on the map to see its next shot.",
				"So here is the trick: put a [Wall] between your Infantry and theirs. Their Infantry will fire at whatever is closest, and a Wall can soak up a lot of bullets while your troops shoot back.",
				"{wall_hint}",
			],
			"button": "Understood",
		},
		"combat_briefing": {
			"title": "How Combat Works",
			"lines": [
				"Every one of your units now fires once ([Rocket Launcher]s and [Howitzer]s four times). Each one marches out towards its target, shoots and marches home. That part is just a show: the cards never leave their hexes.",
				"Damage comes off a card's HP. A destroyed card costs its owner [HP] equal to its [BioCost], and hits on a [flag] go straight to that nation's HP.",
				"When a nation's HP reaches 0 it [collapses]: it gives up border land to whoever hurt it most, then rebuilds. Every hex you take earns [Influence] to spend in the [Shop]. Take every last Insurgent hex to win the chapter.",
				"After you, the Insurgents take their turn the same way, and the camera follows the fighting. Good luck, commander.",
			],
			"button": "Good luck to us all",
		},
		"outro": [
			"The last Insurgent flag came down over Diyarbakir on a grey Thursday afternoon. The State Troops went home, hung up their helmets and slept for two days straight.",
			"On the third day, a supply clerk found a crate among the Insurgents' abandoned stores. It was stamped with a flame.",
			"\"Probably nothing,\" said the general, and went back to bed.",
		],
	},
	{
		"title": "Fire From the South",
		"image": "ch2",
		"intro": [
			"It was not nothing.",
			"The Fundamentalists swept out of the Arabian desert and up the Nile in a single night, under the very same flame that was stamped on the Insurgents' crates.",
			"Their preachers called the State Troops godless bureaucrats. The State Troops, who had been looking forward to a long weekend, found this unfair but not entirely inaccurate.",
			"The Balkans and all of Anatolia are yours to defend now. The desert is theirs. For the moment.",
		],
		"objective": "Break the Fundamentalists. Take the Levant, Arabia and Egypt.",
		"outro": [
			"Cairo fell, and then the desert went quiet.",
			"In the Fundamentalists' last bunker, beneath a portrait nobody recognised, the State Troops found the ledgers. Payments for rifles. Payments for trucks. Payments for preachers. Payments for the Insurgents, too.",
			"Every page was signed in red ink, in a hand that came from very far to the north.",
		],
	},
	{
		"title": "The Puppet Masters",
		"image": "ch3",
		"intro": [
			"The Horde had been pulling the strings all along.",
			"Insurgents to bleed the State Troops in the east, Fundamentalists to burn the south. And when both puppets broke, the puppeteer stepped onto the stage himself: Horde columns rolling down from the Russian steppe, and Mercenaries, long paid and long waiting, marching out of their camps in Libya.",
			"For the first time, the State Troops are fighting on two fronts against an enemy that can actually afford the war.",
			"They have one advantage. They are very, very tired of being pushed around.",
		],
		"objective": "Defeat the Horde and its Mercenaries.",
		"outro": [
			"The Mercenaries surrendered the moment the money stopped. The Horde did not surrender, exactly. It simply melted back beyond the Volga, leaving the Caucasus passes and the whole Libyan coast in State Troops hands.",
			"Back in Constantinople, somebody unrolled a very large map. Somebody else remarked on how much of it was now coloured gold.",
			"And somebody, nobody will ever admit who, put a finger on Brussels and said: \"Why not?\"",
		],
	},
	{
		"title": "Appetite",
		"image": "ch4",
		"intro": [
			"The war was over. The State Troops had won. They could have gone home.",
			"Instead they looked west, at the Coalition's fat, peaceful cities and the very factories that had sold rifles to every side of the last three wars. It would be justice, the generals said. It would be security. It would be, mostly, a great deal of land.",
			"The Coalition Army had spent years warning everyone about the Horde. It was astonished to find tanks rolling in from the other direction.",
		],
		"objective": "Conquer the Coalition. Take Europe.",
		"outro": [
			"Brussels fell in the spring. The gold flag flew over the Rhine, the Seine and the Vistula.",
			"For about a week, it felt wonderful.",
			"Then the ambassadors began to leave. Then the radio channels went silent, one by one. And then, all at once, every capital left on Earth declared war.",
		],
	},
	{
		"title": "The World Against Us",
		"image": "ch5",
		"intro": [
			"Nobody likes an empire. Least of all one that started as a barracks with bad soup.",
			"The Peace Keepers have rallied the rest of the world under their pale blue banner, from the Andes to the Indian Ocean. The Corporate Troops have thrown in their neon war machines from North America. The Horde has crawled back out from beyond the Volga for one last try. Even the Insurgents, the very first enemy, have resurfaced in Britain and northern France.",
			"The State Troops only ever wanted a quiet life. Now the entire planet wants them gone.",
			"There is exactly one way left to get some peace and quiet.",
		],
		"objective": "Defeat everyone. Every last one of them.",
		"outro": [],
	},
]

const EPILOGUE_TITLE := "Peace and Quiet"
const EPILOGUE := [
	"And then, at last, it was quiet.",
	"The State Troops rule every hex of the world. There is nobody left to fight, nobody left to fund an insurgency, nobody left to send a crate stamped with anything at all.",
	"The generals held a parade. The soldiers went home. The paycheques arrived exactly on time.",
	"The canteen still serves the Tuesday soup. Some things even a world war cannot fix.",
	"THE END",
]

const DEFEAT_TITLE := "The Flag Falls"
const DEFEAT := [
	"The last gold flag lies in the mud.",
	"History will remember the State Troops as a footnote: brave, underpaid and badly outnumbered.",
	"But history is written by whoever is still standing. Pick it up and try again.",
]

const STATE := {
	"faction": "State Troops",
	"title": "A State of Emergency",
	"subtitle": "The reluctant war of the State Troops.",
	"era": "Acts III and IV",
}

# A campaign's record: faction, title, subtitle, era, chapters, epilogue.
static func campaign(cid: String) -> Dictionary:
	if cid == "state" or cid == "":
		var d: Dictionary = STATE.duplicate(true)
		d["chapters"] = CHAPTERS
		d["epilogue"] = {"title": EPILOGUE_TITLE, "lines": EPILOGUE, "image": "epilogue"}
		return d
	return StoryCampaigns.CAMPAIGNS.get(cid, {})

static func count(cid: String = "state") -> int:
	return (campaign(cid).get("chapters", []) as Array).size()

# Chapter n (1-based) of a campaign, with its "image" filled in.
static func chapter(cid: String, n: int) -> Dictionary:
	var chs: Array = campaign(cid).get("chapters", [])
	if chs.is_empty():
		return {}
	var d: Dictionary = (chs[clampi(n, 1, chs.size()) - 1] as Dictionary).duplicate(true)
	if not d.has("image"):
		d["image"] = "%s_%d" % [cid, clampi(n, 1, chs.size())]
	return d

# The campaign's finale, shown after its last chapter: {title, lines, image}.
static func epilogue(cid: String) -> Dictionary:
	var d: Dictionary = (campaign(cid).get("epilogue", {}) as Dictionary).duplicate(true)
	if not d.has("image"):
		d["image"] = "%s_end" % cid
	return d

# What the story screen says when a chapter is lost: {title, lines, image}.
static func defeat(cid: String) -> Dictionary:
	if cid == "state" or cid == "":
		return {"title": DEFEAT_TITLE, "lines": DEFEAT, "image": "defeat"}
	var faction := str(campaign(cid).get("faction", "Their"))
	return {
		"title": DEFEAT_TITLE,
		"lines": [
			"The last %s flag lies in the mud." % faction,
			"This is not how the story went, and history is not in the habit of changing its mind.",
			"Pick the flag up and make it go the way it should.",
		],
		"image": "defeat_%s" % cid,
	}

# The map a chapter is played on (tools/make_story.py).
static func map_id(cid: String, n: int) -> String:
	return ("story_%d" % n) if (cid == "state" or cid == "") else ("story_%s_%d" % [cid, n])

static func acts() -> Array:
	return StoryCampaigns.ACTS

static func image(name: String) -> Texture2D:
	var path := "res://Assets/Story/%s.png" % name
	return load(path) as Texture2D if ResourceLoader.exists(path) else null
