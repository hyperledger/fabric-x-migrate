// Copyright the Hyperledger Fabric contributors. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0

package main

import (
	"fmt"
	"os"

	migrationcmd "github.com/syndbg/fabric-x-migrate-poc/internal/cmd"
)

func main() {
	if err := migrationcmd.Run(os.Args[1:], os.Stdout, os.Stderr); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}
