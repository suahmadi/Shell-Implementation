#ifndef command_hh
#define command_hh

#include "simpleCommand.hh"



// Command Data Structure

struct Command {
  std::vector<SimpleCommand *> _simpleCommands;
  std::string * _outFile;
  std::string * _inFile;
  std::string * _errFile;
  bool _background;
  bool _flag;
  int _lastPID;
  int _lastRC;
  std::string get_last();

  Command();
  void insertSimpleCommand( SimpleCommand * simpleCommand );

  void clear();
  void print();
  void execute();
  void prompt();

  static SimpleCommand *_currentSimpleCommand;
  static Command _currentCommand;

};

#endif

