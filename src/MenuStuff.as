
string GetCurrentPage() {
    auto layer = GetCurrentUILayer();
    if (layer is null) return "";
    return layer.ManialinkPageUtf8.SubStr(23, 100).Split('"', 2)[0];
}

CGameUILayer@ GetCurrentUILayer() {
    auto ls = GI::GetUILayers();
    bool foundOverlay = false;
    // currently at ix=13, start a little before
    for (uint i = 11; i < ls.Length; i++) {
        auto layer = ls[i];
        if (!foundOverlay) {
            if (layer.ManialinkPageUtf8.StartsWith("\n<manialink name=\"Overlay_MenuBackground\"")) {
                foundOverlay = true;
            }
            continue;
        } else if (layer.IsVisible) {
            if (layer.ManialinkPageUtf8.StartsWith("\n<manialink name=\"Page_")) {
                return layer;
            }
        }
    }
    return null;
}

// only home page atm
bool IsAppropriateMenu() {
    auto currPage = GetCurrentPage();
    if (currPage.Length == 0) return false;
    if (currPage == "HomePage") return true;
    return false;
}
