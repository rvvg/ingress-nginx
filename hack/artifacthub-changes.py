#!/usr/bin/env python3

# Copyright 2020 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Converts a Markdown change list (stdin) to the artifacthub.io/changes chart annotation (stdout).

Every top-level "- " item becomes one change; its continuation lines are joined. Text outside the list is
dropped. Markdown links become change links, and emphasis and code markers are removed from the description.
"""

import json
import re
import sys

LINK = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")


def items(text):
    current = None
    for line in text.splitlines():
        if line.startswith("- "):
            if current is not None:
                yield current
            current = line[2:].strip()
        elif current is not None and line.startswith("  ") and line.strip():
            current += " " + line.strip()
        else:
            if current is not None:
                yield current
            current = None
    if current is not None:
        yield current


def change(item):
    links = [{"name": name, "url": url} for name, url in LINK.findall(item)]
    description = LINK.sub(r"\1", item)
    description = re.sub(r"\*\*|`", "", description)
    entry = {"kind": "changed", "description": description}
    if links:
        entry["links"] = links
    return entry


# JSON strings are valid YAML scalars, so no YAML library is needed.
for entry in (change(i) for i in items(sys.stdin.read())):
    print(f"- kind: {entry['kind']}")
    print(f"  description: {json.dumps(entry['description'])}")
    if "links" in entry:
        print("  links:")
        for link in entry["links"]:
            print(f"    - name: {json.dumps(link['name'])}")
            print(f"      url: {json.dumps(link['url'])}")
