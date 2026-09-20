#!/usr/bin/env bash

# Whether a switch is on. Anything a switch cannot take read as the default
# before it got here.
setting_on() { [ "$(setting_value "$1")" = "on" ]; }
