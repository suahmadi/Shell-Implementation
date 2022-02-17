

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include "command.hh"
#include "shell.hh"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <wait.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

Command::Command() {
  
    _simpleCommands = std::vector<SimpleCommand *>();

    _outFile = NULL;
    _inFile = NULL;
    _errFile = NULL;
    _background = false;
    _flag = false;
    _lastPID = -1;
    _lastRC = -1;

}

void Command::insertSimpleCommand( SimpleCommand * simpleCommand ) {
    // add the simple command to the vector
    _simpleCommands.push_back(simpleCommand);
}

void Command::clear() {
    // deallocate all the simple commands in the command vector
    for (auto simpleCommand : _simpleCommands) {
        delete simpleCommand;
    }

    // remove all references to the simple commands we've deallocated

    _simpleCommands.clear();

    if ( _outFile ) {
        delete _outFile;
    }
    _outFile = NULL;

    if ( _inFile ) {
        delete _inFile;
    }
    _inFile = NULL;

    if ( _errFile ) {
        delete _errFile;
    }
    _errFile = NULL;

    _background = false;
}

std::string _lastAR = " ";

std::string Command::get_last() {
    return _lastAR;
}

void Command::print() {
 /*
  printf("\n\n");
    printf("              COMMAND TABLE                \n");
    printf("\n");
    printf("  #   Simple Commands\n");
    printf("  --- ----------------------------------------------------------\n");

    int i = 0;
    // iterate over the simple commands and print them nicely
    for ( auto & simpleCommand : _simpleCommands ) {
        printf("  %-3d ", i++ );
        simpleCommand->print();
    }

    printf( "\n\n" );
    printf( "  Output       Input        Error        Background\n" );
    printf( "  ------------ ------------ ------------ ------------\n" );
    printf( "  %-12s %-12s %-12s %-12s\n",
            _outFile?_outFile->c_str():"default",
            _inFile?_inFile->c_str():"default",
            _errFile?_errFile->c_str():"default",
            _background?"YES":"NO");
    printf( "\n\n" );

*/
}

void Command::execute() {
    // Don't do anything if there are no simple commands
    if ( _simpleCommands.size() == 0 ) {
        Shell::prompt();
        return;
    }


    std::string *arg_cd = _simpleCommands[0]->_arguments[0];

    if ( !strcmp(_simpleCommands[0]->_arguments[0]->c_str(), "exit") ) {
         printf("Exiting..\n");
         exit(1);
    }


   if (!strcmp(arg_cd->c_str(), "cd")) {
      if (_simpleCommands[0]->_arguments.size()==1) {
            chdir(getenv("HOME"));
        } else {
            const char * new_dir = _simpleCommands[0]->_arguments[1]->c_str();
            chdir(new_dir);
        }

        clear();
        Shell::prompt();
        return;
    }

    if ( !strcmp(_simpleCommands[0]->_arguments[0]->c_str(), "setenv") ) {
         const char * A = _simpleCommands[0]->_arguments[1]->c_str();
         const char * B = _simpleCommands[0]->_arguments[2]->c_str();
         setenv(A, B, 1);
         clear();
         Shell::prompt();
         return;
    }

    if ( !strcmp(_simpleCommands[0]->_arguments[0]->c_str(), "unsetenv") ) {
         const char * A = _simpleCommands[0]->_arguments[1]->c_str();
         unsetenv(A);
         clear();
         Shell::prompt();
         return;
    }

    // Print contents of Command data structure
    print();

    // Add execution here
    // For every simple command fork a new process
    // Setup i/o redirection
    // and call exec
    int defaultin = dup(0);
    int defaultout = dup(1);
    int defaulterr = dup(2);

    int fin;
    int fout;
    int ferr;

    if (_inFile) {
      const char *in_file = _inFile->c_str();
      fin = open(in_file, O_RDONLY);
    } else {
      fin = dup(defaultin);
    }


    int command_number = _simpleCommands.size();

    for (int i = 0; i < command_number; i++) {

      dup2(fin, 0);
      close(fin);


      if (i == command_number - 1) {

        if (_outFile) {
          const char * out_file = _outFile->c_str();
            if (_flag) {
              fout = open(out_file, O_CREAT | O_WRONLY | O_APPEND, 0664);
            } else {
              fout = open(out_file, O_CREAT | O_WRONLY | O_TRUNC, 0664);
            }
         } else {
            fout = dup(defaultout);
         }

        if (_errFile) {
          const char * err_file = _errFile->c_str();
            if (_flag) {
              ferr = open(err_file, O_CREAT | O_WRONLY | O_APPEND, 0664);
            } else {
              ferr = open(err_file, O_CREAT | O_WRONLY | O_TRUNC, 0664);
            }
         } else {
            ferr = dup(defaulterr);
         }

      dup2(ferr,2);
      close(ferr);

      } else {

        int fpipe[2];
        pipe(fpipe);
        fout = fpipe[1];
        fin = fpipe[0];
      }

      dup2(fout, 1);
      close(fout);

      int pid = fork();

      if (pid < 0){
        perror("fork\n");
        exit(2);
       } else if (pid == 0) {

        if (!strcmp(_simpleCommands[i]->_arguments[0]->c_str(), "printenv")) {
          char **p = environ;
          while (*p != NULL) {
              printf("%s\n", *p);
              p++;
          }
          exit(0);
        }


        int arg_count = _simpleCommands[i]->_arguments.size();
        char ** arguments = new char *[arg_count + 1];
        for (int k = 0; k < arg_count; k++) {
            arguments[k] = (char *)_simpleCommands[i]->_arguments[k]->c_str();

        }
        arguments[arg_count] = NULL;
        execvp(_simpleCommands[i]->_arguments[0]->c_str(), arguments);
        perror("execvp");
        _exit(1);


      } else {
        if (!_background) {
          int temp;
          waitpid(pid, &temp, 0);
          _lastRC = temp;
        } else {
        _lastPID = pid;

        }
    }
}

    dup2(defaultin,0);
    dup2(defaultout,1);
    dup2(defaulterr,2);
    close(defaultin);
    close(defaultout);
    close(defaulterr);

    // Clear to prepare for next command
    clear();

    // Print new prompt
    Shell::prompt();
}


SimpleCommand * Command::_currentSimpleCommand;
Command Command::_currentCommand;



