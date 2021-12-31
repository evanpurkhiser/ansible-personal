# -*- coding: utf-8 -*-

import hassapi as hass
import collections

from dateutil import parser

Value = collections.namedtuple("Value", ["date", "value"])

NOTIFY_AT = [25, 60, 95]


class Printer(hass.Hass):
    def initialize(self):
        self.listen_state(self.status_update, entity="binary_sensor.octoprint_printing")

    def status_update(self, _entity, _attr, prev, new, kwargs):
        self.log(prev, new)

        #self.send_msg(f"🔩 Printer state is now {new}.")

    def send_msg(self, msg, **kwargs):
        self.call_service("telegram_bot/send_message", message=msg, **kwargs)
