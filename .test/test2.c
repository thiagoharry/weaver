#include <string.h>
#include "game.h"
#if defined(__unix__) || defined(__APPLE__)
#include <pthread.h>
#elif defined(_WIN32)
#include <windows.h>
#endif


/*
  This test checks the game loop flow. It checks if the initialization
  really runs only once, the finalization runs only once and the loop
  body is executed many times.
*/

void loop1(void);
#if defined(__unix__) || defined(__APPLE__)
void* clear_pending_files(void*);
#elif defined(_WIN32)
DWORD WINAPI clear_pending_files(void*);
#endif

static int init = 0, end = 0, middle = 0;
static int rc = 0;
#if defined(__unix__) || defined(__APPLE__)
static pthread_t thread;
#elif defined(_WIN32)
HANDLE thread;
#endif


#if defined(__unix__) || defined(__APPLE__)
void* clear_pending_files(void* p) {
    sleep(1);
    W.pending_files = 0;
    pthread_exit(NULL);
    return p;
}
#elif defined(_WIN32)
DWORD WINAPI clear_pending_files(void* p) {
    Sleep(1);
    W.pending_files = 0;
    ExitThread(0);
    return 0;
}
#endif

void loop1(void) {
LOOP_INIT:
    init++;
    if (init > 1 || end > 0) {
        printf("A");
        exit(1);
    }
    W.pending_files = 30;
#if defined(__unix__) || defined(__APPLE__)
    rc = pthread_create(&thread, NULL, clear_pending_files, NULL);
#elif defined(_WIN32)
    thread = CreateThread(NULL, 0, clear_pending_files, NULL, 0, NULL);
    if (thread == NULL)
        rc = 1;
#endif
    if (rc) {
        printf("ERROR: Thread creation failed.\n");
        exit(1);
    }
LOOP_BODY:
    if (init > 1 || end > 0) {
        printf("ERROR: LOOP_INIT or LOOP_END running twice.\n");
        exit(1);
    }
    middle++;
    if (middle == 5)
        Wexit_loop();
LOOP_END:
    end++;
    if (W.pending_files > 0) {
        printf("ERROR: Running LOOP_END while there's pending files.\n");
        exit(1);
    }
    if (end > 1) {
        printf("ERROR: Running LOOP_END twice.\n", end);
        exit(1);
    }
    return;
}


int main(void) {
    Winit();
    Wloop(loop1);
    Wexit();
}
