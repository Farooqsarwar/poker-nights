import os
import sys

sys.stdout.reconfigure(encoding='utf-8')

def show(file, start, end):
    with open(f"D:\\StudioProjects\\poker_night\\{file}", "r", encoding="utf-8") as f:
        lines = f.readlines()
        print(f"=== {file} : {start}-{end} ===")
        for i in range(max(0, start-1), min(len(lines), end)):
            print(f"{i+1}: {lines[i]}", end="")
        print("")

show("lib/utils/tournament_engine.dart", 281, 312)
show("lib/utils/tournament_engine.dart", 514, 533)
show("lib/utils/tournament_engine.dart", 1050, 1076)
show("lib/utils/tournament_engine.dart", 1106, 1197)
show("lib/utils/tournament_engine.dart", 2922, 2962)
show("lib/utils/payouts_engine.dart", 370, 385)
show("lib/utils/payout_bridge.dart", 30, 45)
show("lib/utils/payout_bridge.dart", 70, 80)
show("lib/utils/payout_bridge.dart", 125, 135)
show("lib/utils/payout_bridge.dart", 150, 165)
show("lib/utils/icm.dart", 95, 110)
show("lib/utils/cash_settlement.dart", 100, 120)
show("lib/utils/cash_settlement.dart", 235, 255)
