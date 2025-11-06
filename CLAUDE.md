# Project Description
- this is plain Electron project with a few modification which is supposed to allow execution of
  VSCode extensions is workers
- in order to achieve this, v8 JS engine and electron infrastructural JS code is patched

# V8 Patch Description
- changed logic is located mostly in `/home/kishmakov/build/bl/src/v8/src/inspector/v8-debugger.cc`
  and `/home/kishmakov/build/bl/src/v8/src/builtins/builtins-intl.cc`
- there are new JS builtins command introduced in `builtins-intl.cc` file
- commands `WaitCall` and `WaitType` are used for pausing extension worker thread when it
  needs to get information from extension host thread
- commands `ResumeCall` and `ResumeType` are used for signalling from extension host thread
  that requested information is ready
- `IsThreadPaused` and `RegisterWorker` are used for coordination
- `RunOnPaused` and `RunOnCalled` are used for synchronous computation of the extension function on worker thread,
   when it needed by main extension host thread
  `CheckObjectFullyConstructed` is used for fighting unfinished this leaking handling
- in `v8-debugger.cc` there are number of new functions like `V8Debugger::pauseWorker` and `V8Debugger::resumeWorker` to pause
  and resume worker thread, and also the main function `V8Debugger::processTaskOnStack` for processing task passed from
  main extension host thread

# Electron Patch Description
- JS modification located mostly `/home/kishmakov/build/bl/src/third_party/electron_node/lib/internal/worker`
- `context.js` is for context of execution of current JS
- `communication.js` contains functions which send request to another side over port
- `serialization.js` is for object serialization before transmission
- `extension.js` is the main file, with the rest of the logic
