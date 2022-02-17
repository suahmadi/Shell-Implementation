
/*
 *
 * CS-252 
 * shell.l: lexical analyzer for shell
 * You have to extend it.
 *
 */

%{

#include <cstring>
#include "y.tab.hh"
#include <algorithm>
#include <unistd.h>
#include "shell.hh"
#include <string.h>
#include <sys/wait.h>
#include <sys/types.h>


static  void yyunput (int c,char *buf_ptr  );

void myunputc(int c) {
  unput(c);
}

%}

%option noyywrap

%%

\n {
  return NEWLINE;
}

[ \t] {
  /* Discard spaces and tabs */
}

">" {
  return GREAT;
}

"|" {
  return PIPE;
}

"<" {
  return LESS;
}

">&" {
  return GREATAMPERSAND;
}

">>" {
  return GREATGREAT;
}

">>&" {
  return GREATGREATAMPERSAND;
}

"&" {
  return AMPERSAND;
}


["][^\n\"]*["] {
  std::string temp = std::string(yytext);
  temp.erase(std::remove(temp.begin(), temp.end(), '"'), temp.end());
  yylval.cpp_string = new std::string(temp);
  return WORD;
}

[^ \t\n|><&]*\\[^ \t\n]* {

  std::string temp = std::string(yytext);
  std::size_t escape = temp.find('\\');
  while(escape != -1) {
    temp = temp.substr(0, escape) + temp.substr(escape + 1, std::string::npos);
    escape = temp.find('\\', escape + 1);
  }
  yylval.cpp_string = new std::string(temp);
  return WORD;
}



\$\([^\n\)]+\) {

  std::string cmd = std::string(yytext);
  
  if (cmd.at(0) == '$') {
     cmd = cmd.substr(1, cmd.size()-1);
  }

  cmd = cmd.substr(1, cmd.size()-2);
  cmd += "\nexit\n";

  int in[2];
  int out[2];
  int temp_in;
  int temp_out;
  temp_in = dup(0);
  temp_out = dup(1);
  pipe(in);
  pipe(out);
  dup2(in[0], 0);
  dup2(out[1], 1);
  close(in[0]);
  close(out[1]);

  write(in[1], cmd.c_str(), cmd.size());
  close(in[1]);


  int pid = fork();
  if (pid < 0) {
      exit(1);
  } else if (pid == 0) {
    char **args = new char*[2];
    args[0] = (char *)"/proc/self/exe";
    args[1] = NULL;
    execvp(args[0], args);
    exit(1);
  } else {
    
    waitpid(pid, NULL, 0);
    dup2(temp_in, 0);
    dup2(temp_out, 1);
    close(temp_in);
    close(temp_out);

    char *c = new char[2000];
    int r = read(out[0], c, 2000);
    close(out[0]);

    int i = r - 12;
    while (i >= 0) {
        if (c[i] == '\n') {
          c[i] = '\t';
          }
      myunputc(c[i]);
      i--;
      }
      delete c;
  }
}



[^ \t\n][^ \t\n]*  {
  /* Assume that file names have only alpha chars */
  yylval.cpp_string = new std::string(yytext);
  return WORD;
}
