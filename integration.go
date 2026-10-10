// Copyright the Hyperledger Fabric contributors. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0

//go:build integration

package migrate

import (
	"testing"

	"github.com/hyperledger/fabric-x-migrate/internal/integrationtest"
)

const FabricVersion = integrationtest.Version

func CaptureFabricSnapshots(t *testing.T, repository, stateDB string, channels ...string) map[string]string {
	t.Helper()
	return integrationtest.Capture(t, repository, stateDB, channels...)
}
