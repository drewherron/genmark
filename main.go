package main

import "github.com/drewherron/genmark/cmd"

var (
	Version   = "dev"
	BuildTime = "unknown"
	GitCommit = "unknown"
)

func main() {
	cmd.SetVersionInfo(Version, BuildTime, GitCommit)
	cmd.Execute()
}
