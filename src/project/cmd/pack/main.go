package main

import (
	"fmt"
	"github.com/markbates/pkger"
	"log"
)

func main() {
	if err := run(); err != nil {
		log.Fatal(err)
	}
}
func run() error {
	info, err := pkger.Stat("/assets/user_build_script")
	if err != nil {
		return err
	}
	fmt.Println("Name: ", info.Name())
	fmt.Println("Size: ", info.Size())
	fmt.Println("Mode: ", info.Mode())
	fmt.Println("ModTime: ", info.ModTime())
	return nil
}
