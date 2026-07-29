import asyncio

from dbus_fast.aio import MessageBus


async def main():
    bus = await MessageBus().connect()
    introspection = await bus.introspect(
        "org.gnome.Mutter.DisplayConfig",
        "/org/gnome/Mutter/DisplayConfig")
    proxy = bus.get_proxy_object(
        "org.gnome.Mutter.DisplayConfig",
        "/org/gnome/Mutter/DisplayConfig",
        introspection)
    iface = proxy.get_interface("org.gnome.Mutter.DisplayConfig")

    serial, monitors, logical_monitors, _ = await iface.call_get_current_state()

    new_logical_monitors = []
    for x, y, scale, transform, primary, mons, _lm_props in logical_monitors:
        mon_list = []
        for connector, _vendor, _product, _serial in mons:
            mode_id = None
            for minfo, modes, _mprops in monitors:
                if minfo[0] == connector:
                    for mode in modes:
                        if "is-current" in mode[6]:
                            mode_id = mode[0]
            mon_list.append([connector, mode_id, {}])
        new_logical_monitors.append([x, y, scale, transform, primary, mon_list])

    await iface.call_apply_monitors_config(serial, 1, new_logical_monitors, {})
    bus.disconnect()

asyncio.run(main())
