"""Replays an export phase under _Planner's cut rule, with k jobs per worker.

Reads 01-customer-export-timings.json beside it. Each table's cost per record per job is its
measured elapsed x jobs / records, so contention measured in the run stays in. The pool queues
jobs by record count, largest first, and hands each one to the first free worker. k = 1 is
today's rule and reproduces the run: 46.4 min, 13.1% idle.

    python3 01-simulate-cut.py
"""
import heapq
import json
import math
import os

run = json.load(open(os.path.join(os.path.dirname(__file__), "01-customer-export-timings.json")))
tables = run["tables"]
workers = run["workers"]
total = sum(t["records"] for t in tables)


def phase(k):
    jobs = []
    for t in tables:
        records = t["records"]
        cost = t["elapsed"] * t["jobs"] / records
        n = max(1, min(workers * k, records // 50000, math.ceil(records * workers * k / total)))
        for i in range(n):
            expected = int((i + 1) * records / n) - int(i * records / n)
            jobs.append((expected, expected * cost))
    jobs.sort(key=lambda j: -j[0])
    free = [0.0] * workers
    end = busy = 0.0
    for _, seconds in jobs:
        start = heapq.heappop(free)
        heapq.heappush(free, start + seconds)
        end = max(end, start + seconds)
        busy += seconds
    return len(jobs), end, 1 - busy / (workers * end)


for k in (1, 2, 4, 8):
    n, end, idle = phase(k)
    print(f"k={k}: {n:3} jobs, export phase {end / 60:5.1f} min, idle {idle * 100:4.1f}%")
print(f"no tail at all: {sum(t['elapsed'] * t['jobs'] for t in tables) / workers / 60:5.1f} min")
