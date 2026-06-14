import sys

# The 10 original test instructions
instructions = [
    "06400093", # ADDI x1, x0, 100
    "03700113", # ADDI x2, x0, 55
    "002081B3", # ADD x3, x1, x2
    "40118233", # SUB x4, x3, x1
    "004182B3", # ADD x5, x3, x4
    "0020F333", # AND x6, x1, x2
    "0020E3B3", # OR x7, x1, x2
    "FF628413", # ADDI x8, x5, -10
    "407404B3", # SUB x9, x8, x7
    "00648533", # ADD x10, x9, x6
]

# Write commands for CNN
instructions.append("00100593") # ADDI x11, x0, 1
instructions.append("00001637") # LUI x12, 1 (base address 0x1000)
instructions.append("00b62a23") # SW x11, 0x14(x12) -> trigger START

# First poll
instructions.append("01862683") # LW x13, 0x18(x12) -> should be 0

# Wait for CNN to finish (220 NOPs = 2200ns)
for _ in range(220):
    instructions.append("00000013") # NOP

# Second poll
instructions.append("01862703") # LW x14, 0x18(x12) -> should be 1

# Pad to 256 instructions mapping the IMEM size to stop the "Not enough words" warning
while len(instructions) < 256:
    instructions.append("00000013") # NOP

with open("sim/instructions.mem", "w") as f:
    for instr in instructions:
        f.write(instr + "\n")

print("Generated sim/instructions.mem")
