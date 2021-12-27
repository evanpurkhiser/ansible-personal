# -*- coding: utf-8 -*-

import hassapi as hass


class ThermostatNotification(hass.Hass):
    def initialize(self):
        self.listen_state(self.state_update, entity="climate.apartment")
        self.listen_state(self.temp_update, entity="climate.apartment", attribute="temperature")

    def state_update(self, _entity, _attr, prev, new, kwargs):
        temp = self.get_state(entity_id='climate.apartment', attribute='temperature')

        if new == 'heat':
            self.send_msg(f"🥶 Thermostat set to *heat* @ *{int(temp)}º*")
        else:
            self.send_msg(f"🥵 Thermostat set to *off*")

    def temp_update(self, _entity, _attr, prev, new, kwargs):
        # None when we turn the thermostat off / on
        if new is None or prev is None:
            return

        new = int(new)
        prev = int(prev)
        self.send_msg(f"🔥 Climate set to *{new}º* (was *{prev}º*)")

    def send_msg(self, msg, **kwargs):
        self.call_service("telegram_bot/send_message", message=msg, **kwargs)
