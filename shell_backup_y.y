
/*
 * CS-252
 * shell.y: parser for shell
 *
 * This parser compiles the following grammar:
 *
 *      cmd [arg]* [> filename]
 *
 * you must extend it to understand the complete shell grammar
 *
 */

%code requires
{
#include <string>
#include <string.h>

#if __cplusplus > 199711L
#define register      // Deprecated in C++11 so remove the keyword
#endif
}

%union
{
  char        *string_val;
  // Example of using a c++ type in yacc
  std::string *cpp_string;
}

%token <cpp_string> WORD
%token NOTOKEN GREAT NEWLINE PIPE LESS GREATAMPERSAND GREATGREAT GREATGREATAMPERSAND AMPERSAND TWOGREAT

%{
//#define yylex yylex
#include <cstdio>
#include "shell.hh"
#include "command.hh"
#include <string.h>
#include <regex.h>
#include <dirent.h>
#include <stdlib.h>
#include <unistd.h>

#define MAXFILENAME 1024

static int maxEntries = 20;
static int nEntries = 0;

void yyerror(const char * s);



int yylex();
void sortArrayStrings(char **arr, int n);
static int myCompare(const void* a, const void* b);
void expandWildcardsIfNecessary(std::string *arg);
void expandWildcard(char *prefix, char *suffix, bool hidden, char ***array);

//Expand wildcard if necessary
void expandWildcardsIfNecessary(std::string *arg) {
  //If it is not necessary then insert into argument list
  if(strchr(arg->c_str(), '*') == NULL && strchr(arg->c_str(), '?') == NULL) {
    Command::_currentSimpleCommand->insertArgument( arg );
    return;
  }
  bool hidden = false;

  if(arg->c_str()[0] == '.') {
    hidden = true;
  }

  char **array = (char **) malloc(maxEntries * sizeof(char *));

  char *prefix = NULL;
  expandWildcard(prefix, (char *) arg->c_str(), hidden, &array);
  sortArrayStrings(array, nEntries);

  //Insert arguments into argument list after expansion
  if (array[0] == NULL) {
    Command::_currentSimpleCommand->insertArgument( arg );
  } else {
    for (int i = 0; i < nEntries; i++) {
      arg = new std::string(array[i]);
      Command::_currentSimpleCommand->insertArgument( arg );
    }
  }

  //Free memory
  for(int i = 0; i < nEntries; i++) {
    free(array[i]);
    array[i] = NULL;
  }
  free(array);
  array = NULL;

  maxEntries = 20;
  nEntries = 0;

  return;
}

//Helper function to insert into array
void insertArray(char ***array, char *insert) {
  if (nEntries == maxEntries) {
    maxEntries *= 2;
    *array = (char **) realloc(*array, maxEntries * sizeof(char *));
  }
  (*array)[nEntries] = strdup(insert);
  nEntries++;
  return;
}

void expandWildcard(char *prefix, char *suffix, bool hidden, char ***array) {
  //insert into array if suffix is empty
  if(suffix[0] == '\0') {
    insertArray(array, prefix);
    return;
  }

  char *s;

  if (suffix[0] == '/') {
    s = strchr(&suffix[1], '/');
  } else{
    s = strchr(suffix, '/');
  }

  //Get next component in suffix
  char component[MAXFILENAME];
  if(s != NULL) {
    strncpy(component, suffix, s-suffix);
    component[s-suffix] = '\0';
    suffix = s;
  } else {
    strcpy(component, suffix);
    component[strlen(suffix)] = '\0';
    suffix = suffix + strlen(suffix);
  }


  //if component does not contain wildcard then call expandWildCard
  char newPrefix[MAXFILENAME];
  if(strchr(component, '*') == NULL && strchr(component, '?') == NULL) {
    if(strchr(component, '/') == NULL) {
      if(prefix == NULL) {
        sprintf(newPrefix, "%s", component);
        expandWildcard(newPrefix, suffix, hidden, array);
        return;
      }
      sprintf(newPrefix, "%s%s", prefix, component);
      expandWildcard(newPrefix, suffix, hidden, array);
      return;
    } else {
      if(prefix == NULL) {
        sprintf(newPrefix, "%s", component);
        expandWildcard(newPrefix, suffix, hidden, array);
        return;
      }
      sprintf(newPrefix, "%s%s", prefix, component);
      expandWildcard(newPrefix, suffix, hidden,  array);
      return;
    }
  }

  //If component does contain wildcard then build regex
  char *reg = (char*)malloc(2*strlen(component)+10);
  char *a = component;
  if (component[0] == '/') {
    a = &component[1];
  }
  char *r = reg;

  regex_t re;
  regmatch_t pmatch[1];

  *r = '^';
  r++;
  while(*a != '\0') {
    if(*a == '*') {
      *r = '.';
      r++;
      *r = '*';
      r++;
    } else if(*a == '?') {
      *r = '.';
      r++;
    } else if(*a == '.') {
      *r = '\\';
      r++;
      *r = '.';
      r++;
    } else {
      *r = *a;
      r++;
    }
    a++;
  }
  *r = '$';
  r++;
  *r = '\0';

  //Compile regex
  if(regcomp(&re, reg, 0) != 0) {
    perror("regex compile");
    return;
  }

  free(reg);
  reg = NULL;

  //Open directory
  char *d;

  if (prefix == NULL || prefix[0] == '\0') {
    if(component[0] == '/') {
      d = "/";
    } else {
      d = ".";
    }
  } else {
    d = prefix;
  }
  DIR *dir = opendir(d);
  if (dir == NULL) {
    perror("opedir");
    return;
  }

  //Find regex in current directory
  struct dirent *ent;
  while((ent = readdir(dir)) != NULL) {
    if(regexec(&re, ent->d_name, sizeof(pmatch)/sizeof(pmatch[0]), pmatch, 0) == 0) {
      if (prefix == NULL) {
        if (ent->d_name[0] == '.' && hidden) {
          if(suffix[0] == '/') {
            if(ent->d_type == DT_DIR) {
              sprintf(newPrefix, "%s", ent->d_name);
              expandWildcard(newPrefix, suffix, hidden, array);
            }
          } else {
            sprintf(newPrefix, "%s", ent->d_name);
            expandWildcard(newPrefix, suffix, hidden, array);
          }
        } else if (ent->d_name[0] == '.' && !hidden) {
          continue;
        } else {
          if(suffix[0] == '/') {
            if(ent->d_type == DT_DIR) {
              sprintf(newPrefix, "/%s", ent->d_name);
              expandWildcard(newPrefix, suffix, hidden, array);
            }
          } else {
            sprintf(newPrefix, "%s", ent->d_name);
            expandWildcard(newPrefix, suffix, hidden, array);
          }
        }
      } else {
        if (ent->d_name[0] == '.' && hidden) {
          if(suffix[0] == '/') {
            if(ent->d_type == DT_DIR) {
              sprintf(newPrefix, "%s/%s", prefix, ent->d_name);
              expandWildcard(newPrefix, suffix, hidden, array);
            }
          } else {
            sprintf(newPrefix, "%s/%s", prefix, ent->d_name);
            expandWildcard(newPrefix, suffix, hidden, array);
          }
        } else if (ent->d_name[0] == '.' && !hidden) {
          continue;
        } else {
          if(suffix[0] == '/') {
            if(ent->d_type == DT_DIR) {
              sprintf(newPrefix, "%s/%s", prefix, ent->d_name);
              expandWildcard(newPrefix, suffix, hidden, array);
            }
          } else {
            sprintf(newPrefix, "%s/%s", prefix, ent->d_name);
            expandWildcard(newPrefix, suffix, hidden, array);
          }
        }
      }
    }
  }
  closedir(dir);
  regfree(&re);
}

void sortArrayStrings(char **arr, int n) {
  qsort(arr, n, sizeof(char *), myCompare);
}

static int myCompare(const void* a, const void* b) {
  return strcmp(*(const char **)a, *(const char**)b);
}



%}


