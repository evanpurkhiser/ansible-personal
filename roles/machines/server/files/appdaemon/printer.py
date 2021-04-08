# -*- coding: utf-8 -*-

import hassapi as hass
import collections

from dateutil import parser

Value = collections.namedtuple("Value", ["date", "value"])

NOTIFY_AT = [25, 60, 95]


class Printer(hass.Hass):
    def initialize(self):
        self.listen_state(self.status_update, entity="sensor.ender_3_v2_job_percentage")
        self.status_update()

    @property
    def history(self):
        """
        Most recent entries first
        """
        history = list(
            map(
                lambda v: Value(
                    parser.parse(v["last_updated"]),
                    float(0 if v["state"] == "unknown" else v["state"]),
                ),
                self.get_history(entity_id="sensor.ender_3_v2_job_percentage", days=1)[
                    0
                ],
            )
        )
        history.reverse()
        return history

    def status_update(self, *args, **kwargs):
        history = self.history

        try:
            if history[0] == 100 and history[1] != 100:
                self.send_msg(f"🔩 Print job **COMPLETE**!")
                return
        except KeyError:
            pass

        for threshold in NOTIFY_AT:
            try:
                index = next(i for i, v in enumerate(history) if v.value < threshold)
            except StopIteration:
                return

            if index != 1:
                continue

            self.send_msg(f"🔩 Print job **{threshold}%** complete")
            return

    def send_msg(self, msg, **kwargs):
        self.call_service("telegram_bot/send_message", message=msg, **kwargs)
