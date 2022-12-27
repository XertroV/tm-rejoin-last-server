bool IsInMainMenu(CGameCtnApp@ _app) {
    auto app = cast<CTrackMania>(_app);
    if (app is null || app.RootMap !is null) return false;
    return true;
}

bool IsSettingsOpen() {
    // viewport overlay, index 5, [0][0][0..8]
    try {
        // idk now to get the CControlFrame for the settings, but this buffer's length is 5 before opening settings, and 1181 or 1183 after opening settings.
        return GetApp().Viewport.Overlays[5].m_CorpusVisibles.Length > 100;
    } catch {
        warn("IsSettingsOpen exception: " + getExceptionInfo());
    }
    return false;
}

// the dialog that comes up when you press esc at main menu home page
bool IsQuitDialogOpen() {
    try {
        auto frame = GetCurrentUILayer().LocalPage.GetFirstChild("popupmultichoice-quit-game");
        return frame !is null && frame.Visible;
    } catch {
        warn("IsQuitDialogOpen exception: " + getExceptionInfo());
    }
    return false;
}

bool IsSystemDialogOpen() {
    return GetApp().ActiveMenus.Length > 1;
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
    auto app = cast<CTrackMania>(GetApp());
    CGameManiaAppTitle@ mm;
    try {
        @mm = app.MenuManager.MenuCustom_CurrentManiaApp;
    } catch {
        return null;
    }
    if (mm is null) return null;
    MwFastBuffer<CGameUILayer@> ls = mm.UILayers;
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
        try {
            auto layer = ls[i];
            if (layer.IsVisible) {
                if (layer.ManialinkPageUtf8.StartsWith("\n<manialink name=\"Page_")) {
                    return layer;
                }
            }
        } catch {
            warn("exception looking for menu page: " + getExceptionInfo());
            break;
        }
    }
    return null;
}
