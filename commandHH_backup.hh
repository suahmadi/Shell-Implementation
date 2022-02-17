#ifndef command_hh
#define command_hh

#include "simpleCommand.hh"

// Command Data Structure

struct Command {
  std::vector<SimpleCommand *> _simpleCommands;
  std::string * _outFile;
  std::string * _inFile;
  std::string * _errFile;
  static std::string _relativePath;
  bool _background;
  bool _flag;
  int _lastPID;

  Command();
  void insertSimpleCommand( SimpleCommand * simpleCommand );

  void clear();
  void print();
  void execute();

  static SimpleCommand *_currentSimpleCommand;
  static Command _currentCommand;
  static void setRelativePath(char *relativePath);
  static int _returnCode;
};

#endif
