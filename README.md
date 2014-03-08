cmakebar
========

A simple terminal progress bar for cmake

Cmakebar takes output from cmake and displays a progress bar in the terminal.
In fact, this should work for any output with lines matching `^\[\s*\d+%\]`.

### Usage:

    build_technology make 2>&1 | cmakebar
    build_technology make 2>&1 | cmakebar --out cmake.log
    build_technology make 2>&1 | cmakebar -o
    cat cmake.log | cmakebar --replay

My local cmake script is called `build_technology`.  Your mileage may vary.


### Options:
    
    -help=false    : show help
    -est=false     : show estimated time remaining
    -e=false       : show estimated time remaining (shortcut)
    -no-style=false: turn off colors and bold
    -ns=false      : turn off colors/bold (shortcut)
    -out=""        : log to file name
    -o=false       : log output to file [default: cmake.log]
    -replay=false  : add sleep delays for replay
    -r=false       : add sleep delays for replay (shortcut)


### Todo:
- [ ] Color/style options
- [ ] Test on OSX, cygwin, DOS
- [ ] Stress test with fuzzed input files


### Build and run

```
go build cmakebar.go
./cmakebar --help
cat cmake.log | ./cmakebar --replay
```

The `--replay` option just adds a little sleep delay so that
a replay from file doesn't zip by in a few microseconds.

One interesting thing here is the `DescriptorInUse()` function
that checks to see if there is something on stdin by trying to
request the terminal size using that file descriptor.



