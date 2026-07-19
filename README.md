# 🏠 BSRP Housing

A modern property and housing system built exclusively for the **BSRP Framework**.

BSRP Housing provides property ownership, key management, storage integration, garage support, and seamless compatibility with the BSRP ecosystem.

---

## Features

* 🏡 Purchase and own properties
* 🔑 House key management
* 👥 Shared property access
* 📦 ox_inventory stash integration
* 🚗 Garage support
* 💰 Property buying and selling
* 🛠️ Admin property management tools
* 🎯 ox_target interactions
* 📍 Property blips and markers
* ⚡ Fully optimized for the BSRP Framework

---

## Framework Requirements

This resource requires:

* BSRP Framework
* oxmysql
* ox_lib
* ox_target
* ox_inventory

---

## Installation

### 1. Place Resource

Add the resource to your server:

```text
resources/
└── bsrp-housing/
```

### 2. Ensure Dependencies

```cfg
ensure oxmysql
ensure ox_lib
ensure ox_target
ensure ox_inventory
ensure bsrp

ensure bsrp-housing
```

> BSRP Housing must start after the `bsrp` core resource.

---

## Database

Import the included SQL file if provided:

```sql
sql/bsrp-housing.sql
```

If automatic database creation is enabled, tables will be generated on first startup.

---

## Configuration

Configuration options are located in:

```text
config.lua
```

Common settings include:

* House prices
* Storage capacities
* Garage settings
* Property locations
* Realtor permissions
* Admin options

---

## Property Ownership

Players can:

* Purchase available properties
* Enter and exit owned homes
* Access personal storage
* Manage house keys
* Share access with friends
* Sell owned properties

---

## Integration Example

### Check House Ownership

```lua
local ownsHouse = exports['bsrp-housing']:HasHouse(source)
```

### Get Player Property

```lua
local property = exports['bsrp-housing']:GetPlayerHouse(source)
```

### Give House

```lua
exports['bsrp-housing']:AssignHouse(source, propertyId)
```

### Remove House

```lua
exports['bsrp-housing']:RemoveHouse(source)
```

---

## Admin Features

Administrators can:

* Create properties
* Delete properties
* Transfer ownership
* Reset house keys
* Teleport to properties
* Manage house storage

---

## Permissions

Example permission check:

```lua
if exports.bsrp:IsAdmin(source, 2) then
    -- Allow housing administration
end
```

---

## Compatibility

Built specifically for:

| Resource       | Supported |
| -------------- | --------- |
| BSRP Framework | ✅         |
| ox_inventory   | ✅         |
| ox_target      | ✅         |
| ox_lib         | ✅         |
| oxmysql        | ✅         |

---

## Development

When creating integrations:

```lua
local player = exports.bsrp:GetPlayer(source)

if not player then
    return
end
```



