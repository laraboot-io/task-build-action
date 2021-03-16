package main

import (
	"github.com/cloudfoundry/packit"
	"github.com/markbates/pkger"
	// "github.com/paketo-buildpacks/packit"
	// "github.com/paketo-buildpacks/packit/cargo"
	"github.com/paketo-buildpacks/packit/chronos"
	// "github.com/paketo-buildpacks/packit/postal"
	"fmt"
	laraboot "laraboot-buildpacks/poc/laraboot"
	"os"
)

func main() {

	// nvmrcParser := nodeengine.NewNvmrcParser()
	// buildpackYMLParser := nodeengine.NewBuildpackYMLParser()
	logEmitter := laraboot.NewLogEmitter(os.Stdout)
	// entryResolver := laraboot.NewPlanEntryResolver(logEmitter)
	// postal & cargo
	// dependencyManager := postal.NewService(cargo.NewTransport())
	// environment := nodeengine.NewEnvironment(logEmitter)
	// planRefinery := nodeengine.NewPlanRefinery()

	info, err := pkger.Stat("/assets/user_build_script")
	if err != nil {
		fmt.Println("Error: ", "Error occurred reading pkger script")
		return
	}
	//io.Copy(os.Stdout, info)

	fmt.Println("Name: ", info.Name())
	fmt.Println("Size: ", info.Size())
	fmt.Println("Mode: ", info.Mode())
	fmt.Println("ModTime: ", info.ModTime())

	packit.Build(laraboot.Build(
		logEmitter,
		chronos.DefaultClock))
}
