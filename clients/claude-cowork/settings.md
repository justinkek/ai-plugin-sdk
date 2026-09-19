The hooks read the file every time they run, so a change takes effect at once,
and the reload skill prints with the new value.

The file is written inside the session's container, which is discarded when the
session ends, so say the setting lasts as long as this session does.
