#define _GNU_SOURCE
#include <sys/prctl.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv) {
    const char *name = (argc > 1) ? argv[1] : "test(";
    
    if (strcmp(name, "NEWLINE") == 0) {
        name = "a\nb";
    }
    
    if (prctl(PR_SET_NAME, name) < 0) {
        perror("prctl");
        return 1;
    }
    printf("%d\n", getpid());
    fflush(stdout);
    pause();
    return 0;
}