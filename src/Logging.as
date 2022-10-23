const string c_mid_grey = "\\$777";
const string c_purple = "\\$a4f";

/** startTime should be set earlier via `startTime = Time::Now` */
void trace_benchmark(const string &in action, uint startTime) {
#if DEV
    auto deltaMs = Time::Now - startTime;
    trace(c_mid_grey + "[" + c_purple + action + c_mid_grey + "] took " + c_purple + deltaMs + " ms");
#endif
}

void dev_trace(const string &in msg) {
#if DEV
    trace(msg);
#endif
}
