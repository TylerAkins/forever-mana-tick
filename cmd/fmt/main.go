// SPDX-License-Identifier: GPL-3.0-or-later
// Adapted from Tyler Akins' forever-quest-markers repository.

// Command fmt runs the Forever Mana Tick development tools.
package main

import (
	"fmt"
	"os"

	"github.com/TylerAkins/forever-mana-tick/internal/addontools"
	"github.com/TylerAkins/forever-mana-tick/internal/foreverupdate"
	"github.com/TylerAkins/forever-mana-tick/internal/release"
)

func main() {
	if len(os.Args) < 2 {
		usage()
	}

	var err error
	switch os.Args[1] {
	case "release":
		err = release.Run(os.Args[2:], os.Stdout)
	case "update-interface":
		err = foreverupdate.Run(os.Args[2:], os.Stdout)
	case "compile-addon":
		err = addontools.RunCompile(os.Args[2:], os.Stdout)
	default:
		usage()
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func usage() {
	fmt.Fprintln(os.Stderr, "usage: fmt <release|update-interface|compile-addon> [options]")
	os.Exit(2)
}
