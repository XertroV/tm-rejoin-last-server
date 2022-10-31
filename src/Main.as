string g_lastJoinLink = "";
string g_lastServerName = "";
uint64 g_lastJoinLinkTS = 0;
int nvgFontMontseratt = nvg::LoadFont("fonts/Montserrat-ExtraBoldItalic.ttf");
Audio::Sample@ menuClick = Audio::LoadSample("audio/MenuSelection.wav");
Audio::Sample@ menuOnHover = Audio::LoadSample("audio/MenuSelection2.wav");

const string JoinLinkFilePath = IO::FromStorageFolder("lastJoinLink.json.txt");
#if DEV
const uint SecondsBetweenResave = 1;
#else
const uint SecondsBetweenResave = 5 * 60; // update once per 5 minutes to keep an accurate-enough timestamp
#endif

const double TAU = 6.28318530717958647692;

void Main() {
    PermissionsOkay();
    LoadPreviousJoinLink();
    startnew(MainCoro);
// #if DEV
//     NotifyPermissionsError("PlayLocalMap");
// #endif
}

bool permissionsAreOkay = false;
bool PermissionsOkay() {
    bool allowed = Permissions::PlayPublicClubRoom();
    if (!allowed) {
        NotifyPermissionsError("Permissions::PlayPublicClubRoom (club access required)");
        while (true) yield();
    }
    permissionsAreOkay = allowed;
    return allowed;
}


void LoadPreviousJoinLink() {
    uint startTime = Time::Now;
    if (!IO::FileExists(JoinLinkFilePath)) return;
    auto j = Json::FromFile(JoinLinkFilePath);
    if (j.GetType() != Json::Type::Object) return;
    try {
        g_lastJoinLink = j.Get('joinLink', "");
        g_lastServerName = StripFormatCodes(j.Get('serverName', ""));
        g_lastJoinLinkTS = Text::ParseUInt64(j.Get('ts', 0));
        trace_benchmark("Load last JoinLink", startTime);
        dev_trace("Loaded JoinLink: " + g_lastJoinLink + "; ts: " + g_lastJoinLinkTS + "; now - then: " + (Time::Stamp - g_lastJoinLinkTS));
    } catch {
        warn('Error loading last join link JSON: ' + getExceptionInfo());
        return;
    }
}

void WriteOutJoinLink() {
    auto obj = Json::Object();
    obj['joinLink'] = g_lastJoinLink;
    obj['serverName'] = g_lastServerName;
    obj['ts'] = '' + Time::Stamp; // avoid exponential notation
    Json::ToFile(JoinLinkFilePath, obj);
    dev_trace("Saved last join link w/ timestamp: " + g_lastJoinLink + " for server: " + g_lastServerName);
}

void OnUpdateJoinLink(CTrackManiaNetworkServerInfo@ si) {
    uint startTime = Time::Now;
    g_lastJoinLink = si.JoinLink;
    g_lastServerName = si.ServerName;
    g_lastJoinLinkTS = Time::Stamp;
    WriteOutJoinLink();
    trace_benchmark("Update last JoinLink", startTime);
}

void MainCoro() {
    bool canSaveJoinLink, notCurrentlyDriving;
    while (permissionsAreOkay) {
        if (GetApp().RootMap !is null) lastClick = 0;  // reset click counter when we join a server so we can have a longer disabled-button-on-click
        CTrackManiaNetworkServerInfo@ si = GetServerInfo(GetApp());
        canSaveJoinLink = si !is null && si.JoinLink.Length > 0;
        notCurrentlyDriving = GetUISequence(GetApp()) != CGamePlaygroundUIConfig::EUISequence::Playing;
        // canSaveJoinLink && notCurrentlyDriving && (new joinlink || should update TS)
        if (canSaveJoinLink && notCurrentlyDriving && (g_lastJoinLink != si.JoinLink || g_lastJoinLinkTS + SecondsBetweenResave < uint64(Time::Stamp))) {
            OnUpdateJoinLink(si);
        }
        yield();
    }
}

