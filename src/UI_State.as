vec2 lastMousePos;
float g_time = 0;

/** Called whenever the mouse moves. `x` and `y` are the viewport coordinates.
*/
void OnMouseMove(int x, int y) {
    lastMousePos = vec2(x, y);
}

vec2 get_Screen() {
    return vec2(Draw::GetWidth(), Draw::GetHeight());
}

/** Called every frame. `dt` is the delta time (milliseconds since last frame).
*/
void Update(float dt) {
    UpdateButtonHover(dt);
}

// range 0-1; tracks animation for hover
float buttonBorder = 0;
float buttonHoverAnimDuration = 50; // ms

const vec2 buttonPos1440 = vec2(806, 89);
const vec2 buttonSize1440 =  vec2(533, 93);

const vec2 RefScreen = vec2(2560, 1440);

vec2 PosForScreen(vec2 v) {
    auto screen = Screen;
    vec2 uv = (v - RefScreen / 2) / RefScreen.y;
    vec2 pos = uv * screen.y + (screen / 2.0);
    return pos;
}

vec2 get_buttonPos() {
    // return PosForScreen(buttonPos1440);
    auto screen = Screen;
    vec2 uv = (buttonPos1440 - RefScreen / 2) / RefScreen.y;
    vec2 pos = uv * screen.y + screen / 2.0;
    return pos;
}
vec2 get_buttonSize() {
    // return PosForScreen(buttonSize1440);
    auto s = Screen;
    return buttonSize1440 * (s.y / RefScreen.y);
}

void UpdateButtonHover(float dt) {
    bool fadeUp = Within(lastMousePos, buttonPos, buttonSize);
    float sign = fadeUp ? 1 : -1;
    if (fadeUp) {
        buttonBorder = Math::Min(1, buttonBorder + sign * dt / buttonHoverAnimDuration);
    } else {
        buttonBorder = Math::Max(0, buttonBorder + sign * dt / buttonHoverAnimDuration);
    }
}

bool Within(vec2 pos, vec2 tl, vec2 size) {
    return pos.x > tl.x && pos.y > tl.y && pos.x < tl.x + size.x && pos.y < tl.y + size.y;
}
