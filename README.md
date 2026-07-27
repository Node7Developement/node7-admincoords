[README.md](https://github.com/user-attachments/files/30433560/README.md)
# node7-admincoords


<img width="899" height="930" alt="admincoords" src="https://github.com/user-attachments/assets/07e9073e-11f3-43e6-b38b-ae206938d0be" />


ACE-protected RedM coordinate utility for NODE7 Development Studios.

## Command

`/admin` opens the coordinate utility through `node7-menu-base`.

## Features

- Copy vector2, vector3 and vector4 values.
- Copy heading, rotation, forward vector and velocity.
- Copy raw coordinate values, Lua tables and JSON.
- Copy gameplay camera coordinates and direction.
- Aim at a ped, wagon, vehicle or object and copy its entity data.
- Configurable decimal precision.
- Optional live coordinate display.
- Clipboard output with F8 console backup.
- Server-side ACE validation.

## Requirements

- `node7-core`
- `node7-menu-base` v2.1.0 or newer

The menu is opened with the stable direct export:

```lua
exports['node7-menu-base']:OpenCallbackMenu(
    'default',
    GetCurrentResourceName(),
    'main',
    data,
    submit,
    cancel,
    change
)
```

The resource does not retrieve, cache or return a `GetMenuData()` callback table.

## Installation

```cfg
ensure node7-core
ensure node7-menu-base
exec @node7-admincoords/permissions.cfg
ensure node7-admincoords
```

## Permission

```cfg
add_ace group.node7_admin node7.admincoords.use allow
add_ace group.node7_owner node7.admincoords.use allow
```

All copied values are also printed to F8.
