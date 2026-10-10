// Copyright the Hyperledger Fabric contributors. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0

package fabricsnapshot

type Record struct {
	Namespace string
	Key       []byte
	Value     []byte
	Metadata  []byte
}