/*
UI INTERACTIONS
Other button stuff in ./UI_State.as
*/

/** Called whenever a mouse button is pressed. `x` and `y` are the viewport coordinates.
*/
UI::InputBlocking OnMouseButton(bool down, int button, int x, int y) {
    if (!down || button != 0 || !IsButtonActive() || !permissionsAreOkay) return UI::InputBlocking::DoNothing;
    if (Within(vec2(x, y), buttonPos, buttonSize)) {
        startnew(OnClickJoin);
        return UI::InputBlocking::Block;
    }
    return UI::InputBlocking::DoNothing;;
}

uint lastClick = 0;

void OnClickJoin() {
    /* from `Titles/Trackmania/Scripts/Libs/Nadeo/TMNext/TrackMania/Menu/Components/Settings.Script.txt`
    ```maniascript
        declare Text JoinLink = {{{P}}}TL::Replace(ValidatedValue, "#join", "#qjoin");
        JoinLink = {{{P}}}TL::Replace(JoinLink, "#spectate", "#qspectate");
    ```
    */
    if (!permissionsAreOkay) return;
    lastClick = Time::Now;
    Audio::Play(menuClick, 0.20);
    string jl = g_lastJoinLink.Replace("#join", "#qjoin").Replace("#spectate", "#qspectate");
    cast<CTrackMania>(GetApp()).ManiaPlanetScriptAPI.OpenLink(jl, CGameManiaPlanetScriptAPI::ELinkType::ManialinkBrowser);
}

bool WasClickedRecently() {
    // don't let the user click it twice within 20s -- sometimes joining a server takes this long
    // note: reset when a map is loaded.
    return Time::Now < (lastClick + 20000) && lastClick != 0;
}

/* forClick: when false, `lastClick` won't be considered. This is useful for drawing the button after it has been clicked.
   immediately after click there's a 'connecting' dialog which sets Operation_InProgress=true so skip that.
   also skip
*/
bool IsButtonActive(bool forClick = true) {
    if (!permissionsAreOkay) return false;
    if (uint64(Time::Stamp) > g_lastJoinLinkTS + 3600) return false; // don't show button >1hr after g_lastJoinLinkTS
    if (forClick && WasClickedRecently()) return false;
    if (!IsInMainMenu(GetApp())) return false;
    if (GetApp().Editor !is null) return false;
    if (GetApp().CurrentPlayground !is null) return false;
    if (g_lastJoinLink.Length == 0) return false;
    if (forClick && cast<CTrackMania>(GetApp()).Operation_InProgress) return false;
    auto lp = GetApp().LoadProgress;
    if (lp !is null && lp.State != EState::Disabled) return false;
    if (!IsAppropriateMenu()) return false;
    if (IsSettingsOpen()) return false;
    if (IsQuitDialogOpen()) return false;
    if (IsSystemDialogOpen()) return false;
    return true;
}

void Render() {
    if (!IsButtonActive(false)) return;
    DrawRejoin();
}

// 009b5f
const vec4 buttonBgColor = vec4(0, 0x9b / 255.0, 0x5f / 255.0, 1);
// 005f46
const vec4 buttonBgHoverColor = vec4(0, 0x5f / 255.0, 0x46 / 255.0, 1);
// 6efaa0
const vec4 textNormalColor = vec4(0x6e / 255.0, 0xfa / 255.0, 0xa0 / 255.0, 1);
// white
const vec4 textHoverColor = vec4(1, 1, 1, 1);

