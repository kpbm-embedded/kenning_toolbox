"""Client-side switch for examples/client_server_tflite (on PYTHONPATH of the client only).

Kenning main@ae35386b sets LocalPlatform.needs_protocol = False, so the "protocol" block of a
LocalPlatform scenario is ignored and the client runs the model in-process; upstream's
scripts/jsonconfigs/tflite-tvm-classification-client-server.json then fails with
"Could not open .../compiled_model.tar". Custom platform classes cannot be named in a
scenario (the block loader only resolves classes inside the kenning package), so this
module flips the flag at interpreter start when KENNING_EX_REMOTE_LOCAL=1.
"""
import os

if os.environ.get("KENNING_EX_REMOTE_LOCAL") == "1":
    from kenning.platforms.local import LocalPlatform

    LocalPlatform.needs_protocol = True
