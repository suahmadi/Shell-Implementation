


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
    std::string tmp  = std::string(yytext);
    tmp.erase(std::remove(tmp.begin(), tmp.end(), '"'), tmp.end());
    yylval.cpp_string = new std::string(tmp);
    return WORD;
}


[^ \t\n|><&]*\\[^ \t\n]* {

    std::string temp  = std::string(yytext);
    std::size_t escape = temp.find('\\');
    while (escape!=-1) {
      temp = temp.substr(0, escape) + temp.substr(escape+1, std::string::npos);
      escape = temp.find('\\', escape+1);
      }
    yylval.cpp_string = new std::string(temp);
    return WORD;

}

[~][^ \n]* {

  std::string temp = std::string(yytext);
  std::string home = getenv("HOME");

  if (temp.size() == 1) {
    yylval.cpp_string = new std::string(home);
  } else {
    if (temp[1] == '/') {
     temp = home + temp.substr(1, -1);
    } else {temp = std::string("/homes/") + temp.substr(1,-1);

    }

    yylval.cpp_string = new std::string(temp);
   }

return WORD;
}


\'[^\n\']*\'|$\([^\n]*\) {
  std::string cmd = std::string(yytext);

  if (cmd.at(0) == '$'){
    cmd = cmd.substr(1,cmd.size()-1);
  }

  cmd = cmd.substr(1,cmd.size()-2);
  cmd += "\nexit\n";

  int in[2];
  int out[2];
  int temp_in;
  int temp_out;
  temp_in = dup(0);
  temp_out = dup(1);
  pipe(in);
  pipe(out);
  dup2(in[0],0);
  dup2(out[1],1);
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
      execvp(args[0],args);
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


      int i = r-12;
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



[^ \|><\t\n][^ \|><\t\n]*  {
  /* Assume that file names have only alpha chars */
  yylval.cpp_string = new std::string(yytext);
  std::string tmp = std::string(yytext);

  std::string dollar = "${$}";
  std::string bang = "${!}";
  std::string question = "${?}";
  std::string underscore = "${_}";
  std::string shellsign = "${SHELL}";

  if (tmp.find(dollar) != std::string::npos) {
   tmp = std::to_string(getpid());
   yylval.cpp_string = new std::string(tmp);
   return WORD;

  } else if (tmp.find(bang) != std::string::npos) {

   tmp = std::to_string(Shell::_currentCommand._lastPID);
   yylval.cpp_string = new std::string(tmp);
   return WORD;

  } else if (tmp.find(question) != std::string::npos) {
   tmp = std::to_string(Shell::_currentCommand._lastRC);
   yylval.cpp_string = new std::string(tmp);
   return WORD;
   } else if (tmp.find(underscore) != std::string::npos) {
   tmp = Shell::_currentCommand.get_last();
   yylval.cpp_string = new std::string(tmp);
   return WORD;
  } else if (tmp.find(shellsign) != std::string::npos) {
   char path[500];
   realpath("../shell", path);
   tmp = std::string(path);
   yylval.cpp_string = new std::string(tmp);
   return WORD;
  }

  yylval.cpp_string = new std::string(yytext);
  return WORD;
}