%%

goal:
  commands
  ;

commands:
  command
  | commands command
  ;

command: simple_command
       ;

simple_command:	
    pipe_list iomodifier_list background_opt NEWLINE {
    //printf("   Yacc: Execute command\n");
    Shell::_currentCommand.execute();
  }
  | NEWLINE {
    if(isatty(0)) {
    Shell::prompt();
    }
  }
  | error NEWLINE { yyerrok; }
  ;

command_and_args:
  command_word argument_list {
    Shell::_currentCommand.
    insertSimpleCommand( Command::_currentSimpleCommand );
  }
  ;

argument_list:
  argument_list argument
  | /* can be empty */
  ;

argument:
  WORD {
    //printf("   Yacc: insert argument \"%s\"\n", $1->c_str());
    //Command::_currentSimpleCommand->insertArgument( $1 );\
    expandWildcardsIfNecessary($1);
  }
  ;

command_word:
  WORD {
    //printf("   Yacc: insert command \"%s\"\n", $1->c_str());
    Command::_currentSimpleCommand = new SimpleCommand();
    Command::_currentSimpleCommand->insertArgument( $1 );
  }
  ;

iomodifier_opt:
  GREATGREAT WORD {
  if (Shell::_currentCommand._outFile) {
     exit(1);
  } else {
     Shell::_currentCommand._outFile = $2;
    } Shell::_currentCommand._flag = true;
  } | GREAT WORD {
    //printf("   Yacc: insert output \"%s\"\n", $2->c_str());
    if (Shell::_currentCommand._outFile) {
      exit(1);
   } else {
    Shell::_currentCommand._outFile = $2;
  }
 } | GREATGREATAMPERSAND WORD {
   if (Shell::_currentCommand._outFile) {
      exit(1);
    } else {
    Shell::_currentCommand._outFile = $2;
    }

   if (Shell::_currentCommand._errFile) {
      exit(1);
   } else {
    Shell::_currentCommand._errFile = new std::string($2->c_str());
   }

    Command::_currentCommand._flag = true;
}
| GREATAMPERSAND WORD {
   if (Shell::_currentCommand._outFile) {
      exit(1);
    } else {
    Shell::_currentCommand._outFile = $2;
    }

   if (Shell::_currentCommand._errFile) {
      exit(1);
   } else {
    Shell::_currentCommand._errFile = new std::string($2->c_str());
   }
  }
  | LESS WORD {
  if (Shell::_currentCommand._inFile) {
    exit(1);
  } else {
    Shell::_currentCommand._inFile = $2;
  }
  }
  | TWOGREAT WORD {
  if (Shell::_currentCommand._errFile) {
    exit(1);
  } else {
    Shell::_currentCommand._inFile = $2;
  }
  }
  ;

pipe_list:
  pipe_list PIPE command_and_args
  | command_and_args
  ;

iomodifier_list:
   iomodifier_list iomodifier_opt
   | /* can be empty */
   ;


background_opt:
   AMPERSAND {
    Shell::_currentCommand._background = true;
    }
    | /* can be empty */
    ;


%%

void
yyerror(const char * s)
{
  fprintf(stderr,"%s", s);
}

#if 0
main()
{
  yyparse();
}
#endif
