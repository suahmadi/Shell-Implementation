


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

static int max_entries = 20;
static int entries_number = 0;

void yyerror(const char * s);



int yylex();
void sortStrings(char **arr, int n);
void expandWildCardsIfNecessary(std::string *arg);
void expandWildCard(char *prefix, char *suffix, bool hidden_check, char ***array);
static int str_compare(const void* a, const void* b);


void expandWildCardsIfNecessary(std::string *arg) {
  
  if(strchr(arg->c_str(), '*') == NULL && strchr(arg->c_str(), '?') == NULL) {
    Command::_currentSimpleCommand->insertArgument( arg );
    return;
  }

  bool hidden_check = false;

  if(arg->c_str()[0] == '.') {
    hidden_check = true;
  }

  char **array = (char **) malloc(max_entries * sizeof(char *));

  char *prefix = NULL;
  expandWildCard(prefix, (char *) arg->c_str(), hidden_check, &array);
  sortStrings(array, entries_number);

  
  if (array[0] == NULL) {
    Command::_currentSimpleCommand->insertArgument( arg );
  } else {
    for (int i = 0; i < entries_number; i++) {
      arg = new std::string(array[i]);
      Command::_currentSimpleCommand->insertArgument( arg );
    }
  }

  for(int i = 0; i < entries_number; i++) {
    free(array[i]);
    array[i] = NULL;
  }
  free(array);
  array = NULL;

  max_entries = 20;
  entries_number = 0;

  return;
}


void insert_arr(char ***array, char *insert) {
  if (entries_number == max_entries) {
    max_entries *= 2;
    *array = (char **) realloc(*array, max_entries * sizeof(char *));
  }
  (*array)[entries_number] = strdup(insert);
  entries_number++;
  return;
}

void expandWildCard(char *prefix, char *suffix, bool hidden_check, char ***array) {
  
  if(suffix[0] == '\0') {
    insert_arr(array, prefix);
    return;
  }

  char *s;

  if (suffix[0] == '/') {
    s = strchr(&suffix[1], '/');
  } else{
    s = strchr(suffix, '/');
  }

 
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


 
  char newPrefix[MAXFILENAME];
  if(strchr(component, '*') == NULL && strchr(component, '?') == NULL) {
    if(strchr(component, '/') == NULL) {
      if(prefix == NULL) {
        sprintf(newPrefix, "%s", component);
        expandWildCard(newPrefix, suffix, hidden_check, array);
        return;
      }
      sprintf(newPrefix, "%s%s", prefix, component);
      expandWildCard(newPrefix, suffix, hidden_check, array);
      return;
    } else {
      if(prefix == NULL) {
        sprintf(newPrefix, "%s", component);
        expandWildCard(newPrefix, suffix, hidden_check, array);
        return;
      }
      sprintf(newPrefix, "%s%s", prefix, component);
      expandWildCard(newPrefix, suffix, hidden_check,  array);
      return;
    }
  }

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

 
  if(regcomp(&re, reg, 0) != 0) {
    perror("reg compile");
    return;
  }

  free(reg);
  reg = NULL;

 
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
    perror("opendir");
    return;
  }

 
  struct dirent *ent;

  while((ent = readdir(dir)) != NULL) {
    if(regexec(&re, ent->d_name, sizeof(pmatch)/sizeof(pmatch[0]), pmatch, 0) == 0) {
      if (prefix == NULL) {
        if (ent->d_name[0] == '.' && hidden_check) {
          if(suffix[0] == '/') {
            if(ent->d_type == DT_DIR) {
              sprintf(newPrefix, "%s", ent->d_name);
              expandWildCard(newPrefix, suffix, hidden_check, array);
            }
          } else {
            sprintf(newPrefix, "%s", ent->d_name);
            expandWildCard(newPrefix, suffix, hidden_check, array);
          }
        } else if (ent->d_name[0] == '.' && !hidden_check) {
          continue;
        } else {
          if(suffix[0] == '/') {
            if(ent->d_type == DT_DIR) {
              sprintf(newPrefix, "/%s", ent->d_name);
              expandWildCard(newPrefix, suffix, hidden_check, array);
            }
          } else {
            sprintf(newPrefix, "%s", ent->d_name);
            expandWildCard(newPrefix, suffix, hidden_check, array);
          }
        }
      } else {
        if (ent->d_name[0] == '.' && hidden_check) {
          if(suffix[0] == '/') {
            if(ent->d_type == DT_DIR) {
              sprintf(newPrefix, "%s/%s", prefix, ent->d_name);
              expandWildCard(newPrefix, suffix, hidden_check, array);
            }
          } else {
            sprintf(newPrefix, "%s/%s", prefix, ent->d_name);
            expandWildCard(newPrefix, suffix, hidden_check, array);
          }
        } else if (ent->d_name[0] == '.' && !hidden_check) {
          continue;
        } else {
          if(suffix[0] == '/') {
            if(ent->d_type == DT_DIR) {
              sprintf(newPrefix, "%s/%s", prefix, ent->d_name);
              expandWildCard(newPrefix, suffix, hidden_check, array);
            }
          } else {
            sprintf(newPrefix, "%s/%s", prefix, ent->d_name);
            expandWildCard(newPrefix, suffix, hidden_check, array);
          }
        }
      }
    }
  }
  closedir(dir);
  regfree(&re);
}

void sortStrings(char **arr, int n) {
  qsort(arr, n, sizeof(char *), str_compare);
}

static int str_compare(const void* a, const void* b) {
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
    pipe_list io_modifier_list background_opt NEWLINE {
    //printf("   Yacc: Execute command\n");
    Shell::_currentCommand.execute();
  }
  | NEWLINE {
    Shell::_currentCommand.execute();
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
    expandWildCardsIfNecessary($1);
  }
  ;

command_word:
  WORD {
    //printf("   Yacc: insert command \"%s\"\n", $1->c_str());
    Command::_currentSimpleCommand = new SimpleCommand();
    Command::_currentSimpleCommand->insertArgument( $1 );
  }
  ;


pipe_list:
  pipe_list PIPE command_and_args
  | command_and_args
  ;

io_modifier_opt:
  GREATGREAT WORD {

   if (Shell::_currentCommand._outFile) {
      exit(1);
    } else {
    Shell::_currentCommand._outFile = $2;
    }
    Shell::_currentCommand._flag = true;
  }
  | GREAT WORD {
    //printf("   Yacc: insert output \"%s\"\n", $2->c_str());
    if (Shell::_currentCommand._outFile) {
      exit(1);
    } else {
    Shell::_currentCommand._outFile = $2;
    }
  }
  | GREATGREATAMPERSAND WORD {
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

io_modifier_list:
  io_modifier_list io_modifier_opt
  | io_modifier_opt
  | /*can be  empty */
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

