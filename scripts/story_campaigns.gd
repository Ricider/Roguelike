# StoryCampaigns: the seven other campaigns of the story universe (the State Troops'
# own campaign lives in story_text.gd). Each one tells a different slice of the same
# history, and every chapter ends with the borders the next part of the story starts
# from; ACTS puts every chapter of every campaign in order. Chapter maps are
# Assets/Maps/story_<campaign>_<n>.json (tools/make_story.py); pictures are
# Assets/Story/<campaign>_<n>.png and <campaign>_end.png (tools/story_art.py).
extends RefCounted
class_name StoryCampaigns

const CAMPAIGNS := {
	"corporate": {
		"faction": "Corporate Troops",
		"title": "Hostile Takeover",
		"subtitle": "How a company became a country.",
		"era": "Act I",
		"chapters": [
			{
				"title": "Market Share",
				"intro": [
					"Every war needs boots, bullets and trucks. Somebody has to make them, and somebody has to send the invoice.",
					"The Corporate Troops began as a security department. Then the security department bought the company, and the company bought the coast. By the time anyone thought to object, New York answered its phones with a jingle.",
					"South of the Rio Grande, the Peace Keepers still run Mexico on behalf of everybody. The board has reviewed the situation and finds it inefficient.",
				],
				"objective": "Take Mexico from the Peace Keepers.",
				"outro": [
					"The Peace Keepers withdrew south of Panama with their blue helmets and their stern statements. Mexico became the Southern Division. The quarterly report used the word \"synergy\" eleven times.",
					"Then the geologists came back from Alaska with very good news and very bad news.",
				],
			},
			{
				"title": "The Cold Rush",
				"intro": [
					"The good news: there is oil under the Alaskan tundra. A great deal of it.",
					"The bad news: the Horde got there first. Its riders crossed the frozen strait, planted their black banners at Nome, and are treating the whole western half of Alaska as a pasture.",
					"The Corporate Troops do not believe in sharing pastures.",
				],
				"objective": "Drive the Horde out of Alaska.",
				"outro": [
					"The Horde went back across the ice, swearing in three languages. The khan would remember Alaska. The board would remember the oil.",
					"Some of the contractors hired for the Alaskan campaign, however, had started asking why they were paid in company scrip. That, the board decided, was their mistake.",
				],
			},
			{
				"title": "Hostile Contractors",
				"intro": [
					"The Mercenaries were the Corporate Troops' own hired help: cheap, reliable, and contractually forbidden from having opinions.",
					"Then the scrip bounced. In one weekend the Mercenaries seized the refineries of the Gulf Coast, raised a skull over Houston and sent the board an invoice of their own.",
					"Legal has advised against paying it.",
				],
				"objective": "Retake the Gulf Coast from the Mercenaries.",
				"outro": [
					"The last Mercenary tanker slipped out of Galveston at night, heading east across the Atlantic. Somebody suggested hunting it down. Somebody else pointed out that it was now somebody else's problem.",
					"North America belonged to the Corporate Troops from the Arctic to Panama. The factories ran day and night, and for the first time the order books filled up with names from abroad.",
				],
			},
		],
		"epilogue": {
			"title": "The Order Books",
			"lines": [
				"For years the Corporate Troops sold to everyone. Rifles to the Coalition, trucks to the Insurgents, spare parts to the Horde, through three shell companies and a very discreet bank.",
				"Every war on the far side of the ocean was good for business. So they watched the Proxy Wars, the rise of the State Troops and the fall of Brussels from the boardroom on the ninety-ninth floor.",
				"Until the gold flag grew too big to ignore, and the Peace Keepers came asking for neon war machines. That is where the State Troops' story picks them up.",
			],
		},
	},
	"horde": {
		"faction": "Horde",
		"title": "The Puppet Master",
		"subtitle": "The khan's long game.",
		"era": "Acts I to III",
		"chapters": [
			{
				"title": "Steppe Fire",
				"intro": [
					"Before the strings, before the ledgers, the Horde was just a great many riders and one very patient man in Ulaanbaatar.",
					"To the south lies China: rich, crowded, and held together by the Peace Keepers' blue helmets and a great deal of paperwork.",
					"The khan has read the paperwork. He was not impressed.",
				],
				"objective": "Take East China from the Peace Keepers.",
				"outro": [
					"Beijing opened its gates on the twelfth day. The Peace Keepers left for the islands of the south, still filing objections.",
					"From the Pacific to the Urals, the steppe answered to one voice. And the khan began to wonder what he could own without ever riding there himself.",
				],
			},
			{
				"title": "Bought, Not Broken",
				"intro": [
					"In the mountains around Kabul live the Insurgents: proud, armed, and opposed on principle to anybody who gives them orders.",
					"They have been raiding the Horde's caravans for a year. The generals want them crushed.",
					"The khan wants them beaten. Not destroyed. A broken enemy is useless; a beaten one can be hired.",
				],
				"objective": "Defeat the Insurgents of Central Asia.",
				"outro": [
					"When the last Insurgent stronghold fell, the khan's envoy rode in alone, with a chest of gold and a map of the west.",
					"The Insurgents could keep their pride, he said. They could even keep fighting. They would just be fighting somebody else now, somewhere far to the west, with very new trucks.",
					"The Insurgents took the gold. Nobody ever had to ask them twice.",
				],
			},
			{
				"title": "Wolves at the Strait",
				"intro": [
					"The Horde has lost its war with the State Troops. The puppets broke, the Mercenaries surrendered, and the khan's columns limped back beyond the Volga.",
					"The Corporate Troops smelled blood. Their neon landing craft have crossed the Bering Strait and come ashore on Chukotka, certain that a wounded Horde cannot hold the far east.",
					"The khan has lost the west this year. He does not intend to lose the east as well.",
				],
				"objective": "Throw the Corporate Troops back into the sea.",
				"outro": [
					"The landing craft went back across the strait, fewer than they came.",
					"The Horde was bloodied but whole. When the Peace Keepers' envoys arrived months later, asking the khan to join a united front against the State Troops, he made them wait three days in the snow before saying yes.",
				],
			},
		],
		"epilogue": {
			"title": "One More Try",
			"lines": [
				"The khan had spent twenty years pulling strings. He had bought insurgents, preachers and mercenaries, and watched every one of them break against the State Troops.",
				"So this time he would not send puppets. He would go himself, alongside the Peace Keepers, the Corporate Troops and the rest of the world.",
				"How that ended is told in the State Troops' story. The khan, for once, did not get to write it.",
			],
		},
	},
	"coalition": {
		"faction": "Coalition Army",
		"title": "Old Europe",
		"subtitle": "Warnings nobody heeded.",
		"era": "Acts I and II",
		"chapters": [
			{
				"title": "The Eastern Wall",
				"intro": [
					"Europe had been at peace for so long that its armies had mostly become marching bands.",
					"Then the Horde's riders crossed into Poland, and the Baltic capitals called Berlin at three in the morning.",
					"The old nations signed a treaty in an afternoon, called themselves the Coalition, and discovered they still remembered how to fight.",
				],
				"objective": "Push the Horde back to Russia.",
				"outro": [
					"The Horde fell back to the borders of Russia and stayed there. The Coalition sent warnings to every capital in the world: the khan will be back.",
					"Nobody listened. But the Coalition's factories, retooled for war, never quite went back to making tractors. Somebody, after all, had to buy the rifles.",
				],
			},
			{
				"title": "Sicilian Vespers",
				"intro": [
					"The Coalition's factories sold rifles to every side of every war. The Mercenaries, as it happened, were excellent customers.",
					"Until a Horde paymaster offered them more to turn the guns around. Mercenary raiders from Tunisia have landed in Sicily, Calabria and Sardinia, and the south of Italy is burning.",
					"Rome would like its south back.",
				],
				"objective": "Drive the Mercenaries out of Italy.",
				"outro": [
					"The raiders went back to their boats. Italy counted its losses, and the Coalition quietly stopped selling to the Mercenaries. Mostly.",
					"There was another trade problem to settle, though, closer to home.",
				],
			},
			{
				"title": "The Channel Trade War",
				"intro": [
					"The Corporate Troops had sold weapons to everybody, the Horde included. The Coalition, which had nearly drowned in the Horde's last invasion, voted for an embargo.",
					"The Corporate Troops' factories in the north of Britain voted against it, with artillery.",
					"London has asked for help. The Coalition intends to give it.",
				],
				"objective": "Shut down the Corporate Troops' British factories.",
				"outro": [
					"The last Corporate factory in Manchester became a museum about the dangers of factories.",
					"The Coalition stood at the height of its power: Europe united, the Horde contained, the trade wars won. Its generals were sure the next threat would come from the east, as it always had.",
					"It came from the south-east, under a gold flag.",
				],
			},
		],
		"epilogue": {
			"title": "The Last Warning",
			"lines": [
				"The Coalition spent years warning the world about the Horde. It never thought to warn itself about the State Troops.",
				"When the gold columns crossed the Danube, the Coalition fought for every city between Vienna and Brussels, and lost them all. Its last loyalists fled across the Channel to Britain, where the Insurgents would one day find them.",
				"The war itself is told by the people who won it: the State Troops.",
			],
		},
	},
	"fundamentalists": {
		"faction": "Fundamentalists",
		"title": "The Flame",
		"subtitle": "Faith, fire and somebody else's money.",
		"era": "Act II",
		"chapters": [
			{
				"title": "Between the Rivers",
				"intro": [
					"In the markets of Baghdad, a preacher with a flame on his banner began to say what everybody was thinking: that the old rulers were tired, the foreigners greedy and the hill tribes thieves.",
					"Within a year he had an army. Within two, he had a problem: the Insurgents of the northern hills, who did not care for preachers and had suddenly arrived from the east with a great deal of money.",
				],
				"objective": "Drive the Insurgents out of Mesopotamia.",
				"outro": [
					"The Insurgents fled north into the mountains of Anatolia. Good riddance, said the preacher.",
					"He did not ask where their money had come from. A visitor from the north had already been to see him too, with a chest of gold and the same map of the west.",
				],
			},
			{
				"title": "The Road to Damascus",
				"intro": [
					"Between the Fundamentalists and the Mediterranean stand the Peace Keepers, guarding the Levant with blue helmets and very long reports.",
					"The preacher's new friends from the north have sent rifles, trucks and advice. The advice is: take the coast.",
				],
				"objective": "Take the Levant from the Peace Keepers.",
				"outro": [
					"Damascus fell to the flame, and the Peace Keepers sailed for Africa.",
					"From the Gulf to the Mediterranean the banners flew. One prize was left: the Nile, where a band of foreign mercenaries, thrown out of America, had made themselves at home.",
				],
			},
			{
				"title": "The Nile",
				"intro": [
					"The Mercenaries arrived in Egypt the way they arrive everywhere: by boat, uninvited and armed with an invoice.",
					"They hold Cairo and the whole Nile valley, and they are charging the farmers rent.",
					"The preacher says the river belongs to the faithful. His northern friends say the Mercenaries are useful and should not be destroyed, merely moved along.",
				],
				"objective": "Take Egypt from the Mercenaries.",
				"outro": [
					"The Mercenaries drove west along the coast towards Libya. The Fundamentalists held everything from the Nile to the Gulf.",
					"At the height of his power, the preacher looked north across the sea at the State Troops: tired, underpaid and busy with an insurgency of their own. He sent the Insurgents a crate of rifles, stamped with his flame, as a gesture of goodwill.",
					"It would turn out to be the most expensive gift in history.",
				],
			},
		],
		"epilogue": {
			"title": "The Crate",
			"lines": [
				"The State Troops found that crate. They followed it south, and the Fundamentalists' great realm burned in a single campaign.",
				"The last believers fled up the Nile into Sudan, where the Peace Keepers were waiting, and into the Libyan desert, where the Mercenaries were.",
				"The State Troops' story tells how the flame went out.",
			],
		},
	},
	"mercenaries": {
		"faction": "Mercenaries",
		"title": "Contracts",
		"subtitle": "Loyal to the last paycheque.",
		"era": "Acts II and III",
		"chapters": [
			{
				"title": "Landing at Benghazi",
				"intro": [
					"Thrown out of Texas by their employers and out of Egypt by preachers, the Mercenaries have boats, a great many guns and nowhere to live.",
					"Libya, held by a thin line of Peace Keepers, looks very much like somewhere to live.",
					"The captain's orders: land at Benghazi, take everything, and send the Peace Keepers an invoice for the inconvenience.",
				],
				"objective": "Take Libya from the Peace Keepers.",
				"outro": [
					"Libya became the first country in history run as a limited company. The Mercenaries painted skulls on everything and opened a recruiting office.",
					"Within a month, a visitor from the north arrived with a chest of gold and a very specific job.",
				],
			},
			{
				"title": "The Atlas Contract",
				"intro": [
					"The Horde wants the Coalition's African depots burned: the fuel, the ammunition, the spare parts. Payment on completion.",
					"The depots stretch across the Maghreb from Tunisia to Morocco, guarded by Coalition garrisons who think they are on a quiet posting.",
					"The Mercenaries do not care who the Coalition is. They care that the cheque clears.",
				],
				"objective": "Destroy the Coalition's garrisons in the Maghreb.",
				"outro": [
					"The depots burned for a week. The Horde paid in full, and the Mercenaries, as agreed, left the smoking Maghreb to whoever wanted it and went home to Libya.",
					"A few raiders got ambitious and tried Sicily on their own account. The Coalition taught them that lesson personally.",
				],
			},
			{
				"title": "Desert Recruiting",
				"intro": [
					"The State Troops have smashed the Fundamentalists. Survivors have staggered into the Libyan desert and taken the oasis towns of the Fezzan.",
					"The Horde, meanwhile, has a new job: a big one, against the State Troops themselves. It needs every gun the Mercenaries can find.",
					"The Fundamentalist stragglers have guns. They just need persuading.",
				],
				"objective": "Clear the Fundamentalist remnants out of the Fezzan.",
				"outro": [
					"The survivors who surrendered were offered a contract. Most of them signed it.",
					"Libya was whole, armed and paid for. The Mercenaries settled into their camps to wait for the Horde's signal: one great war against the State Troops, and then retirement somewhere warm.",
				],
			},
		],
		"epilogue": {
			"title": "Severance",
			"lines": [
				"The great war came, and the State Troops won it. The Mercenaries surrendered the moment the money stopped, which was the most sensible thing they ever did.",
				"Those who would not surrender drifted south into the Sahel, where the Peace Keepers eventually came for them.",
				"The war itself is told in the State Troops' story, chapter three. The Mercenaries' accountants tell it differently.",
			],
		},
	},
	"insurgents": {
		"faction": "Insurgents",
		"title": "The Mountain and the Sun",
		"subtitle": "Never the same war twice.",
		"era": "Acts II and IV",
		"chapters": [
			{
				"title": "The Mountains Rise",
				"intro": [
					"The Insurgents have been beaten by the Horde, bought by the Horde and chased out of Mesopotamia by the Fundamentalists. They are, as their commander puts it, having a difficult decade.",
					"Now they hold a few valleys around Hakkari, high in the Anatolian mountains. To the west lie the State Troops: comfortable, sleepy and spread very thin.",
					"Their trucks are new. Their rifles are new. Nobody asks where from.",
				],
				"objective": "Take south-eastern Anatolia from the State Troops.",
				"outro": [
					"In a week of fighting, two thirds of Anatolia flew the orange sun. The commander stood on the walls of Diyarbakir and declared a new age of freedom.",
					"It lasted until the State Troops woke up. How they did is the first chapter of the State Troops' own story.",
				],
			},
			{
				"title": "Highlands",
				"intro": [
					"Years have passed. The Insurgents lost Anatolia, then nearly everything else, and wandered the world as a rumour.",
					"But the State Troops have just conquered Europe, and the Coalition's last loyalists have fled across the Channel to Britain. Everyone is looking at Brussels. Nobody is looking at the Scottish Highlands.",
					"A small boat came ashore at Inverness last night, flying an orange sun.",
				],
				"objective": "Take Britain from the Coalition's loyalists.",
				"outro": [
					"London fell to the Insurgents on a wet Sunday. The loyalists were offered a choice: join, or leave. Most of them joined. Nobody hates the State Troops more than people the State Troops have already beaten.",
				],
			},
			{
				"title": "Across the Channel",
				"intro": [
					"Across the Channel, the State Troops' garrisons in northern France are bored, overstretched and a long way from home.",
					"The Insurgents have waited a long time to pay the State Troops back for Anatolia.",
				],
				"objective": "Take northern France from the State Troops.",
				"outro": [
					"The orange sun flew over Calais and Rouen. For the first time in their history, the Insurgents held a corner of Europe.",
					"Then the Peace Keepers' envoy arrived with a proposal: the whole world was going to war against the State Troops. Would the Insurgents care to join?",
					"The commander laughed for a full minute before saying yes.",
				],
			},
		],
		"epilogue": {
			"title": "The First and the Last",
			"lines": [
				"The Insurgents were the State Troops' first enemy. They were determined to be the last.",
				"In the great war that followed they held Britain and northern France for the united front, and fought the way they always had: hard, stubborn and slightly out of breath.",
				"The State Troops' story tells how that war ended.",
			],
		},
	},
	"peacekeepers": {
		"faction": "Peace Keepers",
		"title": "The Blue Line",
		"subtitle": "Keeping the peace, by any means necessary.",
		"era": "Acts II to IV",
		"chapters": [
			{
				"title": "The Blue Helmets",
				"intro": [
					"The Peace Keepers were founded to stop wars. They have been losing ground ever since: Mexico to the Corporate Troops, China to the Horde, the Levant to the Fundamentalists.",
					"Now Insurgent cells are spreading through the jungles of Indochina, and headquarters has finally authorised something stronger than a strongly worded report.",
				],
				"objective": "Root out the Insurgents of Indochina.",
				"outro": [
					"The jungles went quiet. For the first time in a decade, the Peace Keepers had won something.",
					"Headquarters filed a report about it. The report was eleven hundred pages long and slightly smug.",
				],
			},
			{
				"title": "Desert Mandate",
				"intro": [
					"The State Troops have destroyed the Fundamentalists' realm. Its last believers fled up the Nile into Sudan, and they have taken Khartoum.",
					"The Peace Keepers hold the Ethiopian highlands and the Horn of Africa. The refugees, the hunger and the fighting are all coming their way.",
				],
				"objective": "Defeat the Fundamentalist remnants in Sudan.",
				"outro": [
					"Khartoum was quiet again by the rainy season. The flame was out for good.",
					"But in Constantinople the State Troops were still winning, and still marching. Very carefully, the Peace Keepers began to count their friends.",
				],
			},
			{
				"title": "The Last Contract",
				"intro": [
					"The State Troops have beaten the Horde and conquered Europe. There is nobody left who has not lost a war to them.",
					"The Peace Keepers have a plan: a united front, every nation left on Earth against the gold flag. But first, the Sahel. Mercenaries who refused to surrender with the rest have seized it from Niger to Chad, and the front cannot have them at its back.",
				],
				"objective": "Clear the Mercenaries out of the Sahel.",
				"outro": [
					"The last Mercenary column surrendered at Agadez, demanding back pay. It did not get any.",
					"Then the Peace Keepers sent their envoys out: to the Corporate Troops' ninety-ninth floor, to the khan in the snow, to the Insurgents in London. Every one of them said yes.",
					"For the first time in history, the whole world was on the same side.",
				],
			},
		],
		"epilogue": {
			"title": "The United Front",
			"lines": [
				"The Peace Keepers had spent their whole existence trying to stop wars. Now they had organised the largest one ever fought.",
				"Every capital left on Earth declared war on the State Troops on the same morning. The blue banner flew from the Andes to the Indian Ocean.",
				"What happened next is the last chapter of the State Troops' story: The World Against Us.",
			],
		},
	},
}

# The whole history, in order: [campaign, chapter] pairs under each act.
const ACTS := [
	{"title": "Act I: Before the Storm", "chapters": [["corporate", 1], ["horde", 1], ["corporate", 2], ["coalition", 1], ["corporate", 3]]},
	{"title": "Act II: The Proxy Wars", "chapters": [["horde", 2], ["fundamentalists", 1], ["fundamentalists", 2], ["peacekeepers", 1],
		["fundamentalists", 3], ["mercenaries", 1], ["mercenaries", 2], ["coalition", 2], ["coalition", 3], ["insurgents", 1]]},
	{"title": "Act III: A State of Emergency", "chapters": [["state", 1], ["state", 2], ["mercenaries", 3], ["peacekeepers", 2], ["state", 3],
		["horde", 3], ["state", 4]]},
	{"title": "Act IV: The World Against Us", "chapters": [["insurgents", 2], ["insurgents", 3], ["peacekeepers", 3], ["state", 5]]},
]
