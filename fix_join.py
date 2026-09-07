import re

f = 'lib/repositories/firebase_repository.dart'
with open(f, 'r', encoding='utf-8') as file:
    content = file.read()

def replacer(match):
    return """  Future<String?> joinGroup(String gid, AppUser user,
      {String groupName = '', String groupIcon = '??'}) async {
    final memberRef = _db.collection('groups').doc(gid).collection('members').doc(user.id);
    final snap = await memberRef.get();
    
    final batch = _db.batch();
    if (snap.exists) {
      batch.set(memberRef, {'name': user.name}, SetOptions(merge: true));
    } else {
      batch.set(
          memberRef,
          {
            'name': user.name,
            'role': 'member',
            'joinedAt': FieldValue.serverTimestamp(),
          });
    }"""

pattern = r"  Future<String\?> joinGroup\(String gid, AppUser user,\s*\{String groupName = '', String groupIcon = '[^']+'\}\) async \{\s*final batch = _db\.batch\(\);\s*batch\.set\(\s*_db\.collection\('groups'\)\.doc\(gid\)\.collection\('members'\)\.doc\(user\.id\),\s*\{\s*'name': user\.name,\s*'role': 'member',\s*'joinedAt': FieldValue\.serverTimestamp\(\),\s*\},\s*SetOptions\(merge: true\)\);"

if re.search(pattern, content):
    content = re.sub(pattern, replacer, content)
    with open(f, 'w', encoding='utf-8') as file:
        file.write(content)
    print('Fixed joinGroup')
else:
    print('Not found')
