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
		logger.Title("Started at : %d", clock.Now())

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
		//fmt.Println(fmt.Sprintf("context.CNBPath : %s", context.CNBPath))

		//content := []byte("temporary file's content")
		//tmpfile, err := ioutil.TempFile(fmt.Sprintf("%s/bin", context.CNBPath), "user_build_script")
		//if err != nil {
		//	log.Fatal(err)
		//}
		//
		//defer os.Remove(tmpfile.Name()) // clean up
		//
		//if _, err := tmpfile.Write(content); err != nil {
		//	log.Fatal(err)
		//}

		//// cat for debugging
		//cmd, err := exec.Command("cat",
		//	fmt.Sprintf("%s/bin/user_build_script", context.CNBPath)).Output()
		//output := string(cmd)
		//if err != nil {
		//	fmt.Printf("Eror %s", err)
		//}
		//fmt.Println(output)

		executionDuration, err := clock.Measure(func() error {
			cmd2, err2 := exec.Command(fmt.Sprintf("%s/bin/user_build_script", context.CNBPath)).Output()
			exec_output := string(cmd2)
			if err != nil {
				fmt.Printf("Eror %s", err2)
				log.Fatal(err2)
			}
			fmt.Println(exec_output)
			return nil
		})

		fmt.Printf("Execution duration: %s", executionDuration)

		gitOpsDuration, err := clock.Measure(func() error {
			gitInit(context, logger)
			gitCommitIncludeSignerOperation(context, logger)
			gitCommitOperation(context, logger)
			return nil
		})

		fmt.Printf("Git ops duration: %s", gitOpsDuration)

		//build_script_content, e := pkger.Open("/assets/user_build_script")
		//if e != nil {
		//	fmt.Println("Error: ", "Error occurred opening pkger script")
		//	log.Fatal(err)
		//}
		//
		//io.Copy(os.Stdout, build_script_content)

		// Commit the changes performed by this buildpack into local git project

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
	}
}

func gitCommand(arg ...string) {
	gitPath, err := exec.LookPath("git")
	if err != nil {
		fmt.Printf("Error with git: %s", "there's none")
		log.Fatal(err)
	}
	commit_cmd, err := exec.Command(gitPath, arg...).CombinedOutput()
	exec_output := string(commit_cmd)
	fmt.Println(exec_output)
	if err != nil {
		log.Fatal(err)
	}
}

func gitInit(context packit.BuildContext, logger LogEmitter) {

	filename := context.WorkingDir + "/.gitignore"
	f, err := os.OpenFile(filename, os.O_APPEND|os.O_WRONLY|os.O_CREATE, 0600)
	if err != nil {
		panic(err)
	}

	defer f.Close()

	if _, err = f.WriteString("bin/*"); err != nil {
		panic(err)
	}
}

func gitCommitIncludeSignerOperation(context packit.BuildContext, logger LogEmitter) {

	gitCommand("config", "--global", "user.email", "task-builder@laraboot.io")
	gitCommand("config", "--global", "user.name", "task-builder")

}
func gitCommitOperation(context packit.BuildContext, logger LogEmitter) {

	logger.Title("Committing changes introduced by %s@%s",
		context.BuildpackInfo.Name,
		context.BuildpackInfo.Version)

	commitMessage := fmt.Sprintf("Task %s@%s contribution",
		context.BuildpackInfo.Name,
		context.BuildpackInfo.Version)

	gitCommand("add", ".")
	gitCommand("commit", "-m", commitMessage)

}
