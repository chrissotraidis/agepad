// A bounded iPad process-model test. No Steam or game data is involved.
#include <stdio.h>
int main(void) {
    fputs("DE_DEVICE_CHILD_PROBE_RAN\n", stderr);
    return 42;
}
