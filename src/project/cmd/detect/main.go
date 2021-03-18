package main

import (
	"fmt"
	"github.com/cloudfoundry/packit"
	"laraboot-buildpacks/poc/laraboot"
)

// To be replaced using go generate
var TaskName = "unset"

func main() {
	fmt.Printf("Detecting %s", TaskName)
	packit.Detect(laraboot.Detect(TaskName))
}
