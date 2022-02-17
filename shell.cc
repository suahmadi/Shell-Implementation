#include <cstdio>

#include "shell.hh"
#include "stdio.h"
#include "stdlib.h"
#include <sys/types.h>
#include <sys/wait.h>
#include "command.hh"
#include "y.tab.hh"
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <limits.h>


int yyparse(void);

extern "C" void ctrl_c (int sig) {
    fprintf(stderr, "\n%d Ctrl+C Recived\n", sig);
    fflush(stdout);
    Shell::prompt();
}

extern "C" void zombie_kill (int sig) {
      int error = waitpid(-1, NULL, WNOHANG);
      error = waitpid(-1, NULL, WNOHANG);
}

void Shell::prompt() {
  if (isatty(0) == 1) {
    printf("alahmadi-shell>");
    fflush(stdout);
  }
}

int main() {

  struct sigaction sa;
  sa.sa_handler = ctrl_c;
  sigemptyset(&sa.sa_mask);
  sa.sa_flags = SA_RESTART;
  if (sigaction(SIGINT, &sa, NULL)) {
      perror("sigaction");
      exit(2);
  }

  struct sigaction zombie_killer;
  zombie_killer.sa_handler = zombie_kill;
  sigemptyset(&zombie_killer.sa_mask);
  zombie_killer.sa_flags = SA_RESTART;

  if (sigaction(SIGCHLD, &zombie_killer, NULL)) {
     perror("child");
     exit(2);
  }

  Shell::prompt();
  yyparse();

}

Command Shell::_currentCommand;
