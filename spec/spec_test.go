package spec_test

import (
	"path/filepath"
	"runtime"

	. "github.com/genesis-community/testkit/v2/testing"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = BeforeSuite(func() {
	_, filename, _, _ := runtime.Caller(0)
	KitDir, _ = filepath.Abs(filepath.Join(filepath.Dir(filename), "../"))
})

var _ = Describe("Squid Kit", func() {

	Describe("standalone", func() {
		Test(Environment{
			Name:        "base",
			CloudConfig: "aws",
			CPI:         "aws",
		})
		Test(Environment{
			Name:        "base-all-params",
			CloudConfig: "aws",
			CPI:         "aws",
		})
	})

	Describe("pve", func() {
		Test(Environment{
			Name:        "pve",
			CloudConfig: "pve",
			CPI:         "pve",
		})
	})

	Describe("ocfp", func() {
		Test(Environment{
			Name:        "ocfp-mgmt",
			CloudConfig: "aws-ocfp",
			CPI:         "aws",
		})
	})

	Describe("resolute", func() {
		Test(Environment{
			Name:        "resolute",
			CloudConfig: "aws",
			CPI:         "aws",
		})
		Test(Environment{
			Name:        "ocfp-resolute-mgmt",
			CloudConfig: "aws-ocfp",
			CPI:         "aws",
		})
		Test(Environment{
			Name:        "resolute-wrong-stemcell-os",
			CloudConfig: "aws",
			CPI:         "aws",
			OutputMatchers: OutputMatchers{
				GenesisAddSecrets: ContainSubstring("stemcell os to"),
				GenesisCheck:      ContainSubstring("stemcell os to"),
				GenesisManifest:   ContainSubstring("stemcell os to"),
			},
		})
		Test(Environment{
			Name:        "resolute-stemcell-without-feature",
			CloudConfig: "aws",
			CPI:         "aws",
			OutputMatchers: OutputMatchers{
				GenesisAddSecrets: ContainSubstring("Enable the feature and remove that parameter"),
				GenesisCheck:      ContainSubstring("Enable the feature and remove that parameter"),
				GenesisManifest:   ContainSubstring("Enable the feature and remove that parameter"),
			},
		})
	})
})
