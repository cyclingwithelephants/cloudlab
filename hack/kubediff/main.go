package main

import (
	"bufio"
	"bytes"
	_ "embed"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"text/template"

	"github.com/pkg/errors"
)

const (
	prDir     = "pr"
	targetDir = "target"
	envsDir   = "manifests/groups"
	levels    = 2 // how many levels to recurse before we get to apps
	tmpPath   = "tmp"
)

//go:embed git-diff-template.txt
var diffRenderTemplate string

type AppConfig struct {
	prDir     string
	targetDir string
	envsDir   string
	levels    int
	writePath string
}

type App struct {
	Config AppConfig
	Logger *log.Logger
}

// getDirectories returns a list of all directories in the given path.
func listDirectories(path string) ([]string, error) {
	var directories []string

	files, err := ioutil.ReadDir(path)
	if err != nil {
		return nil, err
	}

	for _, file := range files {
		// Check if the entry is a directory (excluding the root path itself)
		if file.IsDir() && file.Name() != "." && file.Name() != ".." {
			directories = append(directories, filepath.Join(path, file.Name()))
		}
	}

	return directories, nil
}

func (A *App) listApps(
	checkoutDir string,
	envsDir string,
	levels int,
	appSet map[string]struct{},
) (map[string]struct{}, error) {
	globs := ""
	for i := 0; i < levels; i++ {
		globs += "/*"
	}
	path := envsDir + globs
	A.Logger.Println("Globbing: ", path)

	apps, err := filepath.Glob(path)
	if err != nil {
		return nil, err
	}

	// A.Logger.Println("Found apps: ", apps)
	for _, app := range apps {
		isDir, err := isDirectory(app)
		if err != nil {
			return nil, err
		}
		if !isDir {
			continue
		}
		A.Logger.Println("Found app at: ", app)
		appSet[strings.TrimPrefix(app, checkoutDir+"/")] = struct{}{}
	}
	return appSet, nil
}

// isDirectory checks if the given filepath points to a directory.
func isDirectory(filePath string) (bool, error) {
	fileInfo, err := os.Stat(filePath)
	if err != nil {
		// Return false and the error if there's any issue accessing the file/directory
		return false, err
	}

	// Check if the file is a directory
	return fileInfo.IsDir(), nil
}

func (A *App) buildApps(dir string) (map[string]struct{}, error) {
	// get the list of directories we need to manage
	// we use prDir as we assume no environment will be deleted
	// i.e. it's always additive
	path := dir + "/" + A.Config.envsDir
	envs, err := listDirectories(path)
	A.Logger.Println("Found environments: ", envs)
	if err != nil {
		return nil, err
	}

	apps := make(map[string]struct{})
	for _, env := range envs {
		apps, err = A.listApps(dir, env, levels, apps)
		if err != nil {
			return nil, err
		}
	}

	return apps, nil
}

func PrettyPrint(v interface{}) (err error) {
	b, err := json.MarshalIndent(v, "", "  ")
	if err == nil {
		fmt.Println(string(b))
	}
	return
}

func (A *App) buildAllApps() (map[string]struct{}, error) {
	appPaths := make(map[string]struct{})

	prApps, err := A.buildApps(A.Config.prDir)
	if err != nil {
		return nil, err
	}
	for app := range prApps {
		appPaths[app] = struct{}{}
	}

	targetApps, err := A.buildApps(A.Config.targetDir)
	if err != nil {
		return nil, err
	}
	for app := range targetApps {
		appPaths[app] = struct{}{}
	}
	A.Logger.Println("Found apps: ", PrettyPrint(appPaths))
	return appPaths, nil
}

func (A *App) hasDiff(appPath string) (bool, error) {
	// Check if both directories exist
	dir1 := filepath.Join(A.Config.prDir, appPath)
	dir2 := filepath.Join(A.Config.targetDir, appPath)
	_, err1 := os.Stat(dir1)
	_, err2 := os.Stat(dir2)

	if os.IsNotExist(err1) || os.IsNotExist(err2) {
		// Either directory doesn't exist, consider it as a diff
		return true, nil
	} else if err1 != nil {
		return false, fmt.Errorf("error accessing directory %s: %w", dir1, err1)
	} else if err2 != nil {
		return false, fmt.Errorf("error accessing directory %s: %w", dir2, err2)
	}

	// Compare the contents of the directories
	fileInfos1, err := ioutil.ReadDir(dir1)
	if err != nil {
		return false, fmt.Errorf("error reading directory %s: %w", dir1, err)
	}

	fileInfos2, err := ioutil.ReadDir(dir2)
	if err != nil {
		return false, fmt.Errorf("error reading directory %s: %w", dir2, err)
	}

	if len(fileInfos1) != len(fileInfos2) {
		// Number of entries is different, consider it as a diff
		return true, nil
	}

	// Compare file names and sizes to check for differences
	for i := range fileInfos1 {
		if fileInfos1[i].Name() != fileInfos2[i].Name() || fileInfos1[i].Size() != fileInfos2[i].Size() {
			return true, nil
		}
	}

	// No differences found
	return false, nil
}

