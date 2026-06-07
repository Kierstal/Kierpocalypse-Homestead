-- Kierpocalyptic Homestead - Resident Name Generator v0.0.1
--
-- Generates randomised forename + surname for placed residents.
-- Name pools are drawn directly from vanilla SurvivorFactory (MainCreationMethods.lua)
-- so residents feel like they belong in the same world as other survivors.
--
-- Usage:
--   local name = KH.NameGen.random("f")  --> "Sandra Moore"
--   local name = KH.NameGen.random("m")  --> "Walter Harris"
--   local name = KH.NameGen.random()     --> random sex

KH = KH or {}
KH.modules = KH.modules or {}
KH.modules.NameGen = "0.0.1"
KH.NameGen = KH.NameGen or {}

-- ---- name pools (subset of vanilla SurvivorFactory lists) ----

local FEMALE = {
    "Marina",  "Patricia", "Mary",      "Linda",     "Barbara",  "Elizabeth",
    "Jennifer","Maria",    "Susan",     "Margaret",  "Dorothy",  "Lisa",
    "Nancy",   "Karen",    "Betty",     "Helen",     "Sandra",   "Donna",
    "Carol",   "Ruth",     "Sharon",    "Michelle",  "Laura",    "Sarah",
    "Kimberly","Deborah",  "Jessica",   "Angela",    "Melissa",  "Brenda",
    "Amy",     "Anna",     "Rebecca",   "Virginia",  "Kathleen", "Pamela",
    "Martha",  "Debra",    "Amanda",    "Stephanie", "Carolyn",  "Christine",
    "Marie",   "Janet",    "Catherine", "Frances",   "Ann",      "Joyce",
    "Diane",   "Alice",    "Julie",     "Heather",   "Teresa",   "Gloria",
    "Evelyn",  "Jean",     "Cheryl",    "Katherine", "Joan",     "Ashley",
    "Judith",  "Rose",     "Janice",    "Kelly",     "Nicole",   "Judy",
    "Theresa", "Beverly",  "Denise",    "Tammy",     "Irene",    "Jane",
    "Lori",    "Rachel",   "Marilyn",   "Andrea",    "Louise",   "Sara",
    "Anne",    "Wanda",    "Bonnie",    "Julia",     "Ruby",     "Tina",
}

local MALE = {
    "James",   "John",     "Robert",    "Michael",   "William",  "David",
    "Richard", "Charles",  "Joseph",    "Thomas",    "Daniel",   "Paul",
    "Mark",    "Donald",   "George",    "Kenneth",   "Steven",   "Edward",
    "Brian",   "Ronald",   "Anthony",   "Kevin",     "Jason",    "Matthew",
    "Gary",    "Timothy",  "Larry",     "Jeffrey",   "Frank",    "Scott",
    "Eric",    "Andrew",   "Raymond",   "Gregory",   "Joshua",   "Jerry",
    "Dennis",  "Walter",   "Patrick",   "Peter",     "Harold",   "Douglas",
    "Henry",   "Carl",     "Arthur",    "Ryan",      "Roger",    "Albert",
    "Jonathan","Justin",   "Terry",     "Gerald",    "Keith",    "Samuel",
    "Willie",  "Ralph",    "Nicholas",  "Roy",       "Benjamin", "Bruce",
    "Brandon", "Adam",     "Harry",     "Fred",      "Wayne",    "Billy",
    "Steve",   "Louis",    "Jeremy",    "Aaron",     "Randy",    "Howard",
    "Eugene",  "Carlos",   "Russell",   "Victor",    "Martin",   "Ernest",
    "Todd",    "Jesse",    "Craig",     "Alan",
}

local SURNAMES = {
    "Simpson",    "Porter",    "Smith",      "Johnson",   "Williams",  "Jones",
    "Brown",      "Davis",     "Miller",     "Wilson",    "Moore",     "Taylor",
    "Anderson",   "Thomas",    "Jackson",    "White",     "Harris",    "Martin",
    "Thompson",   "Garcia",    "Martinez",   "Robinson",  "Clark",     "Lewis",
    "Lee",        "Walker",    "Hall",       "Allen",     "Young",     "King",
    "Wright",     "Hill",      "Scott",      "Green",     "Adams",     "Baker",
    "Gonzalez",   "Nelson",    "Carter",     "Mitchell",  "Perez",     "Roberts",
    "Turner",     "Phillips",  "Campbell",   "Parker",    "Evans",     "Edwards",
    "Collins",    "Stewart",   "Morris",     "Rogers",    "Reed",      "Cook",
    "Morgan",     "Bell",      "Murphy",     "Bailey",    "Rivera",    "Cooper",
    "Richardson", "Cox",       "Howard",     "Ward",      "Torres",    "Peterson",
    "Gray",       "Ramirez",   "James",      "Watson",    "Brooks",    "Kelly",
    "Sanders",    "Price",     "Bennett",    "Wood",      "Barnes",    "Ross",
    "Henderson",  "Coleman",   "Jenkins",    "Perry",     "Powell",    "Long",
    "Patterson",  "Hughes",    "Flores",     "Washington","Butler",    "Simmons",
}

-- ---- public API ----

-- Returns a full name string: "Forename Surname".
-- sex: "f" for female, "m" for male, nil/other for random.
function KH.NameGen.random(sex)
    if sex ~= "f" and sex ~= "m" then
        sex = (ZombRand(2) == 0) and "f" or "m"
    end
    local forePool = (sex == "f") and FEMALE or MALE
    local forename = forePool[ZombRand(#forePool) + 1]
    local surname  = SURNAMES[ZombRand(#SURNAMES) + 1]
    return forename .. " " .. surname
end

-- Returns forename only (useful for compact labels).
function KH.NameGen.randomForename(sex)
    if sex ~= "f" and sex ~= "m" then
        sex = (ZombRand(2) == 0) and "f" or "m"
    end
    local forePool = (sex == "f") and FEMALE or MALE
    return forePool[ZombRand(#forePool) + 1]
end

print("[KH] NameGen v0.0.1 loaded.")
