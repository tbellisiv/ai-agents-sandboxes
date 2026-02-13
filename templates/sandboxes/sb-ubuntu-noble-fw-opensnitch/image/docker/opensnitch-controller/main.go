package main

import (
	"context"
	"flag"
	"fmt"
	"net"
	"os"
	"os/signal"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	pb "opensnitch-controller/pb"

	"golang.org/x/term"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/peer"
	"google.golang.org/grpc/status"
)

const (
	grey   = "\033[90m"
	green  = "\033[32m"
	red    = "\033[31m"
	yellow = "\033[33m"
	reset  = "\033[0m"
)

type App struct {
	mu            sync.Mutex
	connected     bool
	peerAddr      string
	pendingConn   *pb.Connection
	ruleCh        chan *pb.Rule
	defaultAction string
	dispTimeout   time.Duration
	running       bool
	oldState      *term.State
	logFile       *os.File
	lastPing      time.Time
	healthy       bool
	btnPositions  [4][2]int // [allow, deny, forever, never][start, end]
}

var appInstance *App

func logMsg(format string, args ...any) {
	ts := time.Now().Format("15:04:05")
	msg := fmt.Sprintf(format, args...)
	fmt.Printf("\r\033[K%s%s%s %s\r\n", grey, ts, reset, msg)
	if appInstance != nil && appInstance.logFile != nil {
		fmt.Fprintf(appInstance.logFile, "%s %s\n", ts, msg)
	}
}

func (a *App) setConnected(addr string) {
	a.mu.Lock()
	alreadyConnected := a.connected
	if !alreadyConnected {
		a.connected = true
		a.peerAddr = addr
	}
	a.mu.Unlock()
	if !alreadyConnected {
		logMsg("daemon connected from %s", addr)
	}
}

func (a *App) clearPending() {
	a.mu.Lock()
	defer a.mu.Unlock()
	a.pendingConn = nil
}

func (a *App) getPending() *pb.Connection {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.pendingConn
}

func (a *App) showPrompt(conn *pb.Connection, seconds int) {
	host := conn.DstHost
	if host == "" {
		host = conn.DstIp
	}
	ts := time.Now().Format("15:04:05")
	// Calculate prefix length: "HH:MM:SS ASK host:port [proto] path "
	prefix := fmt.Sprintf("%s ASK %s:%d [%s] %s ", ts, host, conn.DstPort, conn.Protocol, conn.ProcessPath)
	pos := len(prefix) + 1 // +1 for 1-based column
	a.btnPositions[0] = [2]int{pos, pos + 6}            // (A)llow
	a.btnPositions[1] = [2]int{pos + 8, pos + 8 + 5}    // (D)eny
	a.btnPositions[2] = [2]int{pos + 15, pos + 15 + 8}  // (F)orever
	a.btnPositions[3] = [2]int{pos + 25, pos + 25 + 6}  // (N)ever
	fmt.Printf("\r\033[K%s%s%s %sASK%s %s:%d [%s] %s %s(A)llow%s %s(D)eny%s %s(F)orever%s %s(N)ever%s %s%ds%s",
		grey, ts, reset, yellow, reset,
		host, conn.DstPort, conn.Protocol, conn.ProcessPath,
		green, reset, red, reset, green, reset, red, reset, grey, seconds, reset)
	if a.logFile != nil {
		fmt.Fprintf(a.logFile, "%s ASK %s:%d [%s] %s\n",
			ts, host, conn.DstPort, conn.Protocol, conn.ProcessPath)
	}
}

func (a *App) updateCountdown(conn *pb.Connection, seconds int) {
	host := conn.DstHost
	if host == "" {
		host = conn.DstIp
	}
	ts := time.Now().Format("15:04:05")
	// Recalculate button positions (terminal may have resized)
	prefix := fmt.Sprintf("%s ASK %s:%d [%s] %s ", ts, host, conn.DstPort, conn.Protocol, conn.ProcessPath)
	pos := len(prefix) + 1
	a.btnPositions[0] = [2]int{pos, pos + 6}
	a.btnPositions[1] = [2]int{pos + 8, pos + 8 + 5}
	a.btnPositions[2] = [2]int{pos + 15, pos + 15 + 8}
	a.btnPositions[3] = [2]int{pos + 25, pos + 25 + 6}
	fmt.Printf("\r\033[K%s%s%s %sASK%s %s:%d [%s] %s %s(A)llow%s %s(D)eny%s %s(F)orever%s %s(N)ever%s %s%ds%s",
		grey, ts, reset, yellow, reset,
		host, conn.DstPort, conn.Protocol, conn.ProcessPath,
		green, reset, red, reset, green, reset, red, reset, grey, seconds, reset)
}

func (a *App) hidePrompt() {
	fmt.Print("\r\033[K")
}