func kustomizeBuild(directory string) (string, error) {
	if _, err := os.Stat(directory); os.IsNotExist(err) {
		return "", fmt.Errorf("directory %s does not exist", directory)
	}
	cmd := exec.Command("kustomize", "build", "--enable-helm", directory)
	var out bytes.Buffer
	cmd.Stdout = &out
	err := cmd.Run()
	if err != nil {
		return "", err
	}
	return out.String(), nil
}

func writeStringToFile(path string, data string) error {
	file, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE, 0o644)
	if err != nil {
		return errors.Wrap(err, "could not open file '"+path+"'")
	}
	defer file.Close()

	// Write the data to the file
	_, err = file.WriteString(data)
	return err
}

func (A *App) buildAppForTargetAndPrBranch(appPath string) error {
	paths := []string{
		A.Config.prDir,
		A.Config.targetDir,
	}
	for _, path := range paths {
		kustomzePath := filepath.Join(path, appPath)
		// Create the directory
		dirWritePath := filepath.Join(A.Config.writePath, kustomzePath)
		A.Logger.Println("Creating directory: ", dirWritePath)
		err := os.MkdirAll(dirWritePath, 0o755)
		if err != nil {
			return err
		}
		var yaml string
		if _, err := os.Stat(kustomzePath); os.IsNotExist(err) {
			yaml = ""
		} else {
			yaml, err = kustomizeBuild(kustomzePath)
			if err != nil {
				return err
			}
		}

		// write rendered yaml to file in tmpPath
		fileWritePath := filepath.Join(dirWritePath, "gen.yaml")
		err = writeStringToFile(fileWritePath, yaml)
		if err != nil {
			return err
		}

	}
	return nil

	// tmpPath := filepath.Join(A.Config.tmpPath, appPath)
}

func (A *App) renderDiff(appPath string) (string, error) {
	targetPath := filepath.Join(A.Config.writePath, A.Config.targetDir, appPath)
	prPath := filepath.Join(A.Config.writePath, A.Config.prDir, appPath)
	args := []string{"diff", "--no-index", prPath, targetPath, "--color=always"}
	A.Logger.Println("Running git diff with args: ", args)
	cmd := exec.Command("git", args...)
	var out bytes.Buffer
	var outErr bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &outErr
	//err := cmd.Run()
	//if err != nil {
	//	A.Logger.Println("Could not run git diff: ", outErr.String(), out.String())
	//	return "", errors.Wrap(err, "Could not run git diff")
	//}
	//if len(outErr.String()) > 0 {
	//	A.Logger.Println("Error running git diff: ", outErr.String(), out.String())
	//	return outErr.String(), errors.Wrap(err, "git diff returned an error: "+outErr.String())
	//}

	if err := cmd.Start(); err != nil {
		log.Fatalf("cmd.Start: %v", err)
	}

	if err := cmd.Wait(); err != nil {
		if exiterr, ok := err.(*exec.ExitError); ok {
			log.Printf("Exit Status: %d", exiterr.ExitCode())
		} else {
			log.Fatalf("cmd.Wait: %v", err)
		}
	}

	return out.String(), nil
}

func writeToFile(strings []string) error {
	// open a file for writing
	file, err := os.Create("myfile.txt")
	if err != nil {
		log.Fatalf("failed creating file: %s", err)
	}
	defer file.Close()

	// use buffered writer to write to file
	writer := bufio.NewWriter(file)

	for _, line := range strings {
		_, err := writer.WriteString(line + "\n")
		if err != nil {
			log.Fatalf("failed writing to file: %s", err)
		}
	}

	// use Flush to ensure all buffered operations have been applied to the underlying writer
	writer.Flush()
	return nil
}

func main() {
	app := App{
		Config: AppConfig{
			prDir:     prDir,
			targetDir: targetDir,
			envsDir:   envsDir,
			levels:    levels,
			writePath: tmpPath,
		},
		Logger: log.Default(),
	}

	// finds all apps, regardless of which environment or branch they are in.
	allApps, err := app.buildAllApps()
	if err != nil {
		panic(err)
	}

	diffPaths := make(map[string]struct{})
	for eachApp := range allApps {
		diff, err := app.hasDiff(eachApp)
		if err != nil {
			panic(err)
		}
		if diff {
			diffPaths[eachApp] = struct{}{}
			app.Logger.Println("Diff found: ", eachApp)
		}
	}

	// for each diffPath, we want to build the app for the target and pr branch
	for diffPath := range diffPaths {
		// build the diffPath
		err := app.buildAppForTargetAndPrBranch(diffPath)
		if err != nil {
			panic(err)
		}
		// app.Logger.Println("YAML: ", yaml)
	}

	// for each diffPath, we want to render the diffPath and write it to a file
	renderedTemplates := []string{}
	for diffPath := range diffPaths {
		// build the diffPath
		diff, err := app.renderDiff(diffPath)
		if err != nil {
			panic(err)
		}
		template := template.New(diffRenderTemplate)
		template, err = template.Parse(diffRenderTemplate)
		if err != nil {
			panic(err)
		}

		var buf bytes.Buffer
		err = template.Execute(
			&buf,
			map[string]string{
				"DIFF":  diff,
				"TITLE": diffPath,
			},
		)
		if err != nil {
			panic(err)
		}
		renderedTemplates = append(renderedTemplates, buf.String())
		app.Logger.Println("Rendered diff for: ", diffPath)
	}

	err = writeToFile(renderedTemplates)
	if err != nil {
		panic(err)
	}
}
