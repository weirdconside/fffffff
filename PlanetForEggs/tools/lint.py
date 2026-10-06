"""python3 tools/lint.py <luau-analyze> [files...]
Runs luau-analyze over the scripts and prints the warnings that matter: unknown globals that are not
Roblox's own, shadowing, unused locals... (type errors are skipped: the game's scripts are --!nocheck)."""
import subprocess, sys, re, glob, os
ROBLOX = set("""UDim2 Vector3 Enum Color3 CFrame Instance workspace task game Vector2 NumberRange NumberSequenceKeypoint
ColorSequence UDim NumberSequence warn script ColorSequenceKeypoint TweenInfo Random Font RaycastParams UserSettings
DateTime PhysicalProperties Ray Region3 OverlapParams typeof shared plugin delay spawn wait tick time utf8 bit32
Rect BrickColor Axes Faces PathWaypoint Content SharedTable buffer settings elapsedTime""".split())
SKIP = ("ContentData", "IntroAnim", "PrefabInfo")
analyzer = sys.argv[1]
files = sys.argv[2:] or [f for f in glob.glob("scripts/**/*.lua", recursive=True) if not any(s in f for s in SKIP)]
out = subprocess.run([analyzer, "--formatter=plain"] + files, capture_output=True, text=True).stdout
count = 0
for line in out.splitlines():
    if "TypeError" in line or "UnknownType" in line or "SameLineStatement" in line or not line.startswith(("./", "scripts", "/")):
        continue
    m = re.search(r"Unknown global '([^']+)'", line)
    if m and m.group(1) in ROBLOX:
        continue
    print(line); count += 1
print(f"-- {count} warning(s)")
