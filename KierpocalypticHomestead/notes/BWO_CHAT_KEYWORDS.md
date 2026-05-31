# BWO Chat Keywords - Notebook Reference

**Source:** BWO's `BWOChat.lua` (758 entries). This is a curated list grouped by purpose. The full table has many minor variants (alternate phrasings of the same intent); this captures the canonical keyword for each unique response or action.

**How it works:** BWO matches words from your typed message against keyword arrays (order matters somewhat - the first matching pattern wins). Keywords are case-insensitive. You don't have to type the exact phrase, just the keywords in the right adjacency. So "stay here" works, but so does "hey, can you stay here for a sec" because both contain "stay" and "here."

**Actions** flagged with caps (JOIN, GUARD, BASE, LEAVE, RELAX, etc.) actually change the bandit's behavior, not just give a verbal response.

---

## Commands that change behavior

These directly affect the NPC's program. KH adds right-click equivalents for the JOIN / GUARD / LEAVE versions, but typed chat works too.

### Recruit / Join you (action: JOIN)
- come with me / come here / let's go
- follow me / follow my lead / follow my path
- join my group / join my team
- stick with me / stick by me
- team up with me / team up together
- accompany me / accompany my journey
- walk with me / walk beside me
- tag along / tag along with me
- stay with me / be with me
- be my companion

### Stay / Guard a spot (action: GUARD)
- stay here / stay put
- wait here
- guard the / guard this / guard that
- stop here
- stop following me / don't follow me

### Go home (action: BASE)
- go home / return home / head home

### Dismiss (action: LEAVE)
- leave me / go away

### Forgive / de-aggro (action: RELAX)
After you've offended someone or activated a witness reaction, these reset the encounter:
- sorry / my apologies
- excuse me / pardon me
- forgive me

### Surrender to bandits (anim: Surrender)
If a bandit demands your stuff, these acknowledge:
- hands up / freeze / don't move
- robbery / stickup / this is a stickup
- give me everything / hold up

---

## Information they can tell you

### About them
- what your name / who are you → name
- how are you / how you feel / are you ok → mood (PainHead anim)
- are you infected → "No, I don't think so, are you?"
- where you from → city
- what your story / what your plan / what your goal → flavor

### About the world
- what time / what hour / got the time → time
- what year is it → "It's 1993. That's a strange question."
- what season → season
- what temperature → degrees
- is raining / is snowing / is weather → rain/snow status
- what's holding / what weapon → their weapons

### About money / shops / survival
- how earn / how make money → "Picking up trash / doing your job"
- how buy / how pay → "Take items from shelves, payment is automatic Bluetooth bullshit"
- how nuclear / how nuke → "Hazmat suit, hide underground"
- how survive → "Make it day to day"
- how prepare apocalypse → "Collect items, hide, pray"
- where i get money → "Various tasks or picking up garbage"

### About events they've seen
- seen zombie / saw zombie / you zombies → denial ("are you out of your mind?")
- seen party / heard a party → confirms hearing parties
- seen army / seen soldiers → confirms seeing them
- streets blocked / road blocked → confirms roadblocks
- what happened / what going on → "Everything's crazy!"

### About your home (if they're inside it)
- can I come in / let me in / may I enter → intrusion status

---

## Social / mood

### Greetings
- hey / yo / hello / hi / howdy / sup / heyo / hiya
- good morning / good day / evening / hola / bonjour / ciao
- general kenobi (says "Hello there.")

### Farewells / goodbyes
- goodbye / bye / see you / take care
- stay safe ("You too, stay safe!")
- catch you later / i going out
- have a good one / good night

### Gratitude
- thanks / thank you / appreciate / grateful

### Compliments
- you're amazing / cool / fantastic / wonderful
- you rock / you're the best
- you make my day / you brighten my day
- you pretty / you beautiful

### Affection
- i love you / i like you / you're my friend

### Reject offer / propose social activity
- dinner with me / lunch with me → JOIN
- buy drink / have a drink / take coffee / buy coffee → JOIN

---

## Fun / entertainment

### Make them dance (anim: Dance)
- dance / show me your moves / bust a move / boogie

### Make them clap (anim: Clap)
- clap hands / applaud / bravo / can you clap

---

## Things to AVOID saying

These get bad reactions, sometimes hostile. Listed so you know they exist.

### Offensive personal questions
- have boyfriend / wife / husband → "None of your business" (No anim)
- you homo / you gay / you lesbian → angry refusal
- where do you live → "I prefer to keep that to myself"
- you have children → "That's private"

### Sexual advances
- sex / take bed / go bed / sleep me → cold rejection (No anim)

### Insults
- you ugly / you dumb / you stupid / shut up / be quiet → confrontational responses

### Demands
- help me → "You're on your own" (Shrug)
- give me / can i have / i need → "Sorry, I can't"
- open door / open window → "No!"

---

## Favorite-X questions (filler / personality flavor)

These don't change behavior, just give canned answers. Hundreds of them. Pattern: "what's your favorite X" where X is one of:

color, music, game, food, country, animal, song, band, movie, sport, drink, book, season, hobby, fruit, vegetable, ice cream, holiday, show, actor, actress, superhero, villain, subject, quote, dessert, place to visit, instrument, board game, outdoor activity, car, flower, pizza topping, vacation, restaurant, time of day, weather, type of movie, type of music, book genre, channel, radio, team, character, transport, smell, sound, weapon

Use these for relationship-building moments or just to see what kind of person this NPC is. NPCs do have inflexion ("Polish pierogi," "Pink Floyd's High Hopes," "Chess") which suggests they have a personality but it's the same flavor across all NPCs.

---

## Belief questions

Same pattern as favorites - "do you believe in X" where X is god, love, aliens, zombies, magic, ghosts, supernatural, fate, karma, reincarnation, destiny, miracles, soulmates, luck, afterlife, heaven, hell, angels, demons, fairies, psychics, astrology, tarot, Bigfoot, Loch Ness Monster.

---

## Quick-reference cheat card

If you just need to remember the most useful:

| You want | Say |
|---|---|
| Them to follow you | "follow me" or "come with me" |
| Them to stop and stay | "stay here" or "wait here" |
| Them to guard a thing | "guard this" |
| Them to go to base | "go home" |
| Dismiss them | "leave me" |
| Apologize for offense | "sorry" |
| Surrender to them | "hands up" |
| Ask about the world | "what's happened" |
| Get the time | "what time" |
| Get the weather | "is raining" |
| Get their name | "what your name" |
| Get their mood | "how are you" |

---

## How KH integrates

The `<Name> (KH)` right-click submenu I added gives you the same control via mouse for the Stay/Follow/Guard/Come With/Stand Down commands. Useful when typing is awkward (in a vehicle, in the middle of combat, etc.). The typed chat still works for everything else.
