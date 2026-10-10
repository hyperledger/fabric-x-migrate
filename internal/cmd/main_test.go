// Copyright the Hyperledger Fabric contributors. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0

package cmd

import (
	"bytes"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestImportInputs(t *testing.T) {
	var out bytes.Buffer
	require.ErrorContains(t, Run([]string{"import"}, &out, &out), "--source-config")
	var paths channelPaths
	require.NoError(t, paths.Set("assets=/snapshot=1"))
	require.NoError(t, paths.Set("securities=/snapshot2"))
	require.Equal(t, "assets=/snapshot=1,securities=/snapshot2", paths.String())
	require.ErrorContains(t, paths.Set("assets=/again"), "more than once")
	require.Error(t, paths.Set("invalid"))
	for _, oldCommand := range []string{"export", "verify", "verify-source"} {
		require.ErrorContains(t, Run([]string{oldCommand}, &out, &out), "usage:")
	}
}
