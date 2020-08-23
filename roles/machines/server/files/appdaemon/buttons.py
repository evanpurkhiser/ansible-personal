import hassapi as hass


def handle_button(service):
    if "key" not in service.args:
        raise RuntimeError("Key not specified for button")

    def button_event(name, data, kwargs):
        if data["unique_id"] != service.args["key"]:
            return
        press_type = data["args"]["press_type"]
        getattr(service, f"{press_type}_press", lambda: None)()

    service.listen_event(button_event, "zha_event")


class ButtonBlue(hass.Hass):
    def initialize(self):
        handle_button(self)

    def single_press(self):
        self.toggle("light.living_room_lights")

    def double_press(self):
        BRIGHTNESS_STEPS = 5

        state = self.get_state("light.living_room_lights", attribute="all")

        if state["state"] == "off":
            self.turn_on("light.living_room_lights")
            return

        new_level = state["attributes"].get("brightness", 255) - (
            255 / BRIGHTNESS_STEPS
        )
        self.turn_on("light.living_room_lights", brightness=new_level)

    def hold_press(self):
        self.toggle("cover.living_room_shades")


class ButtonGreen(hass.Hass):
    def initialize(self):
        handle_button(self)

    def single_press(self):
        overhead_on = self.get_state("light.kitchen_lights") == "on"
        cove_on = self.get_state("light.kitchen_cove_lights") == "on"

        if not (overhead_on and cove_on):
            self.turn_on("light.kitchen_lights")
            self.turn_on("light.kitchen_cove_lights")
            return

        if overhead_on and cove_on:
            self.turn_off("light.kitchen_lights")
            return

        if not overhead_on and cove_on:
            self.turn_off("light.kitchen_cove_lights")
            self.turn_on("light.kitchen_lights")
            return

        self.turn_off("light.kitchen_lights")
        self.turn_off("light.kitchen_cove_lights")

    def hold_press(self):
        self.turn_on("light.kitchen_cove_lights", brightness=255 * 0.05)
        self.turn_off("light.kitchen_lights")
        self.turn_off("light.living_room_lights")
