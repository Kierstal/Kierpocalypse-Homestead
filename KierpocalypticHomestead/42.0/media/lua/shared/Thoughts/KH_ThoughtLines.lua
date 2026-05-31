-- Kierpocalyptic Homestead - thought line data
-- 
-- Categories of thoughts the dispatcher pulls from. Most categories
-- store { default = {lines}, TraitOrProfessionName = {lines}, ... }
-- and the dispatcher prefers the variant matching the character's traits
-- or profession. Trait/profession ambient are flat keyed tables that the
-- ambient trigger samples directly.
-- 
-- This file is intentionally stuffed with content. Add more lines or
-- categories freely - dispatcher reads fresh.

KH = KH or {}
KH.ThoughtLines = {

    -- Time milestones (force-fired once per milestone)
    time = {
        ["day1"] = {
            default = {
                "First night without a phone signal. Strange how loud the silence is.",
                "Day one. Whatever the news was about, it's here now.",
                "Maybe by morning someone will come.",
                "Twenty-four hours ago I was a normal person.",
                "If I just keep my head down, this might pass.",
            },
        },
        ["day3"] = {
            default = {
                "Three days. Still hoping someone's coming.",
                "Nobody's coming, are they?",
                "Three days. I keep waiting for the helicopters.",
                "Already harder than I thought it'd be.",
                "Has it really only been three days?",
            },
        },
        ["day7"] = {
            default = {
                "A week. I should start counting in weeks now.",
                "Seven days. Feels like a year.",
                "If anyone was coming, they'd be here by now.",
                "One week. The news anchors are dead.",
                "Whatever I was working on last week feels like a dream.",
            },
        },
        ["day14"] = {
            default = {
                "Two weeks in. The food I had is dwindling.",
                "Two weeks. I'm forgetting what other people sounded like.",
                "Half a month. I haven't said my name out loud in days.",
                "Fourteen days. Already I notice the small wins more.",
            },
        },
        ["day30"] = {
            default = {
                "A month. This is my life now.",
                "Thirty days. The calendar feels pointless.",
                "One month. I should celebrate. Should I?",
                "A month down. I'm still here. That counts.",
            },
        },
        ["day60"] = {
            default = {
                "Two months. The world keeps not ending again.",
                "Sixty days. I notice the seasons changing.",
            },
        },
        ["day100"] = {
            default = {
                "A hundred days. I should be proud or terrified.",
                "Hundred days. Whatever this is, I'm in it for good.",
                "Triple digits. Different person now.",
            },
        },
        ["day200"] = {
            default = {
                "Two hundred. I've stopped looking for rescue.",
                "Two hundred days. The plants I planted are food now.",
            },
        },
        ["day365"] = {
            default = {
                "A year. The world ended a year ago. I'm still here.",
                "A year. Anniversary I never wanted.",
                "One whole year. Different person. Different life.",
            },
        },
        ["day730"] = {
            default = {
                "Two years. I barely remember the before.",
                "Two years. Settled. Settled in this.",
            },
        },
    },

    -- Power outage (force-fired once)
    elecOff = {
        default = {
            "The lights just went out. Everywhere.",
            "Power's gone. Whoever was keeping it on... isn't anymore.",
            "Click. And the grid is dead.",
            "No more power. Time to be primitive.",
            "The hum I didn't notice until it stopped.",
        },
        farmer = {
            "Power's out. The freezer was the only thing holding the harvest. Better start preserving.",
            "Grid's dead. Solar would've been smart.",
        },
        doctor = {
            "No electricity. Anything in a fridge that needs it... is gone.",
            "Power out. I'm thinking of every patient who's plugged in somewhere.",
        },
        engineer = {
            "Power's out. I could fix it. If there was anyone left to keep it running.",
        },
    },

    -- Water outage (force-fired once)
    waterOff = {
        default = {
            "Faucet just gave me a sputter. We're on our own for water now.",
            "Tap's dead. Need to figure out the water situation, fast.",
            "No more running water. That was fast.",
            "Goodbye, showers.",
        },
        farmer = {
            "No more tap. The rain barrels just got serious.",
            "Tap's dead. Glad I dug that well.",
        },
    },

    -- Moodle: Hungry just rose to active
    moodle_Hungry = {
        default = {
            "My stomach won't stop reminding me.",
            "Hungry. Should eat soon.",
            "Empty. Need to fix that.",
            "Stomach is shouting.",
            "When did I last eat?",
        },
        HeartyAppetite = {
            "I'm always hungry, but this is more than usual.",
            "Big appetite, big hunger. Standard for me.",
        },
        LightEater = {
            "Even my small appetite is reminding me to eat.",
        },
    },

    -- Moodle: Thirsty just rose to active
    moodle_Thirsty = {
        default = {
            "Throat feels like sandpaper.",
            "I need water.",
            "Tongue stuck to the roof of my mouth.",
            "Thirst is louder than it should be.",
            "Water. Now.",
        },
    },

    -- Moodle: Tired just rose to active
    moodle_Tired = {
        default = {
            "I need to sit down. Just for a minute.",
            "My legs are heavy.",
            "Eyelids are doing their thing.",
            "Tired in the bones.",
            "Could lay down right here.",
        },
        Insomniac = {
            "And I won't even sleep when I lie down. Fun.",
        },
        Athletic = {
            "I'm not used to being this tired.",
        },
    },

    -- Moodle: Bored just rose to active
    moodle_Bored = {
        default = {
            "Wonder what's on TV. ...Oh.",
            "Need something to do.",
            "Mind is spinning on nothing.",
            "Bored. Dangerous.",
            "I'd kill for a book I haven't read.",
        },
        ComicNerd = {
            "I would kill for a comic book right now.",
            "Maybe the next house has the latest issue.",
            "I could go for one of those long Vertigo runs right now.",
        },
        FastReader = {
            "I read so fast and there's nothing left to read.",
        },
    },

    -- Moodle: Unhappy just rose to active
    moodle_Unhappy = {
        default = {
            "Just... heavy today.",
            "Hard to find a reason.",
            "Everything is gray.",
            "Some days are worse than others.",
            "Smiling doesn't come natural anymore.",
        },
        Pluviophile = {
            "Wish it would rain.",
            "Rain would help.",
        },
        Pluviophobe = {
            "Hope the sky stays clear.",
        },
        Hemophobic = {
            "If I see another bloody anything I might lose it.",
        },
    },

    -- Moodle: Stressed just rose to active
    moodle_Stressed = {
        default = {
            "Hard to think straight.",
            "Need to slow my breathing.",
            "Heart is too fast.",
            "Wound up tight.",
            "Just need to breathe.",
        },
        TherapyAnimals = {
            "Wish there was an animal nearby. Even a chicken would help.",
            "Need a paw or a feather near me.",
        },
        Cowardly = {
            "Being scared all the time is exhausting.",
        },
        Brave = {
            "Even brave breaks down sometimes.",
        },
    },

    -- Moodle: Panic just rose to active
    moodle_Panic = {
        default = {
            "Get a grip. Get a grip. Get a grip.",
            "Just breathe. Just breathe.",
            "I can't I can't I can't",
            "Move move move",
            "Not now not now not now",
        },
        AdrenalineJunkie = {
            "Okay. Okay. This is where I'm best. Go.",
            "Heart pounding. Eyes sharp. Now I think.",
        },
        Desensitized = {
            "I shouldn't be feeling this. I trained for this.",
        },
    },

    -- Moodle: Wet just rose to active
    moodle_Wet = {
        default = {
            "I'm soaked through.",
            "Need to dry off.",
            "Cold water dripping down my back.",
            "Squelching every step.",
        },
        Pluviophile = {
            "Soaked. And honestly? Kind of love it.",
            "Wet is fine. Wet is okay. Wet is home.",
        },
        Pluviophobe = {
            "Wet. Cold. I hate every second of this.",
        },
    },

    -- Moodle: Cold just rose to active
    moodle_Cold = {
        default = {
            "My fingers are stiff.",
            "Need to warm up.",
            "Cold is a kind of pain.",
            "I can see my breath.",
        },
    },

    -- Moodle: Sick just rose to active
    moodle_Sick = {
        default = {
            "Something doesn't feel right.",
            "Should I be worried about this?",
            "Hope this is just a cold.",
            "Stomach is doing things.",
        },
        ProneToIllness = {
            "Of course. Of course I get sick first.",
        },
        Resilient = {
            "I'm rarely sick. So why now?",
        },
    },

    -- Moodle: HeavyLoad just rose to active
    moodle_HeavyLoad = {
        default = {
            "This is a lot to carry.",
            "My shoulders are killing me.",
            "Bag's eating into me.",
        },
        Strong = {
            "Even I can feel this load.",
        },
        Weak = {
            "Of course I can't carry it all.",
        },
    },

    -- Moodle: Pain just rose to active
    moodle_Pain = {
        default = {
            "Hurts. Trying to ignore it.",
            "Pain. Focus.",
            "Body's reminding me it's there.",
        },
        Resilient = {
            "Pain. I can keep going.",
        },
    },

    -- Bleeding isn't a vanilla moodle (PZ tracks it per body part). We
    -- scan for any bodyPart:getBleedingTime() > 0 and fire this. Short
    -- cooldown (1 hr) since blood loss is urgent.
    moodle_Bleeding = {
        default = {
            "I'm bleeding. Bandage. Now.",
            "Blood. That's mine.",
            "Stop the bleeding before anything else.",
            "Dripping. Bad sign.",
            "Press it. Wrap it. Move.",
        },
        Hemophobic = {
            "Don't look down. Don't look down.",
            "Red. So much red.",
        },
        FirstAid = {
            "Pressure first. Bandage second.",
            "Need to triage this. On me.",
        },
    },

    -- First time encountering each animal type within 2 tiles
    animal = {
        ["cow"] = {
            default = {
                "Cows. Strange. The animals are just going about their lives.",
                "Cow. The world doesn't know yet.",
                "It just stares at me. Doesn't know we're done.",
            },
            farmer = {
                "A cow. Familiar. Familiar feels rare these days.",
                "Right size for a homestead. Got plans now.",
            },
        },
        ["chicken"] = {
            default = {
                "Hens still laying. The world doesn't know yet.",
                "Chickens. The eggs alone could keep me going.",
                "Cluck cluck. Sweetest sound I've heard in days.",
            },
            Cook = {
                "Eggs. Real eggs. I could weep.",
            },
        },
        ["pig"] = {
            default = {
                "A pig. Smart things. Hope it stays away.",
                "Pig. They turn feral fast, I've heard.",
            },
        },
        ["sheep"] = {
            default = {
                "Sheep. Wool. Food. Useful, if I can manage them.",
                "Sheep. Easier than I'd guess. Right?",
            },
            Tailor = {
                "Wool. The shears are in my pack. We're in business.",
            },
        },
        ["deer"] = {
            default = {
                "Deer. So calm. Lucky them.",
                "A deer. Wonder if I can hunt it.",
                "Look at it. Doesn't even register me.",
            },
            Hunter = {
                "Deer. Now we're talking.",
                "I see the wind. I see the line. I have the bow.",
            },
        },
        ["rabbit"] = {
            default = {
                "A rabbit. So small.",
                "Rabbit. Quiet thing.",
                "Lucky rabbits everywhere. Where's the foot?",
            },
        },
        ["squirrel"] = {
            default = {
                "Squirrels still doing squirrel things.",
                "Squirrel. Bouncing around like nothing's wrong.",
            },
        },
        ["mouse"] = {
            default = {
                "A mouse. They always outlast us.",
                "Mouse. Future tenants.",
            },
        },
        ["rat"] = {
            default = {
                "Rats. Of course.",
                "Where there's one rat there's a hundred.",
                "Plague animals. Fitting.",
            },
        },
        ["fox"] = {
            default = {
                "A fox. Beautiful. Wary. Same as me.",
                "Fox. Pause. Bolt.",
            },
        },
        ["raccoon"] = {
            default = {
                "A raccoon. They're going to be fine.",
                "Trash pandas. Always trash pandas.",
            },
        },
        ["turkey"] = {
            default = {
                "Turkey. ...I miss Thanksgiving.",
                "Wild turkey. Smarter than the supermarket kind, they say.",
            },
        },
        ["goat"] = {
            default = {
                "Goats. They eat anything. Wish I could.",
            },
        },
        ["horse"] = {
            default = {
                "A horse. A whole horse. Transportation that doesn't need gas.",
            },
        },
        ["duck"] = {
            default = {
                "Duck. The pond is doing fine without us.",
            },
        },
        ["bird"] = {
            default = {
                "Bird singing like it's any other day.",
                "Birdsong. Still here. Reassuring.",
            },
        },
    },

    -- Weather changes
    weather = {
        ["rainStart"] = {
            default = {
                "Sky's opening up.",
                "Rain. Rolling in fast.",
                "Hope the roof holds.",
                "Petrichor. Beautiful and sad.",
            },
            Pluviophile = {
                "Yes.",
                "Best sound there is.",
                "There it is.",
            },
            Pluviophobe = {
                "No. Not now.",
                "Of course it rains today.",
            },
        },
        ["thunder"] = {
            default = {
                "Thunder. Close enough to feel.",
                "That was close.",
                "Sky's angry.",
                "Windows rattled with that one.",
            },
        },
        ["fog"] = {
            default = {
                "Fog. Can't see anything past the porch.",
                "Like the world shrank.",
                "Thick out there. Dangerous.",
            },
        },
        ["snow"] = {
            default = {
                "Snow. Already?",
                "First snow. Pretty for about ten minutes.",
                "Crunching under boots.",
            },
        },
        ["heatwave"] = {
            default = {
                "Heat is brutal today.",
                "Sun's a hammer.",
                "Can't catch a breath out here.",
            },
        },
        ["coldsnap"] = {
            default = {
                "Sudden cold. Joints know first.",
                "Bone-deep cold today.",
            },
        },
        ["wind"] = {
            default = {
                "Wind's picking up.",
                "Trees are bowing.",
            },
        },
    },

    -- World sound events
    sound = {
        ["gunshot_distant"] = {
            default = {
                "Gunshot. Far. Someone else is alive.",
                "That was a rifle. Hunter or fight?",
                "Echo in the trees. Single shot.",
                "Someone's shooting. Someone, not something.",
            },
            veteran = {
                "Hunting rifle. Bolt action. Maybe two miles.",
            },
            Hunter = {
                "Not a hunter's shot. Wrong rhythm.",
            },
        },
        ["gunshot_close"] = {
            default = {
                "That was close. Too close.",
                "Crack of a shot. Right here.",
                "Someone's in trouble nearby.",
            },
        },
        ["helicopter"] = {
            default = {
                "Helicopter. Where? Where?",
                "Rotor sound. Faint. Then gone.",
                "Helicopter overhead. Whose?",
            },
        },
        ["scream"] = {
            default = {
                "Scream. Or close enough.",
                "Someone out there.",
                "Don't run toward it. Don't run away. Just listen.",
            },
        },
        ["siren"] = {
            default = {
                "Siren. Still running? Or just the wind?",
                "Old siren, lonely siren.",
            },
        },
        ["explosion"] = {
            default = {
                "Boom. Felt it.",
                "Something just went up.",
            },
        },
        ["dog_bark"] = {
            default = {
                "A dog. A dog. A dog is alive.",
                "Barking. Distant. Friend or feral?",
            },
        },
        ["glass_break"] = {
            default = {
                "Glass shattering. Someone broke in.",
                "That was a window. Not mine, I hope.",
            },
        },
        ["horde_groan"] = {
            default = {
                "That sound. Not one. Many.",
                "The chorus. Time to move.",
            },
        },
    },

    -- Entering specific building/room types
    location = {
        ["abandonedHome"] = {
            default = {
                "Looks abandoned - finders keepers.",
                "Whoever lived here is gone. The fridge is mine.",
                "No one home. Hope they didn't leave the alarm on.",
                "Empty house. Quiet.",
                "Dust on the kitchen counter. Nobody's been here in days.",
                "She wipes her boots out of habit. There's nobody here to mind.",
                "Place is empty. She has time to be thorough.",
                "No footprints but hers in the dust by the door.",
            },
            TherapyAnimals = {
                "Empty house. No pet bowls. No fur on the couch. Nobody kept anything here.",
            },
        },
        ["hospital"] = {
            default = {
                "Hospital. Smell of disinfectant. Or maybe not.",
                "If I'm being honest, this is where the answers might be.",
            },
            doctor = {
                "I know these halls. Different now.",
            },
            nurse = {
                "Charts on the walls. I know them by heart.",
            },
        },
        ["school"] = {
            default = {
                "School. Empty desks.",
                "Coats still on the hooks.",
                "Lunches still in lockers.",
            },
        },
        ["library"] = {
            default = {
                "Library. Quiet. Always was.",
            },
            Illiterate = {
                "Books I can't read. Worse than no books.",
            },
        },
        -- Entity-gated: requires a bookshelf within sight.
        ["library_bookshelf"] = {
            default = {
                "Books. Lots of books. Suddenly priceless.",
            },
        },
        ["church"] = {
            default = {
                "Church. Doors unlocked.",
                "Stained glass still doing its thing.",
                "If anyone was watching, they're busy now.",
            },
        },
        ["gunstore"] = {
            default = {
                "Gun store. Wonder if there's anything left.",
                "Smell of oil and metal.",
            },
            policeofficer = {
                "I knew the owner.",
            },
        },
        ["police"] = {
            default = {
                "Police station. Of course.",
            },
            policeofficer = {
                "Home, I guess.",
            },
        },
        -- Entity-gated: requires a holding-cell tile (jail bars sprite).
        ["police_cells"] = {
            default = {
                "Cells empty. Or are they?",
            },
        },
        ["fireStation"] = {
            default = {
                "Fire station.",
            },
            fireofficer = {
                "My old shift sheet's still on the board.",
            },
        },
        -- Entity-gated: requires an actual fire truck in the bay.
        ["fireStation_truck"] = {
            default = {
                "Truck still in the bay.",
            },
        },
        ["warehouse"] = {
            default = {
                "Warehouse. Lot of nothing or lot of everything.",
            },
        },
        -- Entity-gated: requires pallets or crates nearby.
        ["warehouse_pallets"] = {
            default = {
                "Pallets and pallets.",
            },
        },
        ["garage"] = {
            default = {
                "Garage. Smell of oil.",
            },
            mechanics = {
                "I could fix half this stuff in my sleep.",
            },
        },
        -- Entity-gated: requires shelving / tool storage nearby.
        ["garage_toolwall"] = {
            default = {
                "Tools hanging on the wall.",
            },
        },
        ["kitchen"] = {
            default = {
                "Smells like cold grease.",
                "Cabinets half-open. Someone left in a hurry.",
                "Tile floor. Easier to clean. Was, anyway.",
            },
            chef = {
                "I recognize the knife brand.",
                "Wrong knife on the wrong board. Bothers me more than the zombies.",
            },
        },
        -- Entity-gated: requires a POWERED fridge on a powered tile. An
        -- empty for-sale house kitchen has no fridge - this line should
        -- not fire there.
        ["kitchen_fridge"] = {
            default = {
                "The fridge hums on, like it doesn't know.",
            },
        },
    },

    -- First-time zombie events
    firstZombie = {
        ["firstSighted"] = {
            default = {
                "Oh god. They're real.",
                "I've seen pictures. Different in person.",
                "It's... still wearing its uniform.",
                "Don't run. Don't run. Don't run.",
            },
            Brave = {
                "Okay. So this is what we're doing.",
            },
            Desensitized = {
                "Just a thing. Just a thing to deal with.",
            },
        },
        ["firstKill"] = {
            default = {
                "It went down. I did that.",
                "Don't think about it. Don't think about it.",
                "I killed something that used to be a person.",
                "First one. Won't be the last.",
            },
            Pacifist = {
                "I had no choice. I had no choice.",
            },
            veteran = {
                "Back to old habits, then.",
            },
        },
        ["firstHit"] = {
            default = {
                "It got me. Stop. Check. Stop. Check.",
                "Did the skin break? Did the skin break?",
                "Breathe. Look at the wound. Don't spiral.",
            },
            Hemophobic = {
                "Don't look at the blood. Don't look at the blood.",
            },
        },
        ["firstHorde"] = {
            default = {
                "There are dozens of them. Dozens.",
                "Where do you even start.",
                "Need to move. Now.",
            },
        },
    },

    -- Seasonal transitions
    season = {
        ["winterStart"] = {
            default = {
                "Winter's here. Layer up.",
                "First real cold day.",
                "Going to be a long one.",
            },
            Outdoorsman = {
                "I'm built for this season.",
            },
        },
        ["springStart"] = {
            default = {
                "Spring. Green starting.",
                "Buds. Smaller things first.",
                "Easier days, maybe.",
            },
            Gardener = {
                "Planting season. Lists in my head already.",
            },
        },
        ["summerStart"] = {
            default = {
                "Summer. Sweat starts.",
                "Long days. Useful, dangerous.",
            },
        },
        ["fallStart"] = {
            default = {
                "Leaves turning. Always early it feels like.",
                "Harvest soon.",
            },
            farmer = {
                "Time to bring it all in. Now I'm busy.",
            },
        },
    },

    -- Loneliness after a threshold of solitude
    alone = {
        default = {
            "When was the last time I heard another voice?",
            "I talk to the walls now.",
            "Hello, room. Hello, table. Hello, knife.",
            "I'd take an argument right now.",
            "Did I always sound like this in my head?",
        },
        Cowardly = {
            "I'm safer alone. I'm safer alone. I'm safer alone.",
        },
        Outdoorsman = {
            "I prefer this. ...Mostly.",
        },
    },

    -- Random ambient memories
    memory = {
        default = {
            "Smells like Sunday mornings used to.",
            "Reminds me of grandma's house.",
            "Used to be afraid of dogs. Funny what fear was.",
            "There was a guy at work who would have loved this knife.",
            "Last birthday cake. Strawberry. Awful frosting.",
            "Mom's voice. Saying my name.",
            "First job. First firing. Both stupid.",
            "Concerts. Sweaty crowds. I'd go back to even the worst one.",
            "The way coffee smelled the morning after.",
            "Snow days as a kid. Whole world quiet.",
            "Phone numbers I knew by heart. Gone.",
            "Used to skip leg day. Body remembers anyway.",
        },
    },

    -- First-time rare item discovery (keyed by Base.id)
    rareItem = {
        ["Base.Money"] = {
            default = {
                "Money. Funny. Just paper now.",
                "Cash. Heavier as a memory than as a thing.",
            },
        },
        ["Base.Phone"] = {
            default = {
                "A phone. Like finding a fossil.",
                "Wonder what's on it. Wonder if I want to know.",
            },
        },
        ["Base.PhotoFrame"] = {
            default = {
                "Someone's family on a wall I'll never see again.",
            },
        },
        ["Base.Suitcase"] = {
            default = {
                "Already packed. Where were they going?",
            },
        },
        ["Base.Pills"] = {
            default = {
                "Pills. Worth their weight in gold now.",
            },
        },
        ["Base.WeddingRing"] = {
            default = {
                "A ring. Whoever wore it isn't wearing it now.",
            },
        },
        ["Base.Newspaper"] = {
            default = {
                "Newspaper. Day-of. I shouldn't read it.",
                "Headline from the last morning of the world.",
            },
        },
        ["Base.Diary"] = {
            default = {
                "Someone wrote down their last days. I shouldn't read it. I will.",
            },
        },
        ["Base.GenericLetter"] = {
            default = {
                "A letter, sealed and never sent.",
            },
        },
        ["Base.Compass"] = {
            default = {
                "Compass. North still works.",
            },
        },
        ["Base.Whiskey"] = {
            default = {
                "Whiskey. Bad idea. Good idea. Bad idea.",
            },
        },
    },

    -- Trait-specific ambient flavor (random selection from owned traits)
    traitAmbient = {
        AdrenalineJunkie = {
            "I think I miss the panic. That's not normal, is it?",
            "Calm makes me itchy.",
            "When my heart's pounding I think clearest.",
            "Too quiet. I need a problem.",
            "Bring on the next one.",
        },
        Agoraphobic = {
            "Open spaces feel like teeth.",
            "Sky is too big today.",
            "Walls. I'd like four walls.",
            "Why does outside have to be so much of itself.",
        },
        AllThumbs = {
            "Dropped it. Course I did.",
            "If there's a wrong way to hold it, that's me.",
            "Why does anything have small buttons.",
        },
        Artisan = {
            "Could make this prettier with another hour.",
            "Hands itch for clay.",
            "I see what it could be, not what it is.",
        },
        Asthmatic = {
            "Wheeze. Wait. Wheeze.",
            "Should've kept an extra inhaler everywhere.",
            "Just walking is a workout.",
        },
        Athletic = {
            "Body still does what I tell it.",
            "I should be coaching someone right now.",
            "Move every day. Even if it's pointless.",
        },
        Axeman = {
            "Axe knows my hand.",
            "Wood splits cleaner when you stop fighting it.",
        },
        BaseballPlayer = {
            "Stance. Hands. Eye. Same as always.",
            "Bat is just an axe with no edge.",
        },
        Blacksmith = {
            "Metal speaks if you listen.",
            "Forge sound was the best sound.",
        },
        Brave = {
            "Fear's a knock at the door. I just don't answer.",
            "Scared people make scared decisions. Stay still.",
            "Heart steady. Mind clear.",
        },
        Brawler = {
            "Fists are always loaded.",
            "Old scars on the knuckles aren't going anywhere.",
        },
        burglar = {
            "Funny. All this practice and now nobody cares about locks.",
            "Doors are just suggestions.",
            "Used to break in. Now I move in.",
        },
        Claustrophobic = {
            "Walls too close.",
            "Need a window. Now.",
            "Doorway. Just stand in the doorway.",
        },
        Clumsy = {
            "Of course I knocked it over.",
            "If there's a chair in the room I'll find it with my knee.",
        },
        Conspicuous = {
            "Everything looks at me first. It feels like.",
            "Hard to fade into a corner.",
        },
        Cook = {
            "I can taste what this could be.",
            "Salt would fix half of what's wrong with everything.",
            "Apron in the bag. Just in case.",
        },
        Cowardly = {
            "Not today. Definitely not today.",
            "Safer over here.",
            "Better scared and alive than brave and gone.",
        },
        Crafty = {
            "Hands need something to make.",
            "Idle is dangerous. Make something.",
        },
        Deaf = {
            "I read the room with my eyes.",
            "I miss music more than I miss noise.",
        },
        Desensitized = {
            "Just a body. Just a body. Just a body.",
            "Used to flinch. Don't anymore.",
            "Bad sign or a useful one. Hard to tell.",
        },
        Dextrous = {
            "Hands know before I do.",
        },
        Disorganized = {
            "Where did I put it. Where did I put it.",
            "I had a system once.",
        },
        EagleEyed = {
            "Movement at the edge. Always.",
            "Scan, scan, scan.",
        },
        Emaciated = {
            "Bones too close to the skin.",
            "Hungry isn't the right word anymore.",
        },
        FastHealer = {
            "Bruise yesterday. Almost gone today.",
            "Body always was forgiving.",
        },
        FastLearner = {
            "Pick up things fast. Old habit.",
            "Show me twice. That's all I need.",
        },
        FastReader = {
            "Already done with this one. Need another.",
            "Words go by fast.",
        },
        Feeble = {
            "Why does everything weigh so much.",
        },
        FirstAid = {
            "Bandages first, then the rest.",
            "Triage in my head, constantly.",
        },
        Fishing = {
            "I miss morning by the water.",
            "Lure in my pocket. Always.",
        },
        Fit = {
            "Body is dependable. Mostly.",
        },
        Gardener = {
            "Hands itch for dirt.",
            "Already planning rows in my head.",
            "Compost. Compost is everything.",
        },
        Graceful = {
            "Quiet on my feet. Always was.",
        },
        Gymnast = {
            "Bodies remember.",
            "Could climb that. Used to anyway.",
        },
        Handy = {
            "Could fix this. Just need an hour and the right wrench.",
            "Half this house was held together by someone like me.",
        },
        HardOfHearing = {
            "What was that? Probably nothing.",
            "Should turn around more often.",
        },
        HeartyAppetite = {
            "I could eat. I could always eat.",
            "Smells make me dizzy.",
        },
        Hemophobic = {
            "Don't look down. Don't look down.",
            "Red. Red. Look away.",
        },
        Herbalist = {
            "That's plantain. That's comfrey. That's chamomile.",
            "Garden is everywhere if you look.",
        },
        Hiker = {
            "Boots happy.",
            "Mile after mile. That's the cure.",
        },
        HighThirst = {
            "Always thirsty. Always.",
        },
        Hunter = {
            "Wind in my face. Always.",
            "Tracking is mostly waiting.",
            "Bow stays strung. Rifle stays clean.",
        },
        Illiterate = {
            "Pictures are a language too.",
            "Words on signs. Useless to me.",
        },
        Inconspicuous = {
            "Easier to be a shadow than a person.",
        },
        Inventive = {
            "If I had wire and a screwdriver I could.",
        },
        IronGut = {
            "Eat anything. Always could.",
            "Stomach is a furnace.",
        },
        Insomniac = {
            "Sleep is a country I don't have a visa for.",
            "Ceiling at 3am. Old friend.",
        },
        Jogger = {
            "Pace. Pace. Pace.",
            "Movement is just better than not moving.",
        },
        KeenHearing = {
            "What was that.",
            "I hear it before I see it.",
        },
        LightEater = {
            "Small bites. Still full.",
        },
        LowThirst = {
            "Wonder when I last drank. Don't really need to know.",
        },
        Marksman = {
            "Trigger discipline first. Always.",
            "Front sight. Front sight. Front sight.",
        },
        Mason = {
            "Stone speaks. You just have to chip until it does.",
        },
        Mechanics = {
            "Engines tell you what's wrong if you listen.",
            "Wrench in the bag. Always.",
        },
        NeedsLessSleep = {
            "More daylight in my schedule than most people get.",
        },
        NeedsMoreSleep = {
            "Couldn't I just lie down for twenty minutes.",
        },
        NightOwl = {
            "Better at night. Always was.",
            "Stars are clearer now.",
        },
        NightVision = {
            "Eyes adjust fast. Useful.",
            "Dark is just dim, mostly.",
        },
        Nutritionist = {
            "Macros in my head.",
            "Calories matter. Especially now.",
        },
        Obese = {
            "Bigger than I should be. Bigger than I'd be by choice.",
            "Stairs. Always stairs.",
        },
        Organized = {
            "Everything in its place. Even if the place is a backpack.",
        },
        Outdoorsman = {
            "I sleep better with sky overhead.",
            "Tarp, tinder, knife. Three things.",
        },
        Pacifist = {
            "I do not want to hurt anything.",
            "There's always another option.",
        },
        ProneToIllness = {
            "Of course I get every bug.",
            "Wash hands. Wash hands. Wash hands.",
        },
        Resilient = {
            "Body bounces.",
            "I've been worse before.",
        },
        FormerScout = {
            "Be prepared. Always was the motto.",
            "Compass. Knife. Tinder. Always.",
        },
        ShortSighted = {
            "Glasses on the table. Always remember the glasses.",
        },
        SlowHealer = {
            "Old bruises. New bruises. They blend.",
        },
        SlowLearner = {
            "Going to take a few tries. Always does.",
        },
        SlowReader = {
            "Slow's fine. Read it twice. Catch more.",
        },
        Smoker = {
            "Pack still in the pocket. Routine.",
            "When this is gone I'm going to be a problem.",
        },
        SpeedDemon = {
            "Pedal to the floor. Best therapy.",
        },
        Stout = {
            "Built solid. Always was.",
        },
        Strong = {
            "Hauling is what I do.",
            "Heavy is just heavy. Lift anyway.",
        },
        SundayDriver = {
            "Take it easy. Always.",
            "Speed kills. Cars too.",
        },
        Tailor = {
            "Needle and thread. Could make this last forever.",
            "Patches stack like memories.",
        },
        ThickSkinned = {
            "Cuts and scrapes barely register.",
        },
        ThinSkinned = {
            "Every scrape is a story.",
        },
        Underweight = {
            "Lost weight I didn't have to lose.",
        },
        Unfit = {
            "Stairs are my enemy.",
            "Out of breath again.",
        },
        VeryUnderweight = {
            "Bones too close to the surface.",
        },
        Weak = {
            "Things weigh more than they should.",
        },
        WeakStomach = {
            "Don't think about it. Don't think about it.",
        },
        Whittler = {
            "Wood in my pocket. Knife in my hand.",
            "Pile of shavings is a kind of prayer.",
        },
        WildernessKnowledge = {
            "Forest tells you what it has, if you ask right.",
            "Edible. Edible. Don't eat that.",
        },
    },

    -- Profession-specific ambient flavor
    professionAmbient = {
        burglar = {
            "Locks I used to count as wins look like wallpaper now.",
            "I always knew the world was a series of doors.",
        },
        carpenter = {
            "I see studs in walls. I see joinery.",
            "Could rebuild this whole house from memory.",
        },
        chef = {
            "I know what this kitchen could put out, even now.",
            "Mise en place keeps me sane.",
        },
        constructionworker = {
            "Hard hat in my pack. Sentimental, mostly.",
            "Site work taught me patience for chaos.",
        },
        doctor = {
            "I should be helping people. But who's left?",
            "Triage in my head, constant.",
            "Old oath still applies. To me at least.",
        },
        engineer = {
            "Every system has a single point of failure.",
            "Could engineer my way out of this. If I had time.",
        },
        farmer = {
            "Need to check the seed stock.",
            "Soil first, then everything else.",
            "Old hands, old habits, useful again.",
        },
        fireofficer = {
            "I used to run toward the smoke.",
            "Hoses won't help with this.",
        },
        fisherman = {
            "Water's always honest.",
            "Patience. The kind only water teaches.",
        },
        lumberjack = {
            "Wood will be money this winter.",
            "Sound of an axe is still the right kind of work.",
        },
        mechanics = {
            "Every engine has a story.",
            "Could fix half the cars on this street. If they'd start.",
        },
        metalworker = {
            "Sparks. I miss sparks.",
        },
        nurse = {
            "Patients used to need me. They still do, sort of.",
            "Hands wash automatically.",
        },
        officeworker = {
            "Last thing I filed was a TPS report.",
            "Funny what I miss. Stapler clicking.",
        },
        parkranger = {
            "Forest still tells me everything.",
            "I know the trails. Even the unmarked ones.",
            "Bear spray's in the side pocket. Old habit.",
        },
        policeofficer = {
            "Old radio code still in my head.",
            "Used to know who'd be a problem in any room.",
        },
        burglar = {
            "Locks. Cameras. Habits. Same patterns.",
            "Anything not bolted down was a kind of generosity.",
        },
        securityguard = {
            "Routes. Times. Rounds. Old rhythm.",
        },
        unemployed = {
            "No paycheck to miss.",
            "Free agent. Always was.",
        },
        veteran = {
            "Some things don't unlearn.",
            "Old training. Still loaded.",
            "Sleep with one eye open. Habit.",
        },
        detective = {
            "Always was looking for the pattern.",
        },
        locksmith = {
            "Tumblers are tumblers.",
        },
    },

    -- ============================================================
    -- Filth (room cleanliness) -- triggered by KH_FilthMoodlet
    -- ============================================================
    filth = {
        becameFilthy = {
            default = {
                "This room is rough.",
                "I should clean up.",
                "Whoever lived here let it go.",
                "I can smell this place.",
            },
            NeatFreak = {
                "This is unacceptable. I need to clean.",
                "I can't even think in here.",
                "This is making my skin crawl.",
            },
            Slob = {
                "Eh. Lived-in.",
                "It's fine. Probably.",
            },
        },
        becameClean = {
            default = {
                "Cleaner. That's something.",
                "Better. Small win.",
                "At least the floor's clear.",
            },
            NeatFreak = {
                "There. Now I can breathe.",
                "Order restored. Good.",
                "Finally. A space I can inhabit.",
            },
            Slob = {
                "Looks too clean. Weird.",
            },
        },
        squalor = {
            default = {
                "I'm living in a dump.",
                "This is rock bottom.",
                "Someone help me clean this.",
            },
            NeatFreak = {
                "I want to scream.",
                "I can't anymore. I have to clean. Now.",
            },
        },
    },

    -- ============================================================
    -- Personal dirtiness -- triggered by KH_DirtMoodlet
    -- ============================================================
    dirtiness = {
        becameDirty = {
            default = {
                "I need a bath.",
                "I look at my hands and look away.",
                "I can smell myself.",
                "Grubby. Apocalypse grubby.",
            },
            NeatFreak = {
                "This is intolerable. I need to wash.",
                "I would kill for a hot shower.",
            },
            Slob = {
                "I'm fine. Mostly.",
            },
        },
        becameClean = {
            default = {
                "Clean. God, that's good.",
                "Forgot what soap felt like.",
                "I'm a person again.",
            },
            NeatFreak = {
                "Finally. Human again.",
                "I needed that more than food.",
            },
        },
        reeking = {
            default = {
                "Even I can smell me.",
                "The flies are following me.",
                "I cannot keep going like this.",
            },
        },
    },

    -- ============================================================
    -- Bath need -- triggered by KH_BathNeed
    -- ============================================================
    bath = {
        needsBath = {
            default = {
                "I should wash up sometime.",
                "Hot water sounds like a dream.",
            },
            Outdoorsy = {
                "Lake's right there.",
            },
        },
        desperateBath = {
            default = {
                "I have to wash. I cannot sleep like this.",
                "Whoever I run into will smell me first.",
            },
        },
        fresh = {
            default = {
                "Clean. Worth boiling the water for.",
                "Apocalypse spa day.",
            },
        },
        afterWash = {
            default = {
                "Better. Much better.",
                "Felt almost normal for a second.",
            },
        },
    },

    -- ============================================================
    -- Toilet need -- triggered by KH_ToiletNeed and KH_UseToiletAction
    -- ============================================================
    toilet = {
        urge = {
            default = {
                "I'll find a toilet soon.",
                "Coffee was a mistake.",
            },
        },
        urgent = {
            default = {
                "I really need to go.",
                "Where's the nearest bathroom? Anywhere.",
            },
            WeakBladder = {
                "This is happening NOW. Where can I go?",
            },
        },
        emergency = {
            default = {
                "I cannot hold this much longer.",
                "Any tile. Outdoors. Now.",
            },
        },
        relieved = {
            default = {
                "Better.",
                "Small dignity preserved.",
                "Crisis averted.",
            },
            Outdoorsy = {
                "Like a deer in the woods. No shame.",
            },
        },
        accident = {
            default = {
                "Couldn't make it. Pretend that didn't happen.",
                "This is rock bottom, isn't it.",
                "Bath. I need a bath. NOW.",
            },
            NeatFreak = {
                "I cannot. I cannot. I cannot.",
            },
        },
    },

    -- ============================================================
    -- Wake-from-sleep-in-filth (KH_FilthMoodlet wake hook)
    -- ============================================================
    filthSleep = {
        default = {
            "Slept in my own grime. Feel worse than tired.",
            "Woke up sticky. That's a new low.",
            "The sheets are doing nothing for me.",
        },
        NeatFreak = {
            "I would rather have stayed awake.",
        },
    },

    -- ============================================================
    -- Hygiene mini-actions (junk item uses)
    -- ============================================================
    hygiene = {
        brushedTeeth = {
            default = {
                "Fresh mouth. Small mercy.",
                "Tasted like toothpaste. Almost normal.",
                "Tiny act, but it's mine.",
            },
        },
        deodorant = {
            default = {
                "Not clean. But less notable.",
                "Aerosol diplomacy with my own armpits.",
            },
        },
        shaved = {
            default = {
                "Looking less like a feral animal.",
                "Razor still works. Civilization continues.",
            },
        },
    },

    -- ============================================================
    -- Boredom relief from board games / dice
    -- ============================================================
    game = {
        played = {
            default = {
                "Bishop takes pawn. Tomorrow takes me.",
                "Easier to think with my hands busy.",
                "The dice don't know about the dead. Lucky them.",
            },
        },
    },

    -- ----------------------------------------------------------------
    -- Pet interactions. Each action is its own key so per-(category,key)
    -- cooldown means actions don't block each other. Lines use {NAME}
    -- token as placeholder for the pet's name - the pet action handlers
    -- substitute before calling emit/emitForce.
    -- ----------------------------------------------------------------
    pet = {
        ["adopt"] = {
            default = {
                "Welcome home, {NAME}.",
                "{NAME} is mine now. Mine to look after.",
                "Hi, {NAME}. We're going to be okay.",
                "You're {NAME}. I've decided.",
            },
        },
        ["disown"] = {
            default = {
                "Go on, {NAME}. The world's yours again.",
                "I'm sorry, {NAME}. This isn't working.",
                "Be safe out there, {NAME}.",
                "{NAME} deserves more than what I can give right now.",
            },
        },
        ["release"] = {
            default = {
                "There. Down you go.",
                "Off you go, then.",
                "Stay close, {NAME}.",
            },
        },
        ["pet"] = {
            default = {
                "Good {NAME}. Such a good one.",
                "Hey there. There you are.",
                "You're alright, you know that?",
                "I needed that as much as you did.",
            },
        },
        ["come"] = {
            default = {
                "{NAME}, come here.",
                "Over here, {NAME}.",
                "Come on, then.",
            },
        },
        ["feed"] = {
            default = {
                "There you go, {NAME}.",
                "Eat up.",
                "I saved this for you.",
            },
        },
        ["water"] = {
            default = {
                "Drink, {NAME}.",
                "There. Cool water.",
                "Thirsty work, the apocalypse.",
            },
        },
        ["brush"] = {
            default = {
                "Pretty {NAME}.",
                "Look at you.",
                "Hold still, you.",
            },
        },
        ["chewToy"] = {
            default = {
                "Here. Something to chew on.",
                "Don't lose this one.",
                "Mind your teeth.",
            },
        },
        ["fetch"] = {
            default = {
                "Go get it, {NAME}!",
                "Fetch!",
                "After it!",
            },
        },
        ["pickup"] = {
            default = {
                "Up you come, {NAME}.",
                "Easy now.",
                "I've got you.",
            },
        },
        ["stay"] = {
            default = {
                "Stay here, {NAME}. I'll be back.",
                "Wait for me.",
                "Don't wander off.",
            },
        },
        ["free"] = {
            default = {
                "Alright, {NAME}, you're free.",
                "Go on, then.",
                "Stretch your legs.",
            },
        },
        ["follow"] = {
            default = {
                "Come with me, {NAME}.",
                "Stick close.",
                "On me, {NAME}.",
            },
        },
        ["unfollow"] = {
            default = {
                "Hang back, {NAME}.",
                "Easy, {NAME}. Not this time.",
                "Wait here a bit.",
            },
        },
        ["bindHome"] = {
            default = {
                "This is your home now, {NAME}.",
                "Make yourself comfortable.",
                "Yours. All yours.",
            },
        },
        ["freeHome"] = {
            default = {
                "You're not tied here anymore.",
                "Wherever you want, {NAME}.",
            },
        },
        ["sendHome"] = {
            default = {
                "Go home, {NAME}.",
                "Head back. I'll catch up.",
                "Safer there than here.",
            },
        },
        ["alreadyHave"] = {
            default = {
                "I've already got one mouth to feed.",
                "Maybe later. {NAME} needs me first.",
                "One at a time.",
            },
        },
    },


    -- ----------------------------------------------------------------
    -- Lane 3: ADHD-friendly need reminders. Fire on UPWARD threshold
    -- crossings of vanilla stats (hunger, thirst, fatigue) and KH-aware
    -- boredom. Per-(category,key) cooldown means each tier line fires at
    -- most once per 30 min - so even if the player oscillates near a
    -- threshold, it won't spam.
    --
    -- Trait variants where the inner voice would notably differ.
    -- ----------------------------------------------------------------
    needs = {
        ["hungry"] = {
            default = {
                "Stomach's reminding me it exists.",
                "I should eat soon.",
                "Getting peckish.",
                "When did I last eat? Hours ago.",
            },
            ForageFeast = {
                "Stomach's nagging. The world's a pantry if I know where to look.",
                "Time to forage something up.",
                "Could go for something fresh from the woods.",
            },
            Cook = {
                "I could put together something good if I have the ingredients.",
                "Time to actually cook, not just eat.",
            },
        },
        ["veryHungry"] = {
            default = {
                "I'm hungry. Really hungry.",
                "Eat something. Now.",
                "Hard to think past the hunger.",
                "Everything's starting to look like food.",
            },
            ForageFeast = {
                "Even the dandelions are looking tempting.",
                "I need to get into a yard with something growing.",
            },
        },
        ["starving"] = {
            default = {
                "I can't put this off anymore. Food. Anything.",
                "My hands are shaking. Eat or pass out.",
                "Starving. The kind that makes you do dumb things.",
            },
        },
        ["thirsty"] = {
            default = {
                "Mouth's dry. Water.",
                "I should drink something.",
                "Thirsty. Felt it sneak up.",
            },
        },
        ["veryThirsty"] = {
            default = {
                "Really thirsty now.",
                "Water. Soon.",
                "Can't ignore this much longer.",
            },
        },
        ["parched"] = {
            default = {
                "Lips are cracking. I need water.",
                "Dehydrated. Find a source or drain a can.",
                "This is past 'thirsty.' This is dangerous.",
            },
        },
        ["tired"] = {
            default = {
                "Getting tired.",
                "I could use a sit-down.",
                "Yawn coming on.",
            },
            Outdoorsman = {
                "Tired, but the body knows what to do.",
                "Could rest soon. Not urgent.",
            },
            Veteran = {
                "Tired. Push through.",
                "I've been more tired than this on worse days.",
            },
        },
        ["exhausted"] = {
            default = {
                "I'm beat. Need to sleep before long.",
                "Eyes feel like sandpaper.",
                "Running on fumes.",
            },
        },
        ["dropping"] = {
            default = {
                "I'm going to fall asleep on my feet.",
                "If I don't lie down soon, I'm going to anyway.",
                "Can't keep my eyes open.",
            },
        },
        ["bored"] = {
            default = {
                "Mind's wandering. Need something to do.",
                "I should find something to occupy myself.",
                "This part of the apocalypse is the boring part.",
            },
            ComicBookFan = {
                "I'd kill for a new issue right about now.",
                "Wonder if any of the comic shops are still standing.",
            },
            ComicNerd = {
                "I'd kill for a new issue right about now.",
                "Wonder if any of the comic shops are still standing.",
                "Even a back-issue bin would feel like Christmas.",
            },
        },
        ["veryBored"] = {
            default = {
                "I'm crawling out of my skin.",
                "I need to do something. Anything.",
                "Bored stupid. Apocalypse can be tedious.",
            },
        },
    },
}

return KH.ThoughtLines
