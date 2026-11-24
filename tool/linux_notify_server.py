#!/usr/bin/env python3
"""Minimal org.freedesktop.Notifications server used by the Linux integration
test.

The Linux build of Soty talks to whatever notification server the session has,
through org.freedesktop.Notifications on the session bus. A test that only
mocks the Dart side proves nothing about the wire, so this owns the real bus
name and records every call as JSON, which the Dart test then asserts on.

    dbus-run-session -- python3 tool/linux_notify_server.py --log /tmp/n.jsonl
"""

import argparse
import json

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

BUS_NAME = "org.freedesktop.Notifications"
OBJECT_PATH = "/org/freedesktop/Notifications"

NODE = Gio.DBusNodeInfo.new_for_xml(
    """
<node>
  <interface name="org.freedesktop.Notifications">
    <method name="Notify">
      <arg type="s" name="app_name" direction="in"/>
      <arg type="u" name="replaces_id" direction="in"/>
      <arg type="s" name="app_icon" direction="in"/>
      <arg type="s" name="summary" direction="in"/>
      <arg type="s" name="body" direction="in"/>
      <arg type="as" name="actions" direction="in"/>
      <arg type="a{sv}" name="hints" direction="in"/>
      <arg type="i" name="expire_timeout" direction="in"/>
      <arg type="u" name="id" direction="out"/>
    </method>
    <method name="CloseNotification">
      <arg type="u" name="id" direction="in"/>
    </method>
    <method name="GetCapabilities">
      <arg type="as" name="capabilities" direction="out"/>
    </method>
    <method name="GetServerInformation">
      <arg type="s" name="name" direction="out"/>
      <arg type="s" name="vendor" direction="out"/>
      <arg type="s" name="version" direction="out"/>
      <arg type="s" name="spec_version" direction="out"/>
    </method>
  </interface>
</node>
"""
)

CAPABILITIES = ["body", "sound", "actions", "persistence"]


def record(log, entry):
    with open(log, "a", encoding="utf-8") as handle:
        handle.write(json.dumps(entry) + "\n")
        handle.flush()


def notify(log, state, args):
    app_name, replaces_id, icon, summary, body, actions, hints, timeout = args
    system_id = state["next_id"]
    state["next_id"] += 1
    record(
        log,
        {
            "method": "Notify",
            "app_name": app_name,
            "replaces_id": replaces_id,
            "icon": icon,
            "summary": summary,
            "body": body,
            "actions": list(actions),
            "hints": {key: _plain(value) for key, value in hints.items()},
            "timeout": timeout,
            "id": system_id,
        },
    )
    return "(u)", (system_id,)


def _plain(value):
    """Unwraps a GVariant into something json can hold."""
    try:
        unpacked = value.unpack()
    except AttributeError:
        return value
    if isinstance(unpacked, bytes):
        return unpacked.hex()
    return unpacked


def close_notification(log, _state, args):
    record(log, {"method": "CloseNotification", "id": args[0]})
    return None, None


def get_capabilities(log, _state, _args):
    record(log, {"method": "GetCapabilities"})
    return "(as)", (CAPABILITIES,)


def get_server_information(log, _state, _args):
    record(log, {"method": "GetServerInformation"})
    return "(ssss)", ("soty-test", "dtm", "1.0", "1.2")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--log", required=True)
    args = parser.parse_args()
    open(args.log, "w", encoding="utf-8").close()
    loop = GLib.MainLoop()
    state = {"next_id": 1000}

    def on_bus_acquired(connection, _name):
        def on_call(_conn, _sender, _path, _iface, method, params, invocation):
            method_name = method
            method_args = params.unpack()
            handlers = {
                "Notify": notify,
                "CloseNotification": close_notification,
                "GetCapabilities": get_capabilities,
                "GetServerInformation": get_server_information,
            }
            handler = handlers.get(method_name)
            if handler is None:
                invocation.return_dbus_error(
                    "org.freedesktop.DBus.Error.UnknownMethod", method_name
                )
                return
            signature, values = handler(args.log, state, method_args)
            if signature is None:
                invocation.return_value(None)
            else:
                invocation.return_value(GLib.Variant(signature, values))

        connection.register_object(
            OBJECT_PATH, NODE.interfaces[0], on_call, None, None
        )

    def on_name_acquired(_connection, _name):
        print("ready", flush=True)
        loop.run()

    def on_name_lost(_connection, _name):
        # A real desktop session already has a notification daemon on the bus;
        # the caller is expected to treat this as "cannot test here".
        print("busy", flush=True)
        loop.quit()

    Gio.bus_own_name(
        Gio.BusType.SESSION,
        BUS_NAME,
        Gio.BusNameOwnerFlags.REPLACE,
        on_bus_acquired,
        on_name_acquired,
        on_name_lost,
    )
    loop.run()


if __name__ == "__main__":
    main()