func (a *App) recordPing() {
	a.mu.Lock()
	a.lastPing = time.Now()
	wasHealthy := a.healthy
	a.healthy = true
	a.mu.Unlock()
	if !wasHealthy {
		logMsg("%sHEALTH%s connection restored", green, reset)
	}
}

func (a *App) checkHealth() {
	a.mu.Lock()
	lastPing := a.lastPing
	wasHealthy := a.healthy
	connected := a.connected
	a.mu.Unlock()

	if !connected || lastPing.IsZero() {
		return
	}

	stale := time.Since(lastPing) > 10*time.Second
	if stale && wasHealthy {
		a.mu.Lock()
		a.healthy = false
		a.mu.Unlock()
		logMsg("%sHEALTH%s connection stale (no ping for 10s)", yellow, reset)
	}
}

func (a *App) makeRule(action, duration string, conn *pb.Connection) *pb.Rule {
	var op *pb.Operator
	var label string
	if conn.DstHost != "" {
		escaped := strings.ReplaceAll(conn.DstHost, ".", "\\.")
		pattern := fmt.Sprintf("^(.*\\.)?%s$", escaped)
		op = &pb.Operator{Type: "regexp", Operand: "dest.host", Data: pattern}
		label = conn.DstHost
	} else {
		op = &pb.Operator{Type: "simple", Operand: "dest.ip", Data: conn.DstIp}
		label = conn.DstIp
	}
	return &pb.Rule{
		Name:     fmt.Sprintf("%s-%s", action, label),
		Enabled:  true,
		Action:   action,
		Duration: duration,
		Operator: op,
	}
}

func (a *App) handleAction(key byte) {
	conn := a.getPending()
	if conn == nil {
		return
	}
	var rule *pb.Rule
	var actionStr string
	var color string
	switch key {
	case 'a', 'A':
		rule = a.makeRule("allow", "until restart", conn)
		actionStr = "ALLOW"
		color = green
	case 'd', 'D':
		rule = a.makeRule("deny", "until restart", conn)
		actionStr = "DENY"
		color = red
	case 'f', 'F':
		rule = a.makeRule("allow", "always", conn)
		actionStr = "FOREVER"
		color = green
	case 'n', 'N':
		rule = a.makeRule("deny", "always", conn)
		actionStr = "NEVER"
		color = red
	default:
		return
	}
	if rule != nil {
		host := conn.DstHost
		if host == "" {
			host = conn.DstIp
		}
		a.hidePrompt()
		ts := time.Now().Format("15:04:05")
		fmt.Printf("%s%s%s %sASK%s %s%s%s %s:%d [%s] %s\r\n",
			grey, ts, reset, yellow, reset, color, actionStr, reset,
			host, conn.DstPort, conn.Protocol, conn.ProcessPath)
		if a.logFile != nil {
			fmt.Fprintf(a.logFile, "%s ASK %s %s:%d [%s] %s\n",
				ts, actionStr, host, conn.DstPort, conn.Protocol, conn.ProcessPath)
		}
		a.clearPending()
		select {
		case a.ruleCh <- rule:
		default:
		}
	}
}

type uiServer struct {
	pb.UnimplementedUIServer
	app *App
}

func (s *uiServer) Ping(ctx context.Context, req *pb.PingRequest) (*pb.PingReply, error) {
	addr := "unknown"
	if p, ok := peer.FromContext(ctx); ok {
		addr = p.Addr.String()
	}
	s.app.setConnected(addr)
	s.app.recordPing()
	return &pb.PingReply{Id: req.Id}, nil
}

func (s *uiServer) AskRule(ctx context.Context, conn *pb.Connection) (*pb.Rule, error) {
	seconds := int(s.app.dispTimeout.Seconds())
	s.app.mu.Lock()
	s.app.pendingConn = conn
	s.app.mu.Unlock()
	s.app.showPrompt(conn, seconds)

	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()
	deadline := time.After(s.app.dispTimeout)

	for {
		select {
		case rule := <-s.app.ruleCh:
			return rule, nil
		case <-ticker.C:
			seconds--
			if seconds >= 0 && s.app.getPending() != nil {
				s.app.updateCountdown(conn, seconds)
			}
		case <-deadline:
			s.app.clearPending()
			host := conn.DstHost
			if host == "" {
				host = conn.DstIp
			}
			s.app.hidePrompt()
			ts := time.Now().Format("15:04:05")
			fmt.Printf("%s%s%s %sASK%s %sTIMEOUT%s %s:%d [%s] %s\r\n",
				grey, ts, reset, yellow, reset, grey, reset,
				host, conn.DstPort, conn.Protocol, conn.ProcessPath)
			if s.app.logFile != nil {
				fmt.Fprintf(s.app.logFile, "%s ASK TIMEOUT %s:%d [%s] %s\n",
					ts, host, conn.DstPort, conn.Protocol, conn.ProcessPath)
			}
			return nil, status.Error(codes.DeadlineExceeded, "timeout")
		}
	}
}

