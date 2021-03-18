package main

import (
	"fmt"
	"github.com/cloudfoundry/packit"
	"github.com/markbates/pkger"
	"github.com/paketo-buildpacks/packit/chronos"
	"io"
	laraboot "laraboot-buildpacks/poc/laraboot"
	"os"
)

func main() {

	logEmitter := laraboot.NewLogEmitter(os.Stdout)

	info, err := pkger.Stat("/assets/user_build_script")
	if err != nil {
		fmt.Println("Error: ", "Error occurred reading pkger script")
		return
	}

	fmt.Println("Name: ", info.Name())
	fmt.Println("Size: ", info.Size())
	fmt.Println("Mode: ", info.Mode())
	fmt.Println("ModTime: ", info.ModTime())

	content, e := pkger.Open("/assets/user_build_script")
	if e != nil {
		fmt.Println("Error: ", "Error occurred reading pkger script")
		return
	}

	io.Copy(os.Stdout, content)

	packit.Build(laraboot.Build(
		logEmitter,
		chronos.DefaultClock))
}
