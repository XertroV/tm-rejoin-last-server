bool IsInMainMenu(CGameCtnApp@ _app) {
    auto app = cast<CTrackMania>(_app);
    if (app is null || app.RootMap !is null) return false;
    return true;
}

// only home page atm
bool IsAppropriateMenu() {
    const string currPage = GetCurrentPage();
    if (currPage.Length == 0) return false;
    if (currPage == "HomePage") return true; // can add more pages later on
    if (currPage == "Live") return true;
    if (currPage == "Solo") return true;
    if (currPage == "Local") return true;
    return false;
}

const string GetCurrentPage() {
    auto layer = GetCurrentUILayer();
    if (layer is null) return "";
    return layer.ManialinkPageUtf8.SubStr(23, 100).Split('"', 2)[0];
}

CGameUILayer@ GetCurrentUILayer() {
    auto ls = cast<CTrackMania>(GetApp()).MenuManager.MenuCustom_CurrentManiaApp.UILayers;
    bool foundOverlay = false;
    uint overlayIx = 13;
    // overlay currently at ix=13, start a little before
    for (uint i = 11; i < ls.Length; i++) {
        auto layer = ls[i];
        if (!foundOverlay) {
            if (layer.ManialinkPageUtf8.StartsWith("\n<manialink name=\"Overlay_MenuBackground\"")) {
                foundOverlay = true;
                overlayIx = i;
                break;
            }
            continue;
        }
    }
    // go backwards to prioritize pages on top of other pages
    for (uint i = ls.Length - 1; i > overlayIx; i--) {
        auto layer = ls[i];
        if (layer.IsVisible) {
            if (layer.ManialinkPageUtf8.StartsWith("\n<manialink name=\"Page_")) {
                return layer;
            }
        }
    }
    return null;
}
