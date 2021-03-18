package laraboot

import (
	"encoding/json"
	"fmt"
	"github.com/cloudfoundry/packit"

	"os"
	"path/filepath"
)

type DependenciesArray struct {
	Dependencies []DependencyType `json:"dependencies"`
}

type DependencyType struct {
	Name    string `json:"name"`
	Version string `json:"version"`
	//MsgBodyID         int64   `json:"msg_body_id,omitempty"`
}

func Detect(TaskName string) packit.DetectFunc {
	return func(context packit.DetectContext) (packit.DetectResult, error) {

		// The DetectContext includes a WorkingDir field that specifies the
		// location of the application source code. This field can be combined with
		// other paths to find and inspect files included in the application source
		// code that is provided to the buildpack.
		file, err := os.Open(filepath.Join(context.WorkingDir, "task.json"))

		if err != nil {
			fmt.Printf("Spec file '%s' was not found", filepath.Join(context.WorkingDir, "task.json"))
			return packit.DetectResult{}, fmt.Errorf("task file not found")
		}

		var config struct {
			DependenciesArray
		}

		err = json.NewDecoder(file).Decode(&config)
		if err != nil {
			fmt.Printf("	--> An error ocurred while parsing laraboot file: '%s'", err)
			return packit.DetectResult{}, fmt.Errorf("invalid laraboot file")
		}

		// box := packr.New("user_scripts", "./assets")

		//_, cerr := pkger.Create("/laraboot_user_script_build.sh")
		//
		//if cerr != nil {
		//	return packit.DetectResult{}, fmt.Errorf("An error ocurred calling pkger")
		//}

		// Once the file has been parsed, the detect phase can return
		// a result that indicates the provision of xxxxx and the requirement of
		// xxxxx. As can be seen below, the BuildPlanRequirement may also include
		// optional metadata information to such as the source of the version
		// information for a given requirement.

		var requirements []packit.BuildPlanRequirement

		// Append self one
		requirements = append(requirements, packit.BuildPlanRequirement{
			Name: TaskName,
			Metadata: map[string]string{
				"version-source": "task.json",
			},
		})

		requirements = append(requirements, resolveDependenciesToRequirements(config.DependenciesArray)...)

		return packit.DetectResult{
			Plan: packit.BuildPlan{
				Provides: []packit.BuildPlanProvision{
					{
						Name: TaskName,
					},
				},
				Requires: requirements,
			},
		}, nil
	}
}

func resolveDependenciesToRequirements(deps DependenciesArray) []packit.BuildPlanRequirement {
	var requirements []packit.BuildPlanRequirement

	for _, s := range deps.Dependencies {
		requirements = append(requirements, packit.BuildPlanRequirement{
			Name:    s.Name,
			Version: s.Version,
			Metadata: map[string]string{
				"launch": "true",
				"build":  "true",
			},
		})
	}
	return requirements
}
