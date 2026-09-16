/// Non-web platforms: each running app is already its own isolated process
/// with its own storage, so there is no same-browser-tab race to arbitrate —
/// the persisted device id genuinely identifies one instance. This stub
/// always reports leadership so [AppProvider]'s editor-authority logic is
/// unaffected outside the browser.
class TabLeader {
  TabLeader(String scope);

  bool get isLeader => true;

  void dispose() {}
}
