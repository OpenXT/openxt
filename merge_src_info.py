#!/usr/bin/python

import json
import os
import sys

if len(sys.argv) != 3:
    sys.stderr.write("Usage: %s INPUT_DIR OUTPUT_FILE\n" %
                     os.path.basename(sys.argv[0]))
    exit(1)

input_dir, output_file = sys.argv[1:]

data = {}

for arch in os.listdir(input_dir):
    for pkg in os.listdir(os.path.join(input_dir, arch)):
        with open(os.path.join(input_dir, arch, pkg)) as f:
            data.setdefault(pkg, {})[arch] = json.load(f)

with open(output_file, "w") as f:
    json.dump(data, f, indent=4, sort_keys=True)
