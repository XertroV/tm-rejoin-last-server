CTrackManiaNetworkServerInfo@ GetServerInfo(CGameCtnApp@ app) {
    auto _app = cast<CTrackMania>(app);
    if (_app is null || _app.Network is null) return null;
    return cast<CTrackManiaNetworkServerInfo>(_app.Network.ServerInfo);
}

bool IsInMainMenu(CGameCtnApp@ _app) {
    auto app = cast<CTrackMania>(_app);
    if (app is null || app.RootMap !is null) return false;
    return true;
}
