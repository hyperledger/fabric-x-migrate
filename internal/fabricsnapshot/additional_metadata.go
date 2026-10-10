// Copyright the Hyperledger Fabric contributors. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0

package fabricsnapshot

type AdditionalMetadata struct {
	SnapshotHash        string `json:"snapshot_hash"`
	LastBlockCommitHash string `json:"last_block_commit_hash"`
}
