import re
file_path = 'lib/models/tournament.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    text = f.read()

# Delete enum block
text = re.sub(r'(?://[^\n]*\n)*enum PayoutShape \{.*?\}\n', '', text, flags=re.DOTALL)
text = re.sub(r'\s*final PayoutShape payoutShape;', '', text)
text = re.sub(r'\s*this\.payoutShape = PayoutShape\.standard,', '', text)
text = re.sub(r'\s*PayoutShape\? payoutShape,', '', text)
text = re.sub(r'\s*payoutShape:\s*payoutShape\s*\?\?\s*this\.payoutShape,', '', text)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(text)

file_path = 'lib/models/live_game.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    text = f.read()
text = re.sub(r'\s*final PayoutShape payoutShape;', '', text)
text = re.sub(r'\s*this\.payoutShape = PayoutShape\.standard,', '', text)
text = re.sub(r'\s*PayoutShape\? payoutShape,', '', text)
text = re.sub(r'\s*payoutShape:\s*payoutShape\s*\?\?\s*this\.payoutShape,', '', text)
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(text)

file_path = 'lib/utils/model_codec.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    text = f.read()
text = re.sub(r"(?://[^\n]*\n)*\s*'payoutShape': s\.payoutShape\.name,\n", '', text)
text = re.sub(r"\s*payoutShape: PayoutShape\.values\.firstWhere\([^)]+\),\n", '', text, flags=re.DOTALL)
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(text)
