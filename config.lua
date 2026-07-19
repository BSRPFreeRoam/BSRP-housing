Config = {}

Config.InteractKey = 38 -- E
Config.InteractDistance = 1.6
Config.MarkerDistance = 25.0
Config.DrawMarker = true
Config.BlipForSale = true
Config.BlipOwned = true

Config.Marker = {
    type = 20,
    scale = vector3(0.35, 0.35, 0.35),
    color = { r = 0, g = 229, b = 255, a = 160 },
}

-- For-sale blips
Config.Blip = {
    sale = { sprite = 40, color = 2, scale = 0.55, label = 'House for sale' },
    owned = { sprite = 40, color = 3, scale = 0.55, label = 'Your house' },
}

-- Interior shells by tier (native freemode apartments — no stream required)
-- exit = where player stands inside | door = exit trigger inside
Config.Interiors = {
    [1] = {
        label = 'Low Apartment',
        exit = vector4(266.20, -1007.45, -101.01, 0.0),
        door = vector4(266.20, -1007.45, -101.01, 0.0),
        stash = vector3(265.90, -999.40, -99.01),
        wardrobe = vector3(259.80, -1004.10, -99.01),
    },
    [2] = {
        label = 'Mid Apartment',
        exit = vector4(346.55, -1012.85, -99.20, 0.0),
        door = vector4(346.55, -1012.85, -99.20, 0.0),
        stash = vector3(351.30, -998.80, -99.20),
        wardrobe = vector3(350.70, -993.50, -99.20),
    },
    [3] = {
        label = 'Standard Home',
        exit = vector4(346.55, -1012.85, -99.20, 0.0),
        door = vector4(346.55, -1012.85, -99.20, 0.0),
        stash = vector3(351.30, -998.80, -99.20),
        wardrobe = vector3(350.70, -993.50, -99.20),
    },
    [4] = {
        label = 'Large Home',
        exit = vector4(-31.45, -594.95, 80.03, 250.0),
        door = vector4(-31.45, -594.95, 80.03, 250.0),
        stash = vector3(-28.20, -587.70, 80.03),
        wardrobe = vector3(-38.10, -589.50, 78.83),
    },
    [5] = {
        label = 'Luxury Home',
        exit = vector4(-31.45, -594.95, 80.03, 250.0),
        door = vector4(-31.45, -594.95, 80.03, 250.0),
        stash = vector3(-28.20, -587.70, 80.03),
        wardrobe = vector3(-38.10, -589.50, 78.83),
    },
    [6] = {
        label = 'Mansion',
        exit = vector4(-174.28, 497.69, 137.65, 190.0),
        door = vector4(-174.28, 497.69, 137.65, 190.0),
        stash = vector3(-170.20, 487.50, 137.45),
        wardrobe = vector3(-167.40, 487.80, 133.85),
    },
}

-- Default fallback if tier missing
Config.DefaultTier = 3

-- ox_inventory stash slots/weight by tier
Config.Stash = {
    [1] = { slots = 30, weight = 50000 },
    [2] = { slots = 40, weight = 75000 },
    [3] = { slots = 50, weight = 100000 },
    [4] = { slots = 60, weight = 125000 },
    [5] = { slots = 70, weight = 150000 },
    [6] = { slots = 80, weight = 200000 },
}

Config.SellBackPercent = 0.5 -- sell house back for 50% of price
Config.MaxOwnedHouses = 3
