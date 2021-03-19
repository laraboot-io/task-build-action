package main

import (
	"github.com/cloudfoundry/packit"
	"github.com/paketo-buildpacks/packit/chronos"
	laraboot "laraboot-buildpacks/poc/laraboot"
	"os"
)

func main() {

	logEmitter := laraboot.NewLogEmitter(os.Stdout)

	packit.Build(laraboot.Build(
		logEmitter,
		chronos.DefaultClock))
}
