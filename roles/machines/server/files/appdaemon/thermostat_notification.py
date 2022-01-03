# -*- coding: utf-8 -*-

from typing import List, TypedDict

import hassapi as hass

msg_help = """
🌡️ Control the thermostat

*/climate status* - Show the current status
*/climate [temp]* - Set the temperature
*/climate heat* - Set the thermostat to heat
*/climate off* - Turn the thermostat off
"""


class TelegramMessage(TypedDict):
    user_id: str
    from_first: str
    from_last: str
    chat_id: str
    command: str
    args: List[str]


class ThermostatNotification(hass.Hass):
    def initialize(self):
        self.listen_event(self.handle_telegram, event="telegram_command")
        self.listen_state(self.state_update, "climate.apartment")
        self.listen_state(
            self.temp_update, "climate.apartment", attribute="temperature"
        )

    def state_update(self, *args):
        rt = self.get_state(entity_id="climate.apartment", attribute="all")
        state = rt["state"]
        attrs = rt["attributes"]

        temp = int(attrs.get("temperature", 0) or 0)
        curr_temp = float(attrs.get("current_temperature", 0) or 0)

        curr_text = f"(currently *{curr_temp}º*)"

        if state == "heat":
            self.send_msg(f"🥵 Thermostat set to *heat* @ *{temp}º* {curr_text}")
        else:
            self.send_msg(f"🥶 Thermostat set to *off* {curr_text}")

    def temp_update(self, _entity, _attr, prev, new, kwargs):
        # None when we turn the thermostat off / on
        if new is None or prev is None:
            return

        new = int(new)
        prev = int(prev)
        self.send_msg(f"🔥 Climate set to *{new}º* (was *{prev}º*)")

    def send_msg(self, msg, **kwargs):
        self.call_service("telegram_bot/send_message", message=msg, **kwargs)

    def handle_telegram(self, _, msg: TelegramMessage, *args):
        if not msg["command"].startswith("/climate"):
            return

        args = msg["args"]

        if not args:
            self.send_msg(msg_help)
            return

        action = args.pop(0)

        if action == "status":
            self.state_update()
            return

        if action == "heat":
            self.set_state(entity="climate.apartment", state="heat")
            return

        if action == "off":
            self.set_state(entity="climate.apartment", state="off")
            return

        try:
            temp = int(action)
        except ValueError:
            self.send_msg("🌡️ Temperature must be a number")
            return

        self.set_state(
            entity="climate.apartment", state="heat", attributes={"temperature": temp}
        )
