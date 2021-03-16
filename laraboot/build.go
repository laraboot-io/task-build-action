package laraboot

import (
	"fmt"
	"log"

	// "github.com/BurntSushi/toml"
	"github.com/cloudfoundry/packit"
	"github.com/paketo-buildpacks/packit/chronos"
	"github.com/paketo-buildpacks/packit/postal"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
)

//go:generate faux --interface EntryResolver --output fakes/entry_resolver.go
type EntryResolver interface {
	Resolve([]packit.BuildpackPlanEntry) packit.BuildpackPlanEntry
}

//go:generate faux --interface DependencyManager --output fakes/dependency_manager.go
type DependencyManager interface {
	Resolve(path, id, version, stack string) (postal.Dependency, error)
	Install(dependency postal.Dependency, cnbPath, layerPath string) error
}

//go:generate faux --interface EnvironmentConfiguration --output fakes/environment_configuration.go
type EnvironmentConfiguration interface {
	Configure(buildEnv, launchEnv packit.Environment, path string, optimizeMemory bool) error
}

//go:generate faux --interface BuildPlanRefinery --output fakes/build_plan_refinery.go
type BuildPlanRefinery interface {
	BillOfMaterial(dependency postal.Dependency) packit.BuildpackPlan
}

func Build(logger LogEmitter, clock chronos.Clock) packit.BuildFunc {
	return func(context packit.BuildContext) (packit.BuildResult, error) {

		logger.Title("%s %s", context.BuildpackInfo.Name, context.BuildpackInfo.Version)

		//uri := m.Metadata.Dependencies[0].URI
		uri := fmt.Sprintf("https://amply-app.s3.amazonaws.com/scripts/laraboot-%s.tar.bz2", "0.0.1")

		nodeLayer, err := context.Layers.Get("laraboot", packit.BuildLayer)
		if err != nil {
			return packit.BuildResult{}, err
		}

		err = nodeLayer.Reset()
		if err != nil {
			return packit.BuildResult{}, err
		}

		downloadDir, err := ioutil.TempDir("", "downloadDir")
		if err != nil {
			return packit.BuildResult{}, err
		}
		defer os.RemoveAll(downloadDir)

		logger.Process(fmt.Sprintf("Downloading Laraboot scripts from %s\n", uri))

		err = exec.Command("curl",
			uri,
			"-o", filepath.Join(downloadDir, "laraboot.tar.xz"),
		).Run()
		if err != nil {
			return packit.BuildResult{}, err
		}

		fmt.Println("Untaring dependency...")
		err = exec.Command("tar",
			"-xf",
			filepath.Join(downloadDir, "laraboot.tar.xz"),
			"--strip-components=1",
			"-C", nodeLayer.Path,
		).Run()
		if err != nil {
			return packit.BuildResult{}, err
		}

		// nodeLayer.LaunchEnv.Override("LARABOOT_HOME", fmt.Sprintf("%s/laraboot", nodeLayer.Path))

		fmt.Println("Executing user script...")
		fmt.Println(fmt.Sprintf("context.CNBPath : %s", context.CNBPath))

		// cmd, err := exec.Command("ls", fmt.Sprintf("%s/bin/user_build_script", context.CNBPath)).Output()
		// if err != nil {
		// 	fmt.Printf("error %s", err)
		// }
		// output := string(cmd)
		// fmt.Println(output)

		content := []byte("temporary file's content")
		tmpfile, err := ioutil.TempFile(fmt.Sprintf("%s/bin", context.CNBPath), "user_build_script")
		if err != nil {
			log.Fatal(err)
		}

		defer os.Remove(tmpfile.Name()) // clean up

		if _, err := tmpfile.Write(content); err != nil {
			log.Fatal(err)
		}

		cmd, err := exec.Command(fmt.Sprintf("cat %s/bin/user_build_script", context.CNBPath)).Output()
		output := string(cmd)
		fmt.Println(output)
		if err != nil {
			fmt.Printf("Eror %s", err)
		}
		// fmt.Println(output)

		return packit.BuildResult{
			Layers: []packit.Layer{
				{
					Path: nodeLayer.Path,
					LaunchEnv: packit.Environment{
						"LARABOOT_HOME.append": fmt.Sprintf("%s/laraboot", nodeLayer.Path),
						"SOME_VAR.default":     "default-value",
						"SOME_VAR.delim":       "delim-value",
						"SOME_VAR.prepend":     "prepend-value",
						"SOME_VAR.override":    "override-value",
					},
				},
			},
		}, nil

		// return packit.BuildResult{
		// 	Plan: context.Plan,
		// 	Layers: []packit.Layer{
		// 		nodeLayer,
		// 	},
		// }, nil
	}
}
