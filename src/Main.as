string g_lastJoinLink = "";
uint64 g_lastJoinLinkTS = 0;
int nvgFontMontseratt = nvg::LoadFont("fonts/Montserrat-ExtraBoldItalic.ttf");

const string JoinLinkFilePath = IO::FromStorageFolder("lastJoinLink.json.txt");
#if DEV
const uint SecondsBetweenResave = 1;
#else
const uint SecondsBetweenResave = 60; // update once per minute to keep an accurate-enough timestamp
#endif

const double TAU = 6.28318530717958647692;

void Main() {
    LoadPreviousJoinLink();
    startnew(MainCoro);
}

void LoadPreviousJoinLink() {
    uint startTime = Time::Now;
    if (!IO::FileExists(JoinLinkFilePath)) return;
    auto j = Json::FromFile(JoinLinkFilePath);
    if (j.GetType() != Json::Type::Object) return;
    try {
        g_lastJoinLink = j['joinLink'];
        g_lastJoinLinkTS = Text::ParseUInt64(j['ts']);
        trace_benchmark("Load last JoinLink", startTime);
        dev_trace("Loaded JoinLink: " + g_lastJoinLink);
    } catch {
        warn('Error loading last join link JSON: ' + getExceptionInfo());
        return;
    }
}

void MainCoro() {
    bool canSaveJoinLink;
    while (true) {
        auto si = GetServerInfo(GetApp());
        canSaveJoinLink = si !is null && si.JoinLink.Length > 0;
        // canSaveJoinLink && (new joinlink || should update TS)
        if (canSaveJoinLink && (g_lastJoinLink != si.JoinLink || g_lastJoinLinkTS + SecondsBetweenResave < uint64(Time::Stamp))) {
            OnUpdateJoinLink(si.JoinLink);
        }
        // sleep(250);  // for releases
        yield();  // for dev, to make sure there are no lag spikes
    }
}

void OnUpdateJoinLink(const string &in jl) {
    uint startTime = Time::Now;
    g_lastJoinLink = jl;
    g_lastJoinLinkTS = Time::Stamp;
    WriteOutJoinLink(jl);
    trace_benchmark("Update last JoinLink", startTime);
}

void WriteOutJoinLink(const string &in jl) {
    auto obj = Json::Object();
    obj['joinLink'] = jl;
    obj['ts'] = '' + Time::Stamp; // avoid exponential notation
    Json::ToFile(JoinLinkFilePath, obj);
    dev_trace("Saved last join link w/ timestamp: " + jl);
}


/** Called whenever a mouse button is pressed. `x` and `y` are the viewport coordinates.
*/
UI::InputBlocking OnMouseButton(bool down, int button, int x, int y) {
    if (!down || button != 0) return UI::InputBlocking::DoNothing;
    if (Within(vec2(x, y), buttonPos, buttonSize)) {
        startnew(OnClickJoin);
        return UI::InputBlocking::Block;
    }
    return UI::InputBlocking::DoNothing;;
}

void OnClickJoin() {
    cast<CTrackMania>(GetApp()).ManiaPlanetScriptAPI.OpenLink(g_lastJoinLink.Replace("#join", "#qjoin").Replace("#spectate", "#qspectate"), CGameManiaPlanetScriptAPI::ELinkType::ManialinkBrowser);
}

void Render() {
    if (!IsInMainMenu(GetApp())) return;
    if (g_lastJoinLink.Length == 0) return;
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
    /* get position to draw

    */
    auto bp = buttonPos;
    nvg::Reset();
    nvg::BeginPath();
    SlantyRect(bp, buttonSize);
    // nvg::FillColor(vec4(0, 0, 0, .99));
    nvg::FillColor(buttonBgHoverColor);
    nvg::Fill();
    nvg::FillColor(buttonBgColor * vec4(1, 1, 1, 1 - buttonBorder));
    nvg::Fill();
    nvg::StrokeColor(vec4(1, 1, 1, buttonBorder));
    nvg::StrokeWidth(3 * Screen.y / RefScreen.y);
    nvg::Stroke();
    nvg::ClosePath();
    nvg::BeginPath();
    nvg::FontFace(nvgFontMontseratt);
    nvg::FontSize(buttonSize.y * 0.4);
    nvg::TextAlign(nvg::Align::Center | nvg::Align::Middle);
    nvg::FillColor(textHoverColor);
    nvg::Text(bp + (buttonSize * 0.5), "Rejoin Last Server");
    nvg::FillColor(textNormalColor * vec4(1, 1, 1, 1 - buttonBorder));
    nvg::Text(bp + (buttonSize * 0.5), "Rejoin Last Server");
    // nvg::Fill();
    nvg::ClosePath();
}

float D2R(float degs) {
    return TAU * degs / 360.0;
}

void SlantyRect(vec2 pos, vec2 size, bool topRound = true, bool bottomRound = true) {
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
}

void RenderInterface() {
}

void RenderMenu() {
}

void NotifyDepError(const string &in msg) {
    warn(msg);
    UI::ShowNotification(Meta::ExecutingPlugin().Name + ": Dependency Error", msg, vec4(.9, .6, .1, .5), 15000);
}