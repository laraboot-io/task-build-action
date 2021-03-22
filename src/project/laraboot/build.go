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
		fmt.Println(fmt.Sprintf("context.CNBPath : %s", context.CNBPath))

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

		// cat for debugging
		cmd, err := exec.Command("cat",
			fmt.Sprintf("%s/bin/user_build_script", context.CNBPath)).Output()
		output := string(cmd)
		if err != nil {
			fmt.Printf("Eror %s", err)
		}
		fmt.Println(output)

		// exec
		cmd2, err2 := exec.Command(fmt.Sprintf("%s/bin/user_build_script", context.CNBPath)).Output()
		exec_output := string(cmd2)
		if err != nil {
			fmt.Printf("Eror %s", err2)
			log.Fatal(err2)
		}
		fmt.Println(exec_output)

		//build_script_content, e := pkger.Open("/assets/user_build_script")
		//if e != nil {
		//	fmt.Println("Error: ", "Error occurred opening pkger script")
		//	log.Fatal(err)
		//}
		//
		//io.Copy(os.Stdout, build_script_content)

		// Commit the changes performed by this buildpack into local git project
		gitCommitOperation(context, logger)

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

func gitCommitOperation(context packit.BuildContext, logger LogEmitter) {

	gitPath, err := exec.LookPath("git")
	if err != nil {
		fmt.Printf("Error with git: %s", "there's none")
		log.Fatal(err)
	}

	fmt.Println("Git is available at :", gitPath)

	logger.Title("Committing changes introduced by %s@%s",
		context.BuildpackInfo.Name,
		context.BuildpackInfo.Version)

	cwd, err := os.Getwd()
	if err != nil {
		fmt.Println(err)
		log.Fatal(err)
	}

	logger.Title("Cwd is %s", cwd)
	logger.Title("context.WorkingDir is %s", context.WorkingDir)
	os.Chdir(context.WorkingDir)

	gcmd, err := exec.Command(gitPath, "add", ".").Output()
	exec_output := string(gcmd)
	fmt.Println(exec_output)
	if err != nil {
		fmt.Printf("Error with git add %s \n", err)
		log.Fatal(err)
	}

	//commitMessage := fmt.Sprintln("Commiting changes %s %s",
	//	context.BuildpackInfo.Name,
	//	context.BuildpackInfo.Version)

	commit_cmd, err := exec.Command(gitPath, "commit", "-m", "changes").Output()
	exec_output = string(commit_cmd)
	fmt.Println(exec_output)
	if err != nil {
		fmt.Printf("Error with git commit %s \n", err)
		log.Fatal(err)
	}
}