func (s *uiServer) Subscribe(ctx context.Context, cfg *pb.ClientConfig) (*pb.ClientConfig, error) {
	logMsg("daemon subscribed: %s v%s", cfg.Name, cfg.Version)
	return &pb.ClientConfig{
		Id:      cfg.Id,
		Name:    cfg.Name,
		Version: cfg.Version,
		Config:  fmt.Sprintf(`{"DefaultAction":"%s"}`, s.app.defaultAction),
	}, nil
}

func (s *uiServer) Notifications(stream pb.UI_NotificationsServer) error {
	for {
		_, err := stream.Recv()
		if err != nil {
			return err
		}
	}
}

func (s *uiServer) PostAlert(ctx context.Context, alert *pb.Alert) (*pb.MsgResponse, error) {
	var color, level string
	switch alert.Type {
	case pb.Alert_ERROR:
		color, level = red, "ERR"
	case pb.Alert_WARNING:
		color, level = yellow, "WARN"
	default:
		color, level = grey, "INFO"
	}
	what := alert.What.String()
	data := ""
	if alert.GetText() != "" {
		data = alert.GetText()
	}
	logMsg("%s%s%s [%s] %s", color, level, reset, what, data)
	return &pb.MsgResponse{Id: alert.Id}, nil
}

func main() {
	addr := flag.String("addr", "127.0.0.1:50051", "Listen address")
	defaultAction := flag.String("default", "deny", "Default action")
	timeout := flag.Int("timeout", 60, "Disposition timeout (seconds)")
	logfile := flag.String("logfile", "", "Log file path")
	flag.Parse()

	app := &App{
		ruleCh:        make(chan *pb.Rule, 1),
		defaultAction: *defaultAction,
		dispTimeout:   time.Duration(*timeout) * time.Second,
		running:       true,
		healthy:       true,
	}
	appInstance = app

	if *logfile != "" {
		f, err := os.OpenFile(*logfile, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Failed to open log file: %v\n", err)
			os.Exit(1)
		}
		app.logFile = f
		defer f.Close()
	}

	var listener net.Listener
	var err error

	if strings.HasPrefix(*addr, "unix://") {
		sockPath := strings.TrimPrefix(*addr, "unix://")
		os.Remove(sockPath)
		listener, err = net.Listen("unix", sockPath)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Listen error: %v\r\n", err)
			os.Exit(1)
		}
		os.Chmod(sockPath, 0666)
		logMsg("listening on unix://%s", sockPath)
	} else {
		listener, err = net.Listen("tcp", *addr)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Listen error: %v\r\n", err)
			os.Exit(1)
		}
		logMsg("listening on %s", *addr)
	}

	grpcServer := grpc.NewServer()
	pb.RegisterUIServer(grpcServer, &uiServer{app: app})

	go grpcServer.Serve(listener)

	go func() {
		ticker := time.NewTicker(5 * time.Second)
		defer ticker.Stop()
		for app.running {
			<-ticker.C
			app.checkHealth()
		}
	}()

	oldState, err := term.MakeRaw(int(os.Stdin.Fd()))
	if err == nil {
		app.oldState = oldState
		defer term.Restore(int(os.Stdin.Fd()), oldState)
	}

	fmt.Print("\033[?1000h\033[?1006h")
	defer fmt.Print("\033[?1000l\033[?1006l")

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	mouseRe := regexp.MustCompile(`\033\[<(\d+);(\d+);(\d+)([mM])`)

	go func() {
		buf := make([]byte, 32)
		for app.running {
			n, err := os.Stdin.Read(buf)
			if err != nil || n == 0 {
				continue
			}
			data := string(buf[:n])
			if n == 1 && buf[0] == 3 {
				sigCh <- syscall.SIGINT
				return
			}
			if matches := mouseRe.FindStringSubmatch(data); matches != nil {
				btn, _ := strconv.Atoi(matches[1])
				if btn == 0 && matches[4] == "m" {
					col, _ := strconv.Atoi(matches[2])
					if app.getPending() != nil {
						for i, pos := range app.btnPositions {
							if col >= pos[0] && col <= pos[1] {
								app.handleAction([]byte{'a', 'd', 'f', 'n'}[i])
								break
							}
						}
					}
				}
				continue
			}
			if n == 1 {
				key := buf[0]
				if key == 'a' || key == 'A' || key == 'd' || key == 'D' ||
					key == 'f' || key == 'F' || key == 'n' || key == 'N' {
					app.handleAction(key)
				}
			}
		}
	}()

	<-sigCh
	app.running = false
	fmt.Print("\r\033[K")
	logMsg("shutting down")
	grpcServer.Stop()
}
