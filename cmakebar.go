/*
 * cmakebar - a Cmake progress bar
 * This code takes output from 'build_technology make' as input on stdin
 * and displays a progress bar in the terminal.  This is untested with
 * general cmake output.
 *
 * Usage:
 *
 *     build_technology make 2>&1 | cmakebar
 *     build_technology make 2>&1 | cmakebar --out cmake.log
 *     build_technology make 2>&1 | cmakebar -o
 *     cat cmake.log | cmakebar --replay
 *
 * Todo:
 *  [ ] Color/style options
 *  [ ] Test on OSX, cygwin, DOS
 *  [ ] Stress test with cmake configuration errors, etc.
 *
 * Author: Tracy Atteberry
 * Date:   Spring, 2014
 */
package main

import (
    "errors"
    "flag"
    "fmt"
    "os"
    "regexp"
    "runtime"
    "strconv"
    "strings"
    "syscall"
    "time"
    "unsafe"
    "bufio"
)

const (
    DEFAULT_WIDTH = 20 // it should never come to this
)

var logFile string
var logOutput, showHelp, replay bool

func init() {
    flag.BoolVar(&showHelp, "help", false, "show help")
    flag.BoolVar(&logOutput, "o", false, "log output to file [default: cmake.log]")
    flag.BoolVar(&replay, "replay", false, "add sleep delays for replay")
    flag.BoolVar(&replay, "r", false, "add sleep delays for replay (shortcut)")
    flag.StringVar(&logFile, "out", "", "log to file name")
}

func main() {
    var f *os.File
    var err error
    flag.Parse()

    // Bail if nothing on stdin or help is aked for.
    if !showHelp && !DescriptorInUse(syscall.Stdin) {
        showHelp = true
    }

    if showHelp {
        fmt.Println(`
Cmakebar - a terminal progress bar for cmake

  Cmakebar creates a command line progress bar given cmake
  build output as input on stdin.

      build_technology make 2>&1 | cmakebar
      build_technology make 2>&1 | cmakebar --out cmake.log
      build_technology make 2>&1 | cmakebar -o
      cat cmake.log | cmakebar

  If nothing is provided on stdin you will see this message.

Options:
    `)
        flag.PrintDefaults()
        fmt.Print("\n")
        os.Exit(2)
    }

    if len(logFile) > 0 {
        logOutput = true
    }

    if logOutput {
        if len(logFile) == 0 {
            logFile = "cmake.log"
        }
        f, err = os.Create(logFile)
        if err != nil {
            os.Stderr.WriteString("Could not create file: "+logFile)
            os.Exit(1)
        }
        defer f.Close()
    }

    os.Stdout.Write([]byte("\n"))
    percentRe := regexp.MustCompile(`^\[[\s]*([\d]+)%\]`)
    failedRe := regexp.MustCompile(`^Failed Modules`)
    done := false
    cols, _ := TerminalWidth()
    start := time.Now()
    reader := bufio.NewReader(os.Stdin)

    for {
        line, err := reader.ReadString('\n')
        if err != nil {
            // check if err == io.EOF
            break
        }
        group := percentRe.FindSubmatch([]byte(line))
        if len(group) > 0 {
            i, err := strconv.Atoi(string(group[1]))
            if err == nil {
                if replay {
                    time.Sleep(time.Millisecond * 30)
                }
                progress(i, 100, cols, time.Since(start))
            }
        }
        if failedRe.MatchString(line) {
            fmt.Print("\n\n")
            done = true
        }
        if done {
            fmt.Print(line)
        }
        if logOutput {
            _, err := f.WriteString(line)
            if err != nil {
                os.Stderr.WriteString("Can't write to log file\n")
                os.Exit(1)
            }
        }
    }

    os.Stdout.Write([]byte("\n"))
    elapsed := time.Since(start)
    fmt.Printf("Elpased time: %v\n\n", elapsed)
    f.Sync()
}


func Bold(str string) string {
    return "\033[1m" + str + "\033[0m"
}

func HighlightDone(str string) string {
    return "\033[46;1m" + str + "\033[0m"
}

func HighlightTodo(str string) string {
    return "\033[47;1m" + str + "\033[0m"
}


func durationString(d time.Duration) string {
    var f string
    n  := int(d)
    ms := n / int(time.Millisecond) % 1000
    s  := n / int(time.Second) % 60
    m  := n / int(time.Minute) % 60
    h  := n / int(time.Hour)
    if n > int(time.Hour) {
        f = fmt.Sprintf("%dh %.2dm %.2ds %.3dms", h, m, s, ms)
    } else if n > int(time.Minute) {
        f = fmt.Sprintf("%.2dm %.2ds %.3dms", m, s, ms)
    } else if n > int(time.Second) {
        f = fmt.Sprintf("%.2ds %.3dms", s, ms)
    } else {
        f = fmt.Sprintf("%.3dms", ms)
    }
    return f
}

func progress(current, total, cols int, elapsed time.Duration) string {
    var line string
    prefix := fmt.Sprintf(" %d%%", int(100.0 * float32(current) / float32(total)))
    postfix := durationString(elapsed)
    bar_start := " ["
    bar_end := "] "

    bar_size := cols - len(prefix + bar_start + bar_end + postfix)
    amount := int(float32(current) / (float32(total) / float32(bar_size)))
    remain := bar_size - amount

    // try to degrade nicely for small cols
    if remain < 0 {
       if cols > len(prefix) {
           line = prefix
       }
    } else {
        bar := HighlightDone(strings.Repeat(" ", amount)) + HighlightTodo(strings.Repeat(" ", remain))
        line = Bold(prefix) + bar_start + bar + bar_end + postfix
    }

    os.Stdout.Write([]byte(line + "\r"))
    os.Stdout.Sync()
    return line
}

func DescriptorInUse(fd int) bool {
    _, _, err := TerminalSize(fd)
    return err != nil
}

func TerminalSize(fd int) (rows, cols int, err error) {
    // Dimensions: Row, Col, XPixel, YPixel
    var dimensions [4]uint16
    const (
        TIOCGWINSZ_OSX = 1074295912
    )

    tio := syscall.TIOCGWINSZ
    if runtime.GOOS == "darwin" {
        tio = TIOCGWINSZ_OSX
    }

    r1, _, err := syscall.Syscall(
        syscall.SYS_IOCTL,
        uintptr(fd),
        uintptr(tio),
        uintptr(unsafe.Pointer(&dimensions)),
    )

    // fmt.Println(fd, dimensions)

    if int(r1) == -1 {
        return -1, -1, errors.New("TerminalSize error")
    }

    return int(dimensions[0]), int(dimensions[1]), nil
}

func TerminalWidth() (int, error) {

    // check all three standard file descriptors
    // just to be safely paranoid (did you hear that?)
    _, width, err := TerminalSize(syscall.Stdout)

    if err != nil {
        _, width, err = TerminalSize(syscall.Stdin)
    }
    if err != nil {
        _, width, err = TerminalSize(syscall.Stderr)
    }
    if err != nil {
        return DEFAULT_WIDTH, errors.New("GetWinsize error")
    }
    return width, err
}


