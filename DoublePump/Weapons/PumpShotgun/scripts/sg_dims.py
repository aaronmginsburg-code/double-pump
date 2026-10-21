"""Single source of truth for the shotgun's layout (metres; +Y muzzle, +X right, +Z up).

Edit these numbers and re-run the pipeline to re-proportion the whole weapon.
"""

# Receiver
RECV_REAR = -0.105
RECV_FRONT = 0.110
RECV_TOP = 0.036
RECV_BOT = -0.037
RECV_HW = 0.0205          # half width

# Barrel (bore axis)
BORE_Z = 0.012
BARREL_R = 0.0130
BORE_R = 0.0094
MUZZLE_Y = 0.605

# Magazine tube
TUBE_Z = -0.0175
TUBE_R = 0.0120
TUBE_END_Y = 0.545       # end of tube body; cap extends beyond
CAP_LEN = 0.020

# Barrel band / clamp
BAND_Y = 0.520

# Pump (forend) at rest = fully forward
PUMP_REAR = 0.214
PUMP_FRONT = 0.418
PUMP_HW = 0.0272
PUMP_HH = 0.0285
PUMP_CZ = -0.0130
PUMP_STROKE = 0.092

# Bolt
BOLT_REAR = -0.002       # at rest (closed)
BOLT_FRONT = 0.078
BOLT_HW = 0.0115
BOLT_Z0 = 0.0005
BOLT_Z1 = 0.0245

# Ejection port (right side, +X)
PORT_Y0 = 0.004
PORT_Y1 = 0.078
PORT_Z0 = -0.004
PORT_Z1 = 0.026

# Loading port (bottom)
LOAD_Y0 = 0.000
LOAD_Y1 = 0.082
LOAD_HW = 0.0125

# Trigger
TRIGGER_PIVOT = (0.0, -0.030, -0.036)
GUARD_Y0 = -0.090
GUARD_Y1 = -0.002

# Stock
STOCK_BUTT = -0.408
PAD_LEN = 0.020

# Shell (12 ga 2-3/4")
SHELL_LEN = 0.070
SHELL_R = 0.01025
SHELL_RIM_R = 0.01125
SHELL_HEAD_LEN = 0.014