void DrawRejoin() {
    auto bp = buttonPos;
    vec4 _bgHovColor = buttonBgHoverColor;
    vec4 _bgColor = buttonBgColor;
    vec4 _textHovColor = textHoverColor;
    vec4 _textColor = textNormalColor;
    if (WasClickedRecently()) {
        _bgHovColor = vec4(1, 1, 1, 2) / 4;
        _bgColor = _bgHovColor;
    }
    nvg::Reset();
    // button bg and stroke
    nvg::BeginPath();
    auto slantOffs = SlantyRect(bp, buttonSize);
    nvg::FillColor(_bgHovColor);
    nvg::Fill();
    nvg::FillColor(_bgColor * vec4(1, 1, 1, 1 - buttonBorder));
    nvg::Fill();
    nvg::StrokeColor(vec4(1, 1, 1, buttonBorder));
    nvg::StrokeWidth(3 * Screen.y / RefScreen.y);
    nvg::Stroke();
    nvg::ClosePath();
    // text
    nvg::FontFace(nvgFontMontseratt);
    nvg::FontSize(buttonSize.y * 0.5);
    nvg::TextAlign(nvg::Align::Center | nvg::Align::Middle);

    auto textPos = bp + slantOffs + (buttonSize * 0.5);
    nvg::FillColor(_textHovColor);
    nvg::Text(textPos, "REJOIN SERVER");
    nvg::FillColor(_textColor * vec4(1, 1, 1, 1 - buttonBorder));
    nvg::Text(textPos, "REJOIN SERVER");
    nvg::FillColor(_textColor * vec4(1, 1, 1, buttonBorder));
    nvg::FontSize(buttonSize.y * 0.375);
    nvg::Text(textPos + (buttonSize * vec2(0, .9)), StripFormatCodes(g_lastServerName));
}

float D2R(float degs) {
    return TAU * degs / 360.0;
}

// returns offset from previous center (useful for text)
vec2 SlantyRect(vec2 pos, vec2 size, bool topRound = true, bool bottomRound = true) {
    auto blCornerAngle = D2R(80);
    auto topXOffs = size.y / Math::Tan(blCornerAngle);
    float radius = size.y * 0.251;
    vec2 tlOffs = vec2(topXOffs, 0);
    nvg::MoveTo(pos + vec2(0, size.y));
    if (topRound)
        nvg::Arc(pos + tlOffs + vec2(Math::Sin(D2R(80)) - Math::Cos(D2R(80)) / 1.5, 1)*radius, radius, D2R(-90 - 80), D2R(-90), nvg::Winding::CW);
    else
        nvg::LineTo(pos + tlOffs);
    nvg::LineTo(pos + vec2(size.x + topXOffs, 0));
    // nvg::LineTo(pos + size);
    if (bottomRound)
        nvg::Arc(pos + size - vec2(Math::Sin(D2R(80)) - Math::Cos(D2R(80)) / 1.5, 1)*radius, radius, D2R(90 - 80), D2R(90), nvg::Winding::CW);
    else
        nvg::LineTo(pos + size);
    nvg::LineTo(pos + vec2(0, size.y));
    return tlOffs / 2;
}

void NotifyDepError(const string &in msg) {
    warn(msg);
    UI::ShowNotification(Meta::ExecutingPlugin().Name + ": Dependency Error", msg, vec4(.9, .6, .1, .5), 15000);
}

void NotifyPermissionsError(const string &in issues) {
    warn("Lacked permissions: " + issues);
    UI::ShowNotification(Meta::ExecutingPlugin().Name + ": Permissions Error", "Lacking permission(s): " + issues, vec4(.9, .6, .1, .5), 15000);
}

/* get game stuff */

CTrackManiaNetworkServerInfo@ GetServerInfo(CGameCtnApp@ app) {
    auto _app = cast<CTrackMania>(app);
    if (_app is null || _app.Network is null) return null;
    return cast<CTrackManiaNetworkServerInfo>(_app.Network.ServerInfo);
}

CGamePlaygroundClientScriptAPI@ GetPlaygroundClientScriptAPISync(CGameCtnApp@ app) {
    try {
        return cast<CTrackMania>(app).Network.PlaygroundClientScriptAPI;
    } catch {}
    return null;
}

CGamePlaygroundUIConfig::EUISequence GetUISequence(CGameCtnApp@ app) {
    auto pcs = GetPlaygroundClientScriptAPISync(app);
    if (pcs !is null) return pcs.UI.UISequence;
    return CGamePlaygroundUIConfig::EUISequence::None;
}
