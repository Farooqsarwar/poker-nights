import re

f = 'firestore.rules'
with open(f, 'r', encoding='utf-8') as file:
    content = file.read()

content = content.replace("existsAfter(/databases/$(database)/documents/rate_limits/chat-$(request.auth.uid))", "existsAfter(path('/databases/' + database + '/documents/rate_limits/chat-' + request.auth.uid))")
content = content.replace("getAfter(/databases/$(database)/documents/rate_limits/chat-$(request.auth.uid))", "getAfter(path('/databases/' + database + '/documents/rate_limits/chat-' + request.auth.uid))")

with open(f, 'w', encoding='utf-8') as file:
    file.write(content)
print('Fixed rules path syntax')
