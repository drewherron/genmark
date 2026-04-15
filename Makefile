VERSION ?= 0.2.1
BUILD_TIME := $(shell date -u '+%Y-%m-%d %H:%M:%S UTC')
GIT_COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")

LDFLAGS := -X 'main.Version=$(VERSION)' \
           -X 'main.BuildTime=$(BUILD_TIME)' \
           -X 'main.GitCommit=$(GIT_COMMIT)'

.PHONY: build test clean release-all clean-dist

build:
	go build -ldflags "$(LDFLAGS)" -o genmark .

test:
	go test ./...

clean:
	rm -f genmark

release-all: clean-dist
	mkdir -p dist
	GOOS=linux   GOARCH=amd64 go build -trimpath -ldflags "-s -w $(LDFLAGS)" -o dist/genmark-linux-amd64 .
	GOOS=windows GOARCH=amd64 go build -trimpath -ldflags "-s -w $(LDFLAGS)" -o dist/genmark-windows-amd64.exe .
	GOOS=darwin  GOARCH=amd64 go build -trimpath -ldflags "-s -w $(LDFLAGS)" -o dist/genmark-macos-intel .
	GOOS=darwin  GOARCH=arm64 go build -trimpath -ldflags "-s -w $(LDFLAGS)" -o dist/genmark-macos-arm64 .

clean-dist:
	rm -rf dist/
