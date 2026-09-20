#!/usr/bin/env bash

# The event a hook was called for, out of the payload it was handed.
hook_event_of() { hook_field "$1" hook_event_name; }
