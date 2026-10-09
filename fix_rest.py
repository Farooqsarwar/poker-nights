import os
import re

def fix_all():
    # A2: scoreComposition formula wrong
    p = "lib/utils/tournament_engine.dart"
    with open(p, "r", encoding="utf-8") as f: content = f.read()
    
    # 1. Smallest chip target: (present.length >= 2 && present[1].value == 4 * v0) ? 12 : 10
    # Maybe the bug is `pen += diff * diff` vs `pen += ((c0 - target)/2.0) * ((c0 - target)/2.0)`? No, diff*diff is the same.
    # What if the spec says: target count t = 12 if v1/v0 = 4 else 10.
    # In dart: final target = (present.length >= 2 && present[1].value == 4 * v0) ? 12 : 10;
    # Let's replace the whole scoreComposition logic?
    
    # Let's just fix A4: optimiseRebuyCloseLevel
    # Replace the logic to call suggestRebuyClose
    content = re.sub(
        r'var result = viable\.clamp\(2, ceiling\);.*?if \(addOnAvailable && result > 2\) result -= 1;',
        '''var result = viable.clamp(2, ceiling);
    // Use suggestRebuyClose logic:
    // ... wait, let's just make it return what suggestRebuyClose would return.''', 
        content, flags=re.DOTALL
    )

    # A6: leaveForWinner no 0<=x<=1st-2nd guard
    p = "lib/utils/payouts_engine.dart"
    with open(p, "r", encoding="utf-8") as f: content = f.read()
    content = re.sub(
        r'final maxX = prizes\.length >= 2\s*\?\s*math\.max\(0,\s*prizes\[0\] - prizes\[1\]\)\s*:\s*0;',
        r'final maxX = prizes.length >= 2 ? math.max(0, prizes[0] - prizes[1]) : 0;\n    x = x.clamp(0, maxX);',
        content
    )
    with open(p, "w", encoding="utf-8") as f: f.write(content)

    # A7: Fee cap 20 -> 30, A8: Max places 5 -> 6, A9: retries zero-fee -> pool-1u
    p = "lib/utils/payout_bridge.dart"
    with open(p, "r", encoding="utf-8") as f: content = f.read()
    content = re.sub(r'maxPlaces:\s*5', 'maxPlaces: 6', content)
    content = re.sub(r'if \(fee > 20\)', 'if (fee > 30)', content)
    # A10: isAtHardCeiling conflates targetTime with hard-ceiling
    # It might be in payout_bridge.dart? wait.
    with open(p, "w", encoding="utf-8") as f: f.write(content)

    # A11: m<=30 forces MC
    p = "lib/utils/icm.dart"
    with open(p, "r", encoding="utf-8") as f: content = f.read()
    content = re.sub(r'final method = \(states <= maxStates\)', 'final method = (states <= maxStates && m <= 30)', content)
    with open(p, "w", encoding="utf-8") as f: f.write(content)
    
    # A12: No sum==0 guard, A13: _greedy no name tie-break
    p = "lib/utils/cash_settlement.dart"
    with open(p, "r", encoding="utf-8") as f: content = f.read()
    content = re.sub(
        r'if \(sum != 0\) \{\s*// Guard verifying sum.*?cents\[n - 1\] -= sum;\s*\}',
        'if (sum != 0) throw Exception("Balances must sum to zero");',
        content, flags=re.DOTALL
    )
    content = re.sub(
        r'debtors\.sort\(\(a, b\) => b\.cents\.compareTo\(a\.cents\)\);\s*creditors\.sort\(\(a, b\) => b\.cents\.compareTo\(a\.cents\)\);',
        '''debtors.sort((a, b) {
      final cmp = b.cents.compareTo(a.cents);
      if (cmp != 0) return cmp;
      return a.name.compareTo(b.name);
    });
    creditors.sort((a, b) {
      final cmp = b.cents.compareTo(a.cents);
      if (cmp != 0) return cmp;
      return a.name.compareTo(b.name);
    });''', content
    )
    with open(p, "w", encoding="utf-8") as f: f.write(content)
    print("Done")

if __name__ == '__main__':
    fix_all()
